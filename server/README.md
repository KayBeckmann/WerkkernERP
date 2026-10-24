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
docker compose up -d --build server-db server
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
