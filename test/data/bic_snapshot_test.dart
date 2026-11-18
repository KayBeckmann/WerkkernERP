import 'dart:io';

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:werkkernerp/data/database/database.dart';
import 'package:werkkernerp/data/database/tables.dart';
import 'package:werkkernerp/data/repositories/company_repository.dart';
import 'package:werkkernerp/data/repositories/customer_repository.dart';
import 'package:werkkernerp/data/repositories/invoice_repository.dart';
import 'package:werkkernerp/data/repositories/number_sequence_repository.dart';
import 'package:werkkernerp/pdf/invoice_pdf_builder.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('offline finalization stores BIC and later profile edits cannot change PDF token', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    try {
      final companies = CompanyRepository(db);
      final initial = await companies.create(name: 'Firma', address: 'Straße 1');
      await companies.update(initial.copyWith(bic: const Value('OLDBIC'), pdfFooterText: const Value('BIC: {{bic}}')));
      final old = (await companies.findById(initial.id))!;
      final customer = await CustomerRepository(db).create(companyId: old.id, name: 'Kunde', address: 'Straße 2');
      final invoices = InvoiceRepository(db, NumberSequenceRepository(db));
      final draft = await invoices.createDraft(companyId: old.id, customerId: customer.id,
          issueDate: DateTime(2026, 11, 17), serviceDate: DateTime(2026, 11, 17), items: [
            InvoiceItemInput(kind: InvoiceItemKind.text, description: 'Leistung', quantity: Decimal.one,
                unitPriceCents: 10000, vatRatePercent: 19),
          ]);
      final frozen = (await invoices.finalize(companyId: old.id, id: draft.id))!;
      expect(frozen.companySnapshotBic, 'OLDBIC');
      await companies.update(old.copyWith(bic: const Value('NEWBIC')));
      final current = (await companies.findById(old.id))!;
      final reloaded = (await invoices.findById(companyId: old.id, id: frozen.id))!;
      expect(reloaded.companySnapshotBic, 'OLDBIC');
      final pdf = await buildInvoicePdf(invoice: reloaded,
          items: await invoices.itemsFor(reloaded.id), company: current);
      expect(pdf.length, greaterThan(100));
      final dir = await Directory.systemTemp.createTemp('bic-offline-');
      try {
        final path = '${dir.path}/invoice.pdf';
        await File(path).writeAsBytes(pdf);
        final extracted = await Process.run('pdftotext', [path, '-']);
        expect(extracted.exitCode, 0);
        expect(extracted.stdout, contains('BIC: OLDBIC'));
        expect(extracted.stdout, isNot(contains('NEWBIC')));
      } finally {
        await dir.delete(recursive: true);
      }
    } finally {
      await db.close();
    }
  });
}
