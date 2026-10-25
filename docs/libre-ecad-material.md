# LibreECAD-Materialvorschau

Entwicklungsintegration für LibreECAD M7. In der Artikelansicht öffnet
„LibreECAD-Materialvorschau“ eine JSON-Datei (`libre-ecad.material.v1`).
Offline wird ausschließlich die aktive Firma gelesen; online benötigt der
Einstieg `articles.read` und lädt über die angemeldete Firmen-API.

Die Datei enthält Projekt-/Quell-ID, Projektversion, Zeichnungs-Prüfsumme,
Paket-Prüfsumme, Artikel-ID/-version, Variante, Einheit, Menge und Gerätebezüge.
Eine physische Geräte-ID darf nur einmal vorkommen. Die Prüfsumme erkennt
Veränderungen, sie ist keine Signatur oder Vertrauensbestätigung des Absenders.
Die Vorschau akzeptiert Stückeinheiten. Namensgleichheit schlägt Kandidaten vor;
eine Zuordnung erfolgt erst durch Auswahl einer konkreten ERP-Artikel-ID.

Jedes Laden ersetzt den Vorschauzustand und löscht bisherige Zuordnungen.
Wiederholtes Laden derselben Paket-ID erzeugt keine weiteren Zeilen.
Unzugeordnete LibreECAD-Geräte bleiben sichtbar. Der bestätigte Export
`werkkernerp.ecad-preview.v1` enthält Ziel-Firmen-ID, Quellpaket und
Artikelzuordnungen als Entwurf. Es werden keine Artikel, Bestände, Angebote,
Aufträge oder Bestellungen geschrieben. Der Entwurf ist kein ausführbarer
Buchungsauftrag und wird noch nicht zurück in ERP eingelesen.

Die Integration liegt bewusst auf `feat/libre-ecad-material-preview`, damit
parallel laufende Einkaufs-/Datenbankarbeiten im Hauptarbeitsverzeichnis
unverändert bleiben. Sie ist nicht automatisch in die laufende ERP-Instanz
ausgerollt.

Validierung: `flutter analyze lib test`, `flutter test` (318 Tests plus gezielter Widgettest zum sichtbaren Zurücksetzen der Zuordnung).
`test/fixtures/libre_ecad_material.json` stammt aus dem synthetischen
LibreECAD-Generator `backend/ecad_core/bin/planning_sample.dart`.
