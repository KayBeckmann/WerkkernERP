import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

/// Öffnet die lokale Datenbank für die aktuelle Plattform (Android nativ
/// oder Web/WASM — eine Codebasis für beide primären Zielplattformen,
/// siehe Roadmap A0).
///
/// **F4-Verschlüsselung (Kay-Entscheidung 2026-10-19: optional, Wahl
/// zwischen Geräteschlüssel und Passwort) ist umgesetzt** — braucht
/// keine eigene Schema-Version, da rein verbindungs-/dateiseitig, ohne
/// neue Tabellen/Spalten. [encryptionKey] kommt aus
/// `DatabaseEncryptionService.resolveKey()`
/// (siehe `database_encryption_service.dart`), aufgelöst in `main.dart`
/// VOR dem Erzeugen von `AppDatabase()`. `null` bedeutet unverändert
/// "keine Verschlüsselung" (Standard, Bestandsverhalten).
///
/// Technischer Weg: SQLite3 Multiple Ciphers statt SQLCipher (seit
/// drift 2.32.0 der offiziell empfohlene, nicht mehr experimentelle
/// Weg — `sqlcipher_flutter_libs`/`sqlite3_flutter_libs` sind End-of-
/// Life, bewusst NICHT verwendet):
/// 1. `pubspec.yaml`: `hooks.user_defines.sqlite3.source: sqlite3mc`
///    bündelt eine Cipher-fähige native SQLite-Variante für Android
///    UND Web (per Build-Hook, kein manuelles `.so`/`.wasm` nötig).
/// 2. `DriftNativeOptions.setup` setzt `PRAGMA key` vor der ersten
///    echten Nutzung, genau wie es die drift-eigene Doku vorschlägt
///    (https://drift.simonbinder.eu/platforms/encryption/).
/// 3. Eine bereits bestehende, unverschlüsselte (oder anders
///    verschlüsselte) Datenbankdatei wird NICHT hier migriert — das
///    passiert vorher, explizit und einmalig, über
///    `DatabaseEncryptionService.applyChange()` (per `PRAGMA rekey`
///    direkt auf der Datei), damit ein Fehlschlag nicht mitten in
///    einer laufenden App-Session passiert.
/// 4. Web bleibt bewusst AUSGENOMMEN (siehe
///    `database_encryption_io_web.dart`) — dieselbe Begründung wie bei
///    Backup/Restore: Web ist nur Kays LAN-Vorschau, nicht Teil der
///    Android-Offline-Rolle.
QueryExecutor openConnection({String? encryptionKey}) {
  return driftDatabase(
    name: 'werkkernerp',
    native: DriftNativeOptions(
      setup: (database) {
        // SQLite erzwingt Fremdschlüssel-Constraints nicht automatisch
        // pro Verbindung — ohne das hier würden z. B. Cascade-
        // Löschungen bei Firmenlöschung (A0-Isolation) stillschweigend
        // ausbleiben.
        database.execute('PRAGMA foreign_keys = ON;');
        if (encryptionKey != null) {
          database.execute("PRAGMA key = '${encryptionKey.replaceAll("'", "''")}';");
        }
      },
    ),
    web: DriftWebOptions(
      sqlite3Wasm: Uri.parse('sqlite3.wasm'),
      driftWorker: Uri.parse('drift_worker.js'),
    ),
  );
}
