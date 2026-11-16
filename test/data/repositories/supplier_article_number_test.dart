import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:werkkernerp/data/database/database.dart';
import 'package:werkkernerp/data/repositories/article_repository.dart';
import 'package:werkkernerp/data/repositories/company_repository.dart';
import 'package:werkkernerp/data/repositories/number_sequence_repository.dart';
import 'package:werkkernerp/data/repositories/purchase_order_repository.dart';
import 'package:werkkernerp/data/repositories/supplier_repository.dart';
import 'package:werkkernerp/pdf/purchase_order_pdf_builder.dart';

/// C5.2-Nachtrag (Kay, 16.11.2026): Lieferantenartikelnummer je Artikel ×
/// Lieferant — Bestellung an AZ zeigt nur die AZ-Nummer, an Sonepar nur
/// die Sonepar-Nummer; finalisierte Bestellungen bleiben unverändert.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory(setup: (d) => d.execute('PRAGMA foreign_keys = ON;'))));
  tearDown(() => db.close());

  test('Nummer je Zuordnung, Schnappschuss beim Finalisieren, Entwurf zeigt aktuelle', () async {
    final company = await CompanyRepository(db).create(name: 'Nord-Impuls');
    final suppliers = SupplierRepository(db);
    final az = await suppliers.create(companyId: company.id, name: 'AZ');
    final sonepar = await suppliers.create(companyId: company.id, name: 'Sonepar');
    final articles = ArticleRepository(db);
    final ls = await articles.create(companyId: company.id, name: 'LS B16/1');
    final plain = await articles.create(companyId: company.id, name: 'Ohne Nummer');
    await articles.setSupplierPrice(
      companyId: company.id,
      articleId: ls.id,
      supplierId: az.id,
      purchasePriceCents: 250,
      supplierArticleNumber: const Value(' 0060903A '),
    );
    await articles.setSupplierPrice(
      companyId: company.id,
      articleId: ls.id,
      supplierId: sonepar.id,
      purchasePriceCents: 260,
      supplierArticleNumber: const Value('SP-77'),
    );
    await articles.setSupplierPrice(companyId: company.id, articleId: plain.id, supplierId: az.id, purchasePriceCents: 100);
    // Preisänderung ohne Nummer lässt die Nummer stehen.
    await articles.setSupplierPrice(companyId: company.id, articleId: ls.id, supplierId: az.id, purchasePriceCents: 240);
    final prices = {for (final p in await articles.supplierPricesFor(ls.id)) p.supplierId: p};
    expect((prices[az.id]!.supplierArticleNumber, prices[az.id]!.purchasePriceCents), ('0060903A', 240));

    final orders = PurchaseOrderRepository(db, NumberSequenceRepository(db));
    Future<PurchaseOrder> order(String supplierId) => orders.createDraft(
          companyId: company.id,
          supplierId: supplierId,
          issueDate: DateTime(2026, 11, 16),
          items: [
            PurchaseOrderItemInput(articleId: ls.id, description: 'LS B16/1', quantity: 10),
            PurchaseOrderItemInput(articleId: plain.id, description: 'Ohne Nummer', quantity: 1),
            const PurchaseOrderItemInput(description: 'Versand', quantity: 1),
          ],
        );
    final azDraft = await order(az.id);
    final soneparDraft = await order(sonepar.id);
    Future<List<String>> numbersOf(String id) async {
      final o = (await orders.findById(companyId: company.id, id: id))!;
      final items = await orders.itemsFor(id);
      final map = await orders.supplierArticleNumbers(o, items);
      return [for (final i in items) map[i.id] ?? '-'];
    }

    expect(await numbersOf(azDraft.id), ['0060903A', '-', '-']);
    expect(await numbersOf(soneparDraft.id), ['SP-77', '-', '-']);

    await orders.finalize(companyId: company.id, id: azDraft.id);
    expect([for (final i in await orders.itemsFor(azDraft.id)) i.supplierArticleNumber], ['0060903A', null, null]);
    // Spätere Änderung an der Zuordnung ändert die finalisierte Bestellung nicht.
    await articles.setSupplierPrice(
      companyId: company.id,
      articleId: ls.id,
      supplierId: az.id,
      purchasePriceCents: 240,
      supplierArticleNumber: const Value('NEU'),
    );
    expect(await numbersOf(azDraft.id), ['0060903A', '-', '-']);
    // Leer = entfernen.
    await articles.setSupplierPrice(
      companyId: company.id,
      articleId: ls.id,
      supplierId: sonepar.id,
      purchasePriceCents: 260,
      supplierArticleNumber: const Value('  '),
    );
    expect(await numbersOf(soneparDraft.id), ['-', '-', '-']);

    // PDF der AZ-Bestellung: Schnappschuss-Nummer unter der Beschreibung.
    if ((await Process.run('which', ['pdftotext'])).exitCode != 0) return;
    final azOrder = (await orders.findById(companyId: company.id, id: azDraft.id))!;
    final bytes = await buildPurchaseOrderPdf(
      order: azOrder,
      items: await orders.itemsFor(azOrder.id),
      company: (await CompanyRepository(db).findById(company.id))!,
    );
    final dir = await Directory.systemTemp.createTemp('werkkern-san-');
    try {
      final file = File('${dir.path}/b.pdf')..writeAsBytesSync(bytes);
      final text = (await Process.run('pdftotext', ['-layout', file.path, '-'])).stdout as String;
      expect(text, contains('Ihre Art.-Nr.: 0060903A'));
      expect(text, isNot(contains('NEU')));
      expect(text, isNot(contains('SP-77')));
    } finally {
      await dir.delete(recursive: true);
    }
  });
}
