import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:werkkernerp/data/database/database.dart';
import 'package:werkkernerp/main.dart';
import 'package:werkkernerp/ui/widgets/sidebar_nav_item.dart';

/// C14.5 DATEV-Export (Kay-Priorisierungsentscheidung 2026-10-18).
///
/// Der eigentliche Export (echter Datei-Dialog über `FilePicker.
/// saveFile()`) ist im Widget-Test nicht steuerbar — genau wie beim
/// bestehenden Backup-Export (`backup_screen.dart`) gibt es dafür
/// bewusst keinen Widget-Test, nur die reine Export-Logik ist in
/// `datev_export_service_test.dart` vollständig abgedeckt. Hier wird
/// nur die Validierung VOR dem Datei-Dialog geprüft (kein Export ohne
/// Berater-/Mandantennummer/Gegenkonto).
Finder _sidebarItem(String label) => find.widgetWithText(SidebarNavItem, label);

AppDatabase _inMemoryDb() =>
    AppDatabase.forTesting(NativeDatabase.memory(setup: (db) => db.execute('PRAGMA foreign_keys = ON;')));

void main() {
  testWidgets(
    'DATEV-Export-Dialog lehnt den Export ohne Berater-/Mandantennummer/Gegenkonto ab',
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
      await tester.tap(find.widgetWithText(SwitchListTile, 'Buchhaltung'));
      await tester.pumpAndSettle();

      await tester.tap(_sidebarItem('Belege'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('DATEV-Export'));
      await tester.pumpAndSettle();

      expect(find.text('DATEV-Export (Belege)'), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Beraternummer *'), findsOneWidget);

      await tester.tap(find.text('Exportieren'));
      await tester.pumpAndSettle();

      expect(
        find.text('Bitte Berater-, Mandantennummer und Gegenkonto eintragen.'),
        findsOneWidget,
      );
      // Dialog bleibt offen — kein Datei-Dialog wurde ausgelöst.
      expect(find.text('DATEV-Export (Belege)'), findsOneWidget);
    },
  );
}
