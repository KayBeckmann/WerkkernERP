import 'package:decimal/decimal.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:werkkernerp/data/database/database.dart';
import 'package:werkkernerp/data/database/tables.dart';
import 'package:werkkernerp/data/repositories/company_repository.dart';
import 'package:werkkernerp/data/repositories/customer_repository.dart';
import 'package:werkkernerp/data/repositories/invoice_repository.dart';
import 'package:werkkernerp/data/repositories/number_sequence_repository.dart';
import 'package:werkkernerp/data/repositories/time_entry_repository.dart';

/// C3.2 Festpreis-Kennzeichen + Materialabschlagsrechnung (Nachtrag
/// 2026-10-20, Kay-Entscheidung auf Rückfrage: "Fester Schalter je
/// Auftrag" + "Bestehende Abschlagsrechnung wiederverwenden").
void main() {
  late AppDatabase db;
  late CompanyRepository companies;
  late CustomerRepository customers;
  late InvoiceRepository invoices;
  late TimeEntryRepository timeEntries;

  setUp(() {
    db = AppDatabase.forTesting(
      NativeDatabase.memory(setup: (rawDb) => rawDb.execute('PRAGMA foreign_keys = ON;')),
    );
    companies = CompanyRepository(db);
    customers = CustomerRepository(db);
    invoices = InvoiceRepository(db, NumberSequenceRepository(db));
    timeEntries = TimeEntryRepository(db);
  });

  tearDown(() async => db.close());

  Future<Invoice> finalizedOrder(
    String companyId,
    String customerId, {
    required bool isFixedPrice,
    String hoursQuantity = '10',
  }) async {
    final draft = await invoices.createDraft(
      companyId: companyId,
      customerId: customerId,
      kind: DocumentKind.order,
      issueDate: DateTime.now(),
      serviceDate: DateTime.now(),
      isFixedPrice: isFixedPrice,
      items: [
        InvoiceItemInput(
          kind: InvoiceItemKind.hours,
          description: 'Montagearbeiten',
          quantity: Decimal.parse(hoursQuantity),
          unitPriceCents: 6000,
          vatRatePercent: 19,
          unit: 'h',
        ),
        InvoiceItemInput(
          kind: InvoiceItemKind.article,
          description: 'Steckdose',
          quantity: Decimal.parse('5'),
          unitPriceCents: 250,
          vatRatePercent: 19,
        ),
      ],
    );
    return (await invoices.finalize(companyId: companyId, id: draft.id))!;
  }

  group('Festpreis vs. Zeit-und-Material beim Umwandeln Auftrag->Rechnung', () {
    test(
      'Festpreis vereinbart: convertTo() übernimmt die geplante (Angebots-)Menge unverändert, '
      'auch wenn abweichend gebuchte Ist-Stunden existieren',
      () async {
        final company = await companies.create(name: 'Elektro Beckmann');
        await companies.update(company.copyWith(ordersEnabled: true, timeTrackingEnabled: true));
        final customer = await customers.create(companyId: company.id, name: 'Kunde');
        final order = await finalizedOrder(company.id, customer.id, isFixedPrice: true, hoursQuantity: '10');

        await timeEntries.create(
          companyId: company.id,
          date: DateTime.now(),
          hours: 7,
          invoiceId: order.id,
        );

        final invoiceDraft = await invoices.convertTo(
          companyId: company.id,
          sourceId: order.id,
          targetKind: DocumentKind.invoice,
          timeEntryRepository: timeEntries,
        );
        final items = await invoices.itemsFor(invoiceDraft.id);
        final hoursItem = items.singleWhere((i) => i.kind == InvoiceItemKind.hours);
        expect(hoursItem.quantity, '10', reason: 'Festpreis -> geplante Menge bleibt unverändert');
      },
    );

    test(
      'Kein Festpreis: convertTo() ersetzt die geplante Menge durch die tatsächlich gebuchten '
      'Ist-Stunden, fasst mehrere Stunden-Positionen zu einer zusammen',
      () async {
        final company = await companies.create(name: 'Elektro Beckmann');
        await companies.update(company.copyWith(ordersEnabled: true, timeTrackingEnabled: true));
        final customer = await customers.create(companyId: company.id, name: 'Kunde');
        final order =
            await finalizedOrder(company.id, customer.id, isFixedPrice: false, hoursQuantity: '10');

        await timeEntries.create(companyId: company.id, date: DateTime.now(), hours: 3, invoiceId: order.id);
        await timeEntries.create(companyId: company.id, date: DateTime.now(), hours: 4.5, invoiceId: order.id);

        final invoiceDraft = await invoices.convertTo(
          companyId: company.id,
          sourceId: order.id,
          targetKind: DocumentKind.invoice,
          timeEntryRepository: timeEntries,
        );
        final items = await invoices.itemsFor(invoiceDraft.id);
        final hoursItems = items.where((i) => i.kind == InvoiceItemKind.hours).toList();
        expect(hoursItems, hasLength(1), reason: 'Mehrere Stunden-Positionen werden zu einer zusammengefasst');
        expect(hoursItems.single.quantity, '7.5');
        expect(
          items.where((i) => i.kind == InvoiceItemKind.article),
          hasLength(1),
          reason: 'Artikel-Positionen bleiben unverändert',
        );
      },
    );

    test('Ohne timeEntryRepository verhält sich convertTo() wie bisher (reine Kopie)', () async {
      final company = await companies.create(name: 'Elektro Beckmann');
      await companies.update(company.copyWith(ordersEnabled: true));
      final customer = await customers.create(companyId: company.id, name: 'Kunde');
      final order = await finalizedOrder(company.id, customer.id, isFixedPrice: false);

      final invoiceDraft = await invoices.convertTo(
        companyId: company.id,
        sourceId: order.id,
        targetKind: DocumentKind.invoice,
      );
      final hoursItem =
          (await invoices.itemsFor(invoiceDraft.id)).singleWhere((i) => i.kind == InvoiceItemKind.hours);
      expect(hoursItem.quantity, '10', reason: 'Ohne Zeiterfassungs-Modul keine Ersetzung');
    });

    test('isFixedPrice wandert beim Umwandeln mit, wie projectId', () async {
      final company = await companies.create(name: 'Elektro Beckmann');
      await companies.update(company.copyWith(ordersEnabled: true, deliveryNotesEnabled: true));
      final customer = await customers.create(companyId: company.id, name: 'Kunde');
      final order = await finalizedOrder(company.id, customer.id, isFixedPrice: true);

      final deliveryNoteDraft = await invoices.convertTo(
        companyId: company.id,
        sourceId: order.id,
        targetKind: DocumentKind.deliveryNote,
      );
      expect(deliveryNoteDraft.isFixedPrice, isTrue);
    });
  });

  group('createMaterialAdvanceDraft()', () {
    test(
      'übernimmt alle Artikel und ausgewählte Freitexte als Abschlagsrechnung, lässt Stunden '
      'und nicht ausgewählte Freitexte weg',
      () async {
        final company = await companies.create(name: 'Elektro Beckmann');
        await companies.update(company.copyWith(ordersEnabled: true, advancePaymentInvoicesEnabled: true));
        final customer = await customers.create(companyId: company.id, name: 'Kunde');

        final draft = await invoices.createDraft(
          companyId: company.id,
          customerId: customer.id,
          kind: DocumentKind.order,
          issueDate: DateTime.now(),
          serviceDate: DateTime.now(),
          items: [
            InvoiceItemInput(
              kind: InvoiceItemKind.article,
              description: 'Steckdose',
              quantity: Decimal.parse('5'),
              unitPriceCents: 250,
              vatRatePercent: 19,
            ),
            InvoiceItemInput(
              kind: InvoiceItemKind.text,
              description: 'Sonderanfertigung Schaltschrank',
              quantity: Decimal.one,
              unitPriceCents: 50000,
              vatRatePercent: 19,
            ),
            InvoiceItemInput(
              kind: InvoiceItemKind.text,
              description: 'Anfahrtspauschale',
              quantity: Decimal.one,
              unitPriceCents: 3000,
              vatRatePercent: 19,
            ),
            InvoiceItemInput(
              kind: InvoiceItemKind.hours,
              description: 'Montage',
              quantity: Decimal.parse('8'),
              unitPriceCents: 6000,
              vatRatePercent: 19,
            ),
          ],
        );
        final order = (await invoices.finalize(companyId: company.id, id: draft.id))!;
        final sourceItems = await invoices.itemsFor(order.id);
        final schaltschrankId =
            sourceItems.singleWhere((i) => i.description == 'Sonderanfertigung Schaltschrank').id;

        final advance = await invoices.createMaterialAdvanceDraft(
          companyId: company.id,
          sourceOrderId: order.id,
          includeAllArticles: true,
          selectedFreetextItemIds: {schaltschrankId},
        );

        expect(advance.kind, DocumentKind.invoice);
        expect(advance.isAdvancePayment, isTrue);
        expect(advance.convertedFromId, order.id);

        final items = await invoices.itemsFor(advance.id);
        expect(items, hasLength(2));
        expect(items.any((i) => i.description == 'Steckdose'), isTrue);
        expect(items.any((i) => i.description == 'Sonderanfertigung Schaltschrank'), isTrue);
        expect(items.any((i) => i.description == 'Anfahrtspauschale'), isFalse);
        expect(items.any((i) => i.kind == InvoiceItemKind.hours), isFalse);
      },
    );

    test('wirft ArgumentError, wenn keine Position ausgewählt wurde', () async {
      final company = await companies.create(name: 'Elektro Beckmann');
      await companies.update(company.copyWith(ordersEnabled: true));
      final customer = await customers.create(companyId: company.id, name: 'Kunde');
      final draft = await invoices.createDraft(
        companyId: company.id,
        customerId: customer.id,
        kind: DocumentKind.order,
        issueDate: DateTime.now(),
        serviceDate: DateTime.now(),
        items: [
          InvoiceItemInput(
            kind: InvoiceItemKind.text,
            description: 'Freitext',
            quantity: Decimal.one,
            unitPriceCents: 1000,
            vatRatePercent: 19,
          ),
        ],
      );
      final order = (await invoices.finalize(companyId: company.id, id: draft.id))!;

      expect(
        () => invoices.createMaterialAdvanceDraft(companyId: company.id, sourceOrderId: order.id),
        throwsArgumentError,
      );
    });

    test('wirft ArgumentError für einen falschen Dokumenttyp (kein Auftrag)', () async {
      final company = await companies.create(name: 'Elektro Beckmann');
      final customer = await customers.create(companyId: company.id, name: 'Kunde');
      final invoiceDraft = await invoices.createDraft(
        companyId: company.id,
        customerId: customer.id,
        kind: DocumentKind.invoice,
        issueDate: DateTime.now(),
        serviceDate: DateTime.now(),
      );

      expect(
        () => invoices.createMaterialAdvanceDraft(
          companyId: company.id,
          sourceOrderId: invoiceDraft.id,
          includeAllArticles: true,
        ),
        throwsArgumentError,
        reason: 'kind == invoice ist kein Auftrag',
      );
    });

    test('wirft StateError für einen noch nicht finalisierten Auftrag', () async {
      final company = await companies.create(name: 'Elektro Beckmann');
      await companies.update(company.copyWith(ordersEnabled: true));
      final customer = await customers.create(companyId: company.id, name: 'Kunde');
      final orderDraft = await invoices.createDraft(
        companyId: company.id,
        customerId: customer.id,
        kind: DocumentKind.order,
        issueDate: DateTime.now(),
        serviceDate: DateTime.now(),
      );

      expect(
        () => invoices.createMaterialAdvanceDraft(
          companyId: company.id,
          sourceOrderId: orderDraft.id,
          includeAllArticles: true,
        ),
        throwsStateError,
      );
    });
  });
}
