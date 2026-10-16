import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

/// Öffnet die lokale Datenbank für die aktuelle Plattform (Android nativ
/// oder Web/WASM — eine Codebasis für beide primären Zielplattformen,
/// siehe Roadmap A0).
///
/// **F4-Verschlüsselung ist hier bewusst noch NICHT aktiviert.** Der
/// konkrete, bereits recherchierte Weg (SQLite3 Multiple Ciphers statt
/// SQLCipher, da ohne zusätzliche OpenSSL-Linking-Fragen):
/// 1. `pubspec.yaml`: `hooks.user_defines.sqlite3.source: sqlite3mc`
///    aktiviert eine Cipher-fähige native Bibliothek für Android.
/// 2. `DriftNativeOptions(setup: (db) => db.execute("PRAGMA key = '...';"))`
///    mit einem gerätegebundenen Schlüssel aus `flutter_secure_storage`
///    (kein Nutzer-Passwort — siehe F4-Entscheidung in der Roadmap).
/// 3. Web: eigens gehostetes `sqlite3mc.wasm`
///    (https://github.com/simolus3/sqlite3.dart/releases) statt des
///    Standard-`sqlite3.wasm` in `DriftWebOptions.sqlite3Wasm`, plus
///    derselbe PRAGMA-Key-Aufruf.
/// Das ist ein neuerer, noch wenig erprobter Build-Mechanismus (Dart
/// Native-Asset-Hooks) — wird als eigener, isoliert getesteter Schritt in
/// A4 umgesetzt, statt das Grundgerüst in A0 darauf zu verlassen.
QueryExecutor openConnection() {
  return driftDatabase(
    name: 'werkkernerp',
    native: DriftNativeOptions(
      // SQLite erzwingt Fremdschlüssel-Constraints nicht automatisch pro
      // Verbindung — ohne das hier würden z. B. Cascade-Löschungen bei
      // Firmenlöschung (A0-Isolation) stillschweigend ausbleiben.
      setup: (database) => database.execute('PRAGMA foreign_keys = ON;'),
    ),
    web: DriftWebOptions(
      sqlite3Wasm: Uri.parse('sqlite3.wasm'),
      driftWorker: Uri.parse('drift_worker.js'),
    ),
  );
}
