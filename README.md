# WerkkernERP

Lokal-first ERP für ein Elektro-Kleingewerbe (Android + Web), gebaut mit
Flutter/Dart. Zwei Betriebsarten in derselben App:

- **Offline (Single-User):** lokale SQLite-Datenbank (Drift), mehrere
  vollständig getrennte Firmen, Kunden/Artikel, Angebote, Aufträge,
  Lieferscheine, Proforma-, Abschlags- und echte Rechnungen bis zum
  PDF — ohne Server, Konto, Login oder Internetzwang.
- **Online (Multi-User):** eigener Server (`server/`, Dart + PostgreSQL)
  mit Mitgliedschaften, Gruppen, serverseitiger Rechteprüfung,
  verschlüsseltem selektiven Offline-Bestand und einer Schnittstelle
  für KI-Agenten (MCP). Der Offline-Modus bleibt davon unberührt.

## Status

**Arbeitsstand, keine Zusage für Rechtskonformität oder einen festen
Veröffentlichungstermin.** Die Offline-Single-User-Variante (Android +
eine LAN-Web-Vorschau) ist feature-vollständig für den unten
beschriebenen Umfang und durchgängig automatisiert getestet, aber:

- **Kein fachlich/rechtlich geprüftes Produkt.** Rechnungs-, Umsatzsteuer-,
  GoBD- und E-Rechnungs-Anforderungen sind technisch als Arbeitsgrundlage
  umgesetzt (siehe unten), aber **nicht** von einem Steuerberater/Juristen
  abgenommen. Vor produktivem Einsatz für echte Geschäftsvorgänge selbst
  prüfen bzw. prüfen lassen.
- **Zwei Testschritte sind nur auf einem echten Android-Gerät möglich**
  und stehen noch aus: ein Navigations-/Formulardurchlauf auf einem
  kleinen Bildschirm, sowie ein Backup/Restore-Test über Neustart,
  App-Update und eine frische Installation hinweg.
- Die **Online-Betriebsart** ist funktionsfähig und getestet, umfasst
  serverseitig aber bisher nur den Kern (Kunden, Artikel, Dokumente inkl.
  Umwandlung, Zahlungsstatus, PDF). Weitere Module laufen vorerst nur
  offline — siehe unten.

## Umfang (umgesetzt)

**Grundgerüst**
- Mehrere Firmen vollständig datenseitig getrennt, ohne Login/Konto.
- Kunden, Lieferanten, Artikel/Artikelgruppen mit prozentualem Aufschlag
  auf den Einkaufspreis des Standardlieferanten.
- Geldbeträge durchgängig als Integer-Cent mit kaufmännischer Rundung
  (`package:decimal`), nie als Fließkommazahl.
- Lokale, schema-versionierte SQLite-Datenbank mit automatischer
  Migration bei App-Updates (Stufen werden nur angehängt, nie
  rückwirkend geändert).
- **Dashboard** als Einstiegspunkt nach Firmenwahl: Rechnungssumme
  Monat/Jahr, offene/überfällige Rechnungen, Fuhrpark-TÜV, aktive
  Projekte, wiederkehrende Vorlagen — je nach aktiviertem Modul.

**Dokumente**
- Rechnung, Angebot, Auftrag, Lieferschein, Proforma-Rechnung und
  Gutschrift als eigenständige, pro Firma ein-/ausblendbare
  Dokumentarten mit eigenen Nummernkreisen (`R`/`An`/`A`/`LS`/`PF`/`G`,
  optional mit Projektnummer `R-JJPPxxx`), eigenem PDF-Titel und eigenem
  Einleitungs-/Schlusstext; Kleinunternehmerregelung (§ 19 UStG).
- Entwurf frei editierbar; Finalisierung vergibt atomar die nächste
  Nummer im Firmen-/Typ-/Jahreskreis und ist danach unveränderlich —
  mit einer Ausnahme: ein finalisiertes Angebot/Auftrag/Proforma bleibt
  editierbar, bis daraus tatsächlich ein Folgedokument entstanden ist.
- Umwandlung Angebot → Auftrag → Lieferschein/Rechnung; Abschlags-
  rechnungen mit automatischem Abzug bereits gestellter Abschläge
  (inkl. USt.) in der Schlussrechnung.
- Eigenständig erzeugtes PDF (keine Vorlage/kein Asset aus RechnungsFee
  übernommen) mit Firmendaten, Positionsgruppen, Steueraufschlüsselung
  nach 19/7/0 % und einem bei Finalisierung eingefrorenen Text-
  Schnappschuss (eine spätere Änderung der Firmentexte verändert kein
  bereits finalisiertes PDF mehr).

**Weitere Module (pro Firma einzeln aktivierbar)**
- **Projekte**: Dokumente aller Arten einem Projekt zuordnen, einfache
  Ergebnisrechnung (Erlöse − Belege − Stundenkosten, Stunden Soll/Ist).
- **Zeiterfassung** mit Rollen-Stundensätzen, Festpreis-Kennzeichen,
  Materialabschlag und **Kunden-Stundenzettel mit Touch-Unterschrift**
  (keine qualifizierte elektronische Signatur).
- **Lagerbestand, Inventur, Bewegungsprotokoll und Bestellwesen**
  (Mindestbestand, Mindestbestellmenge, Wareneingang, SKR03-Beleg).
- **Fuhrpark**: Fahrzeuge, TÜV-Fälligkeit, Kostenbuchungen inkl.
  Tilgungs-/Zinsanteil, als Gemeinkosten in der EÜR.
- **Wiederkehrende Rechnungen**: Vorlagen erzeugen bei Fälligkeit einen
  neuen Entwurf (nie automatisch finalisiert), holen beim nächsten
  App-Start alle inzwischen fälligen Perioden nach.
- **Mahnwesen**: Fälligkeitsdatum/Zahlungsstatus, konfigurierbare
  Mahnfristen/-gebühren/Verzugszins, eigenständiges Mahnschreiben-PDF.
- **SMTP-Versand**: Rechnungen, Angebote und Aufträge direkt aus der App
  per E-Mail versenden (Android echt per SMTP; im Web-Build aus
  Browser-Sicherheitsgründen nur als PDF-Download, siehe unten).
- **Buchhaltung** (Kontenrahmen SKR03): Offene-Posten-Übersicht je
  Kunde, Belege/Ausgaben-Erfassung mit frei konfigurierbaren
  Kategorien (SKR03-Kontonummer ist deine eigene Angabe, keine
  Vorgabe durch die App), interne EÜR-Übersicht (Monat/Jahr,
  **keine** steuerliche Erklärung nach § 4 Abs. 3 EStG), Bankabgleich
  per CSV-Import mit konfigurierbarer Spaltenzuordnung (nie
  automatisches Buchen — jede Zuordnung bestätigst du selbst) und ein
  DATEV-Export (EXTF-Buchungsstapel) für Belege, bei dem das
  BU-Schlüssel-Feld bewusst immer leer bleibt und dein Steuerberater
  es ergänzt.

**Backup & Sicherheit**
- Transaktional konsistentes Backup (SQLite `VACUUM INTO`, nicht die
  laufende Datei kopieren) als Zip mit Manifest, optional mit
  Passphrase verschlüsselt (PBKDF2 + AES-256-GCM).
- Restore validiert Format/App-Kennung/Schemaversion/Integrität
  **vollständig vor** jedem Eingriff in die bestehenden Daten; Schreiben
  über eine Temp-Datei + atomares `rename()`.
- SMTP-Passwörter liegen in `flutter_secure_storage` (Android Keystore /
  Web WebCrypto), nie in der SQLite-Datenbank oder im Backup-Zip.
- Optionale Verschlüsselung der laufenden Datenbank (SQLite3 Multiple
  Ciphers) mit Geräteschlüssel **oder** Passwort — Android; Web
  bewusst ohne.

**Online-Betriebsart (Phase B)** — Details in [`server/README.md`](server/README.md)
- Server `server/` (Dart/shelf + PostgreSQL, versionierte Migrationen,
  Docker Compose, optionaler TLS-Proxy). Nutzer ↔ Firmen viele-zu-viele,
  Gruppen + individuelle Ausnahmen, Einladungen, Firmenmodule,
  Audit-Protokoll, Login-Drosselung, verschlüsseltes Backup/Restore.
- Jede Abfrage firmengebunden, fremde IDs verhalten sich wie nicht
  existierende; optimistische Versionierung statt „last write wins“.
- In der App: „Online anmelden“ (Wolken-Symbol) mit Dokumenten, Kunden,
  Artikeln, Verwaltung für Admins, PDF mit demselben Generator wie
  offline.
- **Selektiver Offline-Bestand:** ausdrücklich markierte Dokumente
  liegen AES-256-GCM-verschlüsselt auf dem Gerät, Entwürfe sind offline
  bearbeitbar (Outbox, idempotenter Abgleich, Konflikte sichtbar).
- **KI-Agenten (MCP):** persönliche Agent-Token mit genau den Rechten
  des Nutzers, irreversible Aktionen nur nach Bestätigung in der App;
  MCP-Server in [`packages/werkkern_mcp`](packages/werkkern_mcp/README.md).
- Gemeinsame reine Dart-Pakete: `packages/werkkern_core` (Geld, Summen,
  Nummernformat, Umwandlungsregeln — App und Server rechnen identisch)
  und `packages/werkkern_client` (API-Client, Offline-Abgleich).

## Bewusst nicht umgesetzt / offen

- **E-Rechnung (XRechnung/ZUGFeRD)** und **DATEV-Export für Rechnungen/
  Einnahmen** — brauchen eine eigene fachliche/rechtliche Prüfung.
- Konfigurierbare Steuersätze, Nummernmuster und PDF-Layouts mit
  Migration vorhandener Dokumente.
- Personal-/Einsatzplanung (Disposition, Urlaub, Überstunden).
- **Online-Betriebsart:** Projekte, Zeiterfassung, Lager/Bestellwesen,
  Buchhaltung, Fuhrpark, Mahnwesen, Abschläge/Gutschriften und
  E-Mail-Versand laufen bisher nur offline; Offline-Anlage neuer
  Dokumente im Online-Modus ist nicht vorgesehen.
- Import von Materiallisten aus LibreECAD (Format noch offen).
- Lokaler KI-Adapter für die reine Offline-App (ohne Server).

## E-Mail-Versand: Android vs. Web

Ein echter SMTP-Versand braucht einen rohen Netzwerk-Socket. Das ist im
Browser aus Sicherheitsgründen grundsätzlich nicht möglich — ohne einen
eigenen Relay-Server zu betreiben, was dem Offline-/Kein-Server-Prinzip
dieser App widersprechen würde. Deshalb:

- **Android:** versendet echt per SMTP (Server/Port/Zugangsdaten je
  Firma, Betreff/Text frei editierbar vor dem Senden).
- **Web (nur LAN-Vorschau, kein Ziel-Build dieser Roadmap):** bietet statt
  eines zum Scheitern verurteilten Senden-Buttons nur den PDF-Download/
  Teilen-Weg an.

## Build & Ausführen

```bash
flutter pub get

# Android (Debug)
flutter build apk --debug

# Web-Vorschau (nur fürs LAN, kein Produktionsziel)
flutter build web --release
docker compose build web
docker compose up -d web
# erreichbar unter http://<LAN-IP>:8085
```

Tests und statische Analyse:

```bash
flutter analyze
flutter test
(cd server && dart analyze && dart test)      # + echtes Postgres: siehe server/README.md
(cd packages/werkkern_core && dart test)
(cd packages/werkkern_client && dart test)
```

Online-Server lokal starten:

```bash
docker compose up -d --build server-db server   # http://<LAN-IP>:8190
```

Paketkennung ist aktuell `de.kaybeckmann.werkkernerp` (Platzhalter, vor
einer echten Veröffentlichung noch festzulegen).

## Referenz und Lizenz

[RechnungsFee](https://github.com/nicolettas-muggelbude/RechnungsFee)
(AGPL-3.0) diente ausschließlich als **fachliche/gestalterische**
Referenz für Dokumentfluss, optionale Module und Layoutmuster. Es wurde
zu keinem Zeitpunkt Code, eine Vorlage, ein Text, ein Icon oder ein
anderes Asset daraus übernommen — der gesamte Code in diesem Repository
ist eigenständig entwickelt.

WerkkernERP selbst steht unter der [MIT-Lizenz](LICENSE).
