import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:werkkernerp/data/database/database.dart';
import 'package:werkkernerp/data/database/tables.dart';
import 'package:werkkernerp/data/repositories/article_repository.dart';
import 'package:werkkernerp/data/repositories/company_repository.dart';
import 'package:werkkernerp/data/repositories/customer_repository.dart';
import 'package:werkkernerp/data/repositories/expense_category_repository.dart';
import 'package:werkkernerp/data/repositories/expense_repository.dart';
import 'package:werkkernerp/data/repositories/invoice_repository.dart';
import 'package:werkkernerp/data/repositories/number_sequence_repository.dart';
import 'package:werkkernerp/data/repositories/project_repository.dart';
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
  late ProjectRepository projects;
  late ExpenseCategoryRepository expenseCategories;
  late ExpenseRepository expenses;

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
    projects = ProjectRepository(db);
    expenseCategories = ExpenseCategoryRepository(db);
    expenses = ExpenseRepository(db);
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

  test(
    'receiveGoods() dokumentiert jede Buchung im Bewegungsprotokoll und bucht einen Beleg über '
    'den Wert GENAU dieses Wareneingangs (SKR03-Kategorie + Projekt von der Bestellung übernommen)',
    () async {
      final company = await companies.create(name: 'Elektro Beckmann');
      await companies.update(company.copyWith(projectsEnabled: true, buchhaltungEnabled: true));
      final supplier = await suppliers.create(companyId: company.id, name: 'Großhandel Müller');
      final article = await articles.create(companyId: company.id, name: 'Schrauben');
      final project = await projects.create(companyId: company.id, name: 'Projekt Nord');
      final category = await expenseCategories.create(
        companyId: company.id,
        label: 'Material/Wareneinkauf',
        skr03Account: '3400',
      );

      final draft = await purchaseOrders.createDraft(
        companyId: company.id,
        supplierId: supplier.id,
        issueDate: DateTime.now(),
        projectId: project.id,
        expenseCategoryId: category.id,
        items: [
          PurchaseOrderItemInput(
            articleId: article.id,
            description: 'Schrauben',
            quantity: 100,
            purchasePriceCents: 10,
          ),
        ],
      );
      final finalized = (await purchaseOrders.finalize(companyId: company.id, id: draft.id))!;
      final itemId = (await purchaseOrders.itemsFor(finalized.id)).single.id;

      // Erste Teillieferung: 60 Stück -> 6,00 €.
      await purchaseOrders.receiveGoods(companyId: company.id, id: finalized.id, receipts: {itemId: 60});

      final expensesAfterFirst = await expenses.listForCompany(company.id);
      expect(expensesAfterFirst, hasLength(1));
      expect(expensesAfterFirst.single.amountGrossCents, 600);
      expect(expensesAfterFirst.single.categoryId, category.id);
      expect(expensesAfterFirst.single.projectId, project.id);
      expect(expensesAfterFirst.single.supplierReference, finalized.orderNumber);
      expect(expensesAfterFirst.single.vatRatePercent, 0);

      // Zweite Teillieferung: restliche 40 Stück -> ein ZWEITER,
      // eigenständiger Beleg über 4,00 € (nicht der gesamte Auftragswert
      // erneut) — jede Teillieferung bucht nur ihren eigenen Anteil.
      await purchaseOrders.receiveGoods(companyId: company.id, id: finalized.id, receipts: {itemId: 40});
      final expensesAfterSecond = await expenses.listForCompany(company.id);
      expect(expensesAfterSecond, hasLength(2));
      expect(
        expensesAfterSecond.fold(0, (sum, e) => sum + e.amountGrossCents),
        1000,
        reason: 'Beide Teillieferungen zusammen ergeben den vollen Bestellwert',
      );

      final movements = await db.select(db.stockMovements).get();
      expect(movements, hasLength(2));
      expect(movements.every((m) => m.type == StockMovementType.purchaseOrderReceipt), isTrue);
      expect(movements.every((m) => m.referenceLabel == finalized.orderNumber), isTrue);
    },
  );

  test('receiveGoods() ohne bekannten Einkaufspreis bucht den Bestand, aber keinen Beleg', () async {
    final company = await companies.create(name: 'Elektro Beckmann');
    final supplier = await suppliers.create(companyId: company.id, name: 'Großhandel Müller');
    final draft = await purchaseOrders.createDraft(
      companyId: company.id,
      supplierId: supplier.id,
      issueDate: DateTime.now(),
      items: [const PurchaseOrderItemInput(description: 'Ad-hoc-Position', quantity: 10)],
    );
    final finalized = (await purchaseOrders.finalize(companyId: company.id, id: draft.id))!;
    final itemId = (await purchaseOrders.itemsFor(finalized.id)).single.id;

    await purchaseOrders.receiveGoods(companyId: company.id, id: finalized.id, receipts: {itemId: 10});

    expect(await expenses.listForCompany(company.id), isEmpty);
  });

  test(
    'createDraftsFromOrder() übernimmt die Projektzuordnung des Auftrags automatisch in die '
    'erzeugte(n) Bestellung(en)',
    () async {
      final company = await companies.create(name: 'Elektro Beckmann');
      await companies.update(company.copyWith(ordersEnabled: true, projectsEnabled: true));
      final customer = await customers.create(companyId: company.id, name: 'Kunde');
      final supplier = await suppliers.create(companyId: company.id, name: 'Lieferant');
      final article = await articles.create(companyId: company.id, name: 'Artikel');
      final project = await projects.create(companyId: company.id, name: 'Projekt Süd');
      await articles.setSupplierPrice(
        companyId: company.id,
        articleId: article.id,
        supplierId: supplier.id,
        purchasePriceCents: 100,
      );

      final orderDraft = await invoices.createDraft(
        companyId: company.id,
        customerId: customer.id,
        kind: DocumentKind.order,
        issueDate: DateTime.now(),
        serviceDate: DateTime.now(),
        projectId: project.id,
        items: [
          InvoiceItemInput(
            kind: InvoiceItemKind.article,
            articleId: article.id,
            description: 'Position',
            quantity: Decimal.one,
            unitPriceCents: 1000,
            vatRatePercent: 19,
          ),
        ],
      );
      final order = (await invoices.finalize(companyId: company.id, id: orderDraft.id))!;

      final result = await purchaseOrders.createDraftsFromOrder(
        companyId: company.id,
        sourceOrderId: order.id,
        mode: PurchaseOrderCreationMode.cheapestPerSupplier,
      );

      expect(result.drafts.single.projectId, project.id);
    },
  );

  test('updateDraft() kann Projekt/Kategorie/Dokumentzuordnung setzen und per Value(null) wieder entfernen',
      () async {
    final company = await companies.create(name: 'Elektro Beckmann');
    await companies.update(company.copyWith(projectsEnabled: true, buchhaltungEnabled: true));
    final supplier = await suppliers.create(companyId: company.id, name: 'Lieferant');
    final project = await projects.create(companyId: company.id, name: 'Projekt West');
    final category = await expenseCategories.create(companyId: company.id, label: 'Material');
    final draft = await purchaseOrders.createDraft(
      companyId: company.id,
      supplierId: supplier.id,
      issueDate: DateTime.now(),
    );

    final updated = await purchaseOrders.updateDraft(
      companyId: company.id,
      id: draft.id,
      projectId: Value(project.id),
      expenseCategoryId: Value(category.id),
    );
    expect(updated!.projectId, project.id);
    expect(updated.expenseCategoryId, category.id);

    final cleared = await purchaseOrders.updateDraft(
      companyId: company.id,
      id: draft.id,
      projectId: const Value(null),
    );
    expect(cleared!.projectId, isNull);
    expect(cleared.expenseCategoryId, category.id, reason: 'Value.absent() lässt die Kategorie unberührt');
  });
}
