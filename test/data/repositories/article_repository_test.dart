import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:werkkernerp/data/database/database.dart';
import 'package:werkkernerp/data/repositories/article_group_repository.dart';
import 'package:werkkernerp/data/repositories/article_repository.dart';
import 'package:werkkernerp/data/repositories/company_repository.dart';
import 'package:werkkernerp/data/repositories/supplier_repository.dart';
import 'package:werkkernerp/domain/models/money.dart';

void main() {
  late AppDatabase db;
  late CompanyRepository companies;
  late SupplierRepository suppliers;
  late ArticleGroupRepository articleGroups;
  late ArticleRepository articles;

  setUp(() {
    db = AppDatabase.forTesting(
      NativeDatabase.memory(setup: (rawDb) => rawDb.execute('PRAGMA foreign_keys = ON;')),
    );
    companies = CompanyRepository(db);
    suppliers = SupplierRepository(db);
    articleGroups = ArticleGroupRepository(db);
    articles = ArticleRepository(db);
  });

  tearDown(() async => db.close());

  test(
    'A1-Abnahme: Artikel mit zwei Lieferanten nutzt den Standardlieferanten zur Kalkulation '
    '(100€ EK + 30% Aufschlag = 130€ netto)',
    () async {
      final company = await companies.create(name: 'Elektro Beckmann');
      final supplierA = await suppliers.create(companyId: company.id, name: 'Großhandel A');
      final supplierB = await suppliers.create(companyId: company.id, name: 'Großhandel B');
      final group = await articleGroups.create(
        companyId: company.id,
        name: 'Elektromaterial',
        markupPercent: 30,
      );

      final article = await articles.create(
        companyId: company.id,
        name: 'Steckdose',
        unit: 'Stk',
        articleGroupId: group.id,
        defaultSupplierId: supplierA.id,
      );

      // Zwei Lieferanten, unterschiedliche Einkaufspreise.
      await articles.setSupplierPrice(
        companyId: company.id,
        articleId: article.id,
        supplierId: supplierA.id,
        purchasePriceCents: 10000, // 100,00 €
      );
      await articles.setSupplierPrice(
        companyId: company.id,
        articleId: article.id,
        supplierId: supplierB.id,
        purchasePriceCents: 8000, // billiger, aber NICHT Standardlieferant
      );

      final salePrice = await articles.effectiveSalePrice(
        companyId: company.id,
        articleId: article.id,
      );
      expect(salePrice, Money.fromCents(13000));
    },
  );

  test('Manueller Verkaufspreis überschreibt die Kalkulation', () async {
    final company = await companies.create(name: 'Firma A');
    final supplier = await suppliers.create(companyId: company.id, name: 'Lieferant');
    final group = await articleGroups.create(
      companyId: company.id,
      name: 'Gruppe',
      markupPercent: 50,
    );
    final article = await articles.create(
      companyId: company.id,
      name: 'Artikel',
      articleGroupId: group.id,
      defaultSupplierId: supplier.id,
      manualSalePriceCents: 999, // bewusst abweichend von der Kalkulation
    );
    await articles.setSupplierPrice(
      companyId: company.id,
      articleId: article.id,
      supplierId: supplier.id,
      purchasePriceCents: 10000,
    );

    final salePrice = await articles.effectiveSalePrice(
      companyId: company.id,
      articleId: article.id,
    );
    expect(salePrice, Money.fromCents(999));
  });

  test('Ohne Standardlieferant/Einkaufspreis ist der Preis unbekannt (null statt 0€)', () async {
    final company = await companies.create(name: 'Firma A');
    final article = await articles.create(companyId: company.id, name: 'Artikel ohne Preis');

    final salePrice = await articles.effectiveSalePrice(
      companyId: company.id,
      articleId: article.id,
    );
    expect(salePrice, isNull);
  });

  test('Ohne Artikelgruppe, aber mit Standardlieferant: Aufschlag 0% (reiner EK)', () async {
    final company = await companies.create(name: 'Firma A');
    final supplier = await suppliers.create(companyId: company.id, name: 'Lieferant');
    final article = await articles.create(
      companyId: company.id,
      name: 'Artikel ohne Gruppe',
      defaultSupplierId: supplier.id,
    );
    await articles.setSupplierPrice(
      companyId: company.id,
      articleId: article.id,
      supplierId: supplier.id,
      purchasePriceCents: 5000,
    );

    final salePrice = await articles.effectiveSalePrice(
      companyId: company.id,
      articleId: article.id,
    );
    expect(salePrice, Money.fromCents(5000));
  });

  test(
    'A1-Abnahme: zwei Firmen mit gleichnamigen Artikeln haben unabhängige Preise, keine Vermischung',
    () async {
      final companyA = await companies.create(name: 'Firma A');
      final companyB = await companies.create(name: 'Firma B');
      final supplierA = await suppliers.create(companyId: companyA.id, name: 'Lieferant');
      final supplierB = await suppliers.create(companyId: companyB.id, name: 'Lieferant');

      final articleA = await articles.create(
        companyId: companyA.id,
        name: 'Kabel',
        defaultSupplierId: supplierA.id,
      );
      final articleB = await articles.create(
        companyId: companyB.id,
        name: 'Kabel',
        defaultSupplierId: supplierB.id,
      );
      await articles.setSupplierPrice(
        companyId: companyA.id,
        articleId: articleA.id,
        supplierId: supplierA.id,
        purchasePriceCents: 100,
      );
      await articles.setSupplierPrice(
        companyId: companyB.id,
        articleId: articleB.id,
        supplierId: supplierB.id,
        purchasePriceCents: 999,
      );

      expect(
        await articles.effectiveSalePrice(companyId: companyA.id, articleId: articleA.id),
        Money.fromCents(100),
      );
      expect(
        await articles.effectiveSalePrice(companyId: companyB.id, articleId: articleB.id),
        Money.fromCents(999),
      );

      // Cross-Tenant-Zugriffsversuch: Artikel von A über Firma B ansprechen.
      expect(
        await articles.effectiveSalePrice(companyId: companyB.id, articleId: articleA.id),
        isNull,
      );
    },
  );

  test('setSupplierPrice schlägt fehl, wenn der Artikel nicht zur angegebenen Firma gehört', () async {
    final companyA = await companies.create(name: 'Firma A');
    final companyB = await companies.create(name: 'Firma B');
    final supplierB = await suppliers.create(companyId: companyB.id, name: 'Lieferant B');
    final articleA = await articles.create(companyId: companyA.id, name: 'Artikel A');

    expect(
      () => articles.setSupplierPrice(
        companyId: companyB.id,
        articleId: articleA.id,
        supplierId: supplierB.id,
        purchasePriceCents: 100,
      ),
      throwsStateError,
    );
  });
}
