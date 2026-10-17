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

/// Ein Fehler beim Dateiaustausch **nach** dem Schließen der aktiven
/// Verbindung — siehe Doc-Kommentar bei [BackupService.restoreBackup].
class RestoreWriteException implements Exception {
  const RestoreWriteException(this.message);
  final String message;

  @override
  String toString() => message;
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

    // Audit-Befund 2026-10-17 (Abweichungen.md Abschnitt 2.2): das
    // Manifest führte schemaVersion, wurde aber nie mit der tatsächlich
    // laufenden Datenbankversion verglichen. Eine Backup-Datei aus einer
    // NEUEREN App-Version könnte Spalten/Tabellen enthalten, die diese
    // Version noch nicht kennt — klar abweisen statt es zu versuchen.
    // Ein ÄLTERES Backup ist dagegen unkritisch: drifts eigene
    // `onUpgrade`-Migration läuft beim nächsten Öffnen der
    // wiederhergestellten Datei ganz normal durch (exakt der bereits
    // getestete Pfad in `database_migration_test.dart`).
    final schemaVersionInBackup = manifest['schemaVersion'] as int;
    if (schemaVersionInBackup > _db.schemaVersion) {
      throw FormatException(
        'Dieses Backup stammt von einer neueren App-Version (Schema $schemaVersionInBackup, '
        'diese App kennt nur bis ${_db.schemaVersion}). Bitte zuerst WerkkernERP aktualisieren.',
      );
    }

    final sqliteBytes = sqliteFile.content;
    // SQLite-Dateien beginnen mit dieser 16-Byte-Signatur — eine erste
    // Plausibilitätsprüfung, bevor die Datei überhaupt als Kandidat
    // behandelt wird.
    const sqliteHeader = 'SQLite format 3\x00';
    if (sqliteBytes.length < sqliteHeader.length ||
        latin1.decode(sqliteBytes.sublist(0, sqliteHeader.length)) != sqliteHeader) {
      throw const FormatException('Enthaltene Datenbankdatei ist beschädigt (ungültiger Header).');
    }

    // Audit-Befund 2026-10-17: der Header allein belegt nicht, dass die
    // Datei tatsächlich eine intakte Datenbank ist (z. B. abgeschnittene
    // Übertragung). `PRAGMA quick_check` liest die komplette B-Tree-
    // Struktur — das ist die eigentliche Integritätsprüfung.
    if (!await sqliteQuickCheckOk(Uint8List.fromList(sqliteBytes))) {
      throw const FormatException(
        'Enthaltene Datenbankdatei ist beschädigt (Integritätsprüfung fehlgeschlagen).',
      );
    }

    return _ValidatedBackup(
      sqliteBytes: sqliteBytes,
      exportedAt: DateTime.parse(manifest['exportedAt'] as String),
      schemaVersionInBackup: schemaVersionInBackup,
    );
  }

  /// Validiert [fileBytes] vollständig **vor** jedem Eingriff in die
  /// Live-Daten. Schließt danach die aktive Verbindung und überschreibt
  /// die Datenbankdatei — die App muss anschließend neu gestartet
  /// werden (kein Inprozess-Hotswap der offenen Verbindung, um keinen
  /// inkonsistenten Zustand zwischen Provider-Baum und Datei zu
  /// riskieren).
  ///
  /// Audit-Befund 2026-10-17 (Abweichungen.md Abschnitt 2.2): Ein Fehler,
  /// der **vor** [_db.close] auftritt (also in [_validate]), wirft
  /// weiterhin [FormatException]/[ArgumentError] — hier stimmt die
  /// bisherige Aussage "deine Daten sind unverändert" uneingeschränkt,
  /// die aktive Verbindung läuft sogar noch normal weiter. Ein Fehler
  /// **danach** (beim atomaren Dateiaustausch, siehe
  /// `writeDatabaseFile`) wirft stattdessen [RestoreWriteException]:
  /// Die alte Datei bleibt dank des atomaren Austauschs zwar ebenfalls
  /// unangetastet, aber die aktive DB-Verbindung ist in diesem Fall
  /// bereits geschlossen — die App braucht in jedem Fall einen Neustart,
  /// bevor überhaupt wieder gearbeitet werden kann. Diese Unterscheidung
  /// erlaubt der UI eine ehrliche, phasenabhängige Fehlermeldung statt
  /// einer pauschalen Zusicherung.
  Future<RestoreResult> restoreBackup(Uint8List fileBytes, {String? passphrase}) async {
    if (!backupSupported) {
      throw UnsupportedError('Restore ist auf dieser Plattform nicht verfügbar.');
    }

    final validated = await _validate(fileBytes, passphrase);

    await _db.close();
    try {
      final path = await resolveDatabaseFilePath();
      await writeDatabaseFile(path, validated.sqliteBytes);
    } catch (e) {
      throw RestoreWriteException(
        'Schreiben der wiederhergestellten Datenbank fehlgeschlagen: $e. '
        'Die ursprüngliche Datei ist dank atomarem Austausch unangetastet, '
        'aber die App muss jetzt neu gestartet werden.',
      );
    }

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
