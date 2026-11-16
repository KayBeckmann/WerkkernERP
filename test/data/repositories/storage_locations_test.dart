import 'package:decimal/decimal.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:werkkernerp/data/database/database.dart';
import 'package:werkkernerp/data/database/tables.dart';
import 'package:werkkernerp/data/repositories/article_repository.dart';
import 'package:werkkernerp/data/repositories/company_repository.dart';
import 'package:werkkernerp/data/repositories/customer_repository.dart';
import 'package:werkkernerp/data/repositories/inventory_repository.dart';
import 'package:werkkernerp/data/repositories/invoice_repository.dart';
import 'package:werkkernerp/data/repositories/number_sequence_repository.dart';
import 'package:werkkernerp/data/repositories/purchase_order_repository.dart';
import 'package:werkkernerp/data/repositories/stock_ledger.dart';
import 'package:werkkernerp/data/repositories/storage_repository.dart';
import 'package:werkkernerp/data/repositories/supplier_repository.dart';

/// C5.4-Nachtrag (Kay, 16.11.2026): Lagerorte und Plätze — Summe der
/// Platzbestände = Gesamtbestand, Entnahme-Vorschlag, Wareneingang auf
/// Zielplatz, Umlagerung, Inventur nach Lagerort in Laufreihenfolge.
void main() {
  late AppDatabase db;
  late Company company;
  late ArticleRepository articles;
  late StorageRepository storage;
  late StockLedger ledger;
  late InventoryRepository inventory;
  late InvoiceRepository invoices;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory(setup: (d) => d.execute('PRAGMA foreign_keys = ON;')));
    final companies = CompanyRepository(db);
    company = await companies.create(name: 'Nord-Impuls');
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
      lagerbestandEnabled: true,
      bestellwesenEnabled: true,
      timeTrackingEnabled: false,
    );
    articles = ArticleRepository(db);
    storage = StorageRepository(db);
    ledger = StockLedger(db);
    inventory = InventoryRepository(db);
    invoices = InvoiceRepository(db, NumberSequenceRepository(db));
  });
  tearDown(() => db.close());

  Future<double> total(String articleId) async =>
      (await articles.findById(companyId: company.id, id: articleId))!.stockQuantity;

  Future<Map<String, double>> bins(String articleId) async => {
        for (final s in await ledger.stocksFor(companyId: company.id, articleId: articleId)) s.binKey: s.quantity,
      };

  Future<void> expectConsistent(String articleId) async {
    final sum = (await bins(articleId)).values.fold<double>(0, (a, b) => a + b);
    expect(sum, await total(articleId), reason: 'Summe der Plätze = Gesamtbestand');
  }

  test('Lagerorte/Plätze anlegen, Laufreihenfolge, Platz mit Bestand nicht löschbar', () async {
    final lager = await storage.createLocation(companyId: company.id, name: 'Lager');
    final b10 = await storage.saveBin(companyId: company.id, locationId: lager.id, row: '1', shelf: 'A', compartment: '10');
    final b2 = await storage.saveBin(companyId: company.id, locationId: lager.id, row: '1', shelf: 'A', compartment: '2');
    final r0 = await storage.saveBin(companyId: company.id, locationId: lager.id, row: '0', shelf: 'B', compartment: '1');
    expect((await storage.binsOf(companyId: company.id, locationId: lager.id)).map((b) => b.id), [r0.id, b2.id, b10.id]);
    expect(storageBinLabel(b2, locationName: 'Lager'), 'Lager · Reihe 1 / Regal A / Fach 2');
    expect(
      () => storage.saveBin(companyId: company.id, locationId: lager.id, row: ' ', shelf: '', compartment: ''),
      throwsArgumentError,
    );

    final a = await articles.create(companyId: company.id, name: 'NYM-J 3x1,5');
    await ledger.book(companyId: company.id, articleId: a.id, delta: 5, type: StockMovementType.inventoryCorrection, binKey: b2.id);
    expect(() => storage.deleteBin(companyId: company.id, id: b2.id), throwsA(isA<StorageBinInUseException>()));
    expect(() => storage.deleteLocation(companyId: company.id, id: lager.id), throwsA(isA<StorageBinInUseException>()));
    await storage.setDefaultBin(companyId: company.id, articleId: a.id, binId: b10.id);
    await storage.deleteBin(companyId: company.id, id: b10.id);
    expect((await articles.findById(companyId: company.id, id: a.id))!.defaultBinId, isNull);
    expect(await storage.articleIdsAtLocation(companyId: company.id, locationId: lager.id), {a.id});
  });

  test('Altbestand ohne Platz = „nicht zugeordnet“; Umlagerung hält Gesamtbestand', () async {
    final a = await articles.create(companyId: company.id, name: 'Schalter');
    await articles.setStock(companyId: company.id, id: a.id, newQuantity: 8);
    expect(await bins(a.id), {unassignedBinKey: 8.0});
    final loc = await storage.createLocation(companyId: company.id, name: 'Fahrzeug 1');
    final bin = await storage.saveBin(companyId: company.id, locationId: loc.id, row: '', shelf: 'Kiste', compartment: '1');
    await ledger.transfer(companyId: company.id, articleId: a.id, fromBinKey: unassignedBinKey, toBinKey: bin.id, quantity: 8);
    expect(await bins(a.id), {bin.id: 8.0});
    expect(await total(a.id), 8);
    final moves = await inventory.movementsForArticle(companyId: company.id, articleId: a.id);
    expect(moves.where((m) => m.type == StockMovementType.transfer).map((m) => (m.quantityDelta, m.binKey)).toSet(),
        {(-8.0, unassignedBinKey), (8.0, bin.id)});
  });

  test('Entnahme schlägt Platz vor und bucht dort; Wareneingang auf Ziel- bzw. Standardplatz', () async {
    final loc = await storage.createLocation(companyId: company.id, name: 'Lager');
    final p1 = await storage.saveBin(companyId: company.id, locationId: loc.id, row: '1', shelf: 'A', compartment: '1');
    final p2 = await storage.saveBin(companyId: company.id, locationId: loc.id, row: '1', shelf: 'A', compartment: '2');
    final a = await articles.create(companyId: company.id, name: 'Dose');
    await storage.setDefaultBin(companyId: company.id, articleId: a.id, binId: p1.id);
    // Ohne Bestand: Vorschlag = Standardplatz.
    expect(await ledger.suggestWithdrawalBin(companyId: company.id, articleId: a.id), p1.id);

    // Wareneingang: Position 1 ohne Ziel → Standardplatz; Ziel explizit p2.
    final supplier = await SupplierRepository(db).create(companyId: company.id, name: 'Großhandel');
    final orders = PurchaseOrderRepository(db, NumberSequenceRepository(db));
    final po = await orders.createDraft(
      companyId: company.id,
      supplierId: supplier.id,
      issueDate: DateTime(2026, 11, 16),
      items: [
        PurchaseOrderItemInput(articleId: a.id, description: 'Dose', quantity: 3),
        PurchaseOrderItemInput(articleId: a.id, description: 'Dose (2)', quantity: 10),
      ],
    );
    await orders.finalize(companyId: company.id, id: po.id);
    final poItems = await orders.itemsFor(po.id);
    await orders.receiveGoods(
      companyId: company.id,
      id: po.id,
      receipts: {for (final i in poItems) i.id: i.quantity},
      targetBins: {poItems.firstWhere((i) => i.quantity == 10).id: p2.id},
    );
    expect(await bins(a.id), {p1.id: 3.0, p2.id: 10.0});
    // Vorschlag = Platz mit größtem Bestand.
    expect(await ledger.suggestWithdrawalBin(companyId: company.id, articleId: a.id), p2.id);

    final customer = await CustomerRepository(db).create(companyId: company.id, name: 'Kunde');
    final order = await invoices.createDraft(
      companyId: company.id,
      customerId: customer.id,
      kind: DocumentKind.order,
      issueDate: DateTime(2026, 11, 16),
      serviceDate: DateTime(2026, 11, 16),
      items: [
        InvoiceItemInput(kind: InvoiceItemKind.article, articleId: a.id, description: 'Dose', quantity: Decimal.fromInt(5), unitPriceCents: 100, vatRatePercent: 19),
      ],
    );
    final suggestions = await invoices.withdrawalSuggestions(companyId: company.id, id: order.id);
    expect(suggestions.single.suggestedBinKey, p2.id);
    expect(suggestions.single.quantity, 5);
    // Nutzer wählt p1 (nur 3 dort): Rest kommt vom nächsten Platz mit Bestand.
    await invoices.finalize(companyId: company.id, id: order.id, withdrawalBins: {a.id: p1.id});
    expect(await bins(a.id), {p1.id: 0.0, p2.id: 8.0});
    expect(await total(a.id), 8);
    await expectConsistent(a.id);
  });

  test('Inventur nach Lagerort: Plätze in Laufreihenfolge, Klärfälle, Fund an leerem Platz', () async {
    final loc = await storage.createLocation(companyId: company.id, name: 'Lager');
    final p2 = await storage.saveBin(companyId: company.id, locationId: loc.id, row: '2', shelf: '', compartment: '');
    final p1 = await storage.saveBin(companyId: company.id, locationId: loc.id, row: '1', shelf: '', compartment: '');
    final empty = await storage.saveBin(companyId: company.id, locationId: loc.id, row: '3', shelf: '', compartment: '');
    final a = await articles.create(companyId: company.id, name: 'A');
    final b = await articles.create(companyId: company.id, name: 'B');
    await ledger.book(companyId: company.id, articleId: a.id, delta: 4, type: StockMovementType.inventoryCorrection, binKey: p2.id);
    await ledger.book(companyId: company.id, articleId: b.id, delta: 2, type: StockMovementType.inventoryCorrection, binKey: p1.id);
    await articles.setStock(companyId: company.id, id: b.id, newQuantity: 3); // 1 Stück ohne Platz

    final count = await inventory.startLocationCount(companyId: company.id, label: 'Lager 11/2026', locationId: loc.id);
    expect(count.locationId, loc.id);
    final items = await inventory.itemsFor(count.id);
    expect([for (final i in items) (i.articleId, i.binKey, i.expectedQuantity)], [
      (b.id, p1.id, 2.0),
      (a.id, p2.id, 4.0),
      (b.id, unassignedBinKey, 1.0),
    ]);

    await inventory.setCountedQuantity(itemId: items[0].id, countedQuantity: 2);
    await inventory.setCountedQuantity(itemId: items[1].id, countedQuantity: 3);
    await inventory.setCountedQuantity(itemId: items[2].id, countedQuantity: 0);
    expect(await inventory.addArticleAtBin(companyId: company.id, inventoryCountId: count.id, articleId: b.id, binKey: empty.id), isTrue);
    expect(await inventory.addArticleAtBin(companyId: company.id, inventoryCountId: count.id, articleId: b.id, binKey: empty.id), isFalse);
    final found = (await inventory.itemsFor(count.id)).firstWhere((i) => i.binKey == empty.id);
    await inventory.setCountedQuantity(itemId: found.id, countedQuantity: 1);
    await inventory.complete(companyId: company.id, id: count.id);

    expect(await bins(a.id), {p2.id: 3.0});
    expect(await bins(b.id), {p1.id: 2.0, empty.id: 1.0});
    expect(await total(a.id), 3);
    expect(await total(b.id), 3);
    await expectConsistent(a.id);
    await expectConsistent(b.id);
  });

  test('Artikelweise Inventur und Gutschrift halten Plätze konsistent', () async {
    final loc = await storage.createLocation(companyId: company.id, name: 'Lager');
    final p1 = await storage.saveBin(companyId: company.id, locationId: loc.id, row: '1', shelf: '', compartment: '');
    final a = await articles.create(companyId: company.id, name: 'A');
    await storage.setDefaultBin(companyId: company.id, articleId: a.id, binId: p1.id);
    await inventory.correctSingleArticleStock(companyId: company.id, articleId: a.id, newQuantity: 6, reason: 'Anfangsbestand');
    expect(await bins(a.id), {p1.id: 6.0});
    await inventory.correctSingleArticleStock(companyId: company.id, articleId: a.id, newQuantity: 4, reason: 'Bruch');
    expect(await bins(a.id), {p1.id: 4.0});
    await expectConsistent(a.id);
  });
}
