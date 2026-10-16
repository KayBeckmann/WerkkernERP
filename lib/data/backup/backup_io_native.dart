import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

bool get backupSupported => true;

/// Muss exakt dem Pfad entsprechen, den `drift_flutter`s `driftDatabase()`
/// intern für `name: 'werkkernerp'` verwendet (siehe `connection.dart`):
/// `<applicationDocumentsDirectory>/werkkernerp.sqlite`. Es gibt dafür
/// keine öffentliche API in `drift_flutter` — der Name ist hier bewusst
/// als Konstante dupliziert statt versteckt verknüpft, damit eine
/// spätere Änderung an einer Stelle beide betrifft und nicht leise
/// auseinanderläuft.
Future<String> resolveDatabaseFilePath() async {
  final dir = await getApplicationDocumentsDirectory();
  return p.join(dir.path, 'werkkernerp.sqlite');
}

/// Führt [runVacuumInto] mit einem Temp-Dateipfad aus (soll dort per SQL
/// `VACUUM INTO` eine konsistente Kopie erzeugen) und liest das Ergebnis
/// als Bytes zurück. Löscht die Temp-Datei danach wieder.
Future<Uint8List> readTempVacuumFile(
  Future<void> Function(String path) runVacuumInto,
) async {
  final tempDir = await getTemporaryDirectory();
  final tempPath = p.join(
    tempDir.path,
    'werkkernerp_backup_${DateTime.now().microsecondsSinceEpoch}.sqlite',
  );
  final tempFile = File(tempPath);
  if (await tempFile.exists()) await tempFile.delete();

  await runVacuumInto(tempPath);
  final bytes = await tempFile.readAsBytes();
  await tempFile.delete();
  return bytes;
}

/// Überschreibt die Datenbankdatei an [path] mit [bytes]. Aufrufer muss
/// vorher die aktive Verbindung geschlossen haben — sonst riskiert das
/// einen inkonsistenten Zustand oder einen Schreibfehler durch die noch
/// offene Datei.
Future<void> writeDatabaseFile(String path, Uint8List bytes) async {
  await File(path).writeAsBytes(bytes, flush: true);
}
