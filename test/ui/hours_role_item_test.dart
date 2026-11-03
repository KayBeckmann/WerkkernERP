import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:werkkernerp/data/database/database.dart';
import 'package:werkkernerp/data/database/tables.dart';
import 'package:werkkernerp/data/repositories/staff_role_repository.dart';
import 'package:werkkernerp/main.dart';

/// C3.4 (Nachtrag 2026-11-03): „Beim Hinzufügen von Positionen ‚Stunden‘
/// soll die Einheit ‚h‘ vorgesetzt sein und ich möchte aus den Rollen
/// aussuchen können. Die gesetzten Stundensätze sollen dann genutzt
/// werden.“
AppDatabase _inMemoryDb() =>
    AppDatabase.forTesting(NativeDatabase.memory(setup: (db) => db.execute('PRAGMA foreign_keys = ON;')));

String _text(WidgetTester tester, String label) =>
    tester.widget<TextField>(find.widgetWithText(TextField, label)).controller!.text;

Future<void> _pickRole(WidgetTester tester, String label) async {
  await tester.tap(find.byKey(const Key('item-role')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Stunden-Position: Einheit h, Rolle wählen setzt Verrechnungssatz und Namen, Rolle bleibt gespeichert',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final db = _inMemoryDb();
    await tester.pumpWidget(WerkkernErpApp(database: db));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Firma anlegen'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Elektro Beckmann');
    await tester.tap(find.text('Anlegen'));
    await tester.pumpAndSettle();

    final monteur = (await tester.runAsync(() async {
      final company = (await db.select(db.companies).get()).single;
      final roles = StaffRoleRepository(db);
      await roles.create(companyId: company.id, name: 'Azubi');
      return roles.create(companyId: company.id, name: 'Monteur', hourlyBillingRateCents: 6500);
    }))!;

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

    await tester.tap(find.text('Position hinzufügen'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('item-role')), findsNothing, reason: 'Rolle nur bei Stunden');
    await tester.tap(find.text('Stunden'));
    await tester.pumpAndSettle();
    expect(_text(tester, 'Einheit'), 'h');

    await _pickRole(tester, 'Monteur · 65,00 €/h');
    expect(_text(tester, 'Beschreibung *'), 'Monteur');
    expect(_text(tester, 'Einzelpreis (€) *'), '65,00');

    // Rolle ohne Verrechnungssatz: Preis bleibt leer statt 0 €.
    await _pickRole(tester, 'Azubi');
    expect(_text(tester, 'Beschreibung *'), 'Azubi');
    expect(_text(tester, 'Einzelpreis (€) *'), isEmpty);
    expect(find.text('Kein Verrechnungssatz hinterlegt — Preis bitte eingeben.'), findsOneWidget);

    // Eigener Preis bleibt beim Rollenwechsel stehen, Vorschlagstext wechselt.
    await tester.enterText(find.widgetWithText(TextField, 'Einzelpreis (€) *'), '60');
    await _pickRole(tester, 'Monteur · 65,00 €/h');
    expect(_text(tester, 'Einzelpreis (€) *'), '60');
    expect(_text(tester, 'Beschreibung *'), 'Monteur');

    await tester.enterText(find.widgetWithText(TextField, 'Stunden'), '2');
    await tester.tap(find.text('Hinzufügen'));
    await tester.pumpAndSettle();
    expect(find.text('2 h × 60,00 € · 19 % MwSt.'), findsOneWidget);
    expect(find.widgetWithText(Chip, 'Monteur'), findsOneWidget);

    await tester.tap(find.byTooltip('Entwurf speichern'));
    await tester.pumpAndSettle();
    final item = (await tester.runAsync(() => db.select(db.invoiceItems).getSingle()))!;
    expect(item.kind, InvoiceItemKind.hours);
    expect(item.staffRoleId, monteur.id);
    expect(item.unit, 'h');
    expect(item.unitPriceCents, 6000);

    // Bearbeiten zeigt die gespeicherte Rolle wieder an.
    await tester.tap(find.text('Monteur').first);
    await tester.pumpAndSettle();
    expect(find.text('Monteur · 65,00 €/h'), findsOneWidget);
  });
}
