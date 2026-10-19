import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:werkkernerp/data/database/database.dart';
import 'package:werkkernerp/main.dart';
import 'package:werkkernerp/ui/widgets/sidebar_nav_item.dart';

/// Nachtrag 2026-10-18: "Rechnung muss umstellbar sein" — Kleingewerbe
/// nach §19 UStG darf keine Umsatzsteuer ausweisen.
AppDatabase _inMemoryDb() =>
    AppDatabase.forTesting(NativeDatabase.memory(setup: (db) => db.execute('PRAGMA foreign_keys = ON;')));

void main() {
  testWidgets(
    'Kleinunternehmer-Schalter aktivieren sperrt die USt-Auswahl im Positions-Dialog auf 0 % — '
    'eine neue Position bekommt automatisch keine Umsatzsteuer',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 2000);
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
      await tester.tap(find.text('Umsatzsteuer'));
      await tester.pumpAndSettle();
      expect(find.text('Gemäß § 19 Abs. 1 UStG wird keine Umsatzsteuer berechnet.'), findsNothing);
      await tester.tap(find.widgetWithText(SwitchListTile, 'Kleinunternehmer nach § 19 UStG'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(SidebarNavItem, 'Kunden'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kunde anlegen'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Name *'), 'Testkunde');
      await tester.tap(find.text('Anlegen'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(SidebarNavItem, 'Rechnungen'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Neue Rechnung'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Testkunde'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Position hinzufügen'));
      await tester.pumpAndSettle();

      // MwSt.-Dropdown ist komplett ersetzt durch ein gesperrtes Feld.
      expect(find.widgetWithText(DropdownButtonFormField<double>, 'MwSt.'), findsNothing);
      expect(find.widgetWithText(TextField, 'MwSt.'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextField, 'Beschreibung *'), 'Beratung');
      await tester.enterText(find.widgetWithText(TextField, 'Einzelpreis (€) *'), '100');
      await tester.tap(find.text('Hinzufügen'));
      await tester.pumpAndSettle();

      // 100 € netto bei 0 % USt -> 100,00 € brutto in der Positionszeile.
      expect(find.text('100,00 €'), findsWidgets);
    },
  );
}
