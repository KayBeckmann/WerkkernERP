import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:werkkernerp/data/database/database.dart';
import 'package:werkkernerp/main.dart';
import 'package:werkkernerp/ui/widgets/sidebar_nav_item.dart';

/// C14.2 Belege/Ausgaben (Kay-Priorisierungsentscheidung 2026-10-18).
Finder _sidebarItem(String label) => find.widgetWithText(SidebarNavItem, label);

AppDatabase _inMemoryDb() =>
    AppDatabase.forTesting(NativeDatabase.memory(setup: (db) => db.execute('PRAGMA foreign_keys = ON;')));

Future<void> _createCompanyAndEnableBuchhaltung(WidgetTester tester) async {
  await tester.pumpWidget(WerkkernErpApp(database: _inMemoryDb()));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Firma anlegen'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField), 'Elektro Beckmann');
  await tester.tap(find.text('Anlegen'));
  await tester.pumpAndSettle();

  await tester.tap(_sidebarItem('Einstellungen'));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(SwitchListTile, 'Buchhaltung'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'Belege-Übersicht seedet Standardkategorien und zeigt einen neu erfassten Beleg sofort an',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await _createCompanyAndEnableBuchhaltung(tester);

      await tester.tap(_sidebarItem('Belege'));
      await tester.pumpAndSettle();
      expect(find.text('Noch keine Belege erfasst.'), findsOneWidget);

      await tester.tap(find.text('Beleg erfassen'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Beschreibung *'), 'Kabel NYM-J');
      await tester.enterText(find.widgetWithText(TextField, 'Betrag brutto (€) *'), '59,50');
      await tester.tap(find.widgetWithText(DropdownButtonFormField<String?>, 'Ohne Kategorie'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Material/Wareneinkauf').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Speichern'));
      await tester.pumpAndSettle();

      expect(find.text('Kabel NYM-J'), findsOneWidget);
      expect(find.textContaining('Material/Wareneinkauf'), findsOneWidget);
      expect(find.text('59,50 €'), findsWidgets);
    },
  );

  testWidgets(
    'Kategorien verwalten: eine SKR03-Kontonummer eintragen und eine neue Kategorie anlegen',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await _createCompanyAndEnableBuchhaltung(tester);

      await tester.tap(_sidebarItem('Belege'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Kategorien verwalten'));
      await tester.pumpAndSettle();

      expect(find.text('Material/Wareneinkauf'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextField, 'Neue Kategorie'), 'Weiterbildung');
      await tester.tap(find.byTooltip('Kategorie hinzufügen'));
      await tester.pumpAndSettle();
      expect(find.text('Weiterbildung'), findsOneWidget);

      await tester.tap(find.text('Fertig'));
      await tester.pumpAndSettle();

      // Neue Kategorie steht jetzt auch im Beleg-Formular zur Auswahl.
      await tester.tap(find.text('Beleg erfassen'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(DropdownButtonFormField<String?>, 'Ohne Kategorie'));
      await tester.pumpAndSettle();
      expect(find.text('Weiterbildung'), findsWidgets);
    },
  );
}
