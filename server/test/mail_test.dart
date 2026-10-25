import 'dart:convert';

import 'package:test/test.dart';
import 'package:werkkernerp_server/src/mail.dart';

import 'support/module_harness.dart';

void main() => runMailTests(inMemoryRepositories);

final _pdf = base64Encode(utf8.encode('%PDF-1.4\n% Test\n'));
final _key = base64Encode(List<int>.generate(32, (i) => i));

/// Mailversand über den Server.
void runMailTests(RepositoryFactory create) {
  final transport = RecordingMailTransport();
  final h = ModuleHarness(create, mail: MailService(transport: transport, secrets: SecretSealer.fromBase64(_key)))..install();
  setUp(() {
    transport.sent.clear();
    transport.failWith = null;
  });
  const permissions = [
    'customers.read', 'customers.write', 'invoices.read', 'invoices.write', 'invoices.finalize', 'invoices.payment',
    'dunning.read', 'dunning.write', 'articles.read', 'articles.write', 'purchaseOrders.read', 'purchaseOrders.write',
  ];
  const modules = {'smtp', 'dunning', 'bestellwesen', 'lagerbestand'};

  Future<CompanyClient> configured(String email) async {
    final c = await h.company(email, permissions: permissions, modules: modules);
    await c.put('/mail/settings', {
      'host': 'smtp.example.org',
      'port': 587,
      'username': 'rechnung@elektro.example',
      'password': 'geheim-123',
      'fromAddress': 'rechnung@elektro.example',
      'fromName': 'Elektro Kay',
    });
    return c;
  }

  Future<Map<String, Object?>> finalizedInvoice(CompanyClient c, {String? customerEmail = 'meyer@example.com'}) async {
    final customer = await c.post('/customers', {'name': 'Meyer', 'email': customerEmail});
    final draft = await c.post('/documents', {
      'kind': 'invoice',
      'customerId': customer['id'],
      'items': [
        {'kind': 'text', 'description': 'Leistung', 'quantity': '1', 'unitPriceCents': 10000, 'vatRatePercent': 19},
      ],
    });
    return c.post('/documents/${draft['id']}/finalize', {'version': draft['version']});
  }

  test('Einstellungen nur für Admins, Passwort verschlüsselt und nie zurückgegeben', () async {
    final c = await configured('a@example.com');
    final settings = await c.get('/mail/settings');
    expect(settings['hasPassword'], isTrue);
    expect(settings.toString(), isNot(contains('geheim-123')));
    expect((settings['templates'] as Map)['documentSubject'], '{{firma}}: {{nummer}}');
    final raw = await h.business.getCompanySettings(c.companyId, 'smtp');
    expect(raw['passwordSealed'], isNot('geheim-123'));
    expect(raw.toString(), isNot(contains('geheim-123')));
    await expectLater(c.put('/mail/settings', {'port': 0}), throwsStatus(400));
    await expectLater(c.put('/mail/settings', {'templates': {'unbekannt': 'x'}}), throwsStatus(400));

    final member = await h.member(c, 'monteur@example.com');
    await expectLater(member.request('GET', '/mail/settings'), throwsStatus(403));

    // Leeres Passwort entfernt es.
    await c.put('/mail/settings', {'password': ''});
    expect((await c.get('/mail/settings'))['hasPassword'], isFalse);
  });

  test('Dokument versenden: Kunde als Vorgabe, Platzhalter, PDF-Anhang, entschlüsseltes Passwort, nur finalisiert', () async {
    final c = await configured('a@example.com');
    await c.put('/mail/settings', {'templates': {'documentSubject': 'Rechnung {{nummer}} von {{firma}}'}});
    final invoice = await finalizedInvoice(c);
    final result = await c.post('/documents/${invoice['id']}/send', {'pdfBase64': _pdf});
    expect(result['to'], 'meyer@example.com');
    final sent = transport.sent.single;
    expect(sent.mail.subject, 'Rechnung ${invoice['number']} von Firma a@example.com');
    expect(sent.mail.body, contains('Guten Tag Meyer'));
    expect(sent.mail.attachments.single.fileName, '${invoice['number']}.pdf');
    expect(sent.password, 'geheim-123');
    expect(sent.settings.host, 'smtp.example.org');

    await c.post('/documents/${invoice['id']}/send', {'pdfBase64': _pdf, 'to': 'buchhaltung@meyer.example', 'subject': 'Eigener Betreff'});
    expect(transport.sent.last.mail.to, 'buchhaltung@meyer.example');
    expect(transport.sent.last.mail.subject, 'Eigener Betreff');

    await expectLater(c.post('/documents/${invoice['id']}/send', {'pdfBase64': base64Encode(utf8.encode('kein pdf'))}), throwsStatus(400));
    final customer = await c.post('/customers', {'name': 'Ohne Mail'});
    final draft = await c.post('/documents', {'kind': 'invoice', 'customerId': customer['id'], 'items': []});
    await expectLater(c.post('/documents/${draft['id']}/send', {'pdfBase64': _pdf}), throwsStatus(409));
    final noMail = await finalizedInvoice(c, customerEmail: null);
    await expectLater(c.post('/documents/${noMail['id']}/send', {'pdfBase64': _pdf}), throwsStatus(400));

    transport.failWith = 'Verbindung abgelehnt';
    await expectLater(c.post('/documents/${invoice['id']}/send', {'pdfBase64': _pdf}), throwsStatus(502));
    final audit = await c.client.audit();
    expect(audit.where((a) => a.action == 'mail.document'), hasLength(2));
  });

  test('Mahnung versenden markiert sie als versendet; Bestellung geht an den Lieferanten', () async {
    final c = await configured('a@example.com');
    final invoice = await finalizedInvoice(c);
    final due = DateTime.now().toUtc().subtract(const Duration(days: 20));
    await c.put('/documents/${invoice['id']}/due-date', {'dueDate': '${due.year}-${due.month.toString().padLeft(2, '0')}-${due.day.toString().padLeft(2, '0')}'});
    final notice = await c.post('/documents/${invoice['id']}/dunning-notices');
    await c.post('/dunning-notices/${notice['id']}/send', {'pdfBase64': _pdf});
    expect(transport.sent.single.mail.subject, 'Mahnung: ${invoice['number']}');
    final notices = (await c.get('/documents/${invoice['id']}/dunning-notices'))['notices'] as List;
    expect((notices.single as Map)['sentAt'], isNotNull);

    final supplier = await c.post('/suppliers', {'name': 'Nord', 'email': 'bestellung@nord.example'});
    final draft = await c.post('/purchase-orders', {'supplierId': supplier['id'], 'items': [{'description': 'Kabel', 'quantity': '1'}]});
    await expectLater(c.post('/purchase-orders/${draft['id']}/send', {'pdfBase64': _pdf}), throwsStatus(409));
    final order = await c.post('/purchase-orders/${draft['id']}/finalize', {'version': draft['version']});
    await c.post('/purchase-orders/${draft['id']}/send', {'pdfBase64': _pdf});
    expect(transport.sent.last.mail.to, 'bestellung@nord.example');
    expect(transport.sent.last.mail.subject, contains(order['number'] as String));
  });

  test('Einladung per Mail enthält den Code; ohne Modul bleibt sie gültig mit Hinweis', () async {
    final c = await configured('a@example.com');
    final invitation = await c.post('/invitations', {'email': 'neu@example.com', 'groupId': c.groups['Monteur'], 'sendEmail': true});
    expect(invitation['emailSent'], isTrue);
    expect(transport.sent.single.mail.to, 'neu@example.com');
    expect(transport.sent.single.mail.body, contains(invitation['invitationToken'] as String));

    await c.client.setModules({});
    final second = await c.post('/invitations', {'email': 'zwei@example.com', 'groupId': c.groups['Monteur'], 'sendEmail': true});
    expect(second['emailSent'], isFalse);
    expect(second['emailError'], contains('smtp'));
    expect(second['invitationToken'], isNotEmpty);
  });

  test('Rechte, Modul, Firmentrennung', () async {
    final a = await configured('a@example.com');
    final b = await configured('b@example.com');
    final invoice = await finalizedInvoice(a);
    await expectLater(b.post('/documents/${invoice['id']}/send', {'pdfBase64': _pdf}), throwsStatus(404));
    await a.client.setModules({'dunning'});
    await expectLater(a.post('/documents/${invoice['id']}/send', {'pdfBase64': _pdf}), throwsStatus(403));
    final unconfigured = await h.company('u@example.com', permissions: permissions, modules: modules);
    final own = await finalizedInvoice(unconfigured);
    await expectLater(unconfigured.post('/documents/${own['id']}/send', {'pdfBase64': _pdf}), throwsStatus(409));
    expect(transport.sent, isEmpty);
  });

  group('Server ohne WERKKERN_SECRET_KEY', () {
    final bare = ModuleHarness(create, mail: MailService(transport: transport))..install();
    test('Passwort wird nicht angenommen, Versand verständlich abgelehnt', () async {
      final c = await bare.company('x@example.com', permissions: permissions, modules: modules);
      expect((await c.get('/mail/settings'))['available'], isFalse);
      await expectLater(c.put('/mail/settings', {'password': 'geheim'}), throwsStatus(409));
      await c.put('/mail/settings', {'host': 'smtp.example.org', 'fromAddress': 'a@example.org'});
      await expectLater(c.post('/mail/test', {'to': 'b@example.org'}), throwsStatus(409));
    });
  });
}
