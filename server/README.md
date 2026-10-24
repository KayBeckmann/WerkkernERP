# WerkkernERP Server (Phase B — Online-Multi-User)

Eigenständiger Dart-Dienst für B1 (Mitgliedschaften, Gruppen,
Backend-Isolation). Unabhängig vom Flutter-Client (`../lib/`) und
dessen Offline-SQLite (Drift) — Phase B ist ein **zusätzlicher**
Online-Modus, der Offline-Single-User-Modus bleibt unverändert
nutzbar.

Architektur-Entscheidungen: siehe das Vault-ADR
`10_Projects/Flutter-ERP-RechnungsFee/Decisions/ADR-0001-phase-b-architektur.md`.

## Starten

```bash
cp ../.env.example ../.env   # Secrets anpassen, NIE committen
docker compose up -d --build server-db server   # Build-Kontext: Repo-Root
curl http://localhost:8190/health
```

## Tests

```bash
dart test                      # In-Memory, kein Postgres nötig
```

Dieselbe Router-Suite läuft zusätzlich gegen echtes Postgres, sobald
`WERKKERN_TEST_DB` gesetzt ist (sonst übersprungen):

```bash
docker run -d --rm --name werkkern-test-pg -e POSTGRES_PASSWORD=test \
  -e POSTGRES_USER=test -e POSTGRES_DB=test -p 127.0.0.1:55432:5432 postgres:16-alpine
WERKKERN_TEST_DB=localhost:55432:test:test:test dart test
```

## Kernablauf (B1)

1. `POST /auth/register` — neue, firmenunabhängige Nutzeridentität anlegen.
2. `POST /companies` (mit `identityToken` aus `/auth/login`) — neue
   Firma anlegen; seedet die drei Startgruppen (Projektleiter/Monteur/
   Buchhaltung, **ohne** vorbelegte Rechte) und macht den Ersteller
   zum Admin dieser Firma.
3. `POST /auth/login` → `identityToken` + Liste der Firmen, in denen
   der Nutzer Mitglied ist.
4. `POST /auth/select-company` → firmengebundenes Session-Token.
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
- **Hinweis:** Auch der Firmen-Ersteller hat zunächst keine Fachrechte
  (Startgruppen ohne vorbelegte Rechte) — der Admin vergibt sie seiner
  Gruppe über `PUT /groups/:id/permissions/:key`.

## Firmen-Stammdaten und Audit

- `GET /company/profile` (alle), `PUT /company/profile` (Admin):
  Anschrift, Steuernummer, USt-IdNr., IBAN, E-Mail, Telefon — werden
  beim Finalisieren unveränderlich ins Dokument übernommen.
- `GET /audit?limit=` (Admin): wer hat wann was an welchem Objekt
  getan, neueste zuerst. Bewusst **ohne Inhalte** (Datenminimierung).

## Schema-Migrationen

`lib/src/db/migrations.dart`: versionierte Stufen (Tabelle
`schema_migrations`), beim Serverstart in einer Transaktion mit
Advisory-Lock ausgeführt. Stufen werden nur angehängt, nie geändert —
wie in der Offline-App.

## Erstadmin-Recovery (Betreiber)

Kein API-Endpunkt — nur mit direktem DB-Zugriff:

```bash
docker compose exec server /app/recover_admin <email> <companyId>
```

## Bewusst noch nicht Teil von B1

- Konkrete **Standardrechte je Startgruppe** — laut Roadmap
  ausdrücklich "nicht entschieden, muss vor Rollout fachlich festgelegt
  werden". Der Katalog definiert nur, welche Schlüssel es gibt.
- Mailversand von Einladungen durch den Server.
- Flutter-Client-Integration (Online-Verbindungsmodus).
- Server-seitig noch fehlende Fachteile: Lieferanten/Artikelgruppen-
  Kalkulation, Umwandlung Angebot→Auftrag→Rechnung, Projekte,
  Zahlungsstatus, PDF-Erzeugung, Firmen-Stammdaten (Adresse/Steuernr.).
