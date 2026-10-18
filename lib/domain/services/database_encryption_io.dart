/// Plattformabhängige Dateizugriffe für die optionale F4-DB-
/// Verschlüsselung.
library;

/// Android/Desktop nutzen `dart:io` + `sqlite3` direkt, um die
/// laufende Datenbankdatei per `PRAGMA rekey` zu ver-/entschlüsseln.
/// Im Web-Build (nur Kays LAN-Vorschau, nicht Teil der Android-
/// Offline-Roadmap/A4) ist das bewusst nicht verfügbar — SQLite3-
/// MultipleCiphers unterstützt Verschlüsselung dort zwar grundsätzlich,
/// bräuchte aber ein eigens gehostetes `sqlite3mc.wasm` (siehe
/// Doc-Kommentar in `connection.dart`), was hier bewusst nicht
/// mitgemacht wird (gleiches Prinzip wie Backup/Restore, siehe
/// `backup_io.dart`). `dart:io` lässt sich im Web-Build nicht
/// kompilieren, deshalb per bedingtem Export getrennt. Siehe
/// `database_encryption_io_native.dart` für die tatsächliche
/// Funktionssignatur (`encryptionSupported`, `resolveDatabaseFilePath`,
/// `rekeyDatabaseFile`, `verifyDatabaseKey`).
export 'database_encryption_io_web.dart'
    if (dart.library.io) 'database_encryption_io_native.dart';
