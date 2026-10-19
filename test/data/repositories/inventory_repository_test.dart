import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:werkkernerp/data/database/database.dart';
import 'package:werkkernerp/data/database/tables.dart';
import 'package:werkkernerp/data/repositories/article_repository.dart';
import 'package:werkkernerp/data/repositories/company_repository.dart';
import 'package:werkkernerp/data/repositories/inventory_repository.dart';

/// C5.3 Inventur/Bewegungsprotokoll (Nachtrag 2026-10-19, Kay-
/// Entscheidung auf Rückfrage: "Volle Inventur-Sitzung" + "Das muss
/// alles dokumentiert werden").
void main() {
  late AppDatabase db;
  late CompanyRepository companies;
  late ArticleRepository articles;
  late InventoryRepository inventory;

  setUp(() {
    db = AppDatabase.forTesting(
      NativeDatabase.memory(setup: (rawDb) => rawDb.execute('PRAGMA foreign_keys = ON;')),
    );
    companies = CompanyRepository(db);
    articles = ArticleRepository(db);
    inventory = InventoryRepository(db);
  });

  tearDown(() async => db.close());

  test(
    'Volle Inventur-Sitzung: bucht nur echte Abweichungen, lässt unveränderte Artikel unberührt '
    'und dokumentiert jede Buchung im Bewegungsprotokoll',
    () async {
      final company = await companies.create(name: 'Elektro Beckmann');
      final articleA = await articles.create(companyId: company.id, name: 'Artikel A');
      final articleB = await articles.create(companyId: company.id, name: 'Artikel B');
      await articles.setStock(companyId: company.id, id: articleA.id, newQuantity: 10);
      await articles.setStock(companyId: company.id, id: articleB.id, newQuantity: 5);

      final count = await inventory.startCount(companyId: company.id, label: 'Jahresinventur 2026');
      expect(count.status, InventoryCountStatus.draft);

      await inventory.addArticles(
        companyId: company.id,
        inventoryCountId: count.id,
        articleIds: [articleA.id, articleB.id],
      );
      final items = await inventory.itemsFor(count.id);
      expect(items, hasLength(2));
      expect(items.every((i) => i.countedQuantity == null), isTrue);

      final itemA = items.firstWhere((i) => i.articleId == articleA.id);
      final itemB = items.firstWhere((i) => i.articleId == articleB.id);
      // A wird korrigiert (10 -> 8), B bleibt unverändert (5 -> 5).
      await inventory.setCountedQuantity(itemId: itemA.id, countedQuantity: 8);
      await inventory.setCountedQuantity(itemId: itemB.id, countedQuantity: 5);

      final completed = await inventory.complete(companyId: company.id, id: count.id);
      expect(completed!.status, InventoryCountStatus.completed);
      expect(completed.completedAt, isNotNull);

      expect((await articles.findById(companyId: company.id, id: articleA.id))!.stockQuantity, 8);
      expect(
        (await articles.findById(companyId: company.id, id: articleB.id))!.stockQuantity,
        5,
        reason: 'Unveränderte Zählung bucht nichts',
      );

      final movementsA = await inventory.movementsForArticle(companyId: company.id, articleId: articleA.id);
      expect(movementsA, hasLength(1));
      expect(movementsA.single.type, StockMovementType.inventoryCorrection);
      expect(movementsA.single.quantityDelta, -2);
      expect(movementsA.single.resultingQuantity, 8);
      expect(movementsA.single.referenceLabel, 'Jahresinventur 2026');

      final movementsB = await inventory.movementsForArticle(companyId: company.id, articleId: articleB.id);
      expect(
        movementsB,
        isEmpty,
        reason: 'Keine Abweichung -> keine Bewegungsprotokoll-Zeile',
      );

      // Nach dem Abschluss unveränderlich — ein erneutes Abschließen
      // ist ein No-Op (null), bucht insbesondere nicht noch einmal.
      expect(await inventory.complete(companyId: company.id, id: count.id), isNull);
      expect((await articles.findById(companyId: company.id, id: articleA.id))!.stockQuantity, 8);
    },
  );

  test(
    'correctSingleArticleStock(): Pflicht-Grund wird als Referenz im Bewegungsprotokoll gespeichert',
    () async {
      final company = await companies.create(name: 'Elektro Beckmann');
      final article = await articles.create(companyId: company.id, name: 'Schraube');
      await articles.setStock(companyId: company.id, id: article.id, newQuantity: 10);

      final updated = await inventory.correctSingleArticleStock(
        companyId: company.id,
        articleId: article.id,
        newQuantity: 15,
        reason: 'Nachzählung Lager 2',
      );
      expect(updated!.stockQuantity, 15);

      final movements = await inventory.movementsForArticle(companyId: company.id, articleId: article.id);
      expect(movements, hasLength(1));
      expect(movements.single.quantityDelta, 5);
      expect(movements.single.referenceLabel, 'Nachzählung Lager 2');
      expect(movements.single.type, StockMovementType.inventoryCorrection);

      // Die erzeugte Inventur ist selbst auch gelistet (ein Ein-
      // Artikel-Lauf, kein separater "Quick correction"-Pfad ohne
      // Dokumentation).
      final counts = await inventory.listForCompany(company.id);
      expect(counts, hasLength(1));
      expect(counts.single.label, 'Nachzählung Lager 2');
      expect(counts.single.status, InventoryCountStatus.completed);
    },
  );

  test('movementsForArticle() liefert neueste Bewegung zuerst', () async {
    final company = await companies.create(name: 'Elektro Beckmann');
    final article = await articles.create(companyId: company.id, name: 'Schraube');
    await articles.setStock(companyId: company.id, id: article.id, newQuantity: 10);

    await inventory.correctSingleArticleStock(
      companyId: company.id,
      articleId: article.id,
      newQuantity: 12,
      reason: 'Erste Korrektur',
    );
    // Drift speichert DateTime standardmäßig als Unix-Sekunden (keine
    // Millisekunden-Auflösung) — ohne eine Verzögerung über die
    // Sekundengrenze hinweg bekämen beide Korrekturen denselben
    // `createdAt`-Wert und die Sortierreihenfolge wäre nicht eindeutig.
    await Future<void>.delayed(const Duration(seconds: 1, milliseconds: 100));
    await inventory.correctSingleArticleStock(
      companyId: company.id,
      articleId: article.id,
      newQuantity: 20,
      reason: 'Zweite Korrektur',
    );

    final movements = await inventory.movementsForArticle(companyId: company.id, articleId: article.id);
    expect(movements, hasLength(2));
    expect(movements.first.referenceLabel, 'Zweite Korrektur');
    expect(movements.last.referenceLabel, 'Erste Korrektur');
  });
}
