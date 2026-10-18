import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3_lib;

bool get encryptionSupported => true;

/// Muss exakt dem Pfad entsprechen, den `drift_flutter`s `driftDatabase()`
/// intern für `name: 'werkkernerp'` verwendet (siehe `connection.dart`) —
/// `<applicationDocumentsDirectory>/werkkernerp.sqlite`. Es gibt dafür
/// keine öffentliche API in `drift_flutter`; der Pfad ist hier (wie schon
/// in `backup_io_native.dart`) bewusst als eigene Konstante dupliziert
/// statt versteckt verknüpft, damit eine spätere Änderung an einer
/// Stelle alle drei betrifft und nicht leise auseinanderläuft.
Future<String> resolveDatabaseFilePath() async {
  final dir = await getApplicationDocumentsDirectory();
  return p.join(dir.path, 'werkkernerp.sqlite');
}

String _escape(String value) => value.replaceAll("'", "''");

/// Ver-/entschlüsselt die Datenbankdatei direkt über
/// `PRAGMA rekey` — laut SQLite3MultipleCiphers-Dokumentation für alle
/// drei Fälle geeignet: eine bisher unverschlüsselte Datenbank
/// verschlüsseln ([oldKey] `null`), den Schlüssel einer bereits
/// verschlüsselten Datenbank ändern (beide gesetzt) oder die
/// Verschlüsselung wieder entfernen ([newKey] `null`). Ein leerer
/// String bei `PRAGMA rekey` entschlüsselt zurück zu Klartext.
///
/// Existiert die Datei noch nicht (frische Installation, noch nie eine
/// Firma angelegt), passiert nichts — der gewünschte Schlüssel wird
/// beim allerersten echten Öffnen über den `setup`-Callback in
/// `connection.dart` ganz regulär gesetzt, eine Migration ist dann
/// unnötig.
Future<void> rekeyDatabaseFile({
  required String path,
  String? oldKey,
  String? newKey,
}) async {
  final file = File(path);
  if (!await file.exists()) return;

  final db = sqlite3_lib.sqlite3.open(path);
  try {
    if (oldKey != null) {
      db.execute("PRAGMA key = '${_escape(oldKey)}';");
    }
    db.execute("PRAGMA rekey = '${_escape(newKey ?? '')}';");
  } finally {
    db.close();
  }
}

/// Prüft, ob [key] die Datenbankdatei tatsächlich öffnet (für die
/// Passwort-Eingabe beim App-Start und beim Setzen eines neuen
/// Passworts in den Einstellungen). Existiert die Datei noch nicht,
/// gibt es nichts zu prüfen — `true`, der Schlüssel greift beim
/// erstmaligen Anlegen ganz normal.
Future<bool> verifyDatabaseKey({required String path, String? key}) async {
  final file = File(path);
  if (!await file.exists()) return true;

  sqlite3_lib.Database? db;
  try {
    db = sqlite3_lib.sqlite3.open(path);
    if (key != null) {
      db.execute("PRAGMA key = '${_escape(key)}';");
    }
    // Eine echte Leseabfrage statt nur `PRAGMA key` — ein falscher
    // Schlüssel lässt SQLite3MultipleCiphers erst beim tatsächlichen
    // Lesezugriff auf verschlüsselte Seiten fehlschlagen, nicht schon
    // beim Setzen des PRAGMA selbst.
    db.select('SELECT count(*) FROM sqlite_master;');
    return true;
  } catch (_) {
    return false;
  } finally {
    db?.close();
  }
}
