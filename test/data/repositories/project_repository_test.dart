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
    projects = ProjectRepository(db, NumberSequenceRepository(db));
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

  group('C2-Nachtrag (2026-10-21): Projektnummer-Nummernkreise', () {
    test(
      'create() vergibt PP fortlaufend je Firma und Gründungsjahr, fest eingefroren',
      () async {
        final companyA = await companies.create(name: 'Firma A');
        final companyB = await companies.create(name: 'Firma B');

        final a1 = await projects.create(companyId: companyA.id, name: 'Projekt A1');
        final a2 = await projects.create(companyId: companyA.id, name: 'Projekt A2');
        final b1 = await projects.create(companyId: companyB.id, name: 'Projekt B1');

        final thisYear = DateTime.now().year;
        expect(a1.foundingYear, thisYear);
        expect(a1.projectNumber, 1);
        expect(a2.foundingYear, thisYear);
        expect(a2.projectNumber, 2, reason: 'zweites Projekt derselben Firma/desselben Jahres');
        expect(
          b1.projectNumber,
          1,
          reason: 'eigene Firma -> eigener Zähler, keine Vermischung mit Firma A',
        );
      },
    );

    test(
      'Eine projektbezogene Rechnung zeigt R-JJPPxxx, wobei JJ dem PROJEKT-Gründungsjahr '
      'folgt, nicht dem tatsächlichen Finalisierungsjahr (Kollisionsvermeidung)',
      () async {
        final company = await companies.create(name: 'Firma A');
        final customer = await customers.create(companyId: company.id, name: 'Kunde');
        final project = await projects.create(companyId: company.id, name: 'Altprojekt');

        // Simuliert ein Projekt, das letztes Jahr gegründet wurde, auch
        // wenn der Test selbst "heute" läuft — PP bleibt eingefroren,
        // nur foundingYear wird hier für den Test zurückdatiert.
        await (db.update(db.projects)..where((p) => p.id.equals(project.id)))
            .write(const ProjectsCompanion(foundingYear: Value(2026)));

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

        expect(
          finalized!.invoiceNumber,
          'R-2601001',
          reason: 'JJ=26 (Projekt-Gründungsjahr) + PP=01 + laufende Nummer, nicht das '
              'tatsächliche Finalisierungsjahr',
        );
      },
    );

    test(
      'Eine projektfreie Rechnung bleibt beim bisherigen R-JJxxx-Format ohne PP',
      () async {
        final company = await companies.create(name: 'Firma A');
        final customer = await customers.create(companyId: company.id, name: 'Kunde');
        final draft = await invoices.createDraft(
          companyId: company.id,
          customerId: customer.id,
          issueDate: DateTime.now(),
          serviceDate: DateTime.now(),
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
        final thisYear = (DateTime.now().year % 100).toString().padLeft(2, '0');
        expect(finalized!.invoiceNumber, 'R-${thisYear}001');
      },
    );

    test(
      'backfillProjectNumbersIfMissing() nummeriert Alt-Projekte (projectNumber == null) '
      'rückwirkend in Anlage-Reihenfolge je Gründungsjahr, ist danach ein No-op',
      () async {
        final company = await companies.create(name: 'Firma A');

        // Zwei "Alt-Projekte" ohne PP simulieren (vor dem C2-Nachtrag
        // angelegt) — direkter Rohzugriff, da `create()` inzwischen
        // immer sofort eine PP vergibt.
        await db.into(db.projects).insert(
              ProjectsCompanion.insert(
                id: 'old-1',
                companyId: company.id,
                name: 'Altprojekt 1',
                createdAt: DateTime(2025, 3, 1),
              ),
            );
        await db.into(db.projects).insert(
              ProjectsCompanion.insert(
                id: 'old-2',
                companyId: company.id,
                name: 'Altprojekt 2',
                createdAt: DateTime(2025, 6, 1),
              ),
            );
        // Ein neueres Projekt über create() dazwischen — bekommt sein PP
        // bereits bei Anlage, bleibt vom Backfill unberührt.
        final newProject = await projects.create(companyId: company.id, name: 'Neues Projekt');

        await projects.backfillProjectNumbersIfMissing(company.id);

        final old1 = await projects.findById(companyId: company.id, id: 'old-1');
        final old2 = await projects.findById(companyId: company.id, id: 'old-2');
        expect(old1!.foundingYear, 2025);
        expect(old1.projectNumber, 1);
        expect(old2!.foundingYear, 2025);
        expect(old2.projectNumber, 2, reason: 'nach old-1 angelegt, folgt in der Reihenfolge');

        final reloadedNewProject =
            await projects.findById(companyId: company.id, id: newProject.id);
        expect(
          reloadedNewProject!.projectNumber,
          newProject.projectNumber,
          reason: 'vom Backfill unberührt, da bereits vergeben',
        );

        // Erneuter Aufruf ist ein No-op (keine erneute Vergabe/kein Fehler).
        await projects.backfillProjectNumbersIfMissing(company.id);
        final old1Again = await projects.findById(companyId: company.id, id: 'old-1');
        expect(old1Again!.projectNumber, 1);
      },
    );
  });
}
