import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:werkkernerp/data/database/database.dart';
import 'package:werkkernerp/main.dart';
import 'package:werkkernerp/ui/widgets/sidebar_nav_item.dart';

/// A5-Abnahme (UI-Ebene): Modul-Schalter in den Einstellungen blenden
/// "Angebote"/"Aufträge" in der Navigation ein bzw. aus. Ergänzt die
/// Repository-Tests in `document_kind_test.dart`, die bereits
/// verifizieren, dass Deaktivieren keine Daten löscht — hier geht es
/// nur um die Sichtbarkeit in der Navigation selbst.
///
/// Sidebar-Einträge werden bewusst über `widgetWithText(SidebarNavItem,
/// ...)` gesucht statt über den bloßen Text: die Einstellungen-Seite
/// zeigt denselben Text als Switch-Label an, ein einfacher `find.text`
/// wäre dort mehrdeutig (hat in einer früheren Fassung dieses Tests
/// fälschlich den Switch erneut umgeschaltet statt zu navigieren).
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
    'A5-Abnahme: Angebote/Aufträge sind standardmäßig aus der Sidebar-Navigation ausgeblendet',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await _createCompanyAndEnter(tester);

      expect(_sidebarItem('Angebote'), findsNothing);
      expect(_sidebarItem('Aufträge'), findsNothing);

      await tester.tap(_sidebarItem('Einstellungen'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Module'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(SwitchListTile, 'Angebote'), findsOneWidget);
      expect(find.widgetWithText(SwitchListTile, 'Aufträge'), findsOneWidget);
    },
  );

  testWidgets(
    'A5-Abnahme: Modul "Angebote" aktivieren blendet den Tab in der Sidebar ein, deaktivieren wieder aus',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await _createCompanyAndEnter(tester);

      await tester.tap(_sidebarItem('Einstellungen'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Module'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(SwitchListTile, 'Angebote'));
      await tester.pumpAndSettle();

      expect(_sidebarItem('Angebote'), findsOneWidget);

      await tester.tap(_sidebarItem('Angebote'));
      await tester.pumpAndSettle();
      expect(find.text('Noch keine Angebotsentwürfe.'), findsOneWidget);

      // Wieder in die Einstellungen und deaktivieren -> Tab verschwindet
      // erneut aus der Sidebar (Daten selbst prüft document_kind_test.dart).
      await tester.tap(_sidebarItem('Einstellungen'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Module'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(SwitchListTile, 'Angebote'));
      await tester.pumpAndSettle();
      expect(_sidebarItem('Angebote'), findsNothing);
    },
  );

  testWidgets(
    'A5-Abnahme: Beide Module gleichzeitig aktiv zeigen Rechnungen, Angebote und Aufträge '
    'nebeneinander, ohne dass eine Liste die andere verdrängt',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await _createCompanyAndEnter(tester);

      await tester.tap(_sidebarItem('Einstellungen'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Module'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(SwitchListTile, 'Angebote'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(SwitchListTile, 'Aufträge'));
      await tester.pumpAndSettle();

      expect(_sidebarItem('Rechnungen'), findsOneWidget);
      expect(_sidebarItem('Angebote'), findsOneWidget);
      expect(_sidebarItem('Aufträge'), findsOneWidget);

      await tester.tap(_sidebarItem('Aufträge'));
      await tester.pumpAndSettle();
      expect(find.text('Noch keine Auftragsentwürfe.'), findsOneWidget);

      await tester.tap(_sidebarItem('Rechnungen'));
      await tester.pumpAndSettle();
      expect(find.text('Noch keine Rechnungsentwürfe.'), findsOneWidget);
    },
  );
}
