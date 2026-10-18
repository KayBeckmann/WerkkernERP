import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:werkkernerp/data/database/database.dart';
import 'package:werkkernerp/main.dart';
import 'package:werkkernerp/ui/widgets/sidebar_nav_item.dart';

/// C14.1 Offene-Posten-Übersicht (Kay-Priorisierungsentscheidung
/// 2026-10-18 — erster Baustein der vollen Buchhaltung).
Finder _sidebarItem(String label) => find.widgetWithText(SidebarNavItem, label);

AppDatabase _inMemoryDb() =>
    AppDatabase.forTesting(NativeDatabase.memory(setup: (db) => db.execute('PRAGMA foreign_keys = ON;')));

Future<void> _createCompanyAndEnter(WidgetTester tester) async {
  await tester.pumpWidget(WerkkernErpApp(database: _inMemoryDb()));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Firma anlegen'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField), 'Elektro Beckmann');
  await tester.tap(find.text('Anlegen'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'Buchhaltung aktivieren blendet "Offene Posten" ein; eine finalisierte Rechnung '
    'erscheint dort unter ihrem Kunden und verschwindet nach "Bezahlt"',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await _createCompanyAndEnter(tester);

      await tester.tap(_sidebarItem('Einstellungen'));
      await tester.pumpAndSettle();
      expect(_sidebarItem('Offene Posten'), findsNothing);
      await tester.tap(find.widgetWithText(SwitchListTile, 'Buchhaltung'));
      await tester.pumpAndSettle();
      expect(_sidebarItem('Offene Posten'), findsOneWidget);

      // Kunde + finalisierte Rechnung anlegen.
      await tester.tap(_sidebarItem('Kunden'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kunde anlegen'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Name *'), 'Testkunde');
      await tester.tap(find.text('Anlegen'));
      await tester.pumpAndSettle();

      await tester.tap(_sidebarItem('Rechnungen'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Neue Rechnung'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Testkunde'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Position hinzufügen'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Beschreibung *'), 'Beratung');
      await tester.enterText(find.widgetWithText(TextField, 'Einzelpreis (€) *'), '100');
      await tester.tap(find.text('Hinzufügen'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Entwurf speichern'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Finalisieren'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Finalisieren'));
      await tester.pumpAndSettle();

      await tester.tap(_sidebarItem('Offene Posten'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Aktualisieren'));
      await tester.pumpAndSettle();

      expect(find.text('Testkunde'), findsOneWidget);
      expect(find.text('Gesamt offen'), findsOneWidget);
      expect(find.text('119,00 €'), findsWidgets);

      await tester.tap(find.text('Testkunde'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Bezahlt'));
      await tester.pumpAndSettle();

      expect(find.text('Keine offenen Posten.'), findsOneWidget);
    },
  );
}
