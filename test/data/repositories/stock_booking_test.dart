import 'package:decimal/decimal.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:werkkernerp/data/database/database.dart';
import 'package:werkkernerp/data/database/tables.dart';
import 'package:werkkernerp/data/repositories/article_repository.dart';
import 'package:werkkernerp/data/repositories/company_repository.dart';
import 'package:werkkernerp/data/repositories/customer_repository.dart';
import 'package:werkkernerp/data/repositories/invoice_repository.dart';
import 'package:werkkernerp/data/repositories/number_sequence_repository.dart';

/// C5.1 Lagerbestand (Nachtrag 2026-10-19, Kay-Entscheidung auf
/// Rückfrage): Buchung beim Finalisieren, keine Doppelbuchung über
/// `convertTo()`-Ketten, kein Blockieren bei zu wenig Bestand.
void main() {
  late AppDatabase db;
  late CompanyRepository companies;
  late CustomerRepository customers;
  late ArticleRepository articles;
  late InvoiceRepository invoices;

  setUp(() {
    db = AppDatabase.forTesting(
      NativeDatabase.memory(setup: (rawDb) => rawDb.execute('PRAGMA foreign_keys = ON;')),
    );
    companies = CompanyRepository(db);
    customers = CustomerRepository(db);
    articles = ArticleRepository(db);
    invoices = InvoiceRepository(db, NumberSequenceRepository(db));
  });

  tearDown(() async => db.close());

  Future<Invoice> draftWithArticle({
    required String companyId,
    required String customerId,
    required String articleId,
    required String quantity,
    DocumentKind kind = DocumentKind.order,
  }) =>
      invoices.createDraft(
        companyId: companyId,
        customerId: customerId,
        kind: kind,
        issueDate: DateTime.now(),
        serviceDate: DateTime.now(),
        items: [
          InvoiceItemInput(
            kind: InvoiceItemKind.article,
            articleId: articleId,
            description: 'Testartikel',
            quantity: Decimal.parse(quantity),
            unitPriceCents: 1000,
            vatRatePercent: 19,
          ),
        ],
      );

  test(
    'Modul aus: Finalisieren eines Auftrags verändert den Lagerbestand nicht',
    () async {
      final company = await companies.create(name: 'Elektro Beckmann');
      await companies.setModules(
        companyId: company.id,
        quotesEnabled: false,
        ordersEnabled: true,
        deliveryNotesEnabled: false,
        proformaEnabled: false,
        projectsEnabled: false,
        fleetEnabled: false,
        recurringInvoicesEnabled: false,
        advancePaymentInvoicesEnabled: false,
        dunningEnabled: false,
        smtpEnabled: false,
        buchhaltungEnabled: false,
        creditNotesEnabled: false,
        lagerbestandEnabled: false,
        bestellwesenEnabled: false,
        timeTrackingEnabled: false,
      );
      final customer = await customers.create(companyId: company.id, name: 'Testkunde');
      final article = await articles.create(companyId: company.id, name: 'Steckdose', minimumStock: 5);
      await articles.setStock(companyId: company.id, id: article.id, newQuantity: 10);

      final draft = await draftWithArticle(
        companyId: company.id,
        customerId: customer.id,
        articleId: article.id,
        quantity: '3',
      );
      await invoices.finalize(companyId: company.id, id: draft.id);

      final reloaded = await articles.findById(companyId: company.id, id: article.id);
      expect(reloaded!.stockQuantity, 10, reason: 'Modul lagerbestandEnabled ist aus, keine Buchung');
    },
  );

  test(
    'Modul an: Finalisieren eines Auftrags bucht die Artikel-Menge vom Lagerbestand ab',
    () async {
      final company = await companies.create(name: 'Elektro Beckmann');
      await companies.update(company.copyWith(lagerbestandEnabled: true));
      final customer = await customers.create(companyId: company.id, name: 'Testkunde');
      final article = await articles.create(companyId: company.id, name: 'Steckdose');
      await articles.setStock(companyId: company.id, id: article.id, newQuantity: 10);

      final draft = await draftWithArticle(
        companyId: company.id,
        customerId: customer.id,
        articleId: article.id,
        quantity: '3.5',
      );
      await invoices.finalize(companyId: company.id, id: draft.id);

      final reloaded = await articles.findById(companyId: company.id, id: article.id);
      expect(reloaded!.stockQuantity, 6.5);
    },
  );

  test(
    'Ein Angebot bucht nie — Artikel dürfen dem Lager noch nicht als entnommen gelten',
    () async {
      final company = await companies.create(name: 'Elektro Beckmann');
      await companies.update(company.copyWith(lagerbestandEnabled: true, quotesEnabled: true));
      final customer = await customers.create(companyId: company.id, name: 'Testkunde');
      final article = await articles.create(companyId: company.id, name: 'Steckdose');
      await articles.setStock(companyId: company.id, id: article.id, newQuantity: 10);

      final draft = await draftWithArticle(
        companyId: company.id,
        customerId: customer.id,
        articleId: article.id,
        quantity: '3',
        kind: DocumentKind.quote,
      );
      await invoices.finalize(companyId: company.id, id: draft.id);

      final reloaded = await articles.findById(companyId: company.id, id: article.id);
      expect(reloaded!.stockQuantity, 10);
    },
  );

  test(
    'Kay-Vorgabe: Auftrag bucht beim eigenen Finalisieren; die daraus per convertTo() erzeugte '
    'Rechnung bucht beim Finalisieren NICHT noch einmal (keine Doppelbuchung)',
    () async {
      final company = await companies.create(name: 'Elektro Beckmann');
      await companies.update(company.copyWith(lagerbestandEnabled: true, ordersEnabled: true));
      final customer = await customers.create(companyId: company.id, name: 'Testkunde');
      final article = await articles.create(companyId: company.id, name: 'Steckdose');
      await articles.setStock(companyId: company.id, id: article.id, newQuantity: 10);

      final orderDraft = await draftWithArticle(
        companyId: company.id,
        customerId: customer.id,
        articleId: article.id,
        quantity: '4',
      );
      final order = await invoices.finalize(companyId: company.id, id: orderDraft.id);
      final afterOrder = await articles.findById(companyId: company.id, id: article.id);
      expect(afterOrder!.stockQuantity, 6, reason: 'Auftrag bucht beim eigenen Finalisieren');

      final invoiceDraft = await invoices.convertTo(
        companyId: company.id,
        sourceId: order!.id,
        targetKind: DocumentKind.invoice,
      );
      await invoices.finalize(companyId: company.id, id: invoiceDraft.id);

      final afterInvoice = await articles.findById(companyId: company.id, id: article.id);
      expect(
        afterInvoice!.stockQuantity,
        6,
        reason: 'Die aus dem Auftrag umgewandelte Rechnung darf nicht erneut buchen',
      );
    },
  );

  test(
    'Eine Rechnung, die direkt aus einem Angebot entsteht (kein Auftrag dazwischen), bucht '
    'beim eigenen Finalisieren — sie ist das erste bestandsrelevante Dokument der Kette',
    () async {
      final company = await companies.create(name: 'Elektro Beckmann');
      await companies.update(company.copyWith(lagerbestandEnabled: true, quotesEnabled: true));
      final customer = await customers.create(companyId: company.id, name: 'Testkunde');
      final article = await articles.create(companyId: company.id, name: 'Steckdose');
      await articles.setStock(companyId: company.id, id: article.id, newQuantity: 10);

      final quoteDraft = await draftWithArticle(
        companyId: company.id,
        customerId: customer.id,
        articleId: article.id,
        quantity: '2',
        kind: DocumentKind.quote,
      );
      final quote = await invoices.finalize(companyId: company.id, id: quoteDraft.id);
      expect((await articles.findById(companyId: company.id, id: article.id))!.stockQuantity, 10);

      final invoiceDraft = await invoices.convertTo(
        companyId: company.id,
        sourceId: quote!.id,
        targetKind: DocumentKind.invoice,
      );
      await invoices.finalize(companyId: company.id, id: invoiceDraft.id);

      expect((await articles.findById(companyId: company.id, id: article.id))!.stockQuantity, 8);
    },
  );

  test(
    'Zu wenig Bestand: Finalisieren wird NICHT blockiert, der Lagerbestand darf negativ werden '
    '(Kay-Entscheidung: nur warnen)',
    () async {
      final company = await companies.create(name: 'Elektro Beckmann');
      await companies.update(company.copyWith(lagerbestandEnabled: true, ordersEnabled: true));
      final customer = await customers.create(companyId: company.id, name: 'Testkunde');
      final article = await articles.create(companyId: company.id, name: 'Steckdose');
      await articles.setStock(companyId: company.id, id: article.id, newQuantity: 2);

      final draft = await draftWithArticle(
        companyId: company.id,
        customerId: customer.id,
        articleId: article.id,
        quantity: '5',
      );
      final finalized = await invoices.finalize(companyId: company.id, id: draft.id);
      expect(finalized, isNotNull, reason: 'Finalisieren darf trotz zu wenig Bestand gelingen');

      final reloaded = await articles.findById(companyId: company.id, id: article.id);
      expect(reloaded!.stockQuantity, -3);
    },
  );

  test(
    'checkStockBeforeFinalize(): meldet Artikel, die unter 0 fallen würden, meldet nichts bei '
    'ausreichendem Bestand oder deaktiviertem Modul',
    () async {
      final company = await companies.create(name: 'Elektro Beckmann');
      await companies.update(company.copyWith(lagerbestandEnabled: true, ordersEnabled: true));
      final customer = await customers.create(companyId: company.id, name: 'Testkunde');
      final article = await articles.create(companyId: company.id, name: 'Steckdose');
      await articles.setStock(companyId: company.id, id: article.id, newQuantity: 2);

      final shortDraft = await draftWithArticle(
        companyId: company.id,
        customerId: customer.id,
        articleId: article.id,
        quantity: '5',
      );
      final warnings = await invoices.checkStockBeforeFinalize(companyId: company.id, id: shortDraft.id);
      expect(warnings, hasLength(1));
      expect(warnings.single.articleName, 'Steckdose');
      expect(warnings.single.availableQuantity, 2);
      expect(warnings.single.requestedQuantity, 5);

      final okDraft = await draftWithArticle(
        companyId: company.id,
        customerId: customer.id,
        articleId: article.id,
        quantity: '1',
      );
      expect(
        await invoices.checkStockBeforeFinalize(companyId: company.id, id: okDraft.id),
        isEmpty,
      );

      await companies.update((await companies.findById(company.id))!.copyWith(lagerbestandEnabled: false));
      expect(
        await invoices.checkStockBeforeFinalize(companyId: company.id, id: shortDraft.id),
        isEmpty,
        reason: 'Modul aus -> keine Warnungen',
      );
    },
  );

  test(
    'C5.3: Finalisieren eines bestandsrelevanten Dokuments dokumentiert die Buchung im '
    'Bewegungsprotokoll (Referenz = die vergebene Dokumentnummer)',
    () async {
      final company = await companies.create(name: 'Elektro Beckmann');
      await companies.update(company.copyWith(lagerbestandEnabled: true, ordersEnabled: true));
      final customer = await customers.create(companyId: company.id, name: 'Testkunde');
      final article = await articles.create(companyId: company.id, name: 'Steckdose');
      await articles.setStock(companyId: company.id, id: article.id, newQuantity: 10);

      final draft = await draftWithArticle(
        companyId: company.id,
        customerId: customer.id,
        articleId: article.id,
        quantity: '3',
      );
      final finalized = await invoices.finalize(companyId: company.id, id: draft.id);

      final movements = await db.select(db.stockMovements).get();
      expect(movements, hasLength(1));
      expect(movements.single.type, StockMovementType.documentBooking);
      expect(movements.single.quantityDelta, -3);
      expect(movements.single.resultingQuantity, 7);
      expect(movements.single.referenceLabel, finalized!.invoiceNumber);
    },
  );

  test(
    'C5-Nachtrag (2026-10-21): Finalisieren einer Gutschrift bucht den Lagerbestand automatisch '
    'zurück (Rückbuchung, StockMovements.type == creditNoteReturn)',
    () async {
      final company = await companies.create(name: 'Elektro Beckmann');
      await companies.update(
        company.copyWith(lagerbestandEnabled: true, ordersEnabled: true, creditNotesEnabled: true),
      );
      final customer = await customers.create(companyId: company.id, name: 'Testkunde');
      final article = await articles.create(companyId: company.id, name: 'Steckdose');
      await articles.setStock(companyId: company.id, id: article.id, newQuantity: 10);

      final draft = await draftWithArticle(
        companyId: company.id,
        customerId: customer.id,
        articleId: article.id,
        quantity: '3',
        kind: DocumentKind.invoice,
      );
      final finalizedInvoice = await invoices.finalize(companyId: company.id, id: draft.id);
      final afterInvoice = await articles.findById(companyId: company.id, id: article.id);
      expect(afterInvoice!.stockQuantity, 7, reason: 'Rechnung bucht wie gewohnt ab');

      final creditNoteDraft = await invoices.createCreditNoteDraft(
        companyId: company.id,
        invoiceId: finalizedInvoice!.id,
      );
      final finalizedCreditNote =
          await invoices.finalize(companyId: company.id, id: creditNoteDraft.id);

      final afterCreditNote = await articles.findById(companyId: company.id, id: article.id);
      expect(afterCreditNote!.stockQuantity, 10, reason: 'Gutschrift bucht die volle Menge zurück');

      final movements = await (db.select(db.stockMovements)
            ..where((m) => m.type.equalsValue(StockMovementType.creditNoteReturn)))
          .get();
      expect(movements, hasLength(1));
      expect(movements.single.quantityDelta, 3, reason: 'Rückbuchung ist positiv, kein Abgang');
      expect(movements.single.resultingQuantity, 10);
      expect(movements.single.referenceLabel, finalizedCreditNote!.invoiceNumber);
    },
  );

  test(
    'C5-Nachtrag: Gutschrift über eine TEILMENGE der Originalpositionen bucht nur diese '
    'Teilmenge zurück',
    () async {
      final company = await companies.create(name: 'Elektro Beckmann');
      await companies.update(
        company.copyWith(lagerbestandEnabled: true, ordersEnabled: true, creditNotesEnabled: true),
      );
      final customer = await customers.create(companyId: company.id, name: 'Testkunde');
      final article = await articles.create(companyId: company.id, name: 'Steckdose');
      await articles.setStock(companyId: company.id, id: article.id, newQuantity: 10);

      final draft = await draftWithArticle(
        companyId: company.id,
        customerId: customer.id,
        articleId: article.id,
        quantity: '5',
        kind: DocumentKind.invoice,
      );
      final finalizedInvoice = await invoices.finalize(companyId: company.id, id: draft.id);

      final creditNoteDraft = await invoices.createCreditNoteDraft(
        companyId: company.id,
        invoiceId: finalizedInvoice!.id,
      );
      // Teil-Gutschrift: Nutzer kürzt den vorausgefüllten Entwurf auf eine
      // kleinere Menge, wie in der Doc beschrieben ("Kay kann den
      // entstandenen Entwurf ... auf eine Teil-Gutschrift herunterkürzen").
      await invoices.update(
        companyId: company.id,
        id: creditNoteDraft.id,
        items: [
          InvoiceItemInput(
            kind: InvoiceItemKind.article,
            articleId: article.id,
            description: 'Testartikel',
            quantity: Decimal.parse('2'),
            unitPriceCents: 1000,
            vatRatePercent: 19,
          ),
        ],
      );
      await invoices.finalize(companyId: company.id, id: creditNoteDraft.id);

      final reloaded = await articles.findById(companyId: company.id, id: article.id);
      expect(reloaded!.stockQuantity, 7, reason: '10 - 5 (Rechnung) + 2 (Teil-Gutschrift) = 7');
    },
  );
}
