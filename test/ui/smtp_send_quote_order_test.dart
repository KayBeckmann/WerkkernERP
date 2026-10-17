import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:werkkernerp/data/database/database.dart';
import 'package:werkkernerp/main.dart';
import 'package:werkkernerp/ui/widgets/sidebar_nav_item.dart';

/// Kay-Nachfrage 2026-10-17: "Angebote und Auftragsbestätigungen müssen
/// auch per Mail versendet werden können." `_sendInvoiceByEmail()` war
/// von Anfang an dokumentart-generisch (gleiche Bedingung wie "PDF
/// teilen": `isFinalized && _smtpEnabled`, kein `kind == invoice`-Filter,
/// `buildInvoicePdf()` selbst ist bereits für Angebot/Auftrag/Lieferschein/
/// Proforma genauso wie für Rechnungen getestet) — dieser Test macht das
/// explizit sichtbar statt es nur durch Code-Lesen zu behaupten.
AppDatabase _inMemoryDb() =>
    AppDatabase.forTesting(NativeDatabase.memory(setup: (db) => db.execute('PRAGMA foreign_keys = ON;')));

void main() {
  testWidgets(
    '"Per E-Mail senden" erscheint für ein finalisiertes Angebot UND einen daraus '
    'umgewandelten, finalisierten Auftrag — nicht nur für Rechnungen',
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
      await tester.tap(find.widgetWithText(SwitchListTile, 'Angebote'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(SwitchListTile, 'Aufträge'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(SwitchListTile, 'Versand (SMTP)'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(SidebarNavItem, 'Kunden'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kunde anlegen'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Name *'), 'Testkunde');
      await tester.tap(find.text('Anlegen'));
      await tester.pumpAndSettle();

      // Angebot anlegen, finalisieren — "Per E-Mail senden" muss
      // erscheinen, obwohl es sich nicht um eine Rechnung handelt.
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

      expect(
        find.byTooltip('Per E-Mail senden'),
        findsOneWidget,
        reason: 'Ein finalisiertes Angebot muss per Mail versendet werden können.',
      );

      // In Auftrag umwandeln, finalisieren — dieselbe Erwartung.
      await tester.tap(find.byTooltip('Umwandeln'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('In Auftrag umwandeln'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Finalisieren'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Finalisieren'));
      await tester.pumpAndSettle();

      expect(
        find.byTooltip('Per E-Mail senden'),
        findsOneWidget,
        reason: 'Ein finalisierter Auftrag muss per Mail versendet werden können.',
      );
    },
  );
}
