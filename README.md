# WerkkernERP

Lokal-first Offline-ERP für ein Elektro-Kleingewerbe (Android + Web),
gebaut mit Flutter/Dart und einer lokalen SQLite-Datenbank (Drift). Eine
Person führt mehrere lokal vollständig getrennte Firmen, legt Kunden/
Artikel an und erstellt Angebote, Aufträge, Lieferscheine, Proforma- und
echte Rechnungen bis zum PDF — ohne Server, Konto, Login oder
Internetzwang.

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
- Eine zweite Betriebsart — **Online-Multi-User** mit Server, Mitglied-
  schaften und Rechteprüfung — ist bewusst noch nicht begonnen (siehe
  „Geplant, aber bewusst zurückgestellt" unten).

## Umfang (umgesetzt)

**Grundgerüst**
- Mehrere Firmen vollständig datenseitig getrennt, ohne Login/Konto.
- Kunden, Lieferanten, Artikel/Artikelgruppen mit prozentualem Aufschlag
  auf den Einkaufspreis des Standardlieferanten.
- Geldbeträge durchgängig als Integer-Cent mit kaufmännischer Rundung
  (`package:decimal`), nie als Fließkommazahl.
- Lokale, schema-versionierte SQLite-Datenbank mit automatischer
  Migration bei App-Updates (aktuell 20 Schemastufen, keine wird
  rückwirkend geändert — nur angehängt).
- **Dashboard** als Einstiegspunkt nach Firmenwahl: Rechnungssumme
  Monat/Jahr, offene/überfällige Rechnungen, Fuhrpark-TÜV, aktive
  Projekte, wiederkehrende Vorlagen — je nach aktiviertem Modul.

**Dokumente**
- Rechnung, Angebot, Auftrag, Lieferschein und Proforma-Rechnung als
  eigenständige, pro Firma ein-/ausblendbare Dokumentarten mit eigenen
  Nummernkreisen (`R`/`An`/`A`/`LS`/`PF`), eigenem PDF-Titel und eigenem
  Einleitungs-/Schlusstext.
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
- **Projekte**: Dokumente aller Arten einem Projekt zuordnen.
- **Fuhrpark**: Fahrzeuge, TÜV-Fälligkeit, Kostenbuchungen (Tanken/
  Wartung/Leasing/Versicherung/Sonstiges).
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
- Die laufende SQLite-Datenbank selbst ist **noch nicht** verschlüsselt
  (siehe unten).

## Bewusst nicht umgesetzt / zurückgestellt

- **Verschlüsselung der laufenden lokalen Datenbank** (nur Backups sind
  optional verschlüsselt). Ein konkreter Weg ist recherchiert, aber
  noch nicht gebaut.
- **Gutschrift-/Korrekturbeleg** für finalisierte Rechnungen — eigener
  Dokumenttyp/Nummernkreis, fachlich/steuerlich noch zu klären.
- **DATEV-Export für Rechnungen/Einnahmen** (nur Belege/Ausgaben sind
  umgesetzt, siehe oben) und **E-Rechnung (XRechnung/ZUGFeRD)** —
  brauchen jeweils eine eigene fachliche/rechtliche Prüfung
  (Personenkonten/Debitoren-Kontierung bzw. E-Rechnungs-Pflichtfelder),
  aktuell nicht Teil der App.
- **Projekt-Ergebnisrechnung** (kalkulierte vs. tatsächliche Stunden,
  interne GuV, Fahrzeugkosten-Umlage auf Projekte) — Projekte/Fuhrpark
  erfassen bereits Daten, aber ohne automatische Auswertung.
- Konfigurierbare Steuersätze, Nummernmuster und PDF-Layouts mit
  Migration vorhandener Dokumente.
- Zeiterfassung vor Ort, Kunden-Unterschrift, Personal-/Einsatzplanung,
  Materialbestellung/Lager, externe LLM-Anbindung — nicht begonnen.
- **Online-Multi-User-Betrieb** (Server, Mitgliedschaften, Rechte-
  prüfung, selektive Offline-Synchronisation) — eigene zweite
  Betriebsart, noch nicht begonnen. Diese App bleibt bis dahin bewusst
  Single-User/Single-Device ohne Sync zwischen Geräten.

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
