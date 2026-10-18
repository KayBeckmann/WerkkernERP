import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3_lib;
import 'package:werkkernerp/domain/services/database_encryption_io.dart';

/// F4-Verschlüsselung (Kay-Entscheidung 2026-10-19). `resolveDatabaseFilePath()`
/// nutzt `path_provider` — ohne echte Plattform liefert das sonst
/// `MissingPluginException`, daher derselbe Fake wie in
/// `backup_service_test.dart`.
class _FakePathProviderPlatform extends PathProviderPlatform {
  final _tempDir = Directory.systemTemp.createTempSync('werkkernerp_encryption_test_');

  @override
  Future<String?> getTemporaryPath() async => _tempDir.path;

  @override
  Future<String?> getApplicationDocumentsPath() async => _tempDir.path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  PathProviderPlatform.instance = _FakePathProviderPlatform();

  late Directory tempDir;
  setUp(() => tempDir = Directory.systemTemp.createTempSync('db_encryption_io_test_'));
  tearDown(() => tempDir.deleteSync(recursive: true));

  test('encryptionSupported ist auf Android/Desktop (dart:io) true', () {
    expect(encryptionSupported, isTrue);
  });

  test(
    'resolveDatabaseFilePath() liefert <applicationDocumentsDirectory>/werkkernerp.sqlite',
    () async {
      final path = await resolveDatabaseFilePath();
      expect(p.basename(path), 'werkkernerp.sqlite');
    },
  );

  test('rekeyDatabaseFile(): existiert die Datei noch nicht, passiert nichts (kein Fehler)', () async {
    final path = p.join(tempDir.path, 'nicht-vorhanden.sqlite');
    await rekeyDatabaseFile(path: path, oldKey: null, newKey: 'irgendein-key');
    expect(File(path).existsSync(), isFalse);
  });

  test(
    'verifyDatabaseKey(): existiert die Datei noch nicht, gilt jeder Schlüssel als gültig',
    () async {
      final path = p.join(tempDir.path, 'nicht-vorhanden.sqlite');
      expect(await verifyDatabaseKey(path: path, key: 'irgendein-key'), isTrue);
      expect(await verifyDatabaseKey(path: path, key: null), isTrue);
    },
  );

  test(
    'Voller Zyklus: unverschlüsselt -> verschlüsseln -> falscher Schlüssel abgelehnt -> '
    'richtiger Schlüssel funktioniert -> entschlüsseln -> wieder ohne Schlüssel lesbar',
    () async {
      final path = p.join(tempDir.path, 'test.sqlite');

      final plain = sqlite3_lib.sqlite3.open(path);
      plain.execute('CREATE TABLE t (v TEXT);');
      plain.execute("INSERT INTO t VALUES ('hallo');");
      plain.close();

      // Verschlüsseln (oldKey null -> vorher unverschlüsselt).
      await rekeyDatabaseFile(path: path, oldKey: null, newKey: 'geheim123');

      expect(await verifyDatabaseKey(path: path, key: null), isFalse, reason: 'ohne Schlüssel nicht mehr lesbar');
      expect(await verifyDatabaseKey(path: path, key: 'falsch'), isFalse);
      expect(await verifyDatabaseKey(path: path, key: 'geheim123'), isTrue);

      // Daten sind nach der Migration unversehrt (mit richtigem Schlüssel lesbar).
      final reopened = sqlite3_lib.sqlite3.open(path);
      reopened.execute("PRAGMA key = 'geheim123';");
      final rows = reopened.select('SELECT * FROM t;');
      expect(rows.single['v'], 'hallo');
      reopened.close();

      // Schlüssel ändern.
      await rekeyDatabaseFile(path: path, oldKey: 'geheim123', newKey: 'neuergeheim456');
      expect(await verifyDatabaseKey(path: path, key: 'geheim123'), isFalse, reason: 'alter Schlüssel greift nicht mehr');
      expect(await verifyDatabaseKey(path: path, key: 'neuergeheim456'), isTrue);

      // Entschlüsseln (newKey null -> Klartext).
      await rekeyDatabaseFile(path: path, oldKey: 'neuergeheim456', newKey: null);
      expect(await verifyDatabaseKey(path: path, key: null), isTrue);

      final plainAgain = sqlite3_lib.sqlite3.open(path);
      final rowsAgain = plainAgain.select('SELECT * FROM t;');
      expect(rowsAgain.single['v'], 'hallo', reason: 'Daten bleiben über den ganzen Zyklus erhalten');
      plainAgain.close();
    },
  );
}
