import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:werkkernerp/data/database/database.dart';
import 'package:werkkernerp/data/database/tables.dart';
import 'package:werkkernerp/data/repositories/company_repository.dart';
import 'package:werkkernerp/data/repositories/customer_repository.dart';
import 'package:werkkernerp/data/repositories/invoice_repository.dart';
import 'package:werkkernerp/data/repositories/number_sequence_repository.dart';
import 'package:werkkernerp/data/repositories/project_repository.dart';
import 'package:werkkernerp/data/repositories/staff_role_repository.dart';
import 'package:werkkernerp/data/repositories/time_entry_repository.dart';
import 'package:werkkernerp/domain/models/money.dart';

/// C3.1 Zeiterfassungs-Grundlage (Nachtrag 2026-10-20) — Rollen-Stamm
/// ohne Personenbezug, Zeitbuchungen gegen Auftrag/Rechnung und/oder
/// Projekt, automatische Projektübernahme vom Dokument, Stundenkosten.
void main() {
  late AppDatabase db;
  late CompanyRepository companies;
  late CustomerRepository customers;
  late ProjectRepository projects;
  late InvoiceRepository invoices;
  late StaffRoleRepository staffRoles;
  late TimeEntryRepository timeEntries;

  setUp(() {
    db = AppDatabase.forTesting(
      NativeDatabase.memory(setup: (rawDb) => rawDb.execute('PRAGMA foreign_keys = ON;')),
    );
    companies = CompanyRepository(db);
    customers = CustomerRepository(db);
    projects = ProjectRepository(db, NumberSequenceRepository(db));
    invoices = InvoiceRepository(db, NumberSequenceRepository(db));
    staffRoles = StaffRoleRepository(db);
    timeEntries = TimeEntryRepository(db);
  });

  tearDown(() async => db.close());

  group('StaffRoleRepository', () {
    test('seedDefaultsIfNeverSeeded() legt Monteur/Meister/Projektleiter mit 0 € an, nur einmal', () async {
      final company = await companies.create(name: 'Elektro Beckmann');

      await staffRoles.seedDefaultsIfNeverSeeded(company.id);
      final seeded = await staffRoles.listForCompany(company.id);
      expect(seeded.map((r) => r.name), containsAll(['Monteur', 'Meister', 'Projektleiter']));
      expect(seeded.every((r) => r.hourlyCostRateCents == 0), isTrue);

      // Löscht Kay eine Rolle und ruft erneut auf, kommen nicht
      // automatisch wieder alle drei (gleiches Prinzip wie
      // ExpenseCategoryRepository: "Liste leer?", nicht "schon
      // geseedet?").
      await staffRoles.delete(companyId: company.id, id: seeded.first.id);
      await staffRoles.seedDefaultsIfNeverSeeded(company.id);
      expect(await staffRoles.listForCompany(company.id), hasLength(2));
    });

    test('create()/update() setzen einen eigenen Stundenkostensatz', () async {
      final company = await companies.create(name: 'Elektro Beckmann');
      final role = await staffRoles.create(companyId: company.id, name: 'Meister', hourlyCostRateCents: 4500);
      expect(role.hourlyCostRateCents, 4500);

      await staffRoles.update(companyId: company.id, id: role.id, hourlyCostRateCents: 5000);
      final updated = await staffRoles.findById(companyId: company.id, id: role.id);
      expect(updated!.hourlyCostRateCents, 5000);
      expect(updated.name, 'Meister', reason: 'Nur der Satz wurde geändert');
    });
  });

  group('TimeEntryRepository', () {
    test('create() wirft ArgumentError ohne jeden Bezug (weder Dokument noch Projekt)', () async {
      final company = await companies.create(name: 'Elektro Beckmann');
      expect(
        () => timeEntries.create(companyId: company.id, date: DateTime.now(), hours: 1),
        throwsArgumentError,
      );
    });

    test(
      'create() mit invoiceId übernimmt automatisch die Projektzuordnung des Dokuments',
      () async {
        final company = await companies.create(name: 'Elektro Beckmann');
        await companies.update(company.copyWith(ordersEnabled: true, projectsEnabled: true));
        final customer = await customers.create(companyId: company.id, name: 'Kunde');
        final project = await projects.create(companyId: company.id, name: 'Projekt Nord');

        final order = await invoices.createDraft(
          companyId: company.id,
          customerId: customer.id,
          kind: DocumentKind.order,
          issueDate: DateTime.now(),
          serviceDate: DateTime.now(),
          projectId: project.id,
          items: [
            InvoiceItemInput(
              kind: InvoiceItemKind.hours,
              description: 'Montage',
              quantity: Decimal.parse('4'),
              unitPriceCents: 6000,
              vatRatePercent: 19,
            ),
          ],
        );

        final entry = await timeEntries.create(
          companyId: company.id,
          date: DateTime.now(),
          hours: 3,
          invoiceId: order.id,
        );
        expect(entry.invoiceId, order.id);
        expect(
          entry.projectId,
          project.id,
          reason: 'Automatisch vom Auftrag übernommen, da nicht explizit angegeben',
        );
      },
    );

    test(
      'create() mit invoiceId UND explizitem projectId überschreibt die automatische Übernahme',
      () async {
        final company = await companies.create(name: 'Elektro Beckmann');
        await companies.update(company.copyWith(ordersEnabled: true, projectsEnabled: true));
        final customer = await customers.create(companyId: company.id, name: 'Kunde');
        final projectA = await projects.create(companyId: company.id, name: 'Projekt A');
        final projectB = await projects.create(companyId: company.id, name: 'Projekt B');

        final order = await invoices.createDraft(
          companyId: company.id,
          customerId: customer.id,
          kind: DocumentKind.order,
          issueDate: DateTime.now(),
          serviceDate: DateTime.now(),
          projectId: projectA.id,
          items: [
            InvoiceItemInput(
              kind: InvoiceItemKind.hours,
              description: 'Montage',
              quantity: Decimal.one,
              unitPriceCents: 6000,
              vatRatePercent: 19,
            ),
          ],
        );

        final entry = await timeEntries.create(
          companyId: company.id,
          date: DateTime.now(),
          hours: 2,
          invoiceId: order.id,
          projectId: projectB.id,
        );
        expect(entry.projectId, projectB.id);
      },
    );

    test(
      'totalHoursForProject()/totalCostForProject(): summiert nur Buchungen mit Rolle als Kosten, '
      'rollenlose Buchungen tragen 0 € bei',
      () async {
        final company = await companies.create(name: 'Elektro Beckmann');
        await companies.update(company.copyWith(projectsEnabled: true));
        final project = await projects.create(companyId: company.id, name: 'Projekt Nord');
        final role = await staffRoles.create(
          companyId: company.id,
          name: 'Monteur',
          hourlyCostRateCents: 4000,
        );

        await timeEntries.create(
          companyId: company.id,
          date: DateTime.now(),
          hours: 3,
          projectId: project.id,
          staffRoleId: role.id,
        );
        await timeEntries.create(
          companyId: company.id,
          date: DateTime.now(),
          hours: 2,
          projectId: project.id,
          // Keine Rolle — Standalone-Normalfall ohne Personen-/Rollenbezug.
        );

        expect(
          await timeEntries.totalHoursForProject(companyId: company.id, projectId: project.id),
          5,
          reason: 'Stunden werden unabhängig von einer Rolle gezählt',
        );
        expect(
          await timeEntries.totalCostForProject(companyId: company.id, projectId: project.id),
          Money.fromCents(12000),
          reason: '3 Std. × 40 € (Rolle) + 2 Std. × 0 € (keine Rolle) = 120 €',
        );
      },
    );

    test('update() entfernt die Dokumentzuordnung nur, wenn ein Projekt übrig bleibt', () async {
      final company = await companies.create(name: 'Elektro Beckmann');
      await companies.update(company.copyWith(projectsEnabled: true));
      final project = await projects.create(companyId: company.id, name: 'Projekt Nord');

      final entry = await timeEntries.create(
        companyId: company.id,
        date: DateTime.now(),
        hours: 1,
        projectId: project.id,
      );

      expect(
        () => timeEntries.update(
          companyId: company.id,
          id: entry.id,
          projectId: const Value(null),
        ),
        throwsArgumentError,
      );
    });

    test('delete() entfernt eine Zeitbuchung endgültig', () async {
      final company = await companies.create(name: 'Elektro Beckmann');
      await companies.update(company.copyWith(projectsEnabled: true));
      final project = await projects.create(companyId: company.id, name: 'Projekt Nord');
      final entry = await timeEntries.create(
        companyId: company.id,
        date: DateTime.now(),
        hours: 1,
        projectId: project.id,
      );

      expect(await timeEntries.delete(companyId: company.id, id: entry.id), isTrue);
      expect(await timeEntries.findById(companyId: company.id, id: entry.id), isNull);
    });
  });
}
