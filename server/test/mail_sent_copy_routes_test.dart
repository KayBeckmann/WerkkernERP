import 'dart:convert';
import 'dart:typed_data';

import 'package:test/test.dart';
import 'package:werkkernerp_server/src/mail.dart';

import 'support/module_harness.dart';

void main() {
  final smtp = RecordingMailTransport();
  final sent = RecordingSentCopyTransport();
  final key = base64Encode(List<int>.generate(32, (i) => i));
  final h = ModuleHarness(inMemoryRepositories,
      mail: MailService(transport: smtp, sentCopy: sent,
        secrets: SecretSealer.fromBase64(key)))..install();

  setUp(() {
    smtp.sent.clear();
    smtp.failWith = null;
    sent.saved.clear();
    sent.failWith = null;
  });

  Future<CompanyClient> configured(String email) async {
    final c = await h.company(email, permissions: const [
      'invoices.read', 'invoices.write', 'invoices.finalize',
      'customers.read', 'customers.write',
    ], modules: const {'smtp'});
    await c.put('/mail/settings', {
      'host': 'smtp.example.org', 'port': 587,
      'username': 'sender@example.org', 'fromAddress': 'sender@example.org',
      'password': 'smtp-secret', 'sentImapEnabled': true,
      'sentImapHost': 'imap.example.org', 'sentImapPort': 993,
      'sentImapUsername': 'sender@example.org', 'sentImapFolder': 'Sent',
      'sentImapPassword': 'imap-secret',
    });
    return c;
  }

  Future<Map<String, Object?>> invoice(CompanyClient c) async {
    final customer = await c.post('/customers', {'name': 'Test', 'email': 'test@example.org'});
    final d = await c.post('/documents', {'kind': 'invoice', 'customerId': customer['id'], 'items': [
      {'kind': 'text', 'description': 'Leistung', 'quantity': '1', 'unitPriceCents': 10000, 'vatRatePercent': 19},
    ]});
    return c.post('/documents/${d['id']}/finalize', {'version': d['version']});
  }

  final pdf = base64Encode(utf8.encode('%PDF-1.4\n% Test attachment\n'));
  test('success archives PDF, sends once and saves mail copy with exact text and attachment', () async {
    final c = await configured('copy-ok@example.org');
    final d = await invoice(c);
    final r = await c.post('/documents/${d['id']}/send', {
      'pdfBase64': pdf, 'subject': 'Angebot plus Zusatz', 'body': 'Wichtiger Zusatz: Freitag',
    });
    expect(r['sent'], isTrue);
    expect(r['sentCopySaved'], isTrue);
    expect(smtp.sent, hasLength(1));
    expect(sent.saved, hasLength(1));
    expect(sent.saved.single.settings.host, 'imap.example.org');
    expect(sent.saved.single.password, 'imap-secret');
    expect(sent.saved.single.mail.subject, 'Angebot plus Zusatz');
    expect(sent.saved.single.mail.body, 'Wichtiger Zusatz: Freitag');
    expect(sent.saved.single.mail.attachments.single.bytes, Uint8List.fromList(base64Decode(pdf)));
    expect((await c.get('/pdf-archive/document/${d['id']}/versions'))['versions'], hasLength(1));
  });

  test('SMTP failure leaves PDF archived and does not save a sent copy', () async {
    final c = await configured('copy-smtp-fail@example.org');
    final d = await invoice(c);
    smtp.failWith = 'no SMTP';
    await expectLater(c.post('/documents/${d['id']}/send', {'pdfBase64': pdf}), throwsStatus(502));
    expect(sent.saved, isEmpty);
    expect((await c.get('/pdf-archive/document/${d['id']}/versions'))['versions'], hasLength(1));
  });

  test('signed time sheet mail also saves a copy after successful SMTP', () async {
    final c = await configured('copy-sheet@example.org');
    await c.client.setModules({'smtp', 'timeTracking', 'orders'});
    await c.client.setGroupPermission(c.ownGroup, 'timeTracking.write', granted: true);
    final customer = await c.post('/customers', {'name': 'Test', 'email': 'test@example.org'});
    final d = await c.post('/documents', {'kind': 'order', 'customerId': customer['id'], 'items': []});
    final sheet = await c.post('/time-sheets', {'documentId': d['id']});
    final entry = await c.post('/time-entries', {'date': '2026-10-20', 'hours': '2', 'documentId': d['id']});
    await c.post('/time-sheets/${sheet['id']}/entries', {'entryIds': [entry['id']]});
    await c.post('/time-sheets/${sheet['id']}/sign', {'signaturePng': 'iVBORw0KGgo='});
    await c.post('/pdf-archive/time-sheet/${sheet['id']}/versions', {'pdfBase64': pdf});
    final r = await c.post('/time-sheets/${sheet['id']}/send', {'body': 'Hinweis auf Zusatz'});
    expect(r['sentCopySaved'], isTrue);
    expect(smtp.sent, hasLength(1));
    expect(sent.saved.single.mail.body, 'Hinweis auf Zusatz');
    expect(sent.saved.single.mail.attachments.single.bytes, base64Decode(pdf));
  });

  test('IMAP failure reports sent without retrying SMTP', () async {
    final c = await configured('copy-imap-fail@example.org');
    final d = await invoice(c);
    sent.failWith = 'no IMAP';
    final r = await c.post('/documents/${d['id']}/send', {'pdfBase64': pdf});
    expect(r['sent'], isTrue);
    expect(r['sentCopySaved'], isFalse);
    expect(r['sentCopyWarning'], isNotNull);
    expect(smtp.sent, hasLength(1));
    expect(sent.saved, isEmpty);
  });
}
