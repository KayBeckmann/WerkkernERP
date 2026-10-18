import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:werkkernerp/data/database/database.dart';
import 'package:werkkernerp/main.dart';

/// Kay-Feedback 2026-10-19: "Im Menü sieht man die Punkte für
/// Buchhaltung nicht. [...] Die Menüführung in der Responsiv-Version
/// müssen wir auch noch mal überarbeiten. Das wird zu voll in der
/// bottom Menüleiste." Die schmale Bottom-Bar zeigt jetzt nur noch
/// Dashboard/Rechnungen/Kunden + "Mehr" (statt mit jedem aktivierten
/// Modul immer weiter zu wachsen) — "Mehr" öffnet dieselbe gruppierte
/// Übersicht wie die breite Sidebar.
AppDatabase _inMemoryDb() =>
    AppDatabase.forTesting(NativeDatabase.memory(setup: (db) => db.execute('PRAGMA foreign_keys = ON;')));

void main() {
  testWidgets(
    'Schmale Bottom-Bar zeigt nur 4 feste Einträge, auch mit allen Modulen aktiviert; '
    '"Mehr" zeigt Buchhaltung gruppiert und wechselt den Tab',
    (tester) async {
      // Schmal (unter der 840px-Breit-Layout-Schwelle), aber sehr hoch
      // — die "Mehr"-Liste mit allen aktivierten Modulen passt dann
      // komplett ohne Scrollen hinein, was das lazy-build-/Cache-
      // Extent-Verhalten von Slivern (dazu mehr unten) als Fehlerquelle
      // ausschließt.
      tester.view.physicalSize = const Size(400, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(WerkkernErpApp(database: _inMemoryDb()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Firma anlegen'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Elektro Beckmann');
      await tester.tap(find.text('Anlegen'));
      await tester.pumpAndSettle();

      // Alle optionalen Module aktivieren — die Bottom-Bar darf dadurch
      // NICHT wachsen.
      await tester.tap(find.text('Mehr'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Einstellungen'));
      await tester.pumpAndSettle();
      for (final module in [
        'Angebote',
        'Aufträge',
        'Lieferscheine',
        'Proforma-Rechnungen',
        'Projekte',
        'Fuhrpark',
        'Wiederkehrende Rechnungen',
        'Abschlagsrechnungen',
        'Mahnwesen',
        'Versand (SMTP)',
        'Buchhaltung',
      ]) {
        // Jede weitere aktivierte Kachel/Settings-Karte schiebt die
        // nächsten Schalter weiter nach unten — erst sichtbar scrollen,
        // dann tippen (gleiches Muster wie beim A5-Fund mit dem vierten
        // Modul-Schalter).
        final finder = find.widgetWithText(SwitchListTile, module);
        await tester.ensureVisible(finder);
        await tester.pumpAndSettle();
        await tester.tap(finder);
        await tester.pumpAndSettle();
      }

      expect(find.byType(NavigationDestination), findsNWidgets(4));
      expect(find.text('Dashboard'), findsWidgets);
      expect(find.text('Rechnungen'), findsOneWidget);
      expect(find.text('Kunden'), findsOneWidget);
      expect(find.text('Mehr'), findsOneWidget);

      await tester.tap(find.text('Mehr'));
      await tester.pumpAndSettle();

      // Über `ListTile` statt nacktem `find.text()` gesucht: einige
      // Tab-Titel (z. B. "Offene Posten", "Bankabgleich") stimmen
      // zufällig mit der eigenen AppBar-Überschrift des jeweiligen (per
      // IndexedStack weiterhin im Hintergrund gemounteten) Tabs
      // überein und wären sonst mehrdeutig.
      Finder listTile(String text) => find.widgetWithText(ListTile, text);

      // SectionLabel schreibt die Überschrift groß (siehe
      // section_label.dart: `label.toUpperCase()`).
      expect(find.text('BUCHHALTUNG'), findsOneWidget, reason: 'Sektionsüberschrift');
      expect(listTile('Offene Posten'), findsOneWidget);
      expect(listTile('Belege'), findsOneWidget);
      expect(listTile('EÜR-Übersicht'), findsOneWidget);
      expect(listTile('Bankabgleich'), findsOneWidget);

      await tester.tap(listTile('Belege'));
      await tester.pumpAndSettle();

      expect(find.text('Belege/Ausgaben'), findsOneWidget);
    },
  );
}
