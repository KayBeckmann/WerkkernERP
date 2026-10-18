import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as sqlite3_lib;
import 'package:werkkernerp/domain/services/database_encryption_service.dart';

/// Einfache In-Memory-Variante für Tests — die echte
/// `SecureDbEncryptionSettingsStore` braucht `shared_preferences`/
/// `flutter_secure_storage`-Plattform-Kanäle, die in `flutter test`
/// ohne Mock nicht verfügbar sind (siehe Doc-Kommentar bei
/// `DbEncryptionSettingsStore`).
class _FakeDbEncryptionSettingsStore extends DbEncryptionSettingsStore {
  bool enabled = false;
  DbKeyType keyType = DbKeyType.device;
  String? deviceKeyValue;

  @override
  Future<bool> readEnabled() async => enabled;

  @override
  Future<void> writeEnabled(bool value) async => enabled = value;

  @override
  Future<DbKeyType> readKeyType() async => keyType;

  @override
  Future<void> writeKeyType(DbKeyType value) async => keyType = value;

  @override
  Future<String?> readDeviceKey() async => deviceKeyValue;

  @override
  Future<void> writeDeviceKey(String value) async => deviceKeyValue = value;
}

void main() {
  late Directory tempDir;
  late _FakeDbEncryptionSettingsStore store;
  late DatabaseEncryptionService service;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('db_encryption_service_test_');
    store = _FakeDbEncryptionSettingsStore();
    service = DatabaseEncryptionService(store: store);
  });

  tearDown(() => tempDir.deleteSync(recursive: true));

  test('loadConfig(): Default ist deaktiviert (device) — F4 ist standardmäßig aus', () async {
    final config = await service.loadConfig();
    expect(config.enabled, isFalse);
    expect(config.keyType, DbKeyType.device);
  });

  test(
    'deviceKey(): wird beim ersten Aufruf erzeugt und danach unverändert wiederverwendet',
    () async {
      final first = await service.deviceKey();
      expect(first, isNotEmpty);
      final second = await service.deviceKey();
      expect(second, first, reason: 'einmal erzeugt, nicht bei jedem Aufruf neu');
    },
  );

  test('resolveKey(): deaktiviert -> null, unabhängig vom keyType', () async {
    final key = await service.resolveKey(config: const DbEncryptionConfig(enabled: false, keyType: DbKeyType.password));
    expect(key, isNull);
  });

  test('resolveKey(): Geräteschlüssel -> deviceKey(), kein Passwort nötig', () async {
    final key = await service.resolveKey(config: const DbEncryptionConfig(enabled: true, keyType: DbKeyType.device));
    expect(key, await service.deviceKey());
  });

  test('resolveKey(): Passwort ohne übergebenes Passwort wirft StateError', () async {
    expect(
      () => service.resolveKey(config: const DbEncryptionConfig(enabled: true, keyType: DbKeyType.password)),
      throwsStateError,
    );
  });

  test('resolveKey(): Passwort mit übergebenem Passwort liefert es unverändert zurück', () async {
    final key = await service.resolveKey(
      config: const DbEncryptionConfig(enabled: true, keyType: DbKeyType.password),
      password: 'mein-passwort',
    );
    expect(key, 'mein-passwort');
  });

  test(
    'applyChange(): aktiviert Passwortschutz ohne Passwort -> ArgumentError, Konfiguration bleibt '
    'unverändert (nicht gespeichert)',
    () async {
      final dbPath = p.join(tempDir.path, 'test.sqlite');
      expect(
        () => service.applyChange(
          dbPath: dbPath,
          oldKey: null,
          newEnabled: true,
          newKeyType: DbKeyType.password,
        ),
        throwsArgumentError,
      );
      expect(store.enabled, isFalse, reason: 'bei einem Fehler darf keine inkonsistente Konfiguration gespeichert werden');
    },
  );

  test(
    'applyChange(): voller Zyklus über eine echte Datei — unverschlüsselt -> Passwort -> '
    'Geräteschlüssel -> deaktiviert, Konfiguration wird erst NACH erfolgreicher Migration '
    'gespeichert',
    () async {
      final dbPath = p.join(tempDir.path, 'test.sqlite');
      final db = sqlite3_lib.sqlite3.open(dbPath);
      db.execute('CREATE TABLE t (v TEXT);');
      db.execute("INSERT INTO t VALUES ('bestandsdaten');");
      db.close();

      // 1) Unverschlüsselt -> Passwort.
      await service.applyChange(
        dbPath: dbPath,
        oldKey: null,
        newEnabled: true,
        newKeyType: DbKeyType.password,
        newPassword: 'start123',
      );
      expect(store.enabled, isTrue);
      expect(store.keyType, DbKeyType.password);
      expect(await service.verifyPassword(dbPath: dbPath, password: 'start123'), isTrue);
      expect(await service.verifyPassword(dbPath: dbPath, password: 'falsch'), isFalse);

      // 2) Passwort -> Geräteschlüssel (oldKey = bisheriges Passwort).
      await service.applyChange(
        dbPath: dbPath,
        oldKey: 'start123',
        newEnabled: true,
        newKeyType: DbKeyType.device,
      );
      expect(store.keyType, DbKeyType.device);
      final deviceKey = await service.deviceKey();
      expect(await service.verifyPassword(dbPath: dbPath, password: deviceKey), isTrue);
      expect(await service.verifyPassword(dbPath: dbPath, password: 'start123'), isFalse);

      // 3) Geräteschlüssel -> deaktiviert (zurück zu Klartext).
      await service.applyChange(
        dbPath: dbPath,
        oldKey: deviceKey,
        newEnabled: false,
        newKeyType: DbKeyType.device,
      );
      expect(store.enabled, isFalse);
      expect(await service.verifyPassword(dbPath: dbPath, password: ''), isTrue, reason: 'wieder Klartext, jeder "Schlüssel" greift (siehe verifyDatabaseKey-Doku: key wird nur gesetzt, nicht erzwungen)');

      final reopened = sqlite3_lib.sqlite3.open(dbPath);
      final rows = reopened.select('SELECT * FROM t;');
      expect(rows.single['v'], 'bestandsdaten', reason: 'Bestandsdaten bleiben über den ganzen Zyklus erhalten');
      reopened.close();
    },
  );
}
