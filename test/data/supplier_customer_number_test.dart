import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:werkkernerp/data/database/database.dart';
import 'package:werkkernerp/data/repositories/company_repository.dart';
import 'package:werkkernerp/data/repositories/number_sequence_repository.dart';
import 'package:werkkernerp/data/repositories/purchase_order_repository.dart';
import 'package:werkkernerp/data/repositories/supplier_repository.dart';
import 'package:werkkernerp/pdf/purchase_order_pdf_builder.dart';

/// C5.2-Nachtrag (Kay, 15.11.2026): „Unsere Kundennummer beim
/// Lieferanten“ auf Bestellungen — Abnahmebeispiel Zajadacz `060903`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory(setup: (d) => d.execute('PRAGMA foreign_keys = ON;'))));
  tearDown(() => db.close());

  Future<String?> pdfText(List<int> bytes) async {
    if ((await Process.run('which', ['pdftotext'])).exitCode != 0) return null;
    final dir = await Directory.systemTemp.createTemp('werkkern-po-');
    try {
      final file = File('${dir.path}/b.pdf')..writeAsBytesSync(bytes);
      return (await Process.run('pdftotext', ['-layout', file.path, '-'])).stdout as String;
    } finally {
      await dir.delete(recursive: true);
    }
  }

  test('Nummer mit führender Null bleibt erhalten, erscheint nur auf Bestellungen dieses Lieferanten, Schnappschuss', () async {
    final companies = CompanyRepository(db);
    final company = await companies.create(name: 'Nord-Impuls', address: 'Musterstraße 1, 23966 Wismar');
    final suppliers = SupplierRepository(db);
    final zajadacz = await suppliers.create(companyId: company.id, name: 'Zajadacz Lübeck', ourCustomerNumber: '060903');
    final other = await suppliers.create(companyId: company.id, name: 'Großhandel Müller');
    final orders = PurchaseOrderRepository(db, NumberSequenceRepository(db));
    Future<PurchaseOrder> finalizedOrder(Supplier s) async {
      final draft = await orders.createDraft(
        companyId: company.id,
        supplierId: s.id,
        issueDate: DateTime(2026, 11, 16),
        items: const [PurchaseOrderItemInput(description: 'NYM-J 3x1,5', quantity: 100, purchasePriceCents: 80)],
      );
      return (await orders.finalize(companyId: company.id, id: draft.id))!;
    }

    final order = await finalizedOrder(zajadacz);
    expect(order.supplierSnapshotCustomerNumber, '060903');
    final otherOrder = await finalizedOrder(other);
    expect(otherOrder.supplierSnapshotCustomerNumber, isNull);

    // Stammdatenänderung ändert die finalisierte Bestellung nicht.
    await suppliers.update(companyId: company.id, supplier: zajadacz.copyWith(ourCustomerNumber: const Value('999')));
    final reread = (await orders.findById(companyId: company.id, id: order.id))!;
    expect(reread.supplierSnapshotCustomerNumber, '060903');

    final freshCompany = (await companies.findById(company.id))!;
    final text = await pdfText(await buildPurchaseOrderPdf(
      order: reread,
      items: await orders.itemsFor(order.id),
      company: freshCompany,
    ));
    final otherText = await pdfText(await buildPurchaseOrderPdf(
      order: otherOrder,
      items: await orders.itemsFor(otherOrder.id),
      company: freshCompany,
    ));
    if (text == null) return;
    expect(text, contains('Unsere Kundennummer bei Ihnen: 060903'));
    expect(text, isNot(contains('999')));
    expect(otherText, isNot(contains('Unsere Kundennummer')));
  });
}
