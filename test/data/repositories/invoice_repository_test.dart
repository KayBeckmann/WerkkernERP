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
import 'package:werkkernerp/domain/models/money.dart';
import 'package:drift/drift.dart' show Value;

void main() {
  late AppDatabase db;
  late CompanyRepository companies;
  late CustomerRepository customers;
  late InvoiceRepository invoices;

  setUp(() {
    db = AppDatabase.forTesting(
      NativeDatabase.memory(setup: (rawDb) => rawDb.execute('PRAGMA foreign_keys = ON;')),
    );
    companies = CompanyRepository(db);
    customers = CustomerRepository(db);
    invoices = InvoiceRepository(db, NumberSequenceRepository(db));
  });

  tearDown(() async => db.close());

  test(
    'A2-Abnahme: Rechnung mit Artikel-, Stunden- und Freitextposition, zwei Gruppen, '
    '19/7/0% anlegen, schließen und wieder öffnen',
    () async {
      final company = await companies.create(name: 'Elektro Beckmann');
      final customer = await customers.create(companyId: company.id, name: 'Max Mustermann');

      final invoice = await invoices.createDraft(
        companyId: company.id,
        customerId: customer.id,
        issueDate: DateTime(2026, 10, 16),
        serviceDate: DateTime(2026, 10, 10),
        items: [
          InvoiceItemInput(
            kind: InvoiceItemKind.article,
            description: 'Steckdose',
            quantity: Decimal.fromInt(10),
            unitPriceCents: 250,
            vatRatePercent: 19,
            groupLabel: 'Bad',
          ),
          InvoiceItemInput(
            kind: InvoiceItemKind.hours,
            description: 'Montage',
            quantity: Decimal.parse('3.5'),
            unitPriceCents: 6500,
            vatRatePercent: 19,
            groupLabel: 'Bad',
          ),
          InvoiceItemInput(
            kind: InvoiceItemKind.text,
            description: 'Anfahrtspauschale',
            quantity: Decimal.one,
            unitPriceCents: 5000,
            vatRatePercent: 7,
            groupLabel: 'Küche',
          ),
          InvoiceItemInput(
            kind: InvoiceItemKind.text,
            description: 'Steuerfreie Position (Testfall)',
            quantity: Decimal.one,
            unitPriceCents: 1000,
            vatRatePercent: 0,
          ),
        ],
      );

      // Nummernlos als Entwurf (F3).
      expect(invoice.status, InvoiceStatus.draft);
      expect(invoice.invoiceNumber, isNull);

      // Wieder öffnen: alle Positionen samt Gruppen vollständig da.
      final reopened = await invoices.findById(companyId: company.id, id: invoice.id);
      expect(reopened, isNotNull);
      final items = await invoices.itemsFor(invoice.id);
      expect(items, hasLength(4));
      expect(items.map((i) => i.kind).toSet(), {
        InvoiceItemKind.article,
        InvoiceItemKind.hours,
        InvoiceItemKind.text,
      });
      expect(items.where((i) => i.groupLabel == 'Bad'), hasLength(2));
      expect(items.where((i) => i.groupLabel == 'Küche'), hasLength(1));
      expect(items.where((i) => i.groupLabel == null), hasLength(1));

      // Beträge stimmen mit unabhängig berechneten Sollwerten überein.
      final totals = await invoices.totalsFor(invoice.id);
      // 19%: 10*2,50 + 3,5*65,00 = 25,00 + 227,50 = 252,50
      expect(totals.netByRate[19], Money.fromCents(25250));
      // 7%: 50,00
      expect(totals.netByRate[7], Money.fromCents(5000));
      // 0%: 10,00
      expect(totals.netByRate[0], Money.fromCents(1000));
      expect(totals.totalGross, totals.totalNet + totals.totalTax);
    },
  );

  test(
    'Kay-Nachtrag 2026-10-16: Einheit und Rabatt pro Position werden gespeichert, beim '
    'erneuten Laden übernommen und fließen korrekt in totalsFor() ein',
    () async {
      final company = await companies.create(name: 'Firma A');
      final customer = await customers.create(companyId: company.id, name: 'Kunde');
      final invoice = await invoices.createDraft(
        companyId: company.id,
        customerId: customer.id,
        issueDate: DateTime.now(),
        serviceDate: DateTime.now(),
        items: [
          InvoiceItemInput(
            kind: InvoiceItemKind.article,
            description: 'Kabel NYM-J 3x1,5',
            quantity: Decimal.fromInt(50),
            unitPriceCents: 150,
            vatRatePercent: 19,
            unit: 'm',
            discountPercent: 10,
          ),
        ],
      );

      final items = await invoices.itemsFor(invoice.id);
      expect(items.single.unit, 'm');
      expect(items.single.discountPercent, 10);

      // 50 * 1,50€ = 75,00€ netto vor Rabatt; 10% Rabatt -> 67,50€ netto.
      final totals = await invoices.totalsFor(invoice.id);
      expect(totals.netByRate[19], Money.fromCents(6750));
    },
  );

  test('Freitext- und Stundenposition sind ohne Artikelstamm möglich (articleId null)', () async {
    final company = await companies.create(name: 'Firma A');
    final customer = await customers.create(companyId: company.id, name: 'Kunde');
    final invoice = await invoices.createDraft(
      companyId: company.id,
      customerId: customer.id,
      issueDate: DateTime.now(),
      serviceDate: DateTime.now(),
      items: [
        InvoiceItemInput(
          kind: InvoiceItemKind.hours,
          description: 'Beratung',
          quantity: Decimal.one,
          unitPriceCents: 10000,
          vatRatePercent: 19,
        ),
      ],
    );
    final items = await invoices.itemsFor(invoice.id);
    expect(items.single.articleId, isNull);
  });

  test('Entwurf bearbeiten ersetzt die Positionen vollständig; Firmenwechsel über update() scheitert', () async {
    final companyA = await companies.create(name: 'Firma A');
    final companyB = await companies.create(name: 'Firma B');
    final customer = await customers.create(companyId: companyA.id, name: 'Kunde');
    final invoice = await invoices.createDraft(
      companyId: companyA.id,
      customerId: customer.id,
      issueDate: DateTime.now(),
      serviceDate: DateTime.now(),
      items: [
        InvoiceItemInput(
          kind: InvoiceItemKind.text,
          description: 'Alt',
          quantity: Decimal.one,
          unitPriceCents: 100,
          vatRatePercent: 19,
        ),
      ],
    );

    final updated = await invoices.update(
      companyId: companyA.id,
      id: invoice.id,
      items: [
        InvoiceItemInput(
          kind: InvoiceItemKind.text,
          description: 'Neu',
          quantity: Decimal.one,
          unitPriceCents: 200,
          vatRatePercent: 19,
        ),
      ],
    );
    expect(updated, isNotNull);
    final items = await invoices.itemsFor(invoice.id);
    expect(items, hasLength(1));
    expect(items.single.description, 'Neu');

    // Cross-Tenant-Zugriffsversuch über die falsche Firma schlägt fehl.
    final crossTenant = await invoices.update(
      companyId: companyB.id,
      id: invoice.id,
      notes: 'Übernommen',
    );
    expect(crossTenant, isNull);
  });

  test('Zwei Firmen können unabhängig Rechnungen mit identischer Zählung führen, ohne Vermischung', () async {
    final companyA = await companies.create(name: 'Firma A');
    final companyB = await companies.create(name: 'Firma B');
    final customerA = await customers.create(companyId: companyA.id, name: 'Kunde A');
    final customerB = await customers.create(companyId: companyB.id, name: 'Kunde B');

    await invoices.createDraft(
      companyId: companyA.id,
      customerId: customerA.id,
      issueDate: DateTime.now(),
      serviceDate: DateTime.now(),
    );
    await invoices.createDraft(
      companyId: companyB.id,
      customerId: customerB.id,
      issueDate: DateTime.now(),
      serviceDate: DateTime.now(),
    );

    expect(await invoices.listDraftsForCompany(companyA.id), hasLength(1));
    expect(await invoices.listDraftsForCompany(companyB.id), hasLength(1));
  });

  // C1 Projekte (Kay-Priorisierungsentscheidung 2026-10-17).

  test(
    'C1: eine Rechnung kann einem Projekt zugeordnet, später geändert und wieder entfernt '
    'werden — listForProject() findet sie entsprechend',
    () async {
      final projects = ProjectRepository(db, NumberSequenceRepository(db));
      final company = await companies.create(name: 'Firma A');
      final customer = await customers.create(companyId: company.id, name: 'Kunde');
      final projectA = await projects.create(companyId: company.id, name: 'Projekt A');
      final projectB = await projects.create(companyId: company.id, name: 'Projekt B');

      final draft = await invoices.createDraft(
        companyId: company.id,
        customerId: customer.id,
        issueDate: DateTime.now(),
        serviceDate: DateTime.now(),
        projectId: projectA.id,
      );
      expect(draft.projectId, projectA.id);
      expect(
        await invoices.listForProject(companyId: company.id, projectId: projectA.id),
        hasLength(1),
      );

      // Projekt wechseln ...
      await invoices.update(companyId: company.id, id: draft.id, projectId: Value(projectB.id));
      expect(
        await invoices.listForProject(companyId: company.id, projectId: projectA.id),
        isEmpty,
      );
      expect(
        await invoices.listForProject(companyId: company.id, projectId: projectB.id),
        hasLength(1),
      );

      // ... und wieder entfernen (Value(null), nicht einfach weglassen).
      final unassigned =
          await invoices.update(companyId: company.id, id: draft.id, projectId: const Value(null));
      expect(unassigned!.projectId, isNull);
    },
  );

  test(
    'C1: die erste Rechnung bleibt ausdrücklich projektfrei möglich (Brainstorming) — '
    'projectId ist beim Anlegen optional',
    () async {
      final company = await companies.create(name: 'Firma A');
      final customer = await customers.create(companyId: company.id, name: 'Kunde');
      final draft = await invoices.createDraft(
        companyId: company.id,
        customerId: customer.id,
        issueDate: DateTime.now(),
        serviceDate: DateTime.now(),
      );
      expect(draft.projectId, isNull);
    },
  );
}
