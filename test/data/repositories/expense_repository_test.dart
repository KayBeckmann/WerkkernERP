import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:werkkernerp/data/database/database.dart';
import 'package:werkkernerp/data/repositories/company_repository.dart';
import 'package:werkkernerp/data/repositories/expense_category_repository.dart';
import 'package:werkkernerp/data/repositories/expense_repository.dart';
import 'package:werkkernerp/data/repositories/number_sequence_repository.dart';
import 'package:werkkernerp/data/repositories/project_repository.dart';

/// C14.2 Belege/Ausgaben (Kay-Priorisierungsentscheidung 2026-10-18).
void main() {
  late AppDatabase db;
  late CompanyRepository companies;
  late ExpenseCategoryRepository categories;
  late ExpenseRepository expenses;

  setUp(() {
    db = AppDatabase.forTesting(
      NativeDatabase.memory(setup: (rawDb) => rawDb.execute('PRAGMA foreign_keys = ON;')),
    );
    companies = CompanyRepository(db);
    categories = ExpenseCategoryRepository(db);
    expenses = ExpenseRepository(db);
  });

  tearDown(() async => db.close());

  test('A0-Abnahme: zwei Firmen mit gleichnamigen Belegen haben keine Vermischung', () async {
    final companyA = await companies.create(name: 'Firma A');
    final companyB = await companies.create(name: 'Firma B');
    await expenses.create(
      companyId: companyA.id,
      date: DateTime(2026, 10, 1),
      description: 'Material',
      amountGrossCents: 10000,
      vatRatePercent: 19,
    );
    await expenses.create(
      companyId: companyB.id,
      date: DateTime(2026, 10, 1),
      description: 'Material',
      amountGrossCents: 20000,
      vatRatePercent: 19,
    );

    expect(await expenses.listForCompany(companyA.id), hasLength(1));
    expect(await expenses.listForCompany(companyB.id), hasLength(1));
  });

  test('Fremde Firmen-ID liefert nie einen Beleg zurück, auch bei bekannter echter ID', () async {
    final companyA = await companies.create(name: 'Firma A');
    final companyB = await companies.create(name: 'Firma B');
    final expense = await expenses.create(
      companyId: companyA.id,
      date: DateTime(2026, 10, 1),
      description: 'Material',
      amountGrossCents: 10000,
      vatRatePercent: 19,
    );

    expect(await expenses.findById(companyId: companyB.id, id: expense.id), isNull);
    expect(await expenses.delete(companyId: companyB.id, id: expense.id), isFalse);
    expect(await expenses.update(companyId: companyB.id, id: expense.id, description: 'x'), isNull);
  });

  test('update() ändert nur die übergebenen Felder, Rest bleibt unverändert', () async {
    final company = await companies.create(name: 'Firma A');
    final expense = await expenses.create(
      companyId: company.id,
      date: DateTime(2026, 10, 1),
      description: 'Material',
      amountGrossCents: 10000,
      vatRatePercent: 19,
      supplierReference: 'Beleg-001',
    );

    final updated = await expenses.update(
      companyId: company.id,
      id: expense.id,
      amountGrossCents: 15000,
    );

    expect(updated!.amountGrossCents, 15000);
    expect(updated.description, 'Material', reason: 'nicht übergebene Felder bleiben unverändert');
    expect(updated.supplierReference, 'Beleg-001');
  });

  test(
    'Kay-Entscheidung 2026-10-19 ("Belege bekommen eine optionale Projektzuordnung"): '
    'projectId wird gespeichert, über update() geändert/entfernt und listForProject() '
    'findet nur die zugeordneten Belege',
    () async {
      final company = await companies.create(name: 'Firma A');
      final projects = ProjectRepository(db, NumberSequenceRepository(db));
      final projectA = await projects.create(companyId: company.id, name: 'Projekt A');
      final projectB = await projects.create(companyId: company.id, name: 'Projekt B');

      final expense = await expenses.create(
        companyId: company.id,
        date: DateTime(2026, 10, 1),
        description: 'Material für Projekt A',
        amountGrossCents: 10000,
        vatRatePercent: 19,
        projectId: projectA.id,
      );
      await expenses.create(
        companyId: company.id,
        date: DateTime(2026, 10, 2),
        description: 'Ohne Projekt',
        amountGrossCents: 5000,
        vatRatePercent: 19,
      );

      expect(expense.projectId, projectA.id);
      final forProjectA = await expenses.listForProject(companyId: company.id, projectId: projectA.id);
      expect(forProjectA, hasLength(1));
      expect(forProjectA.single.id, expense.id);
      expect(await expenses.listForProject(companyId: company.id, projectId: projectB.id), isEmpty);

      // Umhängen auf ein anderes Projekt.
      final reassigned = await expenses.update(
        companyId: company.id,
        id: expense.id,
        projectId: Value(projectB.id),
      );
      expect(reassigned!.projectId, projectB.id);
      expect(await expenses.listForProject(companyId: company.id, projectId: projectA.id), isEmpty);
      expect(await expenses.listForProject(companyId: company.id, projectId: projectB.id), hasLength(1));

      // Zuordnung wieder entfernen.
      final unassigned = await expenses.update(
        companyId: company.id,
        id: expense.id,
        projectId: const Value(null),
      );
      expect(unassigned!.projectId, isNull);
    },
  );

  test(
    'Löschen eines Projekts reißt keinen bereits erfassten Beleg mit (onDelete: setNull)',
    () async {
      final company = await companies.create(name: 'Firma A');
      final projects = ProjectRepository(db, NumberSequenceRepository(db));
      final project = await projects.create(companyId: company.id, name: 'Projekt A');
      final expense = await expenses.create(
        companyId: company.id,
        date: DateTime(2026, 10, 1),
        description: 'Material',
        amountGrossCents: 10000,
        vatRatePercent: 19,
        projectId: project.id,
      );

      await projects.delete(companyId: company.id, id: project.id);

      final reloaded = await expenses.findById(companyId: company.id, id: expense.id);
      expect(reloaded, isNotNull);
      expect(reloaded!.projectId, isNull);
    },
  );

  test('delete() entfernt einen Beleg endgültig', () async {
    final company = await companies.create(name: 'Firma A');
    final expense = await expenses.create(
      companyId: company.id,
      date: DateTime(2026, 10, 1),
      description: 'Material',
      amountGrossCents: 10000,
      vatRatePercent: 19,
    );

    expect(await expenses.delete(companyId: company.id, id: expense.id), isTrue);
    expect(await expenses.findById(companyId: company.id, id: expense.id), isNull);
  });

  group('ExpenseCategoryRepository', () {
    test('seedDefaultsIfNeverSeeded legt die Standardkategorien nur einmal an', () async {
      final company = await companies.create(name: 'Firma A');

      await categories.seedDefaultsIfNeverSeeded(company.id);
      final afterFirstSeed = await categories.listForCompany(company.id);
      expect(afterFirstSeed, isNotEmpty);

      // Eine eigene Kategorie hinzufügen, erneuter Aufruf darf nicht
      // noch einmal die Standardliste anhängen.
      await categories.create(companyId: company.id, label: 'Eigene Kategorie');
      await categories.seedDefaultsIfNeverSeeded(company.id);
      final afterSecondCall = await categories.listForCompany(company.id);
      expect(afterSecondCall.length, afterFirstSeed.length + 1);
    });

    test('Kay kann eine SKR03-Kontonummer eintragen und wieder ändern', () async {
      final company = await companies.create(name: 'Firma A');
      final category = await categories.create(companyId: company.id, label: 'Material');
      expect(category.skr03Account, isNull);

      await categories.update(companyId: company.id, id: category.id, skr03Account: const Value('4200'));
      final reloaded = (await categories.listForCompany(company.id)).first;
      expect(reloaded.skr03Account, '4200');
    });

    test('Löschen einer Kategorie reißt keinen bereits erfassten Beleg mit', () async {
      final company = await companies.create(name: 'Firma A');
      final category = await categories.create(companyId: company.id, label: 'Material');
      final expense = await expenses.create(
        companyId: company.id,
        date: DateTime(2026, 10, 1),
        description: 'Material',
        amountGrossCents: 10000,
        vatRatePercent: 19,
        categoryId: category.id,
      );

      await categories.delete(companyId: company.id, id: category.id);

      final reloaded = await expenses.findById(companyId: company.id, id: expense.id);
      expect(reloaded, isNotNull, reason: 'Beleg bleibt erhalten, onDelete: setNull');
      expect(reloaded!.categoryId, isNull);
    });
  });
}
