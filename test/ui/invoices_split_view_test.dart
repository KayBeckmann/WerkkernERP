import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:werkkernerp/data/database/database.dart';
import 'package:werkkernerp/main.dart';
import 'package:werkkernerp/ui/widgets/sidebar_nav_item.dart';

/// Audit-Befund 2026-10-17 (Abweichungen.md Abschnitt 3): RechnungsFees
/// Arbeitsansicht zeigt Liste und Detail/Formular gleichzeitig statt per
/// Navigation zu wechseln. Dieser Test deckt genau das für den breiten
/// Pfad ab — der schmale Pfad (Push-Navigation) bleibt unverändert und
/// ist bereits durch andere Tests abgedeckt (z. B. `home_shell_test.dart`).
AppDatabase _inMemoryDb() =>
    AppDatabase.forTesting(NativeDatabase.memory(setup: (db) => db.execute('PRAGMA foreign_keys = ON;')));

void main() {
  testWidgets(
    'Breit-Layout: Liste bleibt sichtbar, während ein neues Dokument eingebettet rechts '
    'bearbeitet wird — kein Vollbild-Push',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(WerkkernErpApp(database: _inMemoryDb()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Firma anlegen'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Elektro Beckmann');
      await tester.tap(find.text('Anlegen'));
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
      // Vor jeder Auswahl: Liste zeigt den Leertext, rechts der Platzhalter.
      expect(find.text('Noch keine Rechnungsentwürfe.'), findsOneWidget);
      expect(find.textContaining('Dokument auswählen'), findsOneWidget);

      await tester.tap(find.text('Neue Rechnung'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Testkunde'));
      await tester.pumpAndSettle();

      // Der Editor erscheint eingebettet — die Sidebar UND die (jetzt
      // leere) Liste links bleiben gleichzeitig sichtbar, kein
      // Vollbild-Wechsel.
      expect(find.text('Rechnung (Entwurf) — Testkunde'), findsOneWidget);
      expect(find.byType(SidebarNavItem), findsWidgets);
      expect(find.text('Neue Rechnung'), findsOneWidget, reason: 'Listen-FAB bleibt erreichbar');

      await tester.tap(find.text('Position hinzufügen'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Beschreibung *'), 'Beratung');
      await tester.enterText(find.widgetWithText(TextField, 'Einzelpreis (€) *'), '100');
      await tester.tap(find.text('Hinzufügen'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Entwurf speichern'));
      await tester.pumpAndSettle();

      // Nach dem Speichern taucht der Entwurf in der Liste links auf —
      // ohne dass der Detailbereich rechts verschwindet.
      expect(find.textContaining('Entwurf'), findsWidgets);
      expect(find.text('Beratung'), findsOneWidget);
    },
  );
}
