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
      // C10 (Kay-Priorisierungsentscheidung 2026-10-17) fügt einen vierten
      // Modul-Schalter hinzu — die Einstellungen-Seite braucht dadurch
      // mehr Höhe, um "Speichern" noch innerhalb des Testviewports zu
      // treffen (sonst Tap-Miss außerhalb des Render-Baums). Nachtrag
      // 2026-10-18 (Kleinunternehmer-Abschnitt) braucht noch mehr Höhe.
      tester.view.physicalSize = const Size(1200, 2000);
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

      // Angebote-Modul aktivieren -> eigenes Textpaar erscheint.
      expect(find.widgetWithText(TextField, 'Einleitungstext (Angebot)'), findsNothing);
      await tester.tap(find.widgetWithText(SwitchListTile, 'Angebote'));
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

      // Modul aus- und wieder einschalten -> beide Texte bleiben
      // unabhängig erhalten (Controller bleiben über Toggle hinweg
      // bestehen, siehe Doc-Kommentar in SettingsScreen).
      await tester.tap(find.widgetWithText(SwitchListTile, 'Angebote'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextField, 'Einleitungstext (Angebot)'), findsNothing);
      await tester.tap(find.widgetWithText(SwitchListTile, 'Angebote'));
      await tester.pumpAndSettle();

      expect(find.text('Rechnungstext'), findsOneWidget);
      expect(find.text('Angebotstext mit Bindefrist'), findsOneWidget);
    },
  );
}
