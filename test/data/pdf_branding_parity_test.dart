import 'dart:io';
import 'dart:typed_data';

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:werkkern_core/werkkern_core.dart' show encodeFooterColumns;
import 'package:werkkernerp/data/database/database.dart';
import 'package:werkkernerp/data/database/tables.dart';
import 'package:werkkernerp/data/migration/migration_package_builder.dart';
import 'package:werkkernerp/data/repositories/company_repository.dart';
import 'package:werkkernerp/data/repositories/customer_repository.dart';
import 'package:werkkernerp/data/repositories/invoice_repository.dart';
import 'package:werkkernerp/data/repositories/number_sequence_repository.dart';
import 'package:werkkernerp/data/repositories/purchase_order_repository.dart';
import 'package:werkkernerp/data/repositories/supplier_repository.dart';
import 'package:werkkernerp/domain/models/money.dart';
import 'package:werkkernerp/domain/services/dunning_service.dart';
import 'package:werkkernerp/pdf/dunning_letter_pdf_builder.dart';
import 'package:werkkernerp/pdf/invoice_pdf_builder.dart';
import 'package:werkkernerp/pdf/purchase_order_pdf_builder.dart';

/// Parität offline/online (Roadmap-Nachtrag 26.11.2026): Logo, Layout und
/// dreispaltige Fußzeile gibt es jetzt auch in der rein lokalen Firma —
/// Entwurf live, finalisierter Beleg aus dem Schnappschuss.
const _png = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGP4z8DwHwAFAAH/iZk9HQAAAABJRU5ErkJggg==';

Future<({String text, int images})> _inspect(Uint8List pdf) async {
  final dir = await Directory.systemTemp.createTemp('werkkern-branding-');
  try {
    final path = '${dir.path}/doc.pdf';
    await File(path).writeAsBytes(pdf);
    final text = await Process.run('pdftotext', ['-layout', path, '-']);
    final images = await Process.run('pdfimages', ['-list', path]);
    expect(text.exitCode, 0);
    expect(images.exitCode, 0);
    // Nur Bilder zählen, keine Alpha-Masken (`smask`).
    final count = (images.stdout as String)
        .split('\n')
        .where((line) => RegExp(r'^\s*\d+\s+\d+\s+image\s').hasMatch(line))
        .length;
    return (text: text.stdout as String, images: count);
  } finally {
    await dir.delete(recursive: true);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late CompanyRepository companies;
  late InvoiceRepository invoices;
  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    companies = CompanyRepository(db);
    invoices = InvoiceRepository(db, NumberSequenceRepository(db));
  });
  tearDown(() => db.close());

  Future<(Company, Invoice)> draft() async {
    final created = await companies.create(name: 'Synthetik GmbH', address: 'Teststraße 1\n12345 Musterstadt');
    await companies.update(created.copyWith(
      iban: const Value('DE00 1234'),
      taxNumber: const Value('11/222/33333'),
      pdfLayout: 'nordLetterhead',
      pdfLogoBase64: const Value(_png),
      pdfFooterColumns: Value(encodeFooterColumns({
        'left': 'Links {{companyName}}',
        'center': 'Bank {{iban}}',
        'right': 'StNr {{taxNumber}}',
      })),
    ));
    final company = (await companies.findById(created.id))!;
    final customer = await CustomerRepository(db).create(companyId: company.id, name: 'Kundin', address: 'Weg 2');
    final invoice = await invoices.createDraft(
      companyId: company.id,
      customerId: customer.id,
      issueDate: DateTime(2026, 11, 26),
      serviceDate: DateTime(2026, 11, 26),
      items: [
        InvoiceItemInput(kind: InvoiceItemKind.text, description: 'Leistung', quantity: Decimal.one,
            unitPriceCents: 10000, vatRatePercent: 19),
      ],
    );
    return (company, invoice);
  }

  test('Entwurfsvorschau nutzt Logo, Layout und Fußzeilenspalten der lokalen Firma', () async {
    final (company, invoice) = await draft();
    final preview = await _inspect(await buildDraftPreviewPdf(
      invoice: invoice.copyWith(companySnapshotName: Value(company.name), companySnapshotIban: Value(company.iban),
          companySnapshotTaxNumber: Value(company.taxNumber)),
      items: await invoices.itemsFor(invoice.id),
      company: company,
    ));
    expect(preview.text, contains('Links Synthetik GmbH'));
    expect(preview.text, contains('Bank DE00 1234'));
    expect(preview.text, contains('StNr 11/222/33333'));
    expect(preview.images, 1);
  });

  test('finalisierter Beleg friert Layout, Logo und Fußzeile ein', () async {
    final (company, invoice) = await draft();
    final frozen = (await invoices.finalize(companyId: company.id, id: invoice.id))!;
    expect(frozen.pdfLayoutSnapshot, 'nordLetterhead');
    expect(frozen.pdfLogoSnapshot, _png);
    expect(frozen.pdfFooterColumnsSnapshot, company.pdfFooterColumns);

    // Spätere Änderungen an der Firma dürfen den Beleg nicht verändern.
    await companies.update(company.copyWith(
      pdfLayout: 'classic',
      pdfLogoBase64: const Value(null),
      pdfFooterColumns: Value(encodeFooterColumns({'left': 'NEU', 'center': null, 'right': null})),
    ));
    final current = (await companies.findById(company.id))!;
    final pdf = await _inspect(await buildInvoicePdf(
      invoice: (await invoices.findById(companyId: company.id, id: frozen.id))!,
      items: await invoices.itemsFor(frozen.id),
      company: current,
    ));
    expect(pdf.text, contains('Links Synthetik GmbH'));
    expect(pdf.text, isNot(contains('NEU')));
    expect(pdf.images, 1);
  });

  test('Altbeleg ohne Schnappschuss bleibt klassisch ohne Logo', () async {
    final (company, invoice) = await draft();
    final frozen = (await invoices.finalize(companyId: company.id, id: invoice.id))!;
    // Zustand vor Schema 46: keine Schnappschüsse.
    await (db.update(db.invoices)..where((i) => i.id.equals(frozen.id))).write(const InvoicesCompanion(
      pdfLayoutSnapshot: Value(null),
      pdfLogoSnapshot: Value(null),
      pdfFooterColumnsSnapshot: Value(null),
    ));
    final legacy = (await invoices.findById(companyId: company.id, id: frozen.id))!;
    final pdf = await _inspect(await buildInvoicePdf(
      invoice: legacy,
      items: await invoices.itemsFor(frozen.id),
      company: company,
    ));
    expect(pdf.images, 0);
    expect(pdf.text, isNot(contains('Links Synthetik GmbH')));
  });

  test('Lieferantenbestellung offline mit Logo und Fußzeilenspalten wie online', () async {
    final (company, _) = await draft();
    final supplier = await SupplierRepository(db).create(companyId: company.id, name: 'Lieferant');
    final orders = PurchaseOrderRepository(db, NumberSequenceRepository(db));
    final order = await orders.createDraft(companyId: company.id, supplierId: supplier.id, issueDate: DateTime(2026, 11, 26),
        items: [const PurchaseOrderItemInput(description: 'Kabel', quantity: 2)]);
    final finalized = (await orders.finalize(companyId: company.id, id: order.id))!;
    final pdf = await _inspect(await buildPurchaseOrderPdf(
      order: finalized,
      items: await orders.itemsFor(finalized.id),
      company: company,
    ));
    expect(pdf.text, contains('Links Synthetik GmbH'));
    expect(pdf.images, 1);
  });

  test('Mahnschreiben mit Logo und Fußzeilenspalten (offline wie online)', () async {
    final (company, invoice) = await draft();
    final frozen = (await invoices.finalize(companyId: company.id, id: invoice.id))!;
    final pdf = await _inspect(await buildDunningLetterPdf(
      invoice: frozen.copyWith(dueDate: Value(DateTime.now().subtract(const Duration(days: 20)))),
      company: company,
      level: DunningLevel.overdue,
      config: const DunningConfig(
        reminder2AfterDays: 14,
        reminder3AfterDays: 28,
        feeLevel1: Money.fromCents(0),
        feeLevel2: Money.fromCents(0),
        feeLevel3: Money.fromCents(0),
        interestRatePercent: 0,
      ),
      invoiceGross: Money.fromCents(11900),
    ));
    expect(pdf.text, contains('Links Synthetik GmbH'));
    expect(pdf.text, contains('StNr 11/222/33333'));
    expect(pdf.images, 1);
  });

  test('Umzugspaket überträgt Layout, Logo und Fußzeilenspalten samt Schnappschuss', () async {
    final (company, invoice) = await draft();
    await invoices.finalize(companyId: company.id, id: invoice.id);
    final package = await MigrationPackageBuilder(db).build(company.id);
    final profile = package['company'] as Map;
    expect(profile['pdfLayout'], 'nordLetterhead');
    expect(profile['pdfLogoBase64'], _png);
    expect(profile['footerColumns'], {'left': 'Links {{companyName}}', 'center': 'Bank {{iban}}', 'right': 'StNr {{taxNumber}}'});
    final document = (package['documents'] as List).single as Map;
    expect(document['pdfLayoutSnapshot'], 'nordLetterhead');
    expect(document['pdfLogoSnapshot'], _png);
    expect((document['footerColumnsSnapshot'] as Map)['left'], 'Links {{companyName}}');
  });

  test('Schema 45 migriert auf 46 ohne Datenverlust', () async {
    final dir = await Directory.systemTemp.createTemp('werkkern-branding-migration-');
    addTearDown(() => dir.delete(recursive: true));
    final file = File('${dir.path}/test.sqlite');
    final before = AppDatabase.forTesting(NativeDatabase(file));
    final company = await CompanyRepository(before).create(name: 'Bestandsfirma');
    for (final column in ['pdf_layout', 'pdf_logo_base64', 'pdf_footer_columns']) {
      await before.customStatement('ALTER TABLE companies DROP COLUMN $column');
    }
    for (final column in ['pdf_layout_snapshot', 'pdf_logo_snapshot', 'pdf_footer_columns_snapshot']) {
      await before.customStatement('ALTER TABLE invoices DROP COLUMN $column');
    }
    await before.customStatement('PRAGMA user_version = 45');
    await before.close();
    final after = AppDatabase.forTesting(NativeDatabase(file));
    addTearDown(after.close);
    final migrated = (await after.select(after.companies).get()).single;
    expect(migrated.id, company.id);
    expect(migrated.pdfLayout, 'classic');
    expect(migrated.pdfLogoBase64, isNull);
    expect(migrated.pdfFooterColumns, isNull);
  });
}
