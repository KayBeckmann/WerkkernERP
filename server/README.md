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

## Tests (ohne laufende Datenbank)

```bash
dart test
```

Läuft gegen `InMemoryPhaseBRepository` — kein Postgres nötig (gleiches
Prinzip wie bei LibreECAD, siehe `../../libre-ECAD/docs/architecture.md`).

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
   `/memberships/:id/overrides/:permission` innerhalb der **eigenen**
   Firma — jeder Versuch auf eine fremde Firma liefert 404, kein
   Unterschied zwischen "existiert nicht" und "gehört einer anderen
   Firma" (kein Oracle für fremde IDs).

## Bewusst noch nicht Teil von B1

- Einladungs-/Aktivierungstoken für **neue** Nutzer beim Hinzufügen zu
  einer Firma (`POST /memberships` setzt aktuell eine bereits über
  `/auth/register` existierende E-Mail voraus) — Onboarding-UX folgt
  später, analog zum bereits erprobten Muster in LibreECADs
  `company_users_service`.
- Konkrete Berechtigungs-Schlüssel und Standardrechte je Startgruppe
  — laut Roadmap ausdrücklich "nicht entschieden, muss vor Rollout
  fachlich festgelegt werden". Diese B1-Grundlage liefert nur den
  **Mechanismus** (`PermissionResolver`, Gruppenrechte, individuelle
  Ausnahmen), keine fachliche Rechtematrix.
- Erstadmin-Recovery, falls der einzige Admin ausfällt (laut Roadmap
  ausdrücklich offen).
- Flutter-Client-Integration (Online-Verbindungsmodus) — noch nicht
  begonnen.
