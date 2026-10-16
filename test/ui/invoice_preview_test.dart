import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:werkkernerp/data/database/database.dart';
import 'package:werkkernerp/main.dart';

/// Kay-Nachtrag 2026-10-16: "PDF Vorschau, für Dokumente, die noch
/// nicht finalisiert sind — Online/in App Vorschau".
AppDatabase _inMemoryDb() =>
    AppDatabase.forTesting(NativeDatabase.memory(setup: (db) => db.execute('PRAGMA foreign_keys = ON;')));

void main() {
  testWidgets(
    'Vorschau-Button ist ohne Positionen deaktiviert, öffnet mit Positionen eine Entwurfs-Vorschau',
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

      // Ohne Positionen ist die Vorschau deaktiviert (kein sinnvolles
      // PDF ohne Inhalt).
      final previewButtonFinder = find.ancestor(
        of: find.byTooltip('Vorschau (unverbindlich)'),
        matching: find.byType(IconButton),
      );
      expect(previewButtonFinder, findsOneWidget);
      final previewButton = tester.widget<IconButton>(previewButtonFinder);
      expect(previewButton.onPressed, isNull);

      // Eine Position hinzufügen, danach ist der Button aktiv.
      await tester.tap(find.text('Position hinzufügen'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Beschreibung *'), 'Steckdose');
      await tester.enterText(find.widgetWithText(TextField, 'Einzelpreis (€) *'), '10');
      await tester.tap(find.text('Hinzufügen'));
      await tester.pumpAndSettle();

      final previewButtonAfter = tester.widget<IconButton>(previewButtonFinder);
      expect(previewButtonAfter.onPressed, isNotNull);

      // `PdfPreview` (package:printing) rendert intern fortlaufend (PDF-
      // Rasterung/Lade-Indikator) und wird nie vollständig "ruhig" —
      // pumpAndSettle() würde hier endlos warten. Ein begrenztes pump()
      // reicht, um die neue Route samt AppBar-Titel aufzubauen.
      await tester.tap(previewButtonFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Vorschau (Entwurf, nicht final)'), findsOneWidget);
    },
  );
}
