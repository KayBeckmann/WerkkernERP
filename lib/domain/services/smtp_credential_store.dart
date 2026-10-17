import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Speichert das SMTP-Passwort je Firma getrennt von der SQLite-
/// Datenbank (C7a, Kay-Nachfrage 2026-10-17). Grund: die lokale DB ist
/// (noch) nicht verschlüsselt (siehe F4-Hinweis in `connection.dart`)
/// und wandert unverändert in jedes Backup-Zip — ein Klartext-Passwort
/// dort wäre ein eigenständiges Sicherheitsproblem, unabhängig von F4.
/// `flutter_secure_storage` ist bereits als Abhängigkeit für genau
/// diesen Zweck vorgesehen (Android Keystore / Web WebCrypto+
/// IndexedDB) und funktioniert auf beiden Zielplattformen.
///
/// Abstrakt gehalten, damit Tests eine einfache In-Memory-Variante
/// einsetzen können, statt echte Secure-Storage-Plattform-Channels zu
/// brauchen (die in `flutter test` ohne Mock nicht verfügbar sind).
abstract class SmtpCredentialStore {
  Future<String?> readPassword(String companyId);
  Future<void> writePassword(String companyId, String password);
  Future<void> deletePassword(String companyId);
  Future<bool> hasPassword(String companyId) async => (await readPassword(companyId)) != null;
}

class SecureSmtpCredentialStore extends SmtpCredentialStore {
  SecureSmtpCredentialStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  String _key(String companyId) => 'smtp_password_$companyId';

  @override
  Future<String?> readPassword(String companyId) => _storage.read(key: _key(companyId));

  @override
  Future<void> writePassword(String companyId, String password) =>
      _storage.write(key: _key(companyId), value: password);

  @override
  Future<void> deletePassword(String companyId) => _storage.delete(key: _key(companyId));
}
