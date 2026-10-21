import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:werkkernerp/data/database/database.dart';
import 'package:werkkernerp/data/database/tables.dart';
import 'package:werkkernerp/main.dart';
import 'package:werkkernerp/ui/widgets/sidebar_nav_item.dart';

/// C3.3 Projekt-Ergebnisrechnung-Erweiterung (Nachtrag 2026-10-20):
/// Stunden-Soll (aus dem Auftrag) vs. Stunden-Ist (gebucht) sowie die
/// Stundenkosten-Zeile im Projekt-Ergebnis.
Finder _sidebarItem(String label) => find.widgetWithText(SidebarNavItem, label);

AppDatabase _inMemoryDb() =>
    AppDatabase.forTesting(NativeDatabase.memory(setup: (db) => db.execute('PRAGMA foreign_keys = ON;')));

void main() {
  testWidgets(
    'Projekt zeigt geplante (Auftrags-)Stunden, gebuchte Ist-Stunden und die daraus '
    'berechneten Stundenkosten im Ergebnis',
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

      await tester.tap(_sidebarItem('Einstellungen'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Module'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(SwitchListTile, 'Aufträge'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(SwitchListTile, 'Projekte'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.widgetWithText(SwitchListTile, 'Zeiterfassung'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(SwitchListTile, 'Zeiterfassung'));
      await tester.pumpAndSettle();

      // Zurück auf die Settings-Hauptseite, dann die Rolle "Monteur"
      // (von seedDefaultsIfNeverSeeded() beim ersten Öffnen angelegt)
      // mit einem Stundenkostensatz versehen.
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rollen & Stundensätze'));
      await tester.pumpAndSettle();
      final monteurCard = find.ancestor(of: find.text('Monteur'), matching: find.byType(Card));
      await tester.tap(find.descendant(of: monteurCard, matching: find.byIcon(Icons.edit_outlined)));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Stundenkostensatz (€)'), '40,00');
      await tester.tap(find.text('Speichern'));
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();

      // Projekt anlegen.
      await tester.tap(_sidebarItem('Projekte'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Projekt anlegen'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Name *'), 'Testprojekt');
      await tester.tap(find.text('Anlegen'));
      await tester.pumpAndSettle();

      // Kunde anlegen.
      await tester.tap(_sidebarItem('Kunden'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kunde anlegen'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Name *'), 'Testkunde');
      await tester.tap(find.text('Anlegen'));
      await tester.pumpAndSettle();

      // Auftrag mit einer Stunden-Position (10 Std.), dem Projekt
      // zugeordnet, finalisieren.
      await tester.tap(_sidebarItem('Aufträge'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Neuer Auftrag'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Testkunde'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(DropdownButtonFormField<String?>, 'Ohne Projekt'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Testprojekt').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Position hinzufügen'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(SegmentedButton<InvoiceItemKind>),
          matching: find.text('Stunden'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Beschreibung *'), 'Montage');
      await tester.enterText(find.widgetWithText(TextField, 'Stunden'), '10');
      await tester.enterText(find.widgetWithText(TextField, 'Einzelpreis (€) *'), '60,00');
      await tester.tap(find.text('Hinzufügen'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Entwurf speichern'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Finalisieren'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Finalisieren'));
      await tester.pump();
      // Snackbars hängen an der App-weiten ScaffoldMessenger-Overlay,
      // nicht an der Route — ein Tab-Wechsel schiebt sie nicht weg, und
      // mehrere (Speichern + Finalisieren) können sich aneinanderreihen.
      // Großzügig über ihre gesamte Anzeigedauer hinaus pumpen, bevor
      // der nächste tap() in der Nähe der Snackbar-Position erfolgt.
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(seconds: 3));
      }
      await tester.pumpAndSettle();

      // 4 Std. gegen den Auftrag buchen.
      await tester.tap(_sidebarItem('Zeiterfassung'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Zeit buchen'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Stunden *'), '4');
      await tester.tap(find.widgetWithText(DropdownButtonFormField<String?>, 'Auftrag/Rechnung *'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('A-').last);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(DropdownButtonFormField<String?>, '— ohne Rolle —'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Monteur').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Buchen'));
      await tester.pumpAndSettle();

      await tester.tap(_sidebarItem('Projekte'));
      await tester.pumpAndSettle();
      // C2-Nachtrag (2026-10-21): die Projektliste zeigt seitdem
      // "JJ/PP · Name" statt nur den Namen — textContaining statt
      // text, um unabhängig von der vergebenen Projektnummer zu bleiben.
      await tester.tap(find.textContaining('Testprojekt'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Geplante Stunden'), findsOneWidget);
      expect(find.textContaining('10'), findsWidgets);
      expect(find.textContaining('Gebucht: 4.0'), findsOneWidget);
      expect(find.text('Stundenkosten: 160,00 €'), findsOneWidget);
      expect(find.text('Ergebnis: -160,00 €'), findsOneWidget);
    },
  );
}
