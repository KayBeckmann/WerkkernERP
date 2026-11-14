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

      // Kay-Feedback 2026-11-14: kein Verweis auf Umsatzsteuer — die
      // MwSt.-Auswahl fehlt ganz (vorher stand hier ein gesperrtes Feld).
      expect(find.widgetWithText(DropdownButtonFormField<double>, 'MwSt.'), findsNothing);
      expect(find.widgetWithText(TextField, 'MwSt.'), findsNothing);
      expect(find.widgetWithText(TextField, 'Rabatt %'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextField, 'Beschreibung *'), 'Beratung');
      await tester.enterText(find.widgetWithText(TextField, 'Einzelpreis (€) *'), '100');
      await tester.tap(find.text('Hinzufügen'));
      await tester.pumpAndSettle();

      // 100 € netto bei 0 % USt -> 100,00 € brutto in der Positionszeile,
      // ohne „0 % MwSt.“ und ohne Netto-/Steuer-Zeilen in der Summe.
      expect(find.text('1 × 100,00 €'), findsOneWidget);
      expect(find.textContaining('MwSt.'), findsNothing);
      expect(find.textContaining('Steuer:'), findsNothing);
      expect(find.text('Gesamt: 100,00 €'), findsOneWidget);
    },
  );

  testWidgets(
    'Kleinunternehmer: Beleg erfassen (Buchhaltung) zeigt keine USt.-Auswahl, Beleg wird mit 0 % gespeichert',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final db = _inMemoryDb();
      await tester.pumpWidget(WerkkernErpApp(database: db));
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
      await tester.tap(find.widgetWithText(SwitchListTile, 'Kleinunternehmer nach § 19 UStG'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Module'));
      await tester.pumpAndSettle();
      final buchhaltung = find.widgetWithText(SwitchListTile, 'Buchhaltung');
      await tester.ensureVisible(buchhaltung);
      await tester.pumpAndSettle();
      await tester.tap(buchhaltung);
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(SidebarNavItem, 'Belege'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Beleg erfassen'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(DropdownButtonFormField<double>, 'USt.'), findsNothing);
      expect(find.textContaining('USt'), findsNothing);

      await tester.enterText(find.widgetWithText(TextField, 'Beschreibung *'), 'Kabel');
      await tester.enterText(find.widgetWithText(TextField, 'Betrag brutto (€) *'), '50');
      await tester.tap(find.text('Speichern'));
      await tester.pumpAndSettle();
      expect(find.text('Kabel'), findsOneWidget);

      final stored = await db.select(db.expenses).get();
      expect(stored.single.vatRatePercent, 0);
    },
  );
}
