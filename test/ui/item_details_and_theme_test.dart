import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:werkkernerp/data/database/database.dart';
import 'package:werkkernerp/main.dart';
import 'package:werkkernerp/ui/widgets/sidebar_nav_item.dart';

/// Kay-Nachtrag 2026-10-16 (zweiter Nachtrag): Einheit + Rabatt pro
/// Position, klarere Positionsanzeige, Design-Auswahl Hell/Dunkel/System.
AppDatabase _inMemoryDb() =>
    AppDatabase.forTesting(NativeDatabase.memory(setup: (db) => db.execute('PRAGMA foreign_keys = ON;')));

void main() {
  testWidgets(
    'Einheit und Rabatt lassen sich pro Position erfassen und erscheinen in der Detailzeile',
    (tester) async {
      await tester.pumpWidget(WerkkernErpApp(database: _inMemoryDb()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Firma anlegen'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Elektro Beckmann');
      await tester.tap(find.text('Anlegen'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Kunden'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kunde anlegen'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Name *'), 'Testkunde');
      await tester.tap(find.text('Anlegen'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Rechnungen'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Neue Rechnung'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Testkunde'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Position hinzufügen'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Beschreibung *'), 'Kabel');
      await tester.enterText(find.widgetWithText(TextField, 'Menge'), '50');
      await tester.enterText(find.widgetWithText(TextField, 'Einheit'), 'm');
      await tester.enterText(find.widgetWithText(TextField, 'Einzelpreis (€) *'), '1,50');
      await tester.enterText(find.widgetWithText(TextField, 'Rabatt %'), '10');
      await tester.tap(find.text('Hinzufügen'));
      await tester.pumpAndSettle();

      // Detailzeile: Menge inkl. Einheit, und eine eigene Rabattzeile.
      expect(find.textContaining('50 m ×'), findsOneWidget);
      expect(find.textContaining('10 % Rabatt'), findsOneWidget);
    },
  );

  testWidgets('Design-Auswahl in den Einstellungen wechselt zwischen Hell/Dunkel/System', (
    tester,
  ) async {
    await tester.pumpWidget(WerkkernErpApp(database: _inMemoryDb()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Firma anlegen'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Elektro Beckmann');
    await tester.tap(find.text('Anlegen'));
    await tester.pumpAndSettle();

    // Kay-Feedback 2026-10-19 ("zu voll in der bottom Menüleiste"):
    // "Einstellungen" steht in der schmalen Bottom-Bar jetzt unter
    // "Mehr", nicht mehr direkt.
    await tester.tap(find.text('Mehr'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Einstellungen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Darstellung'));
    await tester.pumpAndSettle();

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.themeMode, ThemeMode.system);

    await tester.tap(find.text('Dunkel'));
    await tester.pumpAndSettle();

    final appAfter = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(appAfter.themeMode, ThemeMode.dark);
  });

  testWidgets(
    'Design-Auswahl ist auch in der Breit-Ansicht (Sidebar) erreichbar und bleibt beim '
    'Tab-Wechsel erhalten',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(WerkkernErpApp(database: _inMemoryDb()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Firma anlegen'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Elektro Beckmann');
      await tester.tap(find.text('Anlegen'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(SidebarNavItem, 'Einstellungen'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Darstellung'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hell'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(SidebarNavItem, 'Rechnungen'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(SidebarNavItem, 'Einstellungen'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Darstellung'));
      await tester.pumpAndSettle();

      final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(app.themeMode, ThemeMode.light);
    },
  );
}
