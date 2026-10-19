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
import 'package:werkkernerp/data/repositories/purchase_order_repository.dart';
import 'package:werkkernerp/data/repositories/supplier_repository.dart';

/// C5.2 Bestellwesen (Nachtrag 2026-10-19) — eigener Nummernkreis
/// (Präfix "B"), beide Entstehungswege aus der Roadmap, Wareneingang
/// inkl. Teillieferung, Mindestbestellmengen-Zusammenfassung.
void main() {
  late AppDatabase db;
  late CompanyRepository companies;
  late CustomerRepository customers;
  late SupplierRepository suppliers;
  late ArticleRepository articles;
  late InvoiceRepository invoices;
  late PurchaseOrderRepository purchaseOrders;

  setUp(() {
    db = AppDatabase.forTesting(
      NativeDatabase.memory(setup: (rawDb) => rawDb.execute('PRAGMA foreign_keys = ON;')),
    );
    companies = CompanyRepository(db);
    customers = CustomerRepository(db);
    suppliers = SupplierRepository(db);
    articles = ArticleRepository(db);
    invoices = InvoiceRepository(db, NumberSequenceRepository(db));
    purchaseOrders = PurchaseOrderRepository(db, NumberSequenceRepository(db));
  });

  tearDown(() async => db.close());

  test('Entwurf anlegen/bearbeiten/löschen — nummernlos, Status draft', () async {
    final company = await companies.create(name: 'Elektro Beckmann');
    final supplier = await suppliers.create(companyId: company.id, name: 'Großhandel Müller');

    final draft = await purchaseOrders.createDraft(
      companyId: company.id,
      supplierId: supplier.id,
      issueDate: DateTime(2026, 10, 19),
      items: [
        const PurchaseOrderItemInput(description: 'Schrauben', quantity: 100, purchasePriceCents: 5),
      ],
    );
    expect(draft.status, PurchaseOrderStatus.draft);
    expect(draft.orderNumber, isNull);

    final items = await purchaseOrders.itemsFor(draft.id);
    expect(items, hasLength(1));

    final updated = await purchaseOrders.updateDraft(
      companyId: company.id,
      id: draft.id,
      items: [
        const PurchaseOrderItemInput(description: 'Schrauben', quantity: 200, purchasePriceCents: 5),
      ],
    );
    expect(updated, isNotNull);
    expect((await purchaseOrders.itemsFor(draft.id)).single.quantity, 200);

    final deleted = await purchaseOrders.deleteDraft(companyId: company.id, id: draft.id);
    expect(deleted, isTrue);
    expect(await purchaseOrders.findById(companyId: company.id, id: draft.id), isNull);
  });

  test('Finalisieren vergibt eine Nummer mit Präfix "B" und friert den Lieferanten-Schnappschuss ein',
      () async {
    final company = await companies.create(name: 'Elektro Beckmann');
    final supplier = await suppliers.create(
      companyId: company.id,
      name: 'Großhandel Müller',
      address: 'Industriestraße 5',
    );
    final draft = await purchaseOrders.createDraft(
      companyId: company.id,
      supplierId: supplier.id,
      issueDate: DateTime.now(),
      items: [
        const PurchaseOrderItemInput(description: 'Schrauben', quantity: 100, purchasePriceCents: 5),
      ],
    );

    final finalized = await purchaseOrders.finalize(companyId: company.id, id: draft.id);
    expect(finalized!.status, PurchaseOrderStatus.finalized);
    expect(finalized.orderNumber, startsWith('B-'));
    expect(finalized.supplierSnapshotName, 'Großhandel Müller');
    expect(finalized.supplierSnapshotAddress, 'Industriestraße 5');

    // Ein bereits finalisierter Entwurf lässt sich nicht mehr bearbeiten.
    final blocked = await purchaseOrders.updateDraft(companyId: company.id, id: draft.id, notes: 'x');
    expect(blocked, isNull);
    final blockedDelete = await purchaseOrders.deleteDraft(companyId: company.id, id: draft.id);
    expect(blockedDelete, isFalse);
  });

  test('Finalisieren ohne Positionen wirft StateError', () async {
    final company = await companies.create(name: 'Elektro Beckmann');
    final supplier = await suppliers.create(companyId: company.id, name: 'Großhandel Müller');
    final draft = await purchaseOrders.createDraft(
      companyId: company.id,
      supplierId: supplier.id,
      issueDate: DateTime.now(),
    );
    expect(
      () => purchaseOrders.finalize(companyId: company.id, id: draft.id),
      throwsA(isA<StateError>()),
    );
  });

  test(
    'Wareneingang: Teillieferungen summieren sich, erhöhen den Lagerbestand und setzen den Status',
    () async {
      final company = await companies.create(name: 'Elektro Beckmann');
      await companies.update(company.copyWith(lagerbestandEnabled: true));
      final supplier = await suppliers.create(companyId: company.id, name: 'Großhandel Müller');
      final article = await articles.create(companyId: company.id, name: 'Schrauben');
      await articles.setStock(companyId: company.id, id: article.id, newQuantity: 10);

      final draft = await purchaseOrders.createDraft(
        companyId: company.id,
        supplierId: supplier.id,
        issueDate: DateTime.now(),
        items: [
          PurchaseOrderItemInput(articleId: article.id, description: 'Schrauben', quantity: 100),
        ],
      );
      final finalized = (await purchaseOrders.finalize(companyId: company.id, id: draft.id))!;
      final itemId = (await purchaseOrders.itemsFor(finalized.id)).single.id;

      final afterFirst =
          await purchaseOrders.receiveGoods(companyId: company.id, id: finalized.id, receipts: {itemId: 60});
      expect(afterFirst!.status, PurchaseOrderStatus.partiallyReceived);
      expect((await articles.findById(companyId: company.id, id: article.id))!.stockQuantity, 70);

      final afterSecond =
          await purchaseOrders.receiveGoods(companyId: company.id, id: finalized.id, receipts: {itemId: 40});
      expect(afterSecond!.status, PurchaseOrderStatus.fullyReceived);
      expect((await articles.findById(companyId: company.id, id: article.id))!.stockQuantity, 110);
    },
  );

  test('Wareneingang über die bestellte Menge hinaus wirft StateError, bucht nichts', () async {
    final company = await companies.create(name: 'Elektro Beckmann');
    final supplier = await suppliers.create(companyId: company.id, name: 'Großhandel Müller');
    final draft = await purchaseOrders.createDraft(
      companyId: company.id,
      supplierId: supplier.id,
      issueDate: DateTime.now(),
      items: [const PurchaseOrderItemInput(description: 'Schrauben', quantity: 10)],
    );
    final finalized = (await purchaseOrders.finalize(companyId: company.id, id: draft.id))!;
    final itemId = (await purchaseOrders.itemsFor(finalized.id)).single.id;

    expect(
      () => purchaseOrders.receiveGoods(companyId: company.id, id: finalized.id, receipts: {itemId: 11}),
      throwsA(isA<StateError>()),
    );
  });

  test('Wareneingang auf einem Entwurf ist nicht möglich (null statt Fehler)', () async {
    final company = await companies.create(name: 'Elektro Beckmann');
    final supplier = await suppliers.create(companyId: company.id, name: 'Großhandel Müller');
    final draft = await purchaseOrders.createDraft(
      companyId: company.id,
      supplierId: supplier.id,
      issueDate: DateTime.now(),
      items: [const PurchaseOrderItemInput(description: 'Schrauben', quantity: 10)],
    );
    final itemId = (await purchaseOrders.itemsFor(draft.id)).single.id;
    final result =
        await purchaseOrders.receiveGoods(companyId: company.id, id: draft.id, receipts: {itemId: 1});
    expect(result, isNull);
  });

  Future<Invoice> finalizedOrderWithArticles(
    String companyId,
    String customerId,
    List<(String articleId, String quantity)> lines,
  ) async {
    final draft = await invoices.createDraft(
      companyId: companyId,
      customerId: customerId,
      kind: DocumentKind.order,
      issueDate: DateTime.now(),
      serviceDate: DateTime.now(),
      items: [
        for (final (articleId, quantity) in lines)
          InvoiceItemInput(
            kind: InvoiceItemKind.article,
            articleId: articleId,
            description: 'Position',
            quantity: Decimal.parse(quantity),
            unitPriceCents: 1000,
            vatRatePercent: 19,
          ),
      ],
    );
    return (await invoices.finalize(companyId: companyId, id: draft.id))!;
  }

  test(
    'createDraftsFromOrder — "Alles über einen Lieferanten": nur Artikel mit hinterlegtem Preis bei '
    'diesem Lieferanten landen in der Bestellung, der Rest wird als nicht zuordenbar gemeldet',
    () async {
      final company = await companies.create(name: 'Elektro Beckmann');
      await companies.update(company.copyWith(ordersEnabled: true));
      final customer = await customers.create(companyId: company.id, name: 'Kunde');
      final supplierA = await suppliers.create(companyId: company.id, name: 'Lieferant A');
      final withPrice = await articles.create(companyId: company.id, name: 'Steckdose');
      final withoutPrice = await articles.create(companyId: company.id, name: 'Kabel');
      await articles.setSupplierPrice(
        companyId: company.id,
        articleId: withPrice.id,
        supplierId: supplierA.id,
        purchasePriceCents: 250,
      );

      final order = await finalizedOrderWithArticles(company.id, customer.id, [
        (withPrice.id, '5'),
        (withoutPrice.id, '3'),
      ]);

      final result = await purchaseOrders.createDraftsFromOrder(
        companyId: company.id,
        sourceOrderId: order.id,
        mode: PurchaseOrderCreationMode.oneSupplierForAll,
        supplierId: supplierA.id,
      );

      expect(result.drafts, hasLength(1));
      expect(result.drafts.single.supplierId, supplierA.id);
      final items = await purchaseOrders.itemsFor(result.drafts.single.id);
      expect(items, hasLength(1));
      expect(items.single.articleId, withPrice.id);
      expect(items.single.quantity, 5);
      expect(result.unassignable, hasLength(1));
      expect(result.unassignable.single.articleId, withoutPrice.id);
    },
  );

  test(
    'createDraftsFromOrder — "Billigster Lieferant pro Artikel": eine Bestellung je günstigstem '
    'Lieferanten, nicht je Artikel',
    () async {
      final company = await companies.create(name: 'Elektro Beckmann');
      await companies.update(company.copyWith(ordersEnabled: true));
      final customer = await customers.create(companyId: company.id, name: 'Kunde');
      final cheapSupplier = await suppliers.create(companyId: company.id, name: 'Günstig GmbH');
      final expensiveSupplier = await suppliers.create(companyId: company.id, name: 'Teuer GmbH');
      final articleA = await articles.create(companyId: company.id, name: 'Artikel A');
      final articleB = await articles.create(companyId: company.id, name: 'Artikel B');

      // articleA: cheapSupplier ist günstiger. articleB: nur bei
      // cheapSupplier überhaupt ein Preis bekannt -> beide landen bei
      // cheapSupplier, also EINE Bestellung für beide Artikel.
      await articles.setSupplierPrice(
        companyId: company.id,
        articleId: articleA.id,
        supplierId: cheapSupplier.id,
        purchasePriceCents: 100,
      );
      await articles.setSupplierPrice(
        companyId: company.id,
        articleId: articleA.id,
        supplierId: expensiveSupplier.id,
        purchasePriceCents: 200,
      );
      await articles.setSupplierPrice(
        companyId: company.id,
        articleId: articleB.id,
        supplierId: cheapSupplier.id,
        purchasePriceCents: 50,
      );

      final order = await finalizedOrderWithArticles(company.id, customer.id, [
        (articleA.id, '2'),
        (articleB.id, '4'),
      ]);

      final result = await purchaseOrders.createDraftsFromOrder(
        companyId: company.id,
        sourceOrderId: order.id,
        mode: PurchaseOrderCreationMode.cheapestPerSupplier,
      );

      expect(result.drafts, hasLength(1), reason: 'beide Artikel sind beim selben Lieferanten günstigst');
      expect(result.drafts.single.supplierId, cheapSupplier.id);
      final items = await purchaseOrders.itemsFor(result.drafts.single.id);
      expect(items, hasLength(2));
      expect(result.unassignable, isEmpty);
    },
  );

  test(
    'suggestFromLowStock: fasst alle unterdeckten Artikel automatisch je Lieferant zusammen und '
    'prüft die Mindestbestellmenge, ohne das Anlegen eines Entwurfs zu blockieren',
    () async {
      final company = await companies.create(name: 'Elektro Beckmann');
      await companies.update(company.copyWith(lagerbestandEnabled: true));
      final supplier = await suppliers.create(
        companyId: company.id,
        name: 'Großhandel Müller',
        minimumOrderQuantity: 50,
      );
      final articleA = await articles.create(
        companyId: company.id,
        name: 'Artikel A',
        defaultSupplierId: supplier.id,
        minimumStock: 10,
      );
      final articleB = await articles.create(
        companyId: company.id,
        name: 'Artikel B',
        defaultSupplierId: supplier.id,
        minimumStock: 10,
      );
      await articles.setStock(companyId: company.id, id: articleA.id, newQuantity: 5);
      await articles.setStock(companyId: company.id, id: articleB.id, newQuantity: 2);
      await articles.setSupplierPrice(
        companyId: company.id,
        articleId: articleA.id,
        supplierId: supplier.id,
        purchasePriceCents: 100,
      );
      await articles.setSupplierPrice(
        companyId: company.id,
        articleId: articleB.id,
        supplierId: supplier.id,
        purchasePriceCents: 200,
      );

      final suggestions = await purchaseOrders.suggestFromLowStock(company.id);
      expect(suggestions.bySupplier, hasLength(1));
      final suggestion = suggestions.bySupplier.single;
      expect(suggestion.supplierId, supplier.id);
      // Fehlbetrag: A braucht 5, B braucht 8 -> zusammen 13, unter MOQ 50.
      expect(suggestion.totalQuantity, 13);
      expect(suggestion.meetsMinimumOrderQuantity, isFalse);

      // Trotzdem lässt sich ein Entwurf anlegen (nur warnen, nicht blockieren).
      final draft = await purchaseOrders.createDraftFromSuggestion(
        companyId: company.id,
        suggestion: suggestion,
      );
      expect(draft.status, PurchaseOrderStatus.draft);
      expect(await purchaseOrders.itemsFor(draft.id), hasLength(2));
    },
  );

  test(
    'suggestFromLowStock: ein Artikel ohne Standardlieferant-Preis fällt auf den günstigsten '
    'bekannten Lieferanten zurück, ganz ohne jeden Preis wird er als nicht zuordenbar gemeldet',
    () async {
      final company = await companies.create(name: 'Elektro Beckmann');
      await companies.update(company.copyWith(lagerbestandEnabled: true));
      final supplier = await suppliers.create(companyId: company.id, name: 'Großhandel Müller');
      final articleWithPrice =
          await articles.create(companyId: company.id, name: 'Artikel A', minimumStock: 10);
      final articleWithoutPrice =
          await articles.create(companyId: company.id, name: 'Artikel B', minimumStock: 10);
      await articles.setStock(companyId: company.id, id: articleWithPrice.id, newQuantity: 1);
      await articles.setStock(companyId: company.id, id: articleWithoutPrice.id, newQuantity: 1);
      await articles.setSupplierPrice(
        companyId: company.id,
        articleId: articleWithPrice.id,
        supplierId: supplier.id,
        purchasePriceCents: 100,
      );

      final suggestions = await purchaseOrders.suggestFromLowStock(company.id);
      expect(suggestions.bySupplier, hasLength(1));
      expect(suggestions.bySupplier.single.supplierId, supplier.id);
      expect(suggestions.unassignable, hasLength(1));
      expect(suggestions.unassignable.single.articleId, articleWithoutPrice.id);
    },
  );
}
