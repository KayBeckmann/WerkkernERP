import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:werkkernerp/data/database/database.dart';
import 'package:werkkernerp/main.dart';
import 'package:werkkernerp/ui/widgets/sidebar_nav_item.dart';

/// Kay-Nachtrag 2026-10-16: "Rechtstexte, Fußzeile und Kopfzeile in
/// Dokumenten anpassbar machen".
AppDatabase _inMemoryDb() =>
    AppDatabase.forTesting(NativeDatabase.memory(setup: (db) => db.execute('PRAGMA foreign_keys = ON;')));

void main() {
  testWidgets(
    'Dokumenttexte in den Einstellungen werden gespeichert und bleiben nach erneutem Öffnen erhalten',
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

      // Standardmäßig ist nur die Rechnung aktiv (A0-Prinzip) — nur ihr
      // Textpaar ist sichtbar (Kay-Nachtrag, zweiter Nachtrag: "pro
      // Dokument abweichend").
      await tester.enterText(
        find.widgetWithText(TextField, 'Einleitungstext (Rechnung)'),
        'Vielen Dank für Ihren Auftrag.',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Schlusstext (Rechnung)'),
        'Es gelten unsere AGB.',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Fußzeile (gemeinsam für alle Dokumentarten)'),
        'Elektro Beckmann — Musterstraße 1',
      );
      await tester.tap(find.text('Speichern'));
      await tester.pumpAndSettle();

      expect(find.text('Dokumenttexte gespeichert.'), findsOneWidget);

      // Weg navigieren und zurück -> die Werte müssen weiterhin da sein
      // (nicht nur im Speicher des Formulars, sondern in der DB).
      await tester.tap(find.widgetWithText(SidebarNavItem, 'Rechnungen'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(SidebarNavItem, 'Einstellungen'));
      await tester.pumpAndSettle();

      expect(find.text('Vielen Dank für Ihren Auftrag.'), findsOneWidget);
      expect(find.text('Es gelten unsere AGB.'), findsOneWidget);
      expect(find.text('Elektro Beckmann — Musterstraße 1'), findsOneWidget);
    },
  );
}
