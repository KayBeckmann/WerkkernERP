import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:werkkernerp/data/database/database.dart';
import 'package:werkkernerp/main.dart';
import 'package:werkkernerp/ui/widgets/sidebar_nav_item.dart';

/// C15.4 E-Rechnung offline: Firmendaten-Maske, Modul-Schalter,
/// strukturierte Kundenanschrift, Warnung vor dem Finalisieren,
/// Prüfung nach dem Finalisieren.
AppDatabase _inMemoryDb() =>
    AppDatabase.forTesting(NativeDatabase.memory(setup: (db) => db.execute('PRAGMA foreign_keys = ON;')));

Future<void> _tapSidebar(WidgetTester tester, String label) async {
  await tester.tap(find.widgetWithText(SidebarNavItem, label));
  await tester.pumpAndSettle();
}

Future<void> _invoiceFor(WidgetTester tester, String customer) async {
  await _tapSidebar(tester, 'Rechnungen');
  await tester.tap(find.text('Neue Rechnung'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(customer));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Position hinzufügen'));
  await tester.pumpAndSettle();
  await tester.enterText(find.widgetWithText(TextField, 'Beschreibung *'), 'Montage');
  await tester.enterText(find.widgetWithText(TextField, 'Einzelpreis (€) *'), '100');
  await tester.tap(find.text('Hinzufügen'));
  await tester.pumpAndSettle();
  await tester.tap(find.byTooltip('Entwurf speichern'));
  await tester.pumpAndSettle();
  await tester.tap(find.byTooltip('Finalisieren'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Finalisieren'));
  await tester.pumpAndSettle();
}

Future<void> _createCustomer(WidgetTester tester, String name, {Map<String, String> fields = const {}}) async {
  await _tapSidebar(tester, 'Kunden');
  await tester.tap(find.text('Kunde anlegen'));
  await tester.pumpAndSettle();
  await tester.enterText(find.widgetWithText(TextField, 'Name *'), name);
  for (final e in fields.entries) {
    final field = find.widgetWithText(TextField, e.key);
    await tester.ensureVisible(field);
    await tester.enterText(field, e.value);
  }
  await tester.tap(find.text('Anlegen'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Firmendaten + Modul, unvollständiger Kunde warnt, vollständiger Kunde ist E-Rechnung-bereit', (tester) async {
    tester.view.physicalSize = const Size(1400, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(WerkkernErpApp(database: _inMemoryDb()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Firma anlegen'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Elektro Beckmann');
    await tester.tap(find.text('Anlegen'));
    await tester.pumpAndSettle();

    // Einstellungen → Firmendaten (neu offline), Freitext zerlegen lassen.
    await _tapSidebar(tester, 'Einstellungen');
    await tester.tap(find.text('Firmendaten'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Anschrift (Freitext, fürs PDF)'), 'Musterstraße 1, 23966 Wismar');
    await tester.tap(find.byTooltip('Aus der Anschrift übernehmen'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, 'Musterstraße 1'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, 'Steuernummer'), '079/123/45678');
    await tester.enterText(find.widgetWithText(TextField, 'IBAN'), 'DE02 1203 0000 0000 2020 51');
    await tester.enterText(find.widgetWithText(TextField, 'E-Mail'), 'info@elektro.example');
    await tester.enterText(find.widgetWithText(TextField, 'Telefon'), '03841 1');
    await tester.tap(find.text('Firmendaten speichern'));
    await tester.pumpAndSettle();
    expect(find.text('Firmendaten gespeichert.'), findsOneWidget);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Module'));
    await tester.pumpAndSettle();
    final module = find.widgetWithText(SwitchListTile, 'E-Rechnung (ZUGFeRD / XRechnung)');
    await tester.ensureVisible(module);
    await tester.tap(module);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    // Kunde ohne Anschrift: Warnung beim Finalisieren, „Trotzdem“ geht.
    await _createCustomer(tester, 'Ohne Anschrift');
    await _tapSidebar(tester, 'Rechnungen');
    await tester.tap(find.text('Neue Rechnung'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ohne Anschrift'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Position hinzufügen'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Beschreibung *'), 'Montage');
    await tester.enterText(find.widgetWithText(TextField, 'Einzelpreis (€) *'), '100');
    await tester.tap(find.text('Hinzufügen'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Entwurf speichern'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Finalisieren'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Finalisieren'));
    await tester.pumpAndSettle();
    expect(find.text('E-Rechnung unvollständig'), findsOneWidget);
    expect(find.text('• Kunde: Straße fehlt.'), findsOneWidget);
    await tester.tap(find.text('Trotzdem finalisieren'));
    await tester.pumpAndSettle();
    expect(find.textContaining('— Ohne Anschrift'), findsOneWidget);
    expect(find.byTooltip('Finalisieren'), findsNothing, reason: 'finalisiert');
    await tester.tap(find.byTooltip('E-Rechnung'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('E-Rechnung prüfen'));
    await tester.pumpAndSettle();
    expect(find.text('Format: ZUGFeRD (PDF mit eingebetteter XML)'), findsOneWidget);
    expect(find.text('• Kunde: PLZ fehlt.'), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    // Vollständiger Kunde: keine Warnung, Prüfung grün.
    await _createCustomer(tester, 'Musterwerk', fields: {
      'Straße und Hausnummer': 'Werkstraße 5',
      'PLZ': '23970',
      'Ort': 'Wismar',
    });
    await _invoiceFor(tester, 'Musterwerk');
    expect(find.text('E-Rechnung unvollständig'), findsNothing);
    await tester.tap(find.byTooltip('E-Rechnung'));
    await tester.pumpAndSettle();
    expect(find.text('E-Rechnung (XML) speichern'), findsOneWidget);
    await tester.tap(find.text('E-Rechnung prüfen'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Alle Pflichtangaben vorhanden'), findsOneWidget);
  });
}
