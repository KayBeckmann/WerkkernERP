# WerkkernERP Server (Phase B — Online-Multi-User)

Eigenständiger Dart-Dienst für B1 (Mitgliedschaften, Gruppen,
Backend-Isolation). Unabhängig vom Flutter-Client (`../lib/`) und
dessen Offline-SQLite (Drift) — Phase B ist ein **zusätzlicher**
Online-Modus, der Offline-Single-User-Modus bleibt unverändert
nutzbar.

Architektur-Entscheidungen: siehe das Vault-ADR
`10_Projects/Flutter-ERP-RechnungsFee/Decisions/ADR-0001-phase-b-architektur.md`.

## Produktion mit TLS

ADR-0001 B0.3: Transport-TLS ist Pflicht. Der Server spricht selbst nur
HTTP; davor steht Caddy (Compose-Profil `tls`, automatische
Let's-Encrypt-Zertifikate, HSTS):

```bash
# .env: SERVER_DOMAIN=erp.example.org, SERVER_BIND=127.0.0.1,
#       SERVER_TRUST_PROXY=true, SERVER_CORS_ALLOWED_ORIGINS=<App-Origin>
docker compose --profile tls up -d --build server-db server proxy
```

Sicherheit im Betrieb: Login-Drosselung (5 Fehlversuche je Konto bzw.
30 je Adresse in 15 min -> 429), Passwortänderung beendet alle anderen
Sitzungen, stündliches Aufräumen abgelaufener Sitzungen/Token/
Idempotenz-Einträge. `TRUST_PROXY=true` nur hinter dem eigenen Proxy —
sonst könnte ein Client die Absenderadresse per `X-Forwarded-For` fälschen.

## Online-Betrieb auf Strato

`deploy/strato/deploy.sh` baut Web- und Server-Image **lokal** (der
Strato-Server ist zu knapp zum Kompilieren), überträgt sie per
`docker save | ssh docker load` und startet `~/projekte/werkkernerp`
(Compose: `deploy/strato/docker-compose.yml`, Speicherlimits je
Container). Beim ersten Lauf legt das Skript dort eine `.env` mit
zufälligem DB-Passwort und `SERVER_SECRET_KEY` an und überschreibt sie
danach nie.

Nach außen gehen zwei Ports:

- `WEB_PORT` (Standard 8085): nginx liefert die App aus und reicht
  `/api/` an den Server weiter (`deploy/nginx/web.conf`). In der App als
  Server-Adresse `https://<domain>/api` eintragen — die Web-App belegt
  das selbst vor (eigener Origin + `/api`); Android-Builds belegen
  `https://erp.kay-beckmann.de/api` vor (anderer Server per
  `--dart-define=WERKKERN_SERVER=https://<domain>/api`). Eine zuletzt
  benutzte lokale Test-Adresse (localhost, private IP) überdeckt diese
  Vorgabe nicht.
- `SUPERADMIN_PORT` (Standard 8086): Superadmin-Panel, reicht nur
  `/api/platform/*` weiter (`deploy/nginx/superadmin.conf`), siehe
  `superadmin/README.md`.

## SaaS-Betrieb: Superadmin, Abo, Sperre

`/platform/*` (`lib/src/platform_routes.dart`) mit eigener Anmeldung
(`POST /platform/login`, 8 h) — nur für Konten, die per
`/app/platform_admin grant <email>` im Container freigeschaltet sind:
Firmenliste mit Mitgliederzahl, Admin-E-Mails und Abo
(`PUT /platform/companies/:id/billing` — Tarif, `paidUntil`, Notiz),
`POST /platform/companies/:id/suspend` `{reason}` und `.../resume`.

Eine gesperrte Firma ist komplett gesperrt: ihre Sitzungen werden
gelöscht, `/auth/login` markiert sie mit `suspended: true`,
`select-company`/`switch-company` antworten 403, Agent-Token wirken
nicht mehr. Der Grund bleibt intern. Überfällig (`paidUntil` vorbei)
wird nur angezeigt, gesperrt wird von Hand. Sperren/Entsperren/Abo
landen im Audit-Log der Firma.

## Starten

```bash
cp ../.env.example ../.env   # Secrets anpassen, NIE committen
docker compose up -d --build server-db server   # Build-Kontext: Repo-Root
curl http://localhost:8190/health
```

## Tests

```bash
dart test -x postgres -j 6     # In-Memory, kein Postgres nötig, parallel
```

Dieselbe Router-Suite läuft zusätzlich gegen echtes Postgres, sobald
`WERKKERN_TEST_DB` gesetzt ist (sonst übersprungen):

```bash
docker run -d --rm --name werkkern-test-pg -e POSTGRES_PASSWORD=test \
  -e POSTGRES_USER=test -e POSTGRES_DB=test -p 127.0.0.1:55432:5432 postgres:16-alpine
WERKKERN_TEST_DB=localhost:55432:test:test:test dart test -t postgres
```

Die Postgres-Suiten setzen das gemeinsame Schema vor jedem Test zurück
und laufen deshalb nacheinander (`dart_test.yaml`: `concurrency: 1`).

## Kernablauf (B1)

1. `POST /auth/register` — neue, firmenunabhängige Nutzeridentität anlegen.
2. `POST /companies` (mit `identityToken` aus `/auth/login`) — neue
   Firma anlegen; seedet die drei Startgruppen (Projektleiter/Monteur/
   Buchhaltung, **ohne** vorbelegte Rechte) und macht den Ersteller
   zum Admin dieser Firma.
3. `POST /auth/login` → `identityToken` + Liste der Firmen, in denen
   der Nutzer Mitglied ist.
4. `POST /auth/select-company` → firmengebundenes Session-Token samt
   `expiresAt` (7 Tage, `PhaseBRouter.sessionTtl`). Jede Nutzung
   verlängert auf „jetzt + 7 Tage“ (höchstens ein Schreibzugriff je
   Stunde, ohne Obergrenze); `GET /auth/session` liefert das aktuelle
   `expiresAt`, ohne zu verlängern.
   `POST /auth/switch-company` `{companyId}` wechselt aus einer
   App-Sitzung ohne Passwort in eine andere eigene Firma; die neue
   Sitzung erbt das Ablaufdatum, die alte endet.
5. Admin verwaltet `/groups`, `/memberships`,
   `/memberships/:id/overrides/:permission`, `/company/modules` und
   `/invitations` innerhalb der **eigenen** Firma — jeder Versuch auf
   eine fremde Firma liefert 404, kein Unterschied zwischen "existiert
   nicht" und "gehört einer anderen Firma" (kein Oracle für fremde IDs).
6. Neue Mitarbeiter: Admin erzeugt per `POST /invitations` ein
   Einladungs-Token (einmal einlösbar, 7 Tage gültig) und gibt es selbst
   weiter; die eingeladene Person löst es per `POST /auth/accept-invitation`
   mit ihrem Passwort ein (neues Konto oder Nachweis des bestehenden).

## Berechtigungen

`GET /permissions/catalog` listet alle bekannten Schlüssel
(`lib/src/permission_catalog.dart`) samt erforderlichem Modul;
`GET /permissions/mine` die für die eigene Sitzung wirksamen. Unbekannte
Schlüssel werden beim Vergeben abgewiesen. Reihenfolge der Prüfung:
fehlende/inaktive Mitgliedschaft → deaktiviertes Modul → individuelle
Ausnahme → Gruppenrecht.

## Fachdaten (B1 Punkt 3)

| Endpunkt | Recht (Modul) |
|---|---|
| `GET/POST /customers`, `GET/PUT/DELETE /customers/:id` (`?q=` Suche) | `customers.read` / `customers.write` |
| `GET/POST /articles`, `GET/PUT /articles/:id` (`?q=`, `?includeInactive=true`) | `articles.read` / `articles.write` |
| `GET/POST /documents`, `GET/PUT/DELETE /documents/:id` (`?kind=`, `?status=`, `?q=`) | `invoices.read` / `invoices.write` + Modul der Dokumentart |
| `POST /documents/:id/finalize` | `invoices.finalize` + Modul der Dokumentart |

- Jede Repository-Methode ist firmengebunden; fremde IDs → 404 wie
  nicht existierende, Suche liefert nie Fremddaten.
- Dokumentarten wie offline (`invoice`, `quote`, `order`, `deliveryNote`,
  `proforma`, `creditNote`); alle außer `invoice` brauchen ihr Modul.
- **Kein stilles Überschreiben:** `PUT` und `finalize` verlangen die
  zuletzt gelesene `version`, sonst 409 (Grundlage für B2-Konflikte).
- Finalisierung ist eine Transaktion mit Zeilensperre + Nummernkreis-
  UPSERT (Firma/Art/Jahr); Summen und Nummernformat kommen aus
  `packages/werkkern_core` — identisch zur Offline-App.
- **Standardrechte:** Die Startgruppen Projektleiter/Monteur/Buchhaltung
  werden mit Standardrechten angelegt (`starterGroupPermissions` in
  `lib/src/permission_catalog.dart`). Der Firmen-Ersteller landet in
  „Projektleiter“; Admins brauchen Fachrechte weiterhin über ihre Gruppe
  und ändern sie über `PUT /groups/:id/permissions/:key`. Bestehende
  Firmen behalten ihre bisherigen Gruppenrechte.

## Fachmodule (online wie offline)

Alle Endpunkte prüfen Sitzung → Recht → Modul; fremde IDs verhalten sich
wie nicht existierende. Neue Module liegen je als eigenes Modell/Store
(`lib/src/business/<modul>.dart`), Implementierung als Part-Mixin
(`memory/`, `postgres/`) und Routen (`<modul>_routes.dart`).

| Bereich | Endpunkte | Recht (Modul) |
|---|---|---|
| Lieferanten, Artikelgruppen, Einkaufspreise | `/suppliers`, `/article-groups`, `/articles/:id/prices/:supplierId` | `articles.*` |
| Fuhrpark | `/vehicles`, `/vehicle-costs` (Summen je Kategorie) | `fleet.*` (`fleet`) |
| Lager, Inventur | `/stock/movements`, `/stock/low`, `/articles/:id/stock-correction`, `/inventory-counts`, `/documents/:id/stock-check` | `stock.*` (`lagerbestand`) |
| Bestellwesen | `/purchase-orders` (+ `/finalize`, `/receive`, `/suggestions`, `/from-suggestion`), `/documents/:id/purchase-orders` | `purchaseOrders.*` (`bestellwesen`) |
| Buchhaltung | `/expense-categories`, `/expenses`, `/accounting/open-items`, `/accounting/euer`, `/accounting/settings`, `/accounting/datev`, `/bank-transactions` (+ `/import`, `/:id/match`) | `accounting.*` (`buchhaltung`) |
| Mahnwesen | `/dunning/settings`, `/dunning/overdue`, `/documents/:id/dunning-notices` | `dunning.*` (`dunning`) |
| Wiederkehrende Rechnungen | `/recurring-templates` (+ `/generate`) | `invoices.*` (`recurringInvoices`) |
| Stundenzettel | `/time-sheets` (+ `/entries`, `/sign`, `/correction`) | `timeTracking.write` (`timeTracking`) |
| Rollen & Stundensätze | `/staff-roles` (lesen: wer bucht; pflegen: Admin) | `timeTracking.*` (`timeTracking`) |
| Materialabschlag | `/documents/:id/material-advance` (Artikel und/oder gewählte Freitexte eines finalisierten Auftrags) | `invoices.write` (`advancePaymentInvoices`) |
| Mailversand | `/mail/settings`, `/mail/test` (Admin), `/documents/:id/send`, `/dunning-notices/:id/send`, `/purchase-orders/:id/send` | Fachrecht (`smtp`) |
| Übersicht | `/dashboard`, `/dashboard/preferences` | Kacheln nach Rechten |

- **Bestand** ändert sich nur über unveränderliche Bewegungen. Finalisieren
  bucht in derselben Transaktion (Regel aus `werkkern_core`: genau eine
  Buchung pro Kette, Gutschrift bucht zurück), ein später bearbeiteter
  Auftrag bucht die Differenz nach.
- **Rollen:** Eine Zeitbuchung mit Rolle friert deren Kostensatz ein,
  ohne Rolle den des Mitglieds (wie offline Rollen-Stamm, online
  zusätzlich der Satz je Mitglied). `GET /staff-roles?seed=1` durch einen
  Admin legt die Vorschläge Monteur/Meister/Projektleiter an (nur die
  Rollenverwaltung der App fragt so).
- **Stunden je Rolle (C3.4):** `hourlyBillingCents` an der Rolle ist der
  Verrechnungssatz (Preis für den Kunden, 0 = nicht hinterlegt),
  `staffRoleId` an Stunden-Positionen muss zur Firma gehören. Hat die
  Firma Rollen, verlangt `POST/PUT /time-entries` eine Rolle (sonst 422).
  Umwandeln Auftrag → Rechnung ohne Festpreis erzeugt eine Ist-Stunden-
  Position je Rolle (`billBookedHoursByRole` in `werkkern_core`, gleiche
  Regel wie offline); Dokumente liefern `bookedHoursByRole`.
- **Wiederkehrende Rechnungen:** `bin/server.dart` prüft stündlich und
  legt je fälliger Periode einen Entwurf an; jede Periode wird in
  derselben Transaktion beansprucht, mehrere Instanzen sind unkritisch.
- **Mailversand:** SMTP-Passwort AES-256-GCM-verschlüsselt mit
  `WERKKERN_SECRET_KEY` (32 Byte Base64, z. B. `openssl rand -base64 32`);
  ohne Schlüssel ist der Versand aus. Das PDF rendert die App, der
  Server prüft Recht, Modul, Status und PDF-Signatur; nie über
  Agent-Token, jeder Versand im Audit-Protokoll.
- Die Kalkulationen (Verkaufspreis, Mahnstufe/Zins, Intervall, DATEV,
  Umsatzregeln) kommen aus `packages/werkkern_core` — identisch zur
  Offline-App.

## Offline-Arbeit und Abgleich (B2)

- Schreibaufrufe mit Header `Idempotency-Key` wirken höchstens einmal
  je Firma + Nutzer (Wiederholung -> gespeicherte Antwort,
  `idempotent-replay: true`; anderer Inhalt -> 422; in Bearbeitung ->
  409). Grundlage der Offline-Outbox der App.
- Die Offline-Logik selbst (Bestand, Outbox, Abgleich) liegt im
  Client-Paket `packages/werkkern_client/lib/src/offline.dart`; ihre
  Abnahmetests laufen hier gegen den echten Router:
  `test/offline_sync_test.dart` (Netzausfall, verlorene Antwort,
  konkurrierende Geräte, entzogene Rechte, deaktivierte Mitgliedschaft).
- Offline erlaubt: nur Entwürfe ausdrücklich markierter Dokumente
  bearbeiten. Finalisieren/Umwandeln/Zahlung nur online.

## KI-Agenten: Agent-Token, Freigaben, MCP (C8)

- Firmenmodul `aiAgents` (Admin) schaltet Agent-Token frei. Token
  (`wka_…`) erzeugt jeder Nutzer selbst: `POST /agent-tokens` (nur aus
  einer App-Sitzung). Der Agent hat exakt die Rechte dieses Nutzers,
  nie Admin-Funktionen; Protokolleinträge tragen `[agent]`.
- Irreversibles per Agent -> `202` + Freigabe-Anfrage: Dokument
  finalisieren/Entwurf löschen, Bestellung finalisieren/Wareneingang/
  Entwurf löschen, Bestandskorrektur, Inventur abschließen, Mahnung
  erstellen, Stundenzettel-Entwurf oder Beleg löschen. Stundenzettel
  unterschreiben und Mailversand gehen über ein Agent-Token nie (`403`).
  `GET /approvals`, `POST /approvals/:id/confirm|reject` (nur der
  Nutzer selbst, nicht das Token). Bestätigen führt mit der Sitzung des
  Nutzers aus und prüft dabei alles neu; höchstens einmal.
- MCP-Server: `packages/werkkern_mcp` (siehe dortige README).

## Firmen-Stammdaten und Audit

- `GET /company/profile` (alle), `PUT /company/profile` (Admin):
  Anschrift, Steuernummer, USt-IdNr., IBAN, E-Mail, Telefon — werden
  beim Finalisieren unveränderlich ins Dokument übernommen.
- `GET /audit?limit=` (Admin): wer hat wann was an welchem Objekt
  getan, neueste zuerst. Bewusst **ohne Inhalte** (Datenminimierung).
- `GET /company/export` (Admin, nie über Agent-Token): alle Fachdaten
  der Firma als JSON (online Gegenstück zu „Daten & Sicherung“) —
  ohne Passwörter, Sitzungen, Agent-Token und SMTP-Zugangsdaten; der
  Export steht im Audit-Protokoll.

## Umzug Einzelplatz → Online-Firma (B4)

`POST /company/import` (Admin, nie über Agent-Token) liest das
Umzugspaket der Offline-App (`werkkernerp-migration`, Formatversion in
`werkkern_core/lib/src/migration_package.dart`) in die **leere** Firma
ein — einmalig, alles oder nichts in einer Transaktion
(`lib/src/business/company_import.dart`, Postgres:
`postgres/company_import.dart`).

- Body: `{package, roleAssignments: {Offline-Rollen-ID | "-" → Mitgliedschafts-ID}}`.
  Formatversion 2 (C3.4) bringt Verrechnungssätze und Rollen an
  Stunden-Positionen mit; Version 1 wird weiter angenommen.
  Jede Rolle mit Zeitbuchungen (und „-“ für Buchungen ohne Rolle)
  braucht ein aktives Mitglied, sonst 422.
- `?dryRun=1` schreibt nichts und liefert `counts`, `warnings`,
  `errors`, `roles` und `missingAssignments` für den Assistenten.
- IDs werden neu vergeben; finalisierte Dokumente kommen unverändert
  (Nummer, Schnappschüsse, Zahlstatus), Nummernkreise laufen nahtlos
  weiter, Bestand wie offline. Vorschlags-Rollen und Belegkategorien der
  neuen Firma werden ersetzt. SMTP wird nicht übernommen (Passwort liegt
  nur auf dem Gerät).
- 409, wenn die Firma schon Fachdaten hat oder bereits umgezogen ist
  (Abschnitt `import` in `company_settings`); Eintrag `company.import`
  im Audit-Protokoll.

## Schema-Migrationen

`lib/src/db/migrations.dart`: versionierte Stufen (Tabelle
`schema_migrations`), beim Serverstart in einer Transaktion mit
Advisory-Lock ausgeführt. Stufen werden nur angehängt, nie geändert —
wie in der Offline-App.

## Backup und Restore (B3)

```bash
# Backup (verschlüsselt mit dem ÖFFENTLICHEN Schlüssel des Betreibers)
BACKUP_GPG_RECIPIENT=backup@example.org server/scripts/backup.sh /pfad/zu/backups

# Restore-Test in einer Wegwerf-Instanz (privater Schlüssel nötig),
# --compare-live vergleicht Zeilenzahlen mit der laufenden DB
server/scripts/restore-test.sh /pfad/zu/backups/werkkernerp-server-<stamp>.dump.gpg --compare-live

# Echte Wiederherstellung (ersetzt ALLE Mandanten, fragt nach Bestätigung)
server/scripts/restore.sh /pfad/zu/backups/werkkernerp-server-<stamp>.dump.gpg
```

- `pg_dump -Fc` = transaktional konsistenter Snapshot; vor dem
  Verschlüsseln per `pg_restore --list` geprüft, atomar geschrieben,
  mit `.sha256`.
- Der Server-Host kann Backups erzeugen, aber nicht lesen — der
  private GPG-Schlüssel gehört offline (pass/KeePassXC).
- `restore.sh` stoppt den Server, spielt in **einer** Transaktion ein
  (Fehler → bisheriger Bestand bleibt), beendet danach alle Sitzungen.
- **Offsite-Kopie** der `.gpg`-Dateien (z. B. per Cron + rsync) und
  regelmäßiger `restore-test.sh`-Lauf sind Betreiberaufgabe.
- Mandanten liegen in einer gemeinsamen Datenbank; ein Backup enthält
  daher alle Firmen und ist reines Betreiberwerkzeug (kein Export für
  einzelne Firmen — der wäre ein eigener, firmengebundener API-Pfad).

## Erstadmin-Recovery (Betreiber)

Kein API-Endpunkt — nur mit direktem DB-Zugriff:

```bash
docker compose exec server /app/recover_admin <email> <companyId>
```

## Noch offen

- Offline-Anlage neuer Dokumente/Kunden im Online-Modus.
- Offsite-Kopie/Cron und Monitoring der Backups sind Betreiberaufgabe.
