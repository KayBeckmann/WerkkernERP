import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:werkkernerp/data/database/database.dart';
import 'package:werkkernerp/main.dart';

/// Kay-Nachtrag 2026-10-16: "Positionen ... nachträglich noch
/// bearbeiten können" + "Summen pro Gruppe" + "Dropdown für
/// Positionsgruppen, die es schon gibt".
AppDatabase _inMemoryDb() =>
    AppDatabase.forTesting(NativeDatabase.memory(setup: (db) => db.execute('PRAGMA foreign_keys = ON;')));

Future<void> _addItem(
  WidgetTester tester, {
  required String description,
  required String price,
  required String group,
}) async {
  await tester.tap(find.text('Position hinzufügen'));
  await tester.pumpAndSettle();
  await tester.enterText(find.widgetWithText(TextField, 'Beschreibung *'), description);
  await tester.enterText(find.widgetWithText(TextField, 'Einzelpreis (€) *'), price);
  await tester.enterText(find.widgetWithText(TextField, 'Positionsgruppe (optional)'), group);
  // "Fertig" simulieren statt direkt den Button zu tappen — sonst liegt
  // das Autocomplete-Options-Overlay noch über dem Dialog und fängt den
  // Tap ab.
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Hinzufügen'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'Summe pro Gruppe wird korrekt berechnet und nach Bearbeiten einer Position aktualisiert',
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

      await _addItem(tester, description: 'Steckdose', price: '10', group: 'Bad');
      await _addItem(tester, description: 'Lichtschalter', price: '5', group: 'Bad');

      // 19% Standard-MwSt. auf beide Positionen: netto 15€ -> brutto 17,85€.
      expect(find.text('Gruppensumme: 17,85 €'), findsOneWidget);

      // Bestehende Position bearbeiten statt löschen+neu anlegen.
      await tester.tap(find.text('Steckdose'));
      await tester.pumpAndSettle();
      expect(find.text('Position bearbeiten'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Beschreibung *'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextField, 'Einzelpreis (€) *'), '20');
      await tester.tap(find.text('Speichern'));
      await tester.pumpAndSettle();

      // 20€ + 5€ = 25€ netto -> 29,75€ brutto.
      expect(find.text('Gruppensumme: 29,75 €'), findsOneWidget);
    },
  );

  testWidgets(
    'Autocomplete für Positionsgruppen schlägt bereits verwendete Gruppen vor',
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

      await _addItem(tester, description: 'Steckdose', price: '10', group: 'Bad');

      // Zweite Position anlegen: Gruppenfeld antippen -> "Bad" muss als
      // Vorschlag erscheinen (vorhandene Gruppe aus der ersten Position).
      await tester.tap(find.text('Position hinzufügen'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextField, 'Positionsgruppe (optional)'));
      await tester.pumpAndSettle();

      expect(find.text('Bad'), findsWidgets);
    },
  );
}
