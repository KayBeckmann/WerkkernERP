import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:werkkernerp/data/database/database.dart';
import 'package:werkkernerp/data/database/tables.dart';
import 'package:werkkernerp/data/repositories/company_repository.dart';
import 'package:werkkernerp/data/repositories/number_sequence_repository.dart';
import 'package:werkkernerp/data/repositories/project_repository.dart';
import 'package:werkkernerp/data/repositories/time_entry_repository.dart';
import 'package:werkkernerp/data/repositories/time_sheet_repository.dart';

/// C3-Rest Kunden-Stundenzettel/Unterschrift (Nachtrag 2026-10-21) — der
/// im ursprünglichen C3-Platzhalter zurückgestellte Teil des Nachtrags
/// vom 2026-10-20.
void main() {
  late AppDatabase db;
  late CompanyRepository companies;
  late ProjectRepository projects;
  late TimeEntryRepository timeEntries;
  late TimeSheetRepository timeSheets;

  final fakeSignature = Uint8List.fromList([1, 2, 3, 4]);

  setUp(() {
    db = AppDatabase.forTesting(
      NativeDatabase.memory(setup: (rawDb) => rawDb.execute('PRAGMA foreign_keys = ON;')),
    );
    companies = CompanyRepository(db);
    projects = ProjectRepository(db, NumberSequenceRepository(db));
    timeEntries = TimeEntryRepository(db);
    timeSheets = TimeSheetRepository(db);
  });

  tearDown(() async => db.close());

  test('createDraft() verlangt einen Auftrag/eine Rechnung oder ein Projekt', () async {
    final company = await companies.create(name: 'Firma A');
    expect(
      () => timeSheets.createDraft(companyId: company.id, date: DateTime.now()),
      throwsArgumentError,
    );
  });

  test(
    'Entwurf: Zeitbuchungen zuordnen, entfernen, erneut zuordnen — alles frei möglich vor '
    'dem Unterschreiben',
    () async {
      final company = await companies.create(name: 'Firma A');
      final project = await projects.create(companyId: company.id, name: 'Projekt A');
      final entry = await timeEntries.create(
        companyId: company.id,
        date: DateTime.now(),
        hours: 4,
        projectId: project.id,
      );

      final sheet = await timeSheets.createDraft(
        companyId: company.id,
        date: DateTime.now(),
        projectId: project.id,
      );
      await timeSheets.addEntries(companyId: company.id, timeSheetId: sheet.id, entryIds: {entry.id});
      expect(await timeSheets.entriesFor(sheet.id), hasLength(1));

      await timeSheets.removeEntry(companyId: company.id, entryId: entry.id);
      expect(await timeSheets.entriesFor(sheet.id), isEmpty);

      await timeSheets.addEntries(companyId: company.id, timeSheetId: sheet.id, entryIds: {entry.id});
      expect(await timeSheets.entriesFor(sheet.id), hasLength(1));
    },
  );

  test(
    'sign() wirft ohne Positionen oder ohne Bild, verlangt eine mindestens leere, aber '
    'nicht-leere Unterschrift',
    () async {
      final company = await companies.create(name: 'Firma A');
      final project = await projects.create(companyId: company.id, name: 'Projekt A');
      final sheet = await timeSheets.createDraft(
        companyId: company.id,
        date: DateTime.now(),
        projectId: project.id,
      );

      expect(
        () => timeSheets.sign(companyId: company.id, id: sheet.id, signatureImage: fakeSignature),
        throwsArgumentError,
        reason: 'keine Zeitbuchungen zugeordnet',
      );

      final entry = await timeEntries.create(
        companyId: company.id,
        date: DateTime.now(),
        hours: 2,
        projectId: project.id,
      );
      await timeSheets.addEntries(companyId: company.id, timeSheetId: sheet.id, entryIds: {entry.id});

      expect(
        () => timeSheets.sign(companyId: company.id, id: sheet.id, signatureImage: Uint8List(0)),
        throwsArgumentError,
        reason: 'leeres Bild',
      );
    },
  );

  test(
    'Nach dem Unterschreiben sind Stundenzettel UND zugeordnete Zeitbuchungen unveränderlich',
    () async {
      final company = await companies.create(name: 'Firma A');
      final project = await projects.create(companyId: company.id, name: 'Projekt A');
      final entry = await timeEntries.create(
        companyId: company.id,
        date: DateTime.now(),
        hours: 3,
        projectId: project.id,
      );
      final sheet = await timeSheets.createDraft(
        companyId: company.id,
        date: DateTime.now(),
        projectId: project.id,
        initialEntryIds: {entry.id},
      );

      final signed =
          await timeSheets.sign(companyId: company.id, id: sheet.id, signatureImage: fakeSignature);
      expect(signed.status, TimeSheetStatus.signed);
      expect(signed.signatureImage, fakeSignature);
      expect(signed.signedAt, isNotNull);

      // Stundenzettel selbst: kein zweites Unterschreiben, keine
      // weiteren Zeitbuchungen mehr zuordenbar.
      expect(
        () => timeSheets.sign(companyId: company.id, id: sheet.id, signatureImage: fakeSignature),
        throwsStateError,
      );
      final anotherEntry = await timeEntries.create(
        companyId: company.id,
        date: DateTime.now(),
        hours: 1,
        projectId: project.id,
      );
      expect(
        () => timeSheets.addEntries(
          companyId: company.id,
          timeSheetId: sheet.id,
          entryIds: {anotherEntry.id},
        ),
        throwsStateError,
      );

      // Die zugeordnete Zeitbuchung selbst: weder über
      // TimeEntryRepository.update() noch .delete() noch über
      // TimeSheetRepository.removeEntry() veränderbar.
      expect(
        () => timeEntries.update(companyId: company.id, id: entry.id, hours: 5),
        throwsStateError,
      );
      expect(
        () => timeEntries.delete(companyId: company.id, id: entry.id),
        throwsStateError,
      );
      expect(
        () => timeSheets.removeEntry(companyId: company.id, entryId: entry.id),
        throwsStateError,
      );
      final anotherDraft = await timeSheets.createDraft(
        companyId: company.id,
        date: DateTime.now(),
        projectId: project.id,
      );
      expect(
        () => timeSheets.addEntries(
          companyId: company.id,
          timeSheetId: anotherDraft.id,
          entryIds: {entry.id},
        ),
        throwsStateError,
        reason: 'Umhängen einer bereits unterschriebenen Buchung auf einen anderen Stundenzettel',
      );
    },
  );

  test(
    'createCorrectionDraft(): nur auf einem unterschriebenen Stundenzettel möglich, erzeugt '
    'einen neuen Entwurf mit übernommener Zuordnung, aber ohne Positionen; der alte bleibt '
    'unverändert erhalten',
    () async {
      final company = await companies.create(name: 'Firma A');
      final project = await projects.create(companyId: company.id, name: 'Projekt A');
      final draft = await timeSheets.createDraft(
        companyId: company.id,
        date: DateTime(2026, 10, 21),
        projectId: project.id,
      );
      expect(
        () => timeSheets.createCorrectionDraft(companyId: company.id, supersedesId: draft.id),
        throwsArgumentError,
        reason: 'noch nicht unterschrieben',
      );

      final entry = await timeEntries.create(
        companyId: company.id,
        date: DateTime(2026, 10, 21),
        hours: 6,
        projectId: project.id,
      );
      await timeSheets.addEntries(companyId: company.id, timeSheetId: draft.id, entryIds: {entry.id});
      final signed =
          await timeSheets.sign(companyId: company.id, id: draft.id, signatureImage: fakeSignature);

      final correction =
          await timeSheets.createCorrectionDraft(companyId: company.id, supersedesId: signed.id);
      expect(correction.status, TimeSheetStatus.draft);
      expect(correction.supersedesId, signed.id);
      expect(correction.projectId, project.id);
      expect(correction.date, DateTime(2026, 10, 21));
      expect(await timeSheets.entriesFor(correction.id), isEmpty);

      final reloadedOriginal = await timeSheets.findById(companyId: company.id, id: signed.id);
      expect(reloadedOriginal!.status, TimeSheetStatus.signed, reason: 'bleibt unverändert');
      expect(await timeSheets.entriesFor(signed.id), hasLength(1));
    },
  );

  test('A0-Abnahme: zwei Firmen mit Stundenzetteln haben keine Vermischung', () async {
    final companyA = await companies.create(name: 'Firma A');
    final companyB = await companies.create(name: 'Firma B');
    final projectA = await projects.create(companyId: companyA.id, name: 'Projekt A');
    final projectB = await projects.create(companyId: companyB.id, name: 'Projekt B');

    await timeSheets.createDraft(companyId: companyA.id, date: DateTime.now(), projectId: projectA.id);
    await timeSheets.createDraft(companyId: companyB.id, date: DateTime.now(), projectId: projectB.id);

    expect(await timeSheets.listForCompany(companyA.id), hasLength(1));
    expect(await timeSheets.listForCompany(companyB.id), hasLength(1));
  });
}
