import 'dart:convert';

import 'package:test/test.dart';
import 'package:werkkernerp_server/src/mail.dart';

import 'support/module_harness.dart';

void main() {
  final key = base64Encode(List<int>.generate(32, (i) => i));
  final h = ModuleHarness(inMemoryRepositories,
    mail: MailService(transport: RecordingMailTransport(), secrets: SecretSealer.fromBase64(key)))..install();

  test('IMAP Gesendet-Konfiguration bleibt pro Firma und Passwort verschlüsselt', () async {
    final a = await h.company('sent-a@example.org', permissions: const []);
    final b = await h.company('sent-b@example.org', permissions: const []);
    final saved = await a.put('/mail/settings', {
      'sentImapEnabled': true,
      'sentImapHost': 'mail.example.org',
      'sentImapPort': 993,
      'sentImapUsername': 'outbox@example.org',
      'sentImapFolder': 'Sent',
      'sentImapPassword': 'imap-test-password',
    });
    expect(saved['sentImapEnabled'], isTrue);
    expect(saved['sentImapHost'], 'mail.example.org');
    expect(saved['sentImapPort'], 993);
    expect(saved['sentImapUsername'], 'outbox@example.org');
    expect(saved['sentImapFolder'], 'Sent');
    expect(saved['hasSentImapPassword'], isTrue);
    expect(saved.toString(), isNot(contains('imap-test-password')));
    final raw = await h.business.getCompanySettings(a.companyId, 'smtp');
    expect(raw['sentImapPasswordSealed'], isA<String>());
    expect(raw.toString(), isNot(contains('imap-test-password')));
    expect((await a.get('/mail/settings'))['hasSentImapPassword'], isTrue);
    expect((await b.get('/mail/settings'))['sentImapEnabled'], isFalse);
    await a.put('/mail/settings', {'sentImapFolder': 'Gesendet'});
    expect((await a.get('/mail/settings'))['sentImapFolder'], 'Gesendet');
    expect((await a.get('/mail/settings'))['hasSentImapPassword'], isTrue);
    await expectLater(a.put('/mail/settings', {'sentImapPort': 0}), throwsStatus(400));
    await expectLater(a.put('/mail/settings', {'sentImapFolder': 'Sent\r\nBAD'}), throwsStatus(400));
  });
}
