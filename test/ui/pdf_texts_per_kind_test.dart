import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:werkkernerp/data/database/database.dart';
import 'package:werkkernerp/main.dart';
import 'package:werkkernerp/ui/widgets/sidebar_nav_item.dart';

/// Kay-Nachtrag 2026-10-16, zweiter Nachtrag: "Einleitungstext und
/// Schlußtext müssen pro Dokument abweichend sein!" — Rechnung und
/// Angebot müssen unabhängig voneinander ihre eigenen Texte behalten,
/// nicht denselben gemeinsamen Satz teilen.
AppDatabase _inMemoryDb() =>
    AppDatabase.forTesting(NativeDatabase.memory(setup: (db) => db.execute('PRAGMA foreign_keys = ON;')));

void main() {
  testWidgets(
    'Rechnungs- und Angebots-Texte sind unabhängig voneinander speicherbar',
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

      // Nachtrag 2026-10-18 ("Die Einstellungen müssen aufgeräumt
      // werden"): Module und Dokumenttexte sind jetzt getrennte
      // Unterseiten — Modul zuerst aktivieren, danach auf die
      // Dokumenttexte-Seite wechseln.
      await tester.tap(find.widgetWithText(SidebarNavItem, 'Einstellungen'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Module'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(SwitchListTile, 'Angebote'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Dokumenttexte'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextField, 'Einleitungstext (Angebot)'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextField, 'Einleitungstext (Rechnung)'),
        'Rechnungstext',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Einleitungstext (Angebot)'),
        'Angebotstext mit Bindefrist',
      );
      await tester.tap(find.text('Speichern'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();

      // Modul aus- und wieder einschalten -> beide Texte bleiben
      // unabhängig erhalten (jetzt aus der echten DB geladen, nicht
      // nur aus einem im Speicher gehaltenen Controller — die
      // Dokumenttexte-Unterseite baut ihre Controller bei jedem
      // Öffnen neu aus der Firma auf).
      await tester.tap(find.text('Module'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(SwitchListTile, 'Angebote'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dokumenttexte'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextField, 'Einleitungstext (Angebot)'), findsNothing);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Module'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(SwitchListTile, 'Angebote'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dokumenttexte'));
      await tester.pumpAndSettle();

      expect(find.text('Rechnungstext'), findsOneWidget);
      expect(find.text('Angebotstext mit Bindefrist'), findsOneWidget);
    },
  );
}
