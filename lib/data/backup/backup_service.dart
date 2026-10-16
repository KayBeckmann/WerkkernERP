import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:drift/drift.dart';

import '../database/database.dart';
import 'backup_encryption.dart';
import 'backup_io.dart';

const _manifestEntryName = 'manifest.json';
const _sqliteEntryName = 'werkkernerp.sqlite';
const _manifestFormatVersion = 1;

/// Ergebnis einer erfolgreichen Wiederherstellung — die App muss danach
/// neu gestartet werden, da die aktive Datenbankverbindung bereits
/// geschlossen und die Datei ausgetauscht wurde.
class RestoreResult {
  const RestoreResult({required this.exportedAt, required this.schemaVersionInBackup});
  final DateTime exportedAt;
  final int schemaVersionInBackup;
}

/// Lokales Backup/Restore (A4) — kein automatischer Cloud-Upload, keine
/// stillschweigende Überschreibung. Nur auf Android/Desktop verfügbar
/// ([backupSupported]); im Web-Build bewusst deaktiviert (siehe
/// `backup_io_web.dart`).
class BackupService {
  BackupService(this._db);

  final AppDatabase _db;

  bool get isSupported => backupSupported;

  /// Erzeugt die Backup-Datei als Bytes (zum Speichern über die
  /// Android-Dateiauswahl durch den Aufrufer — dieser Service schreibt
  /// selbst keine Datei außerhalb des eigenen Temp-Verzeichnisses).
  /// [passphrase] ist optional; `null`/leer bedeutet unverschlüsseltes
  /// Backup (siehe `BackupEncryption`-Doc für die Begründung).
  Future<Uint8List> createBackup({String? passphrase}) async {
    if (!backupSupported) {
      throw UnsupportedError('Backup ist auf dieser Plattform nicht verfügbar.');
    }

    final dbBytes = await readTempVacuumFile(
      (path) => _db.customStatement("VACUUM INTO '${_escapeSqlLiteral(path)}'"),
    );

    final manifest = jsonEncode({
      'app': 'WerkkernERP',
      'format': _manifestFormatVersion,
      'schemaVersion': _db.schemaVersion,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
    });

    final archive = Archive()
      ..addFile(ArchiveFile(_manifestEntryName, utf8.encode(manifest).length, utf8.encode(manifest)))
      ..addFile(ArchiveFile(_sqliteEntryName, dbBytes.length, dbBytes));

    final zipBytes = Uint8List.fromList(ZipEncoder().encode(archive));
    return BackupEncryption.encryptIfRequested(zipBytes, passphrase);
  }

  /// Prüft und entpackt [fileBytes] **ohne** die Live-Daten anzufassen.
  /// Wirft [FormatException] bei unbekanntem/beschädigtem Format oder
  /// falscher Passphrase — der Aufrufer zeigt das als verständlichen
  /// Fehler, die aktuellen Daten bleiben unverändert (A4: "kein stilles
  /// Überschreiben").
  Future<_ValidatedBackup> _validate(Uint8List fileBytes, String? passphrase) async {
    final zipBytes = await BackupEncryption.decryptIfNeeded(fileBytes, passphrase);

    late final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(zipBytes);
    } on ArchiveException catch (e) {
      throw FormatException('Backup-Datei ist kein gültiges Archiv: ${e.message}');
    }

    final manifestFile = archive.findFile(_manifestEntryName);
    final sqliteFile = archive.findFile(_sqliteEntryName);
    if (manifestFile == null || sqliteFile == null) {
      throw const FormatException('Backup-Datei ist unvollständig (Manifest oder Datenbank fehlt).');
    }

    late final Map<String, dynamic> manifest;
    try {
      manifest = jsonDecode(utf8.decode(manifestFile.content)) as Map<String, dynamic>;
    } on FormatException {
      throw const FormatException('Manifest in der Backup-Datei ist beschädigt.');
    }

    if (manifest['app'] != 'WerkkernERP') {
      throw const FormatException('Diese Datei stammt nicht aus WerkkernERP.');
    }
    final format = manifest['format'];
    if (format != _manifestFormatVersion) {
      throw FormatException(
        'Unbekanntes Backup-Format ($format) — vermutlich eine andere App-Version. '
        'Während der Entwicklung ist keine Abwärtskompatibilität zugesagt.',
      );
    }

    final sqliteBytes = sqliteFile.content;
    // SQLite-Dateien beginnen mit dieser 16-Byte-Signatur — eine letzte
    // Plausibilitätsprüfung, bevor die Datei als Datenbank behandelt wird.
    const sqliteHeader = 'SQLite format 3\x00';
    if (sqliteBytes.length < sqliteHeader.length ||
        latin1.decode(sqliteBytes.sublist(0, sqliteHeader.length)) != sqliteHeader) {
      throw const FormatException('Enthaltene Datenbankdatei ist beschädigt (ungültiger Header).');
    }

    return _ValidatedBackup(
      sqliteBytes: sqliteBytes,
      exportedAt: DateTime.parse(manifest['exportedAt'] as String),
      schemaVersionInBackup: manifest['schemaVersion'] as int,
    );
  }

  /// Validiert [fileBytes] vollständig **vor** jedem Eingriff in die
  /// Live-Daten. Schließt danach die aktive Verbindung und überschreibt
  /// die Datenbankdatei — die App muss anschließend neu gestartet
  /// werden (kein Inprozess-Hotswap der offenen Verbindung, um keinen
  /// inkonsistenten Zustand zwischen Provider-Baum und Datei zu
  /// riskieren).
  Future<RestoreResult> restoreBackup(Uint8List fileBytes, {String? passphrase}) async {
    if (!backupSupported) {
      throw UnsupportedError('Restore ist auf dieser Plattform nicht verfügbar.');
    }

    final validated = await _validate(fileBytes, passphrase);

    await _db.close();
    final path = await resolveDatabaseFilePath();
    await writeDatabaseFile(path, validated.sqliteBytes);

    return RestoreResult(
      exportedAt: validated.exportedAt,
      schemaVersionInBackup: validated.schemaVersionInBackup,
    );
  }

  String _escapeSqlLiteral(String value) => value.replaceAll("'", "''");
}

class _ValidatedBackup {
  const _ValidatedBackup({
    required this.sqliteBytes,
    required this.exportedAt,
    required this.schemaVersionInBackup,
  });
  final Uint8List sqliteBytes;
  final DateTime exportedAt;
  final int schemaVersionInBackup;
}
