import 'package:decimal/decimal.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:werkkernerp/data/database/database.dart';
import 'package:werkkernerp/data/database/tables.dart';
import 'package:werkkernerp/data/repositories/company_repository.dart';
import 'package:werkkernerp/data/repositories/customer_repository.dart';
import 'package:werkkernerp/data/repositories/invoice_repository.dart';
import 'package:werkkernerp/data/repositories/number_sequence_repository.dart';
import 'package:werkkernerp/data/repositories/recurring_invoice_template_repository.dart';

/// C11 Wiederkehrende Rechnungen (Kay-Priorisierungsentscheidung
/// 2026-10-17, C11-Kern).
void main() {
  late AppDatabase db;
  late CompanyRepository companies;
  late CustomerRepository customers;
  late InvoiceRepository invoices;
  late RecurringInvoiceTemplateRepository templates;

  setUp(() {
    db = AppDatabase.forTesting(
      NativeDatabase.memory(setup: (rawDb) => rawDb.execute('PRAGMA foreign_keys = ON;')),
    );
    companies = CompanyRepository(db);
    customers = CustomerRepository(db);
    invoices = InvoiceRepository(db, NumberSequenceRepository(db));
    templates = RecurringInvoiceTemplateRepository(db, invoices);
  });

  tearDown(() async => db.close());

  InvoiceItemInput textItem(String description, {int price = 10000}) => InvoiceItemInput(
        kind: InvoiceItemKind.text,
        description: description,
        quantity: Decimal.one,
        unitPriceCents: price,
        vatRatePercent: 19,
      );

  test('A0-Abnahme: zwei Firmen mit gleichnamigen Vorlagen haben keine Vermischung', () async {
    final companyA = await companies.create(name: 'Firma A');
    final companyB = await companies.create(name: 'Firma B');
    final customerA = await customers.create(companyId: companyA.id, name: 'Kunde A');
    final customerB = await customers.create(companyId: companyB.id, name: 'Kunde B');

    await templates.create(
      companyId: companyA.id,
      customerId: customerA.id,
      label: 'Hosting',
      interval: RecurrenceInterval.monthly,
      nextDueDate: DateTime(2027, 1, 1),
    );
    await templates.create(
      companyId: companyB.id,
      customerId: customerB.id,
      label: 'Hosting',
      interval: RecurrenceInterval.monthly,
      nextDueDate: DateTime(2027, 1, 1),
    );

    expect(await templates.listForCompany(companyA.id), hasLength(1));
    expect(await templates.listForCompany(companyB.id), hasLength(1));
  });

  test(
    'generateDueDrafts(): eine fällige Vorlage erzeugt genau einen neuen, nummernlosen '
    'Rechnungsentwurf mit den Vorlagen-Positionen und schiebt die Fälligkeit weiter',
    () async {
      final company = await companies.create(name: 'Firma A');
      final customer = await customers.create(companyId: company.id, name: 'Kunde');
      // Weniger als einen Monat überfällig -> genau EINE ausstehende
      // Periode (bewusst relativ zu "jetzt", nicht hartkodiert, damit
      // der Test unabhängig vom tatsächlichen Testdatum funktioniert).
      final dueDate = DateTime.now().subtract(const Duration(days: 10));
      final template = await templates.create(
        companyId: company.id,
        customerId: customer.id,
        label: 'Hosting monatlich',
        interval: RecurrenceInterval.monthly,
        nextDueDate: dueDate,
        paymentTerms: 'Zahlbar in 14 Tagen',
        items: [textItem('Hosting Januar')],
      );

      final created = await templates.generateDueDrafts(companyId: company.id);

      expect(created, hasLength(1));
      expect(created.single.status, InvoiceStatus.draft);
      expect(created.single.invoiceNumber, isNull);
      expect(created.single.customerId, customer.id);
      expect(created.single.paymentTerms, 'Zahlbar in 14 Tagen');

      final items = await invoices.itemsFor(created.single.id);
      expect(items.map((i) => i.description), ['Hosting Januar']);

      final reloaded = await templates.findById(companyId: company.id, id: template.id);
      expect(reloaded!.nextDueDate, DateTime(dueDate.year, dueDate.month + 1, dueDate.day));
    },
  );

  test(
    'generateDueDrafts(): mehrere inzwischen fällige Perioden werden alle nachgeholt, keine '
    'wird stillschweigend übersprungen',
    () async {
      final company = await companies.create(name: 'Firma A');
      final customer = await customers.create(companyId: company.id, name: 'Kunde');
      // Fälligkeit liegt 3 Monate zurück -> 3 ausstehende Perioden.
      await templates.create(
        companyId: company.id,
        customerId: customer.id,
        label: 'Hosting monatlich',
        interval: RecurrenceInterval.monthly,
        nextDueDate: DateTime.now().subtract(const Duration(days: 95)),
        items: [textItem('Hosting')],
      );

      final created = await templates.generateDueDrafts(companyId: company.id);
      expect(created.length, greaterThanOrEqualTo(3));
    },
  );

  test('generateDueDrafts(): eine noch nicht fällige Vorlage erzeugt keinen Entwurf', () async {
    final company = await companies.create(name: 'Firma A');
    final customer = await customers.create(companyId: company.id, name: 'Kunde');
    await templates.create(
      companyId: company.id,
      customerId: customer.id,
      label: 'Hosting',
      interval: RecurrenceInterval.monthly,
      nextDueDate: DateTime.now().add(const Duration(days: 30)),
      items: [textItem('Hosting')],
    );

    final created = await templates.generateDueDrafts(companyId: company.id);
    expect(created, isEmpty);
  });

  test('generateDueDrafts(): eine pausierte Vorlage erzeugt keinen Entwurf', () async {
    final company = await companies.create(name: 'Firma A');
    final customer = await customers.create(companyId: company.id, name: 'Kunde');
    final template = await templates.create(
      companyId: company.id,
      customerId: customer.id,
      label: 'Hosting',
      interval: RecurrenceInterval.monthly,
      nextDueDate: DateTime(2026, 1, 1),
      items: [textItem('Hosting')],
    );
    await templates.setActive(companyId: company.id, id: template.id, active: false);

    final created = await templates.generateDueDrafts(companyId: company.id);
    expect(created, isEmpty);
  });

  test('update() ersetzt Positionen vollständig und ändert Intervall/Fälligkeit', () async {
    final company = await companies.create(name: 'Firma A');
    final customer = await customers.create(companyId: company.id, name: 'Kunde');
    final template = await templates.create(
      companyId: company.id,
      customerId: customer.id,
      label: 'Hosting',
      interval: RecurrenceInterval.monthly,
      nextDueDate: DateTime(2026, 1, 1),
      items: [textItem('Alt')],
    );

    final updated = await templates.update(
      companyId: company.id,
      id: template.id,
      interval: RecurrenceInterval.yearly,
      nextDueDate: DateTime(2027, 1, 1),
      items: [textItem('Neu')],
    );

    expect(updated!.interval, RecurrenceInterval.yearly);
    expect(updated.nextDueDate, DateTime(2027, 1, 1));
    final items = await templates.itemsFor(template.id);
    expect(items.map((i) => i.description), ['Neu']);
  });

  test('Fremde Firmen-ID liefert nie eine Vorlage zurück, auch bei bekannter echter ID', () async {
    final companyA = await companies.create(name: 'Firma A');
    final companyB = await companies.create(name: 'Firma B');
    final customer = await customers.create(companyId: companyA.id, name: 'Kunde');
    final template = await templates.create(
      companyId: companyA.id,
      customerId: customer.id,
      label: 'Hosting',
      interval: RecurrenceInterval.monthly,
      nextDueDate: DateTime(2027, 1, 1),
    );

    expect(await templates.findById(companyId: companyB.id, id: template.id), isNull);
  });
}
