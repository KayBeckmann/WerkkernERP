import 'dart:typed_data';

bool get backupSupported => false;

Never _unsupported() => throw UnsupportedError(
      'Backup/Restore ist in der Web-Vorschau nicht verfügbar — das ist '
      'nur Kays LAN-Testvorschau, nicht Teil der Android-Offline-Roadmap '
      '(A4 ist ausdrücklich ein Android-Punkt).',
    );

Future<String> resolveDatabaseFilePath() async => _unsupported();

Future<Uint8List> readTempVacuumFile(
  Future<void> Function(String path) runVacuumInto,
) async =>
    _unsupported();

Future<void> writeDatabaseFile(String path, Uint8List bytes) async => _unsupported();
