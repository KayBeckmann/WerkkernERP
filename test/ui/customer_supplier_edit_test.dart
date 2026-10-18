import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:werkkernerp/data/database/database.dart';
import 'package:werkkernerp/main.dart';

/// Kay-Nachtrag 2026-10-16: "Kunden und Lieferanten können nicht
/// bearbeitet werden" — deckt ab, dass ein Tipp auf einen bestehenden
/// Kunden/Lieferanten jetzt dasselbe Formular zum Bearbeiten öffnet
/// (vorher nur Anlegen möglich) und die Änderung tatsächlich landet.
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

/// Kay-Feedback 2026-10-19 ("zu voll in der bottom Menüleiste"): nur
/// Dashboard/Rechnungen/Kunden stehen noch direkt in der schmalen
/// Bottom-Bar, "Lieferanten" steht jetzt unter "Mehr".
Future<void> _openTab(WidgetTester tester, String label) async {
  await tester.tap(find.text('Mehr'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Tippen auf einen Kunden öffnet das Bearbeiten-Formular und speichert Änderungen', (
    tester,
  ) async {
    await _createCompanyAndEnter(tester);

    await tester.tap(find.text('Kunden'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kunde anlegen'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Name *'), 'Alter Name GmbH');
    await tester.tap(find.text('Anlegen'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Alter Name GmbH'));
    await tester.pumpAndSettle();
    expect(find.text('Kunde bearbeiten'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'USt-IdNr.'), 'DE123456789');
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();

    // Zurück bearbeiten öffnen -> die USt-IdNr. muss vorausgefüllt sein,
    // nicht nur in der DB gelandet sein.
    await tester.tap(find.text('Alter Name GmbH'));
    await tester.pumpAndSettle();
    expect(find.text('DE123456789'), findsOneWidget);
  });

  testWidgets('Tippen auf einen Lieferanten öffnet das Bearbeiten-Formular und speichert Änderungen', (
    tester,
  ) async {
    await _createCompanyAndEnter(tester);

    await _openTab(tester, 'Lieferanten');
    await tester.tap(find.text('Lieferant anlegen'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Name *'), 'Großhändler Süd');
    await tester.tap(find.text('Anlegen'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Großhändler Süd'));
    await tester.pumpAndSettle();
    expect(find.text('Lieferant bearbeiten'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'Ansprechpartner'), 'Frau Fischer');
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Großhändler Süd'));
    await tester.pumpAndSettle();
    expect(find.text('Frau Fischer'), findsOneWidget);
  });

  testWidgets(
    'Kay-Nachtrag 2026-10-16: Kunden-Suchmaske im "Neue Rechnung"-Dialog filtert live',
    (tester) async {
      await _createCompanyAndEnter(tester);

      await tester.tap(find.text('Kunden'));
      await tester.pumpAndSettle();
      for (final name in ['Müller Bau GmbH', 'Schmidt Elektro', 'Müller Transporte']) {
        await tester.tap(find.text('Kunde anlegen'));
        await tester.pumpAndSettle();
        await tester.enterText(find.widgetWithText(TextField, 'Name *'), name);
        await tester.tap(find.text('Anlegen'));
        await tester.pumpAndSettle();
      }

      await tester.tap(find.text('Rechnungen'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Neue Rechnung'));
      await tester.pumpAndSettle();

      expect(find.text('Müller Bau GmbH'), findsOneWidget);
      expect(find.text('Schmidt Elektro'), findsOneWidget);
      expect(find.text('Müller Transporte'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextField, 'Suchen'), 'Müller');
      await tester.pumpAndSettle();

      expect(find.text('Müller Bau GmbH'), findsOneWidget);
      expect(find.text('Müller Transporte'), findsOneWidget);
      expect(find.text('Schmidt Elektro'), findsNothing);
    },
  );
}
