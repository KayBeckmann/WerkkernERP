import 'package:drift/drift.dart' show Value;
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

  test(
    'Nachtrag 2026-10-18 ("Artikel können nicht nachträglich bearbeitet werden"): update() ändert '
    'nur die übergebenen Felder, Zuordnungen lassen sich per Value(null) wieder entfernen',
    () async {
      final company = await companies.create(name: 'Elektro Beckmann');
      final supplier = await suppliers.create(companyId: company.id, name: 'Großhandel');
      final group = await articleGroups.create(companyId: company.id, name: 'Elektromaterial', markupPercent: 20);
      final article = await articles.create(
        companyId: company.id,
        name: 'Steckdose',
        unit: 'Stk',
        articleGroupId: group.id,
        defaultSupplierId: supplier.id,
      );

      // Nur den Namen ändern (Tippfehler korrigieren) — Rest bleibt.
      final renamed = await articles.update(companyId: company.id, id: article.id, name: 'Steckdose weiß');
      expect(renamed!.name, 'Steckdose weiß');
      expect(renamed.unit, 'Stk', reason: 'nicht übergebene Felder bleiben unverändert');
      expect(renamed.articleGroupId, group.id);
      expect(renamed.defaultSupplierId, supplier.id);

      // Zuordnungen explizit entfernen.
      final cleared = await articles.update(
        companyId: company.id,
        id: article.id,
        articleGroupId: const Value(null),
        defaultSupplierId: const Value(null),
      );
      expect(cleared!.articleGroupId, isNull);
      expect(cleared.defaultSupplierId, isNull);
      expect(cleared.name, 'Steckdose weiß', reason: 'Value.absent() bei name lässt ihn unverändert');
    },
  );

  test('update() über eine fremde Firma schlägt fehl (liefert null)', () async {
    final companyA = await companies.create(name: 'Firma A');
    final companyB = await companies.create(name: 'Firma B');
    final article = await articles.create(companyId: companyA.id, name: 'Artikel A');

    expect(await articles.update(companyId: companyB.id, id: article.id, name: 'Manipuliert'), isNull);
  });

  test(
    'Nachtrag 2026-10-18 ("Artikel müssen deaktiviert werden können"): setActive(false) blendet '
    'einen Artikel aus listForCompany() aus, löscht aber keine Lieferantenpreise; setActive(true) '
    'macht ihn wieder sichtbar',
    () async {
      final company = await companies.create(name: 'Elektro Beckmann');
      final supplier = await suppliers.create(companyId: company.id, name: 'Großhandel');
      final article = await articles.create(companyId: company.id, name: 'Steckdose');
      await articles.setSupplierPrice(
        companyId: company.id,
        articleId: article.id,
        supplierId: supplier.id,
        purchasePriceCents: 250,
      );

      expect((await articles.listForCompany(company.id)).map((a) => a.id), contains(article.id));

      await articles.setActive(companyId: company.id, id: article.id, active: false);
      expect((await articles.listForCompany(company.id)).map((a) => a.id), isNot(contains(article.id)));
      expect(
        (await articles.listForCompany(company.id, includeInactive: true)).map((a) => a.id),
        contains(article.id),
        reason: 'includeInactive: true zeigt ihn weiterhin',
      );
      expect(
        await articles.supplierPricesFor(article.id),
        hasLength(1),
        reason: 'Deaktivieren löscht keine Lieferantenpreise',
      );

      await articles.setActive(companyId: company.id, id: article.id, active: true);
      expect((await articles.listForCompany(company.id)).map((a) => a.id), contains(article.id));
    },
  );

  test('Fremde Firmen-ID kann einen Artikel nicht deaktivieren', () async {
    final companyA = await companies.create(name: 'Firma A');
    final companyB = await companies.create(name: 'Firma B');
    final article = await articles.create(companyId: companyA.id, name: 'Artikel A');

    expect(await articles.setActive(companyId: companyB.id, id: article.id, active: false), isFalse);
    expect((await articles.findById(companyId: companyA.id, id: article.id))!.active, isTrue);
  });
}
