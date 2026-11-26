import 'dart:io';
import 'dart:typed_data';

import 'package:decimal/decimal.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:werkkernerp/data/database/database.dart';
import 'package:werkkernerp/data/database/tables.dart';
import 'package:werkkernerp/data/repositories/company_repository.dart';
import 'package:werkkernerp/data/repositories/customer_repository.dart';
import 'package:werkkernerp/domain/services/draft_preview.dart';
import 'package:werkkernerp/pdf/invoice_pdf_builder.dart';

Future<String> _text(Uint8List pdf) async {
  final dir = await Directory.systemTemp.createTemp('werkkern-draft-preview-');
  try {
    final path = '${dir.path}/preview.pdf';
    await File(path).writeAsBytes(pdf);
    return (await Process.run('pdftotext', [path, '-'])).stdout as String;
  } finally {
    await dir.delete(recursive: true);
  }
}

/// Parität offline/online (Nachtrag 26.11.2026): Die Offline-Vorschau
/// zeigt wie online Zahlungsbedingung/Skonto und Bindefrist des Entwurfs.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Vorschau enthält Zahlungsbedingung, Skonto und Bindefrist des Entwurfs', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final company = await CompanyRepository(db).create(name: 'Synthetik GmbH');
    final customer = await CustomerRepository(db).create(companyId: company.id, name: 'Kundin');
    final items = [
      InvoiceItem(id: 'i1', invoiceId: 'preview', kind: InvoiceItemKind.text, description: 'Leistung',
          quantity: Decimal.one.toString(), unitPriceCents: 10000, vatRatePercent: 19, discountPercent: 0, sortOrder: 0),
    ];
    final now = DateTime(2026, 11, 26);

    final invoice = draftPreviewInvoice(
      id: 'preview', company: company, customer: customer, kind: DocumentKind.invoice,
      issueDate: now, serviceDate: now, now: now,
      terms: (termId: null, label: '14 Tage', netDays: 14, skontoPercent: 2, skontoDays: 7),
    );
    final invoiceText = await _text(await buildDraftPreviewPdf(invoice: invoice, items: items, company: company));
    expect(invoiceText, contains('ENTWURF'));
    expect(invoiceText, contains('Zahlbar innerhalb von 14 Tagen'));
    expect(invoiceText, contains('Skonto'));

    final quote = draftPreviewInvoice(
      id: 'preview', company: company, customer: customer, kind: DocumentKind.quote,
      issueDate: now, serviceDate: now, now: now, quoteValidityDays: 30,
    );
    final quoteText = await _text(await buildDraftPreviewPdf(invoice: quote, items: items, company: company));
    expect(quoteText, contains('30 Tage'));
  });
}
