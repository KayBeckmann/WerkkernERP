# Parität eigenständige Offline-Firma ↔ Online-Firma

Stand: 26.11.2026, Branch `feat/offline-online-paritaet`. Grundlage ist der
Roadmap-Nachtrag „Funktionsparität eigenständige Offline-Firma ↔
Online-Firma“ vom 26.11.2026.

„Offline-Firma“ meint die lokal in SQLite angelegte Einzelplatzfirma, nicht
den verschlüsselten Offline-Cache einer Online-Firma.

Spalte **Prüfung**:

- **getestet:** durch automatische Tests abgedeckt (Speichern, Neuladen,
  PDF-Text bzw. PDF-Bilder).
- **Code:** nur am Code abgeglichen, noch nicht durchgespielt.
- **offen:** noch nicht geprüft.

Gerätetests auf echtem Android stehen für alle Zeilen noch aus.

## 1. Einstellungen

| Einstellung | Offline | Online | Bewertung | Prüfung |
|---|---|---|---|---|
| Darstellung (Hell/Dunkel) | ja | ja | gleich | Code |
| Firmendaten, strukturierte Anschrift, Steuer, Bank | ja | ja | gleich | Code |
| **PDF-Layout** (klassisch / Nord-Briefbogen) | **neu** | ja | war Lücke, behoben | getestet |
| **PDF-Kopflogo** hochladen/ersetzen/entfernen | **neu** | ja | war Lücke, behoben; gleiche Prüfung (PNG/JPEG, ≤ 1 MiB, ≤ 2048 px, wird dekodiert) | getestet |
| **Dreispaltige Fußzeile** mit Platzhaltern | **neu** | ja | war Lücke, behoben | getestet |
| Einspaltige Fußzeile (Altform) | ja | ja | gleich | getestet |
| Einleitung/Schluss je Dokumentart inkl. Lieferantenbestellung | ja | ja | gleich | Code |
| Standard-Bindefrist für Angebote | ja | ja | gleich | Code |
| Module | ja | ja | gleich; „KI-Agenten (MCP/API)“ nur online (Serverfunktion) | Code |
| Zahlungsbedingungen, Skonto | ja | ja | gleich | Code |
| Umsatzsteuer § 19 | ja | ja | gleich | Code |
| Mahnwesen (Fristen, Gebühren, Zins, Texte) | ja | ja | gleich | Code |
| Versand (SMTP), Mailvorlagen | ja | ja | Transport unterschiedlich, siehe Abschnitt 4 | Code |
| Rollen & Stundensätze | ja | ja | gleich | Code |
| Daten & Sicherung | Backup/Restore der SQLite-Datei | Datenexport; Sicherung durch den Betreiber | bewusst verschieden (Infrastruktur) | Code |
| Datenbank-Verschlüsselung | ja | – | nur lokal sinnvoll | – |
| Mitglieder, Gruppen & Rechte, Einladungen, Protokoll | – | ja | bewusst online (Mehrbenutzer) | – |

## 2. Belege und PDF

Logo, Layout und dreispaltige Fußzeile gelten offline jetzt so wie online:

- **Entwurf:** Die Vorschau nutzt die aktuellen Einstellungen.
- **Finalisierung:** Layout, Logo und Fußzeilenspalten werden zusammen mit
  den Texten als Schnappschuss am Beleg gespeichert.
- **Altbelege ohne Schnappschuss:** bleiben klassisch, ohne Logo, mit der
  bisherigen Fußzeile. Am Altbestand wird nichts nachträglich geändert.

| Beleg/Weg | Offline | Online | Prüfung |
|---|---|---|---|
| Rechnung, Angebot, Auftrag, Lieferschein, Proforma, Gutschrift: Layout/Logo/Fußzeile | neu | ja | getestet (Rechnung); übrige Arten: gemeinsamer Renderer, Code |
| Abschlags-/Schlussrechnung, Storno | wie Rechnung | wie Rechnung | Code |
| Lieferantenbestellung: Logo, Fußzeilenspalten | **neu** (aktuelle Firmendaten, wie online) | ja | getestet |
| Mahnschreiben: Logo, Fußzeilenspalten | **neu** | **neu** | getestet (offline); online: Code |
| Mahnschreiben: einspaltiger Fußzeilentext | jetzt wie online (Text der Rechnung, sonst aktueller) | ja | Code |
| **Entwurfsvorschau: Zahlungsbedingung, Skonto, Bindefrist** | **behoben** (fehlten in der Vorschau) | ja | getestet |
| E-Rechnung (ZUGFeRD/XRechnung) | ja | ja | Code; das Logo ändert nur die Ansicht, nicht die XML |
| Teilen/Download, Mailanhang | ja | ja | Code |

## 3. Datenwege

| Weg | Stand | Prüfung |
|---|---|---|
| App-Update (Drift-Schema 45 → 46) | neue Spalten, Altdaten unverändert, Layout `classic` | getestet |
| Backup → Restore | sichert die komplette SQLite-Datei, die neuen Spalten sind also enthalten | Code |
| Umzugspaket Offline → Online | Layout, Logo und Fußzeilenspalten der Firma sowie Beleg-Schnappschüsse werden übertragen. Der Server prüft das Logo und weist kaputte Logos oder unbekannte Layouts ab. | getestet (App und Server, In-Memory) |

## 4. SMTP

| | Offline (Android) | Offline (Browser) | Online |
|---|---|---|---|
| Direktversand | ja, nach SMTP-Einrichtung | nein: Der Browser kann kein SMTP. Stattdessen PDF herunterladen oder teilen. | über den Server |
| Vorlagen für Betreff und Text | ja | ja | ja |

Diese technische Abweichung erklärt nicht fehlende Texte, Logo oder Fußzeile
– diese sind jetzt in allen Modi gleich. Ein Testversand an echte Kunden hat
nicht stattgefunden.

## 5. Fachmodule (grob, noch nicht durchgespielt)

Für folgende Bereiche gibt es offline und online je eine Oberfläche. Der
genaue Abgleich von Regeln und Ergebnissen je Aktion ist **offen**:

- Kunden mit Ansprechpartnern
- Artikel mit Gruppen und Barcode
- Dokumentfluss: Umwandeln, Kopieren, Stornieren, Zahlungen
- Projekte, Zeiten und Stundenzettel mit Unterschrift
- Fuhrpark
- Wiederkehrende Rechnungen
- Lieferanten und Bestellwesen
- Lager mit Lagerorten, Inventur und Nachbestellvorschlägen
- Buchhaltung: Offene Posten, Ausgaben, EÜR, Bankabgleich, DATEV
- Dokumentarchiv
- Dashboard

Wenn die Berechnung im gemeinsamen Kern `packages/werkkern_core` liegt,
rechnen beide Modi nach denselben Regeln. Das ist aber nur ein Code-Indiz,
kein Nachweis.

## Offen

- Echter Android-Gerätetest: Logo wählen, Fußzeile, Layout, PDF teilen,
  Neustart, Backup → Restore.
- Sichtprüfung der erzeugten PDFs durch Kay.
- Abschnitt 5 je Aktion durchspielen.
- Server-Änderung (Paketimport) ist nicht auf Strato ausgerollt.
