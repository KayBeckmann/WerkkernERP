import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:werkkernerp/data/database/database.dart';
import 'package:werkkernerp/data/database/tables.dart' show InvoiceItemKind;
import 'package:werkkernerp/main.dart';

/// Nachtrag 2026-10-18: "Artikel können nicht nachträglich bearbeitet
/// werden" + "Artikel müssen deaktiviert werden können, wenn der
/// Hersteller sie abkündigt".
AppDatabase _inMemoryDb() =>
    AppDatabase.forTesting(NativeDatabase.memory(setup: (db) => db.execute('PRAGMA foreign_keys = ON;')));

Future<void> _openTab(WidgetTester tester, String label) async {
  await tester.tap(find.text('Mehr'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'Ein Artikel kann über die Detailseite umbenannt werden (Tippfehler korrigieren), '
    'die Änderung erscheint sofort in der Liste',
    (tester) async {
      await tester.pumpWidget(WerkkernErpApp(database: _inMemoryDb()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Firma anlegen'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Elektro Beckmann');
      await tester.tap(find.text('Anlegen'));
      await tester.pumpAndSettle();

      await _openTab(tester, 'Artikel');
      await tester.tap(find.text('Artikel anlegen'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Name *'), 'Steckdoes');
      await tester.tap(find.text('Anlegen'));
      await tester.pumpAndSettle();

      expect(find.text('Steckdoes'), findsOneWidget);

      await tester.tap(find.text('Steckdoes'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Bearbeiten'));
      await tester.pumpAndSettle();

      expect(find.text('Artikel bearbeiten'), findsOneWidget);
      final nameField = find.widgetWithText(TextField, 'Name *');
      await tester.enterText(nameField, 'Steckdose');
      await tester.tap(find.text('Speichern'));
      await tester.pumpAndSettle();

      expect(find.text('Steckdose'), findsWidgets, reason: 'AppBar-Titel der Detailseite');

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Steckdose'), findsOneWidget, reason: 'Artikelliste zeigt den korrigierten Namen');
      expect(find.text('Steckdoes'), findsNothing);
    },
  );

  testWidgets(
    'Ein deaktivierter Artikel verschwindet aus der Artikelliste (gleiches Prinzip wie '
    'Projekte/Fahrzeuge) — die Repository-Ebene unterstützt die Reaktivierung über '
    'setActive(true), siehe article_repository_test.dart',
    (tester) async {
      await tester.pumpWidget(WerkkernErpApp(database: _inMemoryDb()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Firma anlegen'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Elektro Beckmann');
      await tester.tap(find.text('Anlegen'));
      await tester.pumpAndSettle();

      await _openTab(tester, 'Artikel');
      await tester.tap(find.text('Artikel anlegen'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Name *'), 'Auslaufmodell');
      await tester.tap(find.text('Anlegen'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Auslaufmodell'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Deaktivieren'));
      await tester.pumpAndSettle();

      expect(find.text('Auslaufmodell (deaktiviert)'), findsOneWidget);

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();

      // Aus der Artikelliste verschwunden.
      expect(find.text('Auslaufmodell'), findsNothing);
      expect(find.text('Noch keine Artikel angelegt.'), findsOneWidget);

      // Auch aus dem Artikel-Dropdown im Positions-Dialog einer Rechnung
      // verschwunden — ein deaktivierter Artikel darf keiner neuen
      // Position mehr zugeordnet werden können. "Rechnungen" steht
      // direkt in der schmalen Bottom-Bar (einer der vier festen
      // Einträge), kein Umweg über "Mehr" nötig.
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
      await tester.tap(find.descendant(of: find.byType(SegmentedButton<InvoiceItemKind>), matching: find.text('Artikel')));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<Article>));
      await tester.pumpAndSettle();
      expect(find.text('Auslaufmodell'), findsNothing);
    },
  );
}
