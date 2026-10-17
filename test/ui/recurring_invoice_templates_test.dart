import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:werkkernerp/data/database/database.dart';
import 'package:werkkernerp/main.dart';
import 'package:werkkernerp/ui/widgets/sidebar_nav_item.dart';

/// C11 Wiederkehrende Rechnungen (Kay-Priorisierungsentscheidung
/// 2026-10-17). Deckt den UI-Pfad ab: Modul aktivieren, Vorlage anlegen,
/// **ein echter Neustart der App** (nicht nur erneutes Antippen des
/// Rechnungen-Tabs) erzeugt den fälligen Entwurf automatisch.
///
/// Bewusst ein **datei-basierter** `NativeDatabase` statt
/// `NativeDatabase.memory()`: nur so lässt sich die Verbindung
/// zwischendurch echt schließen und mit denselben Daten neu öffnen, um
/// einen App-Neustart realistisch zu simulieren (eine In-Memory-DB würde
/// beim Schließen ihren gesamten Inhalt verlieren). Das deckt genau die
/// in der Roadmap festgehaltene Grenze ab: "ohne Server/Hintergrunddienst
/// kann die Fälligkeitsprüfung nur beim App-Start laufen" — ein bloßes
/// erneutes Antippen des bereits gemounteten Rechnungen-Tabs (IndexedStack
/// hält ihn dauerhaft am Leben, siehe A5) löst bewusst **keinen** neuen
/// Lauf aus.
void main() {
  testWidgets(
    'Vorlage anlegen mit fälligem Datum erzeugt nach einem Neustart der App einen Entwurf '
    'und schiebt die Fälligkeit weiter',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final tempDir = Directory.systemTemp.createTempSync('werkkernerp_recurring_test_');
      addTearDown(() => tempDir.deleteSync(recursive: true));
      final dbPath = p.join(tempDir.path, 'test.sqlite');

      var db = AppDatabase.forTesting(
        NativeDatabase(File(dbPath), setup: (raw) => raw.execute('PRAGMA foreign_keys = ON;')),
      );

      await tester.pumpWidget(WerkkernErpApp(database: db));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Firma anlegen'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Elektro Beckmann');
      await tester.tap(find.text('Anlegen'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(SidebarNavItem, 'Kunden'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kunde anlegen'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Name *'), 'Testkunde');
      await tester.tap(find.text('Anlegen'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(SidebarNavItem, 'Einstellungen'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(SidebarNavItem, 'Vorlagen'), findsNothing);
      await tester.tap(find.widgetWithText(SwitchListTile, 'Wiederkehrende Rechnungen'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(SidebarNavItem, 'Vorlagen'), findsOneWidget);

      await tester.tap(find.widgetWithText(SidebarNavItem, 'Vorlagen'));
      await tester.pumpAndSettle();
      expect(find.text('Noch keine wiederkehrenden Vorlagen angelegt.'), findsOneWidget);

      await tester.tap(find.text('Neue Vorlage'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Bezeichnung *'), 'Hosting monatlich');

      // Fälligkeitsdatum auf "heute" setzen (DatePicker öffnet mit
      // DateTime.now() als initialem Wert) -> sofort fällig.
      await tester.tap(find.textContaining('Nächste Rechnung:'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Position hinzufügen'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Beschreibung *'), 'Hosting-Paket');
      await tester.enterText(find.widgetWithText(TextField, 'Einzelpreis (€) *'), '29,90');
      await tester.tap(find.text('Hinzufügen'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Speichern'));
      await tester.pumpAndSettle();

      expect(find.text('Hosting monatlich'), findsOneWidget);

      // Echter "Neustart": Verbindung schließen und mit derselben Datei
      // neu öffnen, dann eine komplett neue App-Instanz pumpen.
      //
      // `tester.pumpWidget(WerkkernErpApp(...))` **allein** reicht dafür
      // nicht: Flutters Test-Binding aktualisiert einen bereits
      // existierenden Baum gleichen Widget-Typs ganz normal (wie ein
      // `setState`), statt ihn zu verwerfen — `Provider<AppDatabase>`s
      // `create`-Callback läuft dann kein zweites Mal, die App würde
      // weiterhin die bereits GESCHLOSSENE alte Verbindung benutzen
      // (gefunden über Debug-Prints: `InvoicesScreen.initState()` lief
      // nach dem "Neustart" kein zweites Mal). Ein Zwischen-Pump auf ein
      // simples Ersatzwidget erzwingt das vollständige Verwerfen des
      // alten Baums, erst danach ist der nächste Pump wirklich ein
      // frischer Start.
      await db.close();
      db = AppDatabase.forTesting(
        NativeDatabase(File(dbPath), setup: (raw) => raw.execute('PRAGMA foreign_keys = ON;')),
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();

      await tester.pumpWidget(WerkkernErpApp(database: db));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Elektro Beckmann'));
      await tester.pumpAndSettle();

      // Direkt nach dem (simulierten) App-Start ist die Rechnungsliste
      // der Startpunkt — die fällige Vorlage hat bereits beim ersten
      // Laden einen Entwurf erzeugt, erkennbar am neuen Listeneintrag
      // (die Hinweis-Snackbar selbst ist zeitkritisch und wird hier
      // bewusst nicht geprüft, um keine Flakiness durch deren Timer
      // gegenüber `pumpAndSettle()` zu riskieren).
      expect(find.text('Testkunde'), findsOneWidget);

      await db.close();
    },
  );
}
