import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:werkkernerp/data/database/database.dart';
import 'package:werkkernerp/main.dart';
import 'package:werkkernerp/ui/widgets/sidebar_nav_item.dart';

/// Dashboard-Kern (Kay-Anfrage 2026-10-17: "Ein Dashboard hätte ich
/// auch gerne als Einstiegspunkt, wenn man eine Firma ausgewählt hat").
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
    'Dashboard ist der Einstiegspunkt nach Firmenwahl und zeigt die Basis-Kennzahlen ohne '
    'optionale Module',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await _createCompanyAndEnter(tester);

      // Dashboard, nicht Rechnungen, ist der Startpunkt.
      expect(find.text('Dashboard'), findsWidgets);
      expect(find.text('Noch keine Rechnungsentwürfe.'), findsNothing);
      expect(find.text('Rechnungssumme diesen Monat'), findsOneWidget);
      expect(find.text('Rechnungssumme dieses Jahr'), findsOneWidget);
      expect(find.text('0,00 €'), findsWidgets);

      // Ohne aktivierte Module erscheinen deren Kacheln nicht.
      expect(find.text('Aktive Projekte'), findsNothing);
      expect(find.textContaining('TÜV fällig'), findsNothing);
      expect(find.text('Offene Rechnungen'), findsNothing);
    },
  );

  testWidgets(
    'Eine finalisierte Rechnung erhöht die Rechnungssumme des Dashboards; aktivierte Module '
    'blenden ihre Kacheln ein',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await _createCompanyAndEnter(tester);

      // C1 Projekte aktivieren -> Kachel sollte nach Rückkehr zum
      // Dashboard erscheinen.
      await tester.tap(_sidebarItem('Einstellungen'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Module'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(SwitchListTile, 'Projekte'));
      await tester.pumpAndSettle();

      // Kunde + Rechnung mit einer Position anlegen und finalisieren.
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

      await tester.tap(_sidebarItem('Dashboard'));
      await tester.pumpAndSettle();
      // Dashboard lädt beim initState einmalig — manuell aktualisieren,
      // damit die inzwischen finalisierte Rechnung berücksichtigt wird
      // (gleiches Prinzip wie der "Aktualisieren"-Button im Screen).
      await tester.tap(find.byTooltip('Aktualisieren'));
      await tester.pumpAndSettle();

      // 100€ netto + 19% USt = 119,00 €.
      expect(find.text('119,00 €'), findsWidgets);
      // Kein Projekt angelegt, nur das Modul aktiviert — die Kachel muss
      // trotzdem erscheinen (das ist der eigentliche Test hier), ihr
      // Wert bleibt dabei korrekt 0.
      expect(find.text('Aktive Projekte'), findsOneWidget);
    },
  );
}
