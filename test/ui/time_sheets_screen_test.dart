import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:werkkernerp/data/database/database.dart';
import 'package:werkkernerp/data/repositories/company_repository.dart';
import 'package:werkkernerp/data/repositories/project_repository.dart';
import 'package:werkkernerp/data/repositories/number_sequence_repository.dart';
import 'package:werkkernerp/data/repositories/time_entry_repository.dart';
import 'package:werkkernerp/data/repositories/time_sheet_repository.dart';
import 'package:werkkernerp/domain/services/active_company_service.dart';
import 'package:werkkernerp/main.dart';
import 'package:werkkernerp/ui/screens/time_sheets_screen.dart';
import 'package:werkkernerp/ui/widgets/sidebar_nav_item.dart';
import 'package:werkkernerp/ui/widgets/signature_pad.dart';

/// C3-Rest Kunden-Stundenzettel/Unterschrift (Nachtrag 2026-10-21) — der
/// im ursprünglichen C3-Platzhalter zurückgestellte Teil des Nachtrags
/// vom 2026-10-20.
///
/// **Bewusst zwei getrennte Tests statt eines einzigen durchgehenden
/// Ablaufs:** `RenderRepaintBoundary.toImage()` (die eigentliche
/// PNG-Rasterung der Unterschrift) löst unter `flutter_test` nie auf —
/// bekannte Einschränkung der Testumgebung (kein echter Rasterizer,
/// auch nicht mit `tester.runAsync()`), kein Produktionsbug. Deshalb
/// prüft Test 1 den kompletten UI-Ablauf bis einschließlich "Zeichnen
/// aktiviert den Bestätigen-Button", und Test 2 die Anzeige/Sperre NACH
/// dem Unterschreiben, erzeugt aber die Signatur direkt über das
/// Repository statt über die echte Zeichenfläche.
Finder _sidebarItem(String label) => find.widgetWithText(SidebarNavItem, label);

AppDatabase _inMemoryDb() =>
    AppDatabase.forTesting(NativeDatabase.memory(setup: (db) => db.execute('PRAGMA foreign_keys = ON;')));

void main() {
  testWidgets(
    'Stundenzettel-Entwurf: anlegen, Zeitbuchung zuordnen, Zeichnen auf der '
    'Signatur-Fläche aktiviert den Bestätigen-Button',
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

      // Module aktivieren: Projekte + Zeiterfassung.
      await tester.tap(_sidebarItem('Einstellungen'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Module'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(SwitchListTile, 'Projekte'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.widgetWithText(SwitchListTile, 'Zeiterfassung'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(SwitchListTile, 'Zeiterfassung'));
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

      // Zeit buchen (gegen das Projekt).
      await tester.tap(_sidebarItem('Zeiterfassung'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Zeit buchen'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Stunden *'), '4');
      await tester.tap(find.text('Projekt'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(DropdownButtonFormField<String?>, 'Projekt *'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Testprojekt').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Buchen'));
      await tester.pumpAndSettle();

      // Stundenzettel-Entwurf anlegen (gleiches Projekt).
      await tester.tap(_sidebarItem('Stundenzettel'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Stundenzettel erstellen'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Projekt'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(DropdownButtonFormField<String?>, 'Projekt *'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Testprojekt').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Anlegen'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Entwurf'), findsWidgets);

      // In den Entwurf wechseln, die gebuchte Zeit zuordnen.
      await tester.tap(find.textContaining('Testprojekt'));
      await tester.pumpAndSettle();
      expect(find.text('Weitere Zeitbuchungen hinzufügen'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      expect(find.textContaining('4.0 Std.'), findsWidgets);
      expect(find.text('Weitere Zeitbuchungen hinzufügen'), findsNothing);

      // Unterschreiben-Dialog öffnen: Bestätigen-Button startet
      // deaktiviert (noch nichts gezeichnet).
      await tester.tap(find.text('Unterschreiben'));
      await tester.pumpAndSettle();
      final confirmButton = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, 'Unterschreiben'),
      );
      expect(tester.widget<FilledButton>(confirmButton).onPressed, isNull);

      // Zeichnen auf der Signatur-Fläche aktiviert den Button — das ist
      // der eigentliche Zweck des `ListenableBuilder` um den Dialog.
      await tester.dragFrom(tester.getCenter(find.byType(SignaturePad)), const Offset(80, 40));
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(confirmButton).onPressed, isNotNull);

      // Dialog wieder schließen, ohne die (in flutter_test nicht
      // auflösende) PNG-Rasterung tatsächlich auszulösen.
      await tester.tap(find.text('Abbrechen'));
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'Nach dem Unterschreiben (hier direkt über das Repository erzeugt, da '
    'RenderRepaintBoundary.toImage() unter flutter_test nicht auflöst): '
    'Detailansicht zeigt Unterschrift/Hinweistext, keine Entfernen-Buttons mehr, '
    'und "Korrektur erstellen" führt zu einem neuen, offenen Entwurf',
    (tester) async {
      final db = AppDatabase.forTesting(
        NativeDatabase.memory(setup: (d) => d.execute('PRAGMA foreign_keys = ON;')),
      );
      addTearDown(db.close);
      final companyRepo = CompanyRepository(db);
      final projectRepo = ProjectRepository(db, NumberSequenceRepository(db));
      final timeEntryRepo = TimeEntryRepository(db);
      final timeSheetRepo = TimeSheetRepository(db);

      final company = await companyRepo.create(name: 'Elektro Beckmann');
      await companyRepo.update(company.copyWith(projectsEnabled: true, timeTrackingEnabled: true));
      final project = await projectRepo.create(companyId: company.id, name: 'Testprojekt');
      final entry = await timeEntryRepo.create(
        companyId: company.id,
        date: DateTime(2026, 10, 21),
        hours: 4,
        projectId: project.id,
      );
      final sheet = await timeSheetRepo.createDraft(
        companyId: company.id,
        date: DateTime(2026, 10, 21),
        projectId: project.id,
        initialEntryIds: {entry.id},
      );
      // Echte, minimale gültige PNG-Bytes (2x2, erzeugt via PIL) — reine
      // Platzhalter-Bytes wie `[1,2,3,4]` lassen `Image.memory()` beim
      // Dekodieren mit "Invalid image data" fehlschlagen, da die
      // Detailansicht die Unterschrift tatsächlich rendert.
      await timeSheetRepo.sign(
        companyId: company.id,
        id: sheet.id,
        signatureImage: Uint8List.fromList(const [
          137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82, 0, 0, 0, 2, 0, 0, 0, 2, 8, 6,
          0, 0, 0, 114, 182, 13, 36, 0, 0, 0, 20, 73, 68, 65, 84, 120, 156, 99, 100, 96, 96, 248, 207,
          192, 192, 192, 192, 196, 0, 5, 0, 14, 40, 1, 3, 71, 112, 28, 81, 0, 0, 0, 0, 73, 69, 78, 68,
          174, 66, 96, 130,
        ]),
      );

      final activeCompanyService = ActiveCompanyService(companyRepo);
      activeCompanyService.select((await companyRepo.findById(company.id))!);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<TimeSheetRepository>.value(value: timeSheetRepo),
            Provider<TimeEntryRepository>.value(value: timeEntryRepo),
            ChangeNotifierProvider<ActiveCompanyService>.value(value: activeCompanyService),
          ],
          child: MaterialApp(home: TimeSheetDetailScreen(timeSheetId: sheet.id)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Unterschrieben am'), findsOneWidget);
      expect(find.byIcon(Icons.close), findsNothing, reason: 'Entfernen-Button verschwindet gesperrt');
      expect(find.text('Weitere Zeitbuchungen hinzufügen'), findsNothing);
      expect(find.textContaining('qualifizierte elektronische Signatur'), findsOneWidget);
      expect(find.text('Korrektur erstellen'), findsOneWidget);

      await tester.tap(find.text('Korrektur erstellen'));
      await tester.pumpAndSettle();

      // Neuer, eigener Entwurf ohne Positionen — die signierte Buchung
      // bleibt dem ALTEN Stundenzettel zugeordnet.
      expect(find.text('Entwurf'), findsOneWidget);
      expect(find.textContaining('Unterschrieben am'), findsNothing);
      expect(await timeSheetRepo.entriesFor(sheet.id), hasLength(1));
    },
  );
}
