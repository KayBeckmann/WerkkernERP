import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:werkkernerp/data/database/database.dart';
import 'package:werkkernerp/data/database/tables.dart';
import 'package:werkkernerp/main.dart';
import 'package:werkkernerp/ui/widgets/sidebar_nav_item.dart';

/// Kay-Nachtrag 2026-10-16: Lieferschein-Modul + "Finalisiertes Angebot
/// in Auftrag/Lieferschein/Rechnung umwandeln".
AppDatabase _inMemoryDb() =>
    AppDatabase.forTesting(NativeDatabase.memory(setup: (db) => db.execute('PRAGMA foreign_keys = ON;')));

void main() {
  testWidgets(
    'Lieferschein-Modul aktivieren blendet den Tab ein; Stunden-Segment fehlt im '
    'Positions-Dialog für Lieferscheine',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
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
      expect(find.widgetWithText(SidebarNavItem, 'Lieferscheine'), findsNothing);
      await tester.tap(find.text('Module'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(SwitchListTile, 'Lieferscheine'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(SidebarNavItem, 'Lieferscheine'), findsOneWidget);

      // Kunde + Lieferschein-Entwurf anlegen, Positions-Dialog öffnen.
      await tester.tap(find.widgetWithText(SidebarNavItem, 'Kunden'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kunde anlegen'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Name *'), 'Testkunde');
      await tester.tap(find.text('Anlegen'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(SidebarNavItem, 'Lieferscheine'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Neuer Lieferschein'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Testkunde'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Position hinzufügen'));
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: find.byType(SegmentedButton<InvoiceItemKind>), matching: find.text('Artikel')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: find.byType(SegmentedButton<InvoiceItemKind>), matching: find.text('Freitext')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: find.byType(SegmentedButton<InvoiceItemKind>), matching: find.text('Stunden')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'Finalisiertes Angebot zeigt ein Umwandeln-Menü; Umwandlung in Auftrag öffnet einen '
    'neuen Entwurf mit denselben Positionen',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
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
      await tester.tap(find.text('Module'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(SwitchListTile, 'Angebote'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(SwitchListTile, 'Aufträge'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(SidebarNavItem, 'Kunden'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kunde anlegen'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Name *'), 'Testkunde');
      await tester.tap(find.text('Anlegen'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(SidebarNavItem, 'Angebote'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Neues Angebot'));
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

      await tester.tap(find.byTooltip('Umwandeln'));
      await tester.pumpAndSettle();
      expect(find.text('In Auftrag umwandeln'), findsOneWidget);
      expect(find.text('In Lieferschein umwandeln'), findsOneWidget);
      expect(find.text('In Rechnung umwandeln'), findsOneWidget);

      await tester.tap(find.text('In Auftrag umwandeln'));
      await tester.pumpAndSettle();

      expect(find.text('Auftrag (Entwurf) — Testkunde'), findsOneWidget);
      expect(find.text('Beratung'), findsOneWidget);
    },
  );
}
