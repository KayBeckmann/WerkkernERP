import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3_lib;

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
///
/// Audit-Befund 2026-10-17 (Abweichungen.md Abschnitt 2.2): **Atomarer
/// Austausch statt direktem Überschreiben.** Vorher schrieb
/// `writeAsBytes` direkt auf [path] — ein Fehler mitten im Schreiben
/// (z. B. Speicher voll) hätte die bisherige Datei halb überschrieben
/// und beschädigt zurückgelassen. Jetzt werden die Bytes zuerst
/// vollständig in eine Temp-Datei **neben** [path] geschrieben; nur ein
/// erfolgreicher `rename()` ersetzt die Zieldatei — das ist auf einem
/// POSIX-Dateisystem (Android/Linux, also die tatsächliche Zielplattform
/// dieser App) eine atomare Operation des Dateisystems selbst: Entweder
/// die neue Datei liegt vollständig unter [path], oder [path] ist
/// unverändert die alte Datei. Schlägt bereits das Schreiben der
/// Temp-Datei fehl, bleibt [path] ebenfalls unberührt.
/// Prüft, ob [bytes] eine **strukturell intakte** SQLite-Datenbank
/// ergeben — `PRAGMA quick_check` liest dafür tatsächlich alle Seiten/
/// B-Tree-Strukturen, nicht nur die ersten 16 Header-Bytes (Audit-Befund
/// 2026-10-17, Abweichungen.md Abschnitt 2.2: "geprüft werden ... nur
/// der 16-Byte-SQLite-Header"). Schreibt [bytes] dafür kurz in eine
/// Temp-Datei (sqlite3 kann nicht direkt aus einem Byte-Array öffnen),
/// öffnet sie **read-only** (keine versehentliche Veränderung) und
/// räumt die Temp-Datei danach in jedem Fall wieder auf.
Future<bool> sqliteQuickCheckOk(Uint8List bytes) async {
  final tempDir = await getTemporaryDirectory();
  final tempPath = p.join(
    tempDir.path,
    'werkkernerp_restore_check_${DateTime.now().microsecondsSinceEpoch}.sqlite',
  );
  final tempFile = File(tempPath);
  await tempFile.writeAsBytes(bytes, flush: true);
  try {
    // Eine wirklich kaputte Datei (z. B. gültiger Header, aber Müll
    // danach) lässt sqlite3 nicht immer saubere "quick_check"-Zeilen
    // zurückgeben — teils wird direkt beim Öffnen/Abfragen eine native
    // Exception geworfen. Beides zählt hier als "nicht in Ordnung",
    // damit der Aufrufer immer eine klare [FormatException] bekommt statt
    // einer rohen sqlite3-Exception.
    try {
      final db = sqlite3_lib.sqlite3.open(tempPath, mode: sqlite3_lib.OpenMode.readOnly);
      try {
        final rows = db.select('PRAGMA quick_check;');
        return rows.isNotEmpty && rows.first.values.first == 'ok';
      } finally {
        db.close();
      }
    } catch (_) {
      return false;
    }
  } finally {
    if (await tempFile.exists()) await tempFile.delete();
  }
}

Future<void> writeDatabaseFile(String path, Uint8List bytes) async {
  final tempPath = '$path.restore-tmp';
  final tempFile = File(tempPath);
  try {
    await tempFile.writeAsBytes(bytes, flush: true);
    await tempFile.rename(path);
  } finally {
    // Falls writeAsBytes fehlschlug oder rename() aus irgendeinem Grund
    // nicht griff: keine Temp-Datei-Leiche liegen lassen.
    if (await tempFile.exists()) {
      await tempFile.delete();
    }
  }
}
