---
name: werkkernerp-workflow
description: Projektspezifischer Entwicklungsablauf für WerkkernERP (Flutter-ERP, Android+Web, lokal-first). Ergänzt den allgemeinen coding-workflow-Skill um die konkreten Befehle, Testmuster und Entscheidungen dieses Repos — aktiviert sich bei Arbeit an der Roadmap in 10_Projects/Flutter-ERP-RechnungsFee/Roadmap.md oder am Code in diesem Repository.
---

# WerkkernERP-Workflow

Ergänzt [[coding-workflow]] um alles, was spezifisch für dieses Repo ist.
Die allgemeinen Regeln (Commit nach jedem Roadmap-Punkt, Test+Push nach
jedem Meilenstein) gelten unverändert.

## Branch-Granularität in diesem Projekt

Ein Branch pro **Roadmap-Großschritt** (A0, A1, A2, A3, A4, A5, B0, ...),
nicht pro Unterpunkt — die Unterpunkte eines Schritts hängen meist zu eng
zusammen (z. B. A2 "Rechnung als Entwurf" ist ohne Positionen/Summen
nicht sinnvoll teilbar). Commits innerhalb des Branches trotzdem pro
fertiggestelltem Unterpunkt.

```
git checkout master && git pull --ff-only
git checkout -b feat/a1-kunden-artikel
# ... implementieren, testen, committen ...
git push -u origin feat/a1-kunden-artikel
git checkout master && git merge --no-ff feat/a1-kunden-artikel
git push origin master
```

## Qualitätstore vor jedem Commit

```bash
flutter analyze        # 0 Probleme, keine Ausnahme
flutter test           # alle Tests grün
```

Nach jedem A-Schritt zusätzlich ein echter Android-Debug-Build:

```bash
flutter build apk --debug   # dauert beim ersten Mal lang (Gradle-Download)
```

## Testmuster dieses Repos

**Datenbank-/Repository-Tests** (reines Dart, kein Flutter-Widget-Tree):

```dart
final db = AppDatabase.forTesting(
  NativeDatabase.memory(setup: (db) => db.execute('PRAGMA foreign_keys = ON;')),
);
```

`PRAGMA foreign_keys = ON` **nicht vergessen** — SQLite erzwingt
Fremdschlüssel sonst nicht automatisch, auch nicht mit `ON DELETE
CASCADE` im Schema. Ohne das greift z. B. die A0-Firmenisolation beim
Löschen nicht (hat in diesem Repo schon einen Test fehlschlagen lassen).

**Widget-Tests:** `WerkkernErpApp(database: ...)` nimmt eine
In-Memory-Testdatenbank entgegen. **Nie** `WerkkernErpApp()` ohne
`database:`-Override in Tests verwenden — die echte Verbindung läuft
über `path_provider` (`getApplicationDocumentsDirectory()`), das ohne
echte Plattform in Tests nicht verfügbar ist und zu stillem Hängen statt
einer klaren Fehlermeldung führt.

**Nach jeder Schemaänderung** (`lib/data/database/tables.dart`):

```bash
dart run build_runner build --delete-conflicting-outputs
```

`schemaVersion` in `lib/data/database/database.dart` erhöhen und eine
Migrationsstufe in `MigrationStrategy.onUpgrade` ergänzen — nie eine
bestehende Stufe nachträglich ändern (A0-Vorgabe: "schema-versionierte
Migrationen").

## Web-Build + Docker-Vorschau fürs LAN

Das öffentliche `ghcr.io/cirruslabs/flutter:stable`-Image hinkt der
lokal installierten Flutter-Version hinterher (hat hier zu einem
Dart-SDK-Versionskonflikt geführt). Deshalb baut der Container **nicht**
selbst aus dem Quellcode — immer erst lokal bauen, dann der Container
nur noch nginx mit dem fertigen Ergebnis:

```bash
flutter build web --release
docker compose build web
docker compose up -d web
```

Erreichbar unter `http://<LAN-IP-des-Rechners>:8085` (siehe
`docker-compose.yml`, Port ggf. anpassen falls belegt). `hostname -I`
oder `ip -4 addr show` liefert die LAN-IP.

## Android-Build

```bash
flutter build apk --debug      # für Kay zum Installieren/Testen
flutter build apk --release    # erst nach Paketname-/Signierungs-Entscheidung
```

Paketkennung ist aktuell `de.kaybeckmann.werkkernerp` (Platzhalter aus
A0 — laut Roadmap "vor Veröffentlichung mit Kay festlegen", für
Entwicklung unkritisch).

## Geld- und Mengenwerte (F2)

**Immer** `Money` (`lib/domain/models/money.dart`) verwenden, nie
`double` für Preise/Summen. Rundung ist kaufmännisch (round half away
from zero) über `package:decimal` — nicht neu erfinden, `Money`
erweitern statt parallele Rechenwege einbauen.

## F4-Verschlüsselung — vorbereiteter, noch nicht umgesetzter Plan

Konkret recherchiert, aber bewusst erst bei A4 umzusetzen (siehe
Doc-Kommentar in `lib/data/database/connection.dart`):

1. `pubspec.yaml`: `hooks.user_defines.sqlite3.source: sqlite3mc` aktiviert
   eine Cipher-fähige native SQLite-Bibliothek für Android.
2. `DriftNativeOptions(setup: (db) => db.execute("PRAGMA key = '...';"))`
   mit einem Schlüssel aus `flutter_secure_storage` (gerätegebunden, kein
   Nutzer-Passwort — passt zum "kein Login"-Prinzip).
3. Web: eigens gehostetes `sqlite3mc.wasm`
   (github.com/simolus3/sqlite3.dart/releases, exakt passend zur
   gepinnten `sqlite3`-Paketversion) statt des Standard-`sqlite3.wasm`.

Das ist ein neuerer, noch wenig erprobter Build-Mechanismus (Dart
Native-Asset-Hooks) — als eigener, isoliert zu testender Schritt
behandeln, nicht nebenbei in eine andere Änderung mischen.

## Roadmap-Pflege

Nach jedem gemergten A-Schritt in
`~/git/obsidian_vault/10_Projects/Flutter-ERP-RechnungsFee/Roadmap.md`:

- Erledigte Checkbox-Punkte auf `[x]` setzen.
- Kurze Fortschrittsnotiz mit Datum ergänzen (Muster: siehe bereits
  dokumentierte F1–F5-Entscheidungen).
- **Nie** stillschweigend eine "Abnahme"-Zeile als erfüllt markieren,
  ohne dass die dort genannten konkreten Tests tatsächlich grün sind.

## Lizenz-/Referenzgrenze (wichtig, leicht zu übersehen)

RechnungsFee (AGPL-3.0) darf als **fachliche/gestalterische Referenz**
dienen (Bedienlogik, Layoutmuster), aber: niemals Code, Templates, Texte,
Icons oder Assets aus einem geklonten RechnungsFee-Repo in dieses Repo
kopieren. Ein Referenz-Checkout gehört **außerhalb** von `WerkkernERP`
(z. B. `~/git/reference-RechnungsFee`), nie als Submodule, Copy-Paste
oder Build-Dependency hier eingebunden.
