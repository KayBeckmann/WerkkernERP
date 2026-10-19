import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:werkkernerp/data/database/database.dart';
import 'package:werkkernerp/main.dart';
import 'package:werkkernerp/ui/widgets/sidebar_nav_item.dart';

/// Gutschriften (Kay-Entscheidung 2026-10-19: "Gutschriften bekommen einen
/// eigenen Nummernkreis") — UI-Flow: Modul aktivieren, Rechnung anlegen und
/// finalisieren, "Gutschrift erstellen" nutzen, Entwurf finalisieren und die
/// entstandene Gutschrift sowohl im neuen Tab als auch auf der
/// Original-Rechnung ("Gutschriften zu diesem Dokument") wiederfinden.
AppDatabase _inMemoryDb() =>
    AppDatabase.forTesting(NativeDatabase.memory(setup: (db) => db.execute('PRAGMA foreign_keys = ON;')));

void main() {
  testWidgets(
    'Gutschrift-Modul aktivieren, aus einer finalisierten Rechnung eine Gutschrift erstellen, '
    'finalisieren — eigener Nummernkreis "G", kein FAB in der Gutschriften-Liste, Original-'
    'Rechnung bleibt gesperrt und zeigt die Gutschrift in "Gutschriften zu diesem Dokument"',
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
      expect(find.widgetWithText(SidebarNavItem, 'Gutschriften'), findsNothing);
      await tester.tap(find.text('Module'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(SwitchListTile, 'Gutschriften'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(SidebarNavItem, 'Gutschriften'), findsOneWidget);

      await tester.tap(find.widgetWithText(SidebarNavItem, 'Kunden'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kunde anlegen'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Name *'), 'Testkunde');
      await tester.tap(find.text('Anlegen'));
      await tester.pumpAndSettle();

      // Rechnung anlegen, Position hinzufügen, finalisieren.
      await tester.tap(find.widgetWithText(SidebarNavItem, 'Rechnungen'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Neue Rechnung'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Testkunde'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Position hinzufügen'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Beschreibung *'), 'Montagearbeiten');
      await tester.enterText(find.widgetWithText(TextField, 'Einzelpreis (€) *'), '100');
      await tester.tap(find.text('Hinzufügen'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Entwurf speichern'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Finalisieren'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Finalisieren'));
      await tester.pumpAndSettle();

      // Gutschrift-Button sichtbar, "Umwandeln" nicht (Rechnung hat keine
      // allowedConversionTargets).
      expect(find.byTooltip('Gutschrift erstellen'), findsOneWidget);
      expect(find.byTooltip('Umwandeln'), findsNothing);

      await tester.tap(find.byTooltip('Gutschrift erstellen'));
      await tester.pumpAndSettle();

      // Neuer Entwurf mit kopierter Position, Titel "Gutschrift (Entwurf)".
      expect(find.text('Gutschrift (Entwurf) — Testkunde'), findsOneWidget);
      expect(find.text('Montagearbeiten'), findsOneWidget);

      // Gutschrift selbst hat weder "Gutschrift erstellen" noch "Umwandeln"
      // (keine Schachtel-Gutschriften, keine Konversion ab Gutschrift).
      await tester.tap(find.byTooltip('Entwurf speichern'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Finalisieren'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Finalisieren'));
      await tester.pumpAndSettle();

      expect(find.byTooltip('Gutschrift erstellen'), findsNothing);
      expect(find.byTooltip('Umwandeln'), findsNothing);

      // Nummer trägt den eigenen Nummernkreis "G".
      final numberFinder = find.textContaining('G-');
      expect(numberFinder, findsWidgets);

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();

      // Zurück auf der Original-Rechnung: "Gutschriften zu diesem Dokument"
      // listet die soeben finalisierte Gutschrift auf.
      expect(find.text('Gutschriften zu diesem Dokument'), findsOneWidget);

      // Die Gutschriften-Liste selbst hat KEINEN "Neue Gutschrift"-FAB —
      // Gutschriften entstehen ausschließlich aus einer Rechnung heraus.
      await tester.tap(find.widgetWithText(SidebarNavItem, 'Gutschriften'));
      await tester.pumpAndSettle();
      expect(find.text('Neue Gutschrift'), findsNothing);
      expect(find.byType(FloatingActionButton), findsNothing);
    },
  );
}
