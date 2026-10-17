import 'package:decimal/decimal.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:werkkernerp/data/database/database.dart';
import 'package:werkkernerp/data/database/tables.dart';
import 'package:werkkernerp/data/repositories/company_repository.dart';
import 'package:werkkernerp/data/repositories/customer_repository.dart';
import 'package:werkkernerp/data/repositories/invoice_repository.dart';
import 'package:werkkernerp/data/repositories/number_sequence_repository.dart';
import 'package:werkkernerp/data/repositories/project_repository.dart';

/// C1 Projekte (Kay-Priorisierungsentscheidung 2026-10-17, C1-Kern).
void main() {
  late AppDatabase db;
  late CompanyRepository companies;
  late CustomerRepository customers;
  late ProjectRepository projects;
  late InvoiceRepository invoices;

  setUp(() {
    db = AppDatabase.forTesting(
      NativeDatabase.memory(setup: (rawDb) => rawDb.execute('PRAGMA foreign_keys = ON;')),
    );
    companies = CompanyRepository(db);
    customers = CustomerRepository(db);
    projects = ProjectRepository(db);
    invoices = InvoiceRepository(db, NumberSequenceRepository(db));
  });

  tearDown(() async => db.close());

  test('A0-Abnahme: zwei Firmen mit gleichnamigen Projekten haben keine Vermischung', () async {
    final companyA = await companies.create(name: 'Firma A');
    final companyB = await companies.create(name: 'Firma B');
    await projects.create(companyId: companyA.id, name: 'Neubau Halle 1');
    await projects.create(companyId: companyB.id, name: 'Neubau Halle 1');

    expect(await projects.listForCompany(companyA.id), hasLength(1));
    expect(await projects.listForCompany(companyB.id), hasLength(1));
  });

  test('Fremde Firmen-ID liefert nie ein Projekt zurück, auch bei bekannter echter ID', () async {
    final companyA = await companies.create(name: 'Firma A');
    final companyB = await companies.create(name: 'Firma B');
    final project = await projects.create(companyId: companyA.id, name: 'Projekt A');

    expect(await projects.findById(companyId: companyB.id, id: project.id), isNull);
  });

  test(
    'Archivieren blendet ein Projekt aus listForCompany() aus, ohne seine Zuordnungen zu '
    'verändern — gleiches Prinzip wie die Modul-Schalter',
    () async {
      final company = await companies.create(name: 'Firma A');
      final customer = await customers.create(companyId: company.id, name: 'Kunde');
      final project = await projects.create(companyId: company.id, name: 'Projekt A');
      await invoices.createDraft(
        companyId: company.id,
        customerId: customer.id,
        issueDate: DateTime.now(),
        serviceDate: DateTime.now(),
        projectId: project.id,
      );

      await projects.setStatus(companyId: company.id, id: project.id, status: ProjectStatus.archived);
      expect(await projects.listForCompany(company.id), isEmpty);
      expect(await projects.listForCompany(company.id, includeArchived: true), hasLength(1));
      expect(
        await invoices.listForProject(companyId: company.id, projectId: project.id),
        hasLength(1),
        reason: 'Archivieren darf keine bestehende Dokumentzuordnung löschen',
      );
    },
  );

  test(
    'Ein Projekt mit zugeordneten Dokumenten kann nicht gelöscht werden — archivieren statt '
    'löschen ist der vorgesehene Weg',
    () async {
      final company = await companies.create(name: 'Firma A');
      final customer = await customers.create(companyId: company.id, name: 'Kunde');
      final project = await projects.create(companyId: company.id, name: 'Projekt A');
      await invoices.createDraft(
        companyId: company.id,
        customerId: customer.id,
        issueDate: DateTime.now(),
        serviceDate: DateTime.now(),
        projectId: project.id,
      );

      expect(
        () => projects.delete(companyId: company.id, id: project.id),
        throwsStateError,
      );
    },
  );

  test('Ein Projekt ohne zugeordnete Dokumente kann gelöscht werden', () async {
    final company = await companies.create(name: 'Firma A');
    final project = await projects.create(companyId: company.id, name: 'Projekt ohne Doks');

    expect(await projects.delete(companyId: company.id, id: project.id), isTrue);
    expect(await projects.findById(companyId: company.id, id: project.id), isNull);
  });

  test(
    'Ein gelöschtes Projekt entfernt nur die Zuordnung (projectId -> null), löscht aber '
    'keine Rechnung mit — onDelete: setNull statt cascade',
    () async {
      final company = await companies.create(name: 'Firma A');
      final customer = await customers.create(companyId: company.id, name: 'Kunde');
      final project = await projects.create(companyId: company.id, name: 'Projekt A');
      final draft = await invoices.createDraft(
        companyId: company.id,
        customerId: customer.id,
        issueDate: DateTime.now(),
        serviceDate: DateTime.now(),
        projectId: project.id,
        items: [
          InvoiceItemInput(
            kind: InvoiceItemKind.text,
            description: 'Testposition',
            quantity: Decimal.one,
            unitPriceCents: 1000,
            vatRatePercent: 19,
          ),
        ],
      );
      final finalized = await invoices.finalize(companyId: company.id, id: draft.id);

      // Löschen ist hier über die normale delete()-Schutzschiene gar
      // nicht möglich (siehe obigen Test) — direkter Rohzugriff simuliert
      // trotzdem den FK-Fall, falls der Schutz je umgangen würde.
      await (db.delete(db.projects)..where((p) => p.id.equals(project.id))).go();

      final stillThere =
          await (db.select(db.invoices)..where((i) => i.id.equals(finalized!.id))).getSingle();
      expect(stillThere.projectId, isNull);
      expect(stillThere.invoiceNumber, isNotNull, reason: 'Finalisierte Rechnung bleibt erhalten');
    },
  );
}
