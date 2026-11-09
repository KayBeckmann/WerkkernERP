import 'dart:convert';

import 'package:test/test.dart';
import 'package:werkkern_client/werkkern_client.dart';
import 'package:werkkernerp_server/src/mail.dart';

import 'support/module_harness.dart';

void main() => runCustomerContactTests(inMemoryRepositories);

final _pdf = base64Encode(utf8.encode('%PDF-1.4\n% Test\n'));
final _key = base64Encode(List<int>.generate(32, (i) => i));

/// Kontaktpersonen je Kunde, Rechnungs-E-Mail und Empfänger-Reihenfolge
/// beim Versand (Kay 2026-11-09).
void runCustomerContactTests(RepositoryFactory create) {
  final transport = RecordingMailTransport();
  final h = ModuleHarness(create, mail: MailService(transport: transport, secrets: SecretSealer.fromBase64(_key)))..install();
  setUp(() => transport.sent.clear());
  const permissions = [
    'customers.read', 'customers.write', 'invoices.read', 'invoices.write', 'invoices.finalize', 'invoices.payment',
    'dunning.read', 'dunning.write',
  ];
  Matcher status(int code) => throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', code));

  Future<CompanyClient> configured(String email) async {
    final c = await h.company(email, permissions: permissions, modules: {'smtp', 'quotes', 'orders', 'dunning'});
    await c.put('/mail/settings', {'host': 'smtp.example.org', 'fromAddress': 'rechnung@elektro.example'});
    return c;
  }

  Future<Map<String, Object?>> remondis(CompanyClient c) => c.post('/customers', {
        'name': 'Remondis',
        'email': 'info@remondis.example',
        'phone': '0201 123',
        'invoiceEmail': 'rechnung@remondis.example',
        'contacts': [
          {'name': 'Vincent', 'role': 'Betriebstechniker', 'email': 'vincent@remondis.example', 'phone': '0171 111'},
          {'name': 'Annika', 'role': 'Buchhaltung', 'email': 'annika@remondis.example'},
        ],
      });

  String contactId(Map<String, Object?> customer, String name) =>
      ((customer['contacts'] as List).cast<Map>().firstWhere((x) => x['name'] == name))['id'] as String;

  test('Kontaktpersonen anlegen, ändern, entfernen — ältere App-Fassungen löschen nichts', () async {
    final c = await configured('k@example.com');
    final created = await remondis(c);
    expect([for (final x in created['contacts'] as List) ((x as Map)['name'], x['role'])],
        [('Vincent', 'Betriebstechniker'), ('Annika', 'Buchhaltung')]);
    expect(created['invoiceEmail'], 'rechnung@remondis.example');
    final vincent = contactId(created, 'Vincent');

    // Ändern behält die ID, neue bekommen eine, fehlende entfallen.
    final updated = await c.put('/customers/${created['id']}', {
      'name': 'Remondis',
      'contacts': [
        {'id': vincent, 'name': 'Vincent', 'role': 'Betriebsleiter', 'phone': '0171 222'},
        {'name': 'Jonas', 'role': 'Lager'},
      ],
    });
    expect(contactId(updated, 'Vincent'), vincent);
    expect([for (final x in updated['contacts'] as List) (x as Map)['name']], ['Vincent', 'Jonas']);
    expect(updated['invoiceEmail'], 'rechnung@remondis.example', reason: 'nicht genannt = unverändert');

    // Altes Format ohne contacts/invoiceEmail.
    final legacy = await c.put('/customers/${created['id']}', {'name': 'Remondis GmbH', 'email': 'info@remondis.example'});
    expect([for (final x in legacy['contacts'] as List) (x as Map)['name']], ['Vincent', 'Jonas']);
    expect(legacy['invoiceEmail'], 'rechnung@remondis.example');

    // Erfundene IDs werden nicht übernommen, ungültige Angaben abgelehnt.
    final other = await c.post('/customers', {'name': 'Andere', 'contacts': [{'name': 'Fremd'}]});
    final fremd = contactId(other, 'Fremd');
    final hijack = await c.put('/customers/${created['id']}', {
      'name': 'Remondis GmbH',
      'contacts': [{'id': fremd, 'name': 'Übernahme'}],
    });
    expect(contactId(hijack, 'Übernahme'), isNot(fremd));
    expect(contactId(await c.get('/customers/${other['id']}'), 'Fremd'), fremd, reason: 'fremder Kontakt unberührt');
    await expectLater(c.put('/customers/${created['id']}', {'name': 'X', 'contacts': [{'role': 'ohne Namen'}]}), status(400));
    await expectLater(c.put('/customers/${created['id']}', {'name': 'X', 'invoiceEmail': 'keine-adresse'}), status(400));

    final listed = ((await c.get('/customers'))['customers'] as List).cast<Map>().firstWhere((x) => x['id'] == created['id']);
    expect((listed['contacts'] as List).single['name'], 'Übernahme');
  });

  test('Kontaktperson am Dokument: nur vom eigenen Kunden, wandert bei Umwandlung mit', () async {
    final c = await configured('k2@example.com');
    final customer = await remondis(c);
    final other = await c.post('/customers', {'name': 'Andere', 'contacts': [{'name': 'Fremd'}]});
    final vincent = contactId(customer, 'Vincent');

    await expectLater(
      c.post('/documents', {'kind': 'quote', 'customerId': customer['id'], 'contactId': contactId(other, 'Fremd'), 'items': []}),
      status(400),
    );
    final quote = await c.post('/documents', {'kind': 'quote', 'customerId': customer['id'], 'contactId': vincent, 'items': []});
    expect(quote['contactId'], vincent);

    // Ohne contactId bleibt die Zuordnung, mit null wird sie entfernt.
    final kept = await c.put('/documents/${quote['id']}', {'version': quote['version'], 'notes': 'x', 'items': []});
    expect(kept['contactId'], vincent);
    final cleared = await c.put('/documents/${quote['id']}', {'version': kept['version'], 'contactId': null, 'items': []});
    expect(cleared['contactId'], isNull);
    final again = await c.put('/documents/${quote['id']}', {
      'version': cleared['version'],
      'contactId': vincent,
      'items': [
        {'kind': 'text', 'description': 'Leistung', 'quantity': '1', 'unitPriceCents': 10000, 'vatRatePercent': 19},
      ],
    });

    // Kundenwechsel im Entwurf: Kontakt des alten Kunden entfällt.
    final draft = await c.post('/documents', {'kind': 'order', 'customerId': customer['id'], 'contactId': vincent, 'items': []});
    final switched = await c.put('/documents/${draft['id']}', {'version': draft['version'], 'customerId': other['id'], 'items': []});
    expect(switched['contactId'], isNull);

    final finalized = await c.post('/documents/${quote['id']}/finalize', {'version': again['version']});
    final order = await c.post('/documents/${finalized['id']}/convert', {'kind': 'order'});
    expect(order['contactId'], vincent);
  });

  test('Empfänger: Rechnungs-E-Mail → Kontaktperson → Kunde; Angebot ohne Rechnungs-E-Mail', () async {
    final c = await configured('k3@example.com');
    final customer = await remondis(c);
    final vincent = contactId(customer, 'Vincent');
    Future<Map<String, Object?>> finalized(String kind, {String? contact}) async {
      final draft = await c.post('/documents', {
        'kind': kind,
        'customerId': customer['id'],
        'contactId': ?contact,
        'items': [
          {'kind': 'text', 'description': 'Leistung', 'quantity': '1', 'unitPriceCents': 10000, 'vatRatePercent': 19},
        ],
      });
      return c.post('/documents/${draft['id']}/finalize', {'version': draft['version']});
    }

    Future<String> sendTo(Map<String, Object?> document) async =>
        (await c.post('/documents/${document['id']}/send', {'pdfBase64': _pdf}))['to'] as String;

    final quote = await finalized('quote', contact: vincent);
    final invoice = await finalized('invoice', contact: vincent);
    final plainInvoice = await finalized('invoice');
    expect(await sendTo(quote), 'vincent@remondis.example', reason: 'Angebot an die Kontaktperson');
    expect(await sendTo(invoice), 'rechnung@remondis.example', reason: 'Rechnungs-E-Mail hat Vorrang');

    // Mahnung geht ebenfalls an die Rechnungs-E-Mail.
    final due = DateTime.now().toUtc().subtract(const Duration(days: 20));
    await c.put('/documents/${invoice['id']}/due-date', {
      'dueDate': '${due.year}-${due.month.toString().padLeft(2, '0')}-${due.day.toString().padLeft(2, '0')}',
    });
    final notice = await c.post('/documents/${invoice['id']}/dunning-notices');
    await c.post('/dunning-notices/${notice['id']}/send', {'pdfBase64': _pdf});
    expect(transport.sent.last.mail.to, 'rechnung@remondis.example');

    await c.put('/customers/${customer['id']}', {'name': 'Remondis', 'email': 'info@remondis.example', 'invoiceEmail': null});
    expect(await sendTo(invoice), 'vincent@remondis.example', reason: 'ohne Rechnungs-E-Mail: Kontaktperson');
    expect(await sendTo(plainInvoice), 'info@remondis.example', reason: 'ohne Kontaktperson: allgemeine E-Mail');

    // Kontaktperson gelöscht: Dokument verliert nur die Zuordnung.
    await c.put('/customers/${customer['id']}', {'name': 'Remondis', 'email': 'info@remondis.example', 'contacts': []});
    expect((await c.get('/documents/${invoice['id']}'))['contactId'], isNull);
    expect(await sendTo(invoice), 'info@remondis.example');
  });
}
