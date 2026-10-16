import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:werkkernerp/data/database/database.dart';
import 'package:werkkernerp/main.dart';

/// Regressionstest: derselbe Fehlertyp wie in `home_shell_test.dart`
/// ("Rechnung öffnen lässt die Sidebar verschwinden") führte dazu, dass
/// ein über den Lieferanten-Tab neu angelegter Lieferant im "Artikel
/// anlegen"-Dialog nicht auftauchte, solange der Artikel-Tab schon vor
/// dem Anlegen geöffnet war (IndexedStack initialisiert den Screen nur
/// einmal, die Dropdown-Liste blieb auf dem alten Stand).
AppDatabase _inMemoryDb() =>
    AppDatabase.forTesting(NativeDatabase.memory(setup: (db) => db.execute('PRAGMA foreign_keys = ON;')));

void main() {
  testWidgets(
    'A1-Regressionstest: ein nach dem ersten Öffnen des Artikel-Tabs über den Lieferanten-Tab '
    'angelegter Lieferant erscheint im "Artikel anlegen"-Dialog, ohne App-Neustart',
    (tester) async {
      await tester.pumpWidget(WerkkernErpApp(database: _inMemoryDb()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Firma anlegen'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Elektro Beckmann');
      await tester.tap(find.text('Anlegen'));
      await tester.pumpAndSettle();

      // Artikel-Tab ZUERST öffnen (lädt die damals noch leere
      // Lieferantenliste) ...
      await tester.tap(find.text('Artikel'));
      await tester.pumpAndSettle();

      // ... DANACH erst einen Lieferanten über den eigenen Tab anlegen.
      await tester.tap(find.text('Lieferanten'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lieferant anlegen'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Elektro Großhandel Nord');
      await tester.tap(find.text('Anlegen'));
      await tester.pumpAndSettle();

      // Zurück zum (bereits einmal initialisierten) Artikel-Tab.
      await tester.tap(find.text('Artikel'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Artikel anlegen'));
      await tester.pumpAndSettle();

      // Dropdown "Standardlieferant" öffnen und prüfen, dass der neue
      // Lieferant dort auftaucht.
      await tester.tap(find.text('— keiner —'));
      await tester.pumpAndSettle();
      expect(find.text('Elektro Großhandel Nord'), findsOneWidget);
    },
  );
}
