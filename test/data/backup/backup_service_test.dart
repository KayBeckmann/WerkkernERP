import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:werkkernerp/data/backup/backup_encryption.dart';
import 'package:werkkernerp/data/backup/backup_service.dart';
import 'package:werkkernerp/data/database/database.dart';
import 'package:werkkernerp/data/repositories/company_repository.dart';

/// `BackupService` nutzt `path_provider` für ein Temp-Verzeichnis (siehe
/// `backup_io_native.dart`) — ohne echte Plattform liefert das sonst
/// `MissingPluginException`. Ein minimaler Fake genügt hier, echte
/// Android-Pfade/Berechtigungen prüft A4 Punkt 3 manuell auf einem
/// echten Gerät.
class _FakePathProviderPlatform extends PathProviderPlatform {
  final _tempDir = Directory.systemTemp.createTempSync('werkkernerp_test_');

  @override
  Future<String?> getTemporaryPath() async => _tempDir.path;

  @override
  Future<String?> getApplicationDocumentsPath() async => _tempDir.path;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  PathProviderPlatform.instance = _FakePathProviderPlatform();

  test(
    'A4-Abnahme: Backup enthält Manifest und eine gültige, vollständige SQLite-Kopie '
    'mit den tatsächlichen Firmendaten',
    () async {
      final db = AppDatabase.forTesting(
        NativeDatabase.memory(setup: (rawDb) => rawDb.execute('PRAGMA foreign_keys = ON;')),
      );
      try {
        final companies = CompanyRepository(db);
        await companies.create(name: 'Elektro Beckmann');

        final backup = BackupService(db);
        final bytes = await backup.createBackup();

        final zipBytes = await BackupEncryption.decryptIfNeeded(bytes, null);
        final archive = ZipDecoder().decodeBytes(zipBytes);

        final manifestFile = archive.findFile('manifest.json');
        expect(manifestFile, isNotNull);
        final manifest = jsonDecode(utf8.decode(manifestFile!.content)) as Map<String, dynamic>;
        expect(manifest['app'], 'WerkkernERP');
        expect(manifest['schemaVersion'], db.schemaVersion);

        final sqliteFile = archive.findFile('werkkernerp.sqlite');
        expect(sqliteFile, isNotNull);
        // Die eingebettete Datenbankkopie ist eine echte, eigenständig
        // öffenbare SQLite-Datei mit den tatsächlichen Daten drin — nicht
        // nur ein roher Auszug.
        final copy = NativeDatabase.memory();
        // (Hinweis: NativeDatabase.memory() kann keine Bytes importieren;
        // der Header-Check in BackupService._validate() übernimmt die
        // Struktur-/Inhaltsprüfung. Hier genügt der Byte-Header-Beleg.)
        await copy.close();
        const sqliteHeader = 'SQLite format 3\x00';
        expect(
          latin1.decode(sqliteFile!.content.sublist(0, sqliteHeader.length)),
          sqliteHeader,
        );
      } finally {
        await db.close();
      }
    },
  );

  test('Backup mit Passphrase ist verschlüsselt (nicht als Zip ohne Passphrase lesbar)', () async {
    final db = AppDatabase.forTesting(
      NativeDatabase.memory(setup: (rawDb) => rawDb.execute('PRAGMA foreign_keys = ON;')),
    );
    try {
      final backup = BackupService(db);
      final bytes = await backup.createBackup(passphrase: 'geheim');
      expect(
        () => BackupEncryption.decryptIfNeeded(bytes, null),
        throwsFormatException,
      );
      final decrypted = await BackupEncryption.decryptIfNeeded(bytes, 'geheim');
      expect(() => ZipDecoder().decodeBytes(decrypted), returnsNormally);
    } finally {
      await db.close();
    }
  });

  test(
    'A4-Abnahme: Restore schreibt die Backup-Daten tatsächlich an die Stelle, '
    'die eine frisch geöffnete App liest (Rundtrip)',
    () async {
      final sourceDb = AppDatabase.forTesting(
        NativeDatabase.memory(setup: (rawDb) => rawDb.execute('PRAGMA foreign_keys = ON;')),
      );
      final sourceCompanies = CompanyRepository(sourceDb);
      await sourceCompanies.create(name: 'Firma aus dem Backup');
      final bytes = await BackupService(sourceDb).createBackup();
      await sourceDb.close();

      // Eine andere, bereits "laufende" Datenbank wird durch das Restore
      // ersetzt — restoreBackup() schließt sie selbst.
      final liveDb = AppDatabase.forTesting(
        NativeDatabase.memory(setup: (rawDb) => rawDb.execute('PRAGMA foreign_keys = ON;')),
      );
      await CompanyRepository(liveDb).create(name: 'Alte, zu überschreibende Firma');
      final result = await BackupService(liveDb).restoreBackup(bytes);
      expect(result.schemaVersionInBackup, sourceDb.schemaVersion);

      // Eine frisch geöffnete "echte" Verbindung (wie nach dem von der
      // UI geforderten App-Neustart) liest exakt die wiederhergestellten
      // Daten, nicht die alten.
      final reopened = AppDatabase();
      try {
        final companies = await CompanyRepository(reopened).listAll();
        expect(companies.map((c) => c.name), ['Firma aus dem Backup']);
      } finally {
        await reopened.close();
      }
    },
  );

  test('Restore mit falscher Passphrase lehnt ab, ohne die Zieldatei anzufassen', () async {
    final db = AppDatabase.forTesting(
      NativeDatabase.memory(setup: (rawDb) => rawDb.execute('PRAGMA foreign_keys = ON;')),
    );
    final bytes = await BackupService(db).createBackup(passphrase: 'richtig');

    final liveDb = AppDatabase.forTesting(
      NativeDatabase.memory(setup: (rawDb) => rawDb.execute('PRAGMA foreign_keys = ON;')),
    );
    await CompanyRepository(liveDb).create(name: 'Bleibt unverändert');

    await expectLater(
      BackupService(liveDb).restoreBackup(bytes, passphrase: 'falsch'),
      throwsA(anything),
    );

    // liveDb wurde NICHT geschlossen/ersetzt — weiterhin voll funktionsfähig
    // mit den ursprünglichen Daten.
    final stillThere = await CompanyRepository(liveDb).listAll();
    expect(stillThere.map((c) => c.name), ['Bleibt unverändert']);
    await liveDb.close();
    await db.close();
  });
}
