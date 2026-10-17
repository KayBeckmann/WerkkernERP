/// Plattformabhängige Dateizugriffe fürs Backup.
library;

/// Android/Desktop nutzen `dart:io`; im Web-Build (nur Kays LAN-
/// Vorschau, nicht Teil der Android-Offline-Roadmap/A4) ist Backup/
/// Restore bewusst nicht verfügbar. `dart:io` lässt sich im Web-Build
/// nicht kompilieren, deshalb per bedingtem Export getrennt. Siehe
/// `backup_io_native.dart` für die tatsächliche Funktionssignatur
/// (`backupSupported`, `resolveDatabaseFilePath`, `readTempVacuumFile`,
/// `writeDatabaseFile`, `sqliteQuickCheckOk`).
export 'backup_io_web.dart' if (dart.library.io) 'backup_io_native.dart';
