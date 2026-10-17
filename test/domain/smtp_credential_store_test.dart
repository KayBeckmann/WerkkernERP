import 'package:flutter_test/flutter_test.dart';
import 'package:werkkernerp/domain/services/smtp_credential_store.dart';

/// Einfache In-Memory-Variante für Tests — die echte
/// `SecureSmtpCredentialStore` braucht einen Platform-Channel
/// (Android Keystore/Web WebCrypto), der in `flutter test` ohne Mock
/// nicht verfügbar ist (siehe Doc-Kommentar bei `SmtpCredentialStore`).
class _FakeSmtpCredentialStore extends SmtpCredentialStore {
  final Map<String, String> _passwords = {};

  @override
  Future<String?> readPassword(String companyId) async => _passwords[companyId];

  @override
  Future<void> writePassword(String companyId, String password) async {
    _passwords[companyId] = password;
  }

  @override
  Future<void> deletePassword(String companyId) async {
    _passwords.remove(companyId);
  }
}

void main() {
  test('hasPassword ist standardmäßig aus readPassword abgeleitet (kein Passwort gesetzt)', () async {
    final store = _FakeSmtpCredentialStore();
    expect(await store.hasPassword('company-1'), isFalse);
  });

  test('schreiben/lesen/löschen funktioniert pro Firma getrennt', () async {
    final store = _FakeSmtpCredentialStore();
    await store.writePassword('company-1', 'geheim-1');
    await store.writePassword('company-2', 'geheim-2');

    expect(await store.hasPassword('company-1'), isTrue);
    expect(await store.readPassword('company-1'), 'geheim-1');
    expect(await store.readPassword('company-2'), 'geheim-2');

    await store.deletePassword('company-1');
    expect(await store.hasPassword('company-1'), isFalse);
    expect(await store.readPassword('company-2'), 'geheim-2', reason: 'andere Firma bleibt unberührt');
  });
}
