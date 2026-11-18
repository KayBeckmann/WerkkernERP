import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';
import 'package:werkkern_client/werkkern_client.dart';

void main() {
  test('sent mail result reports IMAP failure without suggesting SMTP failure', () async {
    final client = WerkkernApiClient(baseUrl: Uri.parse('https://erp.example/api'),
      httpClient: MockClient((request) async {
        expect(request.url.path, '/api/documents/d1/send');
        return http.Response(jsonEncode({
          'sent': true, 'to': 'to@example.org', 'sentCopyConfigured': true,
          'sentCopySaved': false,
          'sentCopyWarning': 'SMTP erfolgreich; Gesendet-Kopie konnte nicht gespeichert werden. Nicht erneut senden.',
        }), 200);
      }));
    final sent = await client.sendDocumentMailWithStatus('d1', Uint8List.fromList('%PDF-1.4'.codeUnits));
    expect(sent.to, 'to@example.org');
    expect(sent.sentCopyWarning, contains('Nicht erneut senden'));
  });

  test('IMAP Gesendet wird gelesen und mit expliziten Feldern gespeichert', () async {
    Map<String, Object?>? payload;
    final client = WerkkernApiClient(baseUrl: Uri.parse('https://erp.example/api'),
      httpClient: MockClient((request) async {
        if (request.method == 'PUT') payload = jsonDecode(request.body) as Map<String, Object?>;
        return http.Response(jsonEncode({
          'available': true, 'host': 'smtp.example.org', 'port': 587,
          'sentImapEnabled': true, 'sentImapHost': 'imap.example.org',
          'sentImapPort': 993, 'sentImapUsername': 'user@example.org',
          'sentImapFolder': 'Sent', 'hasSentImapPassword': true,
        }), 200);
      }));
    final settings = await client.mailSettings();
    expect(settings.sentImapEnabled, isTrue);
    expect(settings.sentImapHost, 'imap.example.org');
    expect(settings.hasSentImapPassword, isTrue);
    await client.saveMailSettings(host: 'smtp.example.org', port: 587,
      username: 'user@example.org', fromAddress: 'user@example.org',
      fromName: null, useTls: true, sentImapEnabled: true,
      sentImapHost: 'imap.example.org', sentImapPort: 993,
      sentImapUsername: 'user@example.org', sentImapFolder: 'Sent',
      sentImapPassword: 'new-password');
    expect(payload?['sentImapHost'], 'imap.example.org');
    expect(payload?['sentImapEnabled'], isTrue);
    expect(payload?['sentImapPassword'], 'new-password');
  });
}
