import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'database_encryption_io.dart';

/// F4-Verschlüsselung, Kay-Entscheidung 2026-10-19: "Verschlüsselung
/// soll optional sein und der User soll entscheiden ob ein Passwort
/// oder ein Geräteschlüssel verwendet wird." Technischer Weg:
/// SQLite3MultipleCiphers über Dart-Build-Hooks (`pubspec.yaml`,
/// `hooks.user_defines.sqlite3.source: sqlite3mc`) — der inzwischen
/// (seit drift 2.32.0) offiziell empfohlene, nicht mehr experimentelle
/// Weg; `sqlcipher_flutter_libs`/`sqlite3_flutter_libs` sind End-of-
/// Life und werden hier bewusst NICHT verwendet. Siehe Doc-Kommentar
/// in `connection.dart` für die Gesamtübersicht.
enum DbKeyType { device, password }

class DbEncryptionConfig {
  const DbEncryptionConfig({required this.enabled, required this.keyType});
  final bool enabled;
  final DbKeyType keyType;

  static const disabled = DbEncryptionConfig(enabled: false, keyType: DbKeyType.device);
}

/// Hält den Schlüssel, mit dem die laufende Session die Datenbank
/// tatsächlich geöffnet hat (`null` = unverschlüsselt) — als Provider
/// in `main.dart` bereitgestellt, damit die Einstellungen beim Ändern
/// der Verschlüsselung (z. B. Passwort ändern, auf Geräteschlüssel
/// wechseln) den bisherigen Schlüssel kennen, ohne den Nutzer erneut
/// danach zu fragen (er hat sich ja bereits für diese Session damit
/// erfolgreich angemeldet).
class ActiveDbKey {
  const ActiveDbKey(this.value);
  final String? value;
}

/// Persistiert, OB und WIE die laufende Datenbank verschlüsselt ist —
/// bewusst NICHT in der Datenbank selbst (man muss ja erst wissen, WIE
/// man sie entschlüsselt, bevor man sie überhaupt öffnen kann) und
/// bewusst NICHT firmenbezogen (die SQLite-Datei enthält alle Firmen
/// gemeinsam, siehe A0-Isolation — Verschlüsselung ist eine Geräte-/
/// App-Einstellung, kein `Companies`-Feld).
///
/// Abstrakt gehalten wie `SmtpCredentialStore` — die echte
/// Implementierung braucht Plattform-Kanäle (`shared_preferences`,
/// `flutter_secure_storage`), die in `flutter test` ohne Mock nicht
/// verfügbar sind.
abstract class DbEncryptionSettingsStore {
  Future<bool> readEnabled();
  Future<void> writeEnabled(bool value);
  Future<DbKeyType> readKeyType();
  Future<void> writeKeyType(DbKeyType value);

  /// Gerätegebundener Schlüssel — wird bei Bedarf einmalig erzeugt und
  /// danach unverändert wiederverwendet, nie neu generiert, solange er
  /// existiert.
  Future<String?> readDeviceKey();
  Future<void> writeDeviceKey(String value);
}

class SecureDbEncryptionSettingsStore extends DbEncryptionSettingsStore {
  SecureDbEncryptionSettingsStore({FlutterSecureStorage? secureStorage})
      : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _secureStorage;

  static const _prefEnabled = 'db_encryption_enabled';
  static const _prefKeyType = 'db_encryption_key_type';
  static const _secureDeviceKeyName = 'db_encryption_device_key';

  @override
  Future<bool> readEnabled() async => (await SharedPreferences.getInstance()).getBool(_prefEnabled) ?? false;

  @override
  Future<void> writeEnabled(bool value) async =>
      (await SharedPreferences.getInstance()).setBool(_prefEnabled, value);

  @override
  Future<DbKeyType> readKeyType() async {
    final stored = (await SharedPreferences.getInstance()).getString(_prefKeyType);
    return stored == DbKeyType.password.name ? DbKeyType.password : DbKeyType.device;
  }

  @override
  Future<void> writeKeyType(DbKeyType value) async =>
      (await SharedPreferences.getInstance()).setString(_prefKeyType, value.name);

  @override
  Future<String?> readDeviceKey() => _secureStorage.read(key: _secureDeviceKeyName);

  @override
  Future<void> writeDeviceKey(String value) => _secureStorage.write(key: _secureDeviceKeyName, value: value);
}

/// Orchestriert Settings-Store + Dateimigration. Die eigentliche
/// Dateizugriffslogik (`rekeyDatabaseFile`/`verifyDatabaseKey`/
/// `resolveDatabaseFilePath`) kommt aus `database_encryption_io.dart`
/// (Web/Native per bedingtem Export getrennt) und wird hier NICHT noch
/// einmal dupliziert, damit sie weiterhin mit echten Dateien testbar
/// bleibt, ohne eine Flutter-Testumgebung zu brauchen.
class DatabaseEncryptionService {
  DatabaseEncryptionService({DbEncryptionSettingsStore? store})
      : _store = store ?? SecureDbEncryptionSettingsStore();

  final DbEncryptionSettingsStore _store;

  Future<DbEncryptionConfig> loadConfig() async {
    final enabled = await _store.readEnabled();
    final keyType = await _store.readKeyType();
    return DbEncryptionConfig(enabled: enabled, keyType: keyType);
  }

  /// Liefert den gerätegebundenen Schlüssel — erzeugt ihn beim ersten
  /// Aufruf (kryptographisch zufällig, 32 Byte/256 Bit, hex-kodiert)
  /// und merkt ihn sich danach unverändert.
  Future<String> deviceKey() async {
    final existing = await _store.readDeviceKey();
    if (existing != null && existing.isNotEmpty) return existing;
    final generated = _generateRandomKey();
    await _store.writeDeviceKey(generated);
    return generated;
  }

  String _generateRandomKey() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Löst den aktuell zu verwendenden Schlüssel auf — `null` bedeutet
  /// "keine Verschlüsselung". Fragt bei [DbKeyType.password] NIEMALS
  /// selbst nach einem Passwort (das ist Aufgabe der UI, z. B. des
  /// Entsperr-Bildschirms beim App-Start) — [password] muss dafür
  /// bereits vorliegen.
  Future<String?> resolveKey({required DbEncryptionConfig config, String? password}) async {
    if (!config.enabled) return null;
    switch (config.keyType) {
      case DbKeyType.device:
        return deviceKey();
      case DbKeyType.password:
        if (password == null || password.isEmpty) {
          throw StateError('Passwort erforderlich, aber nicht übergeben.');
        }
        return password;
    }
  }

  /// Öffnet die Datenbankdatei probeweise mit [password] — für den
  /// Entsperr-Bildschirm beim App-Start und beim Setzen eines neuen
  /// Passworts. Siehe Doc-Kommentar bei `verifyDatabaseKey`.
  Future<bool> verifyPassword({required String dbPath, required String password}) =>
      verifyDatabaseKey(path: dbPath, key: password);

  /// Wendet eine Konfigurationsänderung an: migriert die bestehende
  /// Datenbankdatei (per `PRAGMA rekey`, falls vorhanden) vom aktuell
  /// gültigen Schlüssel [oldKey] (`null` = bisher unverschlüsselt) auf
  /// den neuen Zustand, und speichert die neue Konfiguration erst
  /// NACH erfolgreicher Migration — damit bei einem Fehler nicht eine
  /// Konfiguration gespeichert wird, die nicht zum tatsächlichen
  /// Dateizustand passt.
  ///
  /// Bei [DbKeyType.password] muss [newPassword] gesetzt sein, wenn
  /// [newEnabled] true ist.
  Future<void> applyChange({
    required String dbPath,
    required String? oldKey,
    required bool newEnabled,
    required DbKeyType newKeyType,
    String? newPassword,
  }) async {
    if (newEnabled && newKeyType == DbKeyType.password && (newPassword == null || newPassword.isEmpty)) {
      throw ArgumentError('Für Passwortschutz muss ein Passwort angegeben werden.');
    }

    final String? newKey = !newEnabled
        ? null
        : newKeyType == DbKeyType.device
            ? await deviceKey()
            : newPassword;

    await rekeyDatabaseFile(path: dbPath, oldKey: oldKey, newKey: newKey);

    await _store.writeEnabled(newEnabled);
    await _store.writeKeyType(newKeyType);
  }
}
