import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:werkkern_client/werkkern_client.dart';
import 'package:werkkernerp/pdf/invoice_pdf_builder.dart' show PdfLayout;
import 'package:werkkernerp/pdf/online_document_pdf.dart';

const syntheticPng = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGP4z8DwHwAFAAH/iZk9HQAAAABJRU5ErkJggg==';

OnlineDocument document(String status, {String? snapshot}) => OnlineDocument.fromJson({
  'id': 'synthetic-doc', 'customerId': 'synthetic-customer', 'kind': 'quote',
  'status': status, 'number': status == 'draft' ? null : 'SYN-1',
  'issueDate': '2026-01-02', 'serviceDate': '2026-01-02', 'version': 1,
  'pdfLogoSnapshot': snapshot,
  'companySnapshot': {'name': 'Synthetic Company'},
  'items': [{'kind': 'text', 'description': 'Synthetic service', 'quantity': '1', 'unitPriceCents': 100, 'vatRatePercent': 0}],
});

Future<int> imageCount(OnlineDocument doc, {OnlineCompanyProfile? live, PdfLayout layout = PdfLayout.classic}) async {
  final bytes = await buildOnlineDocumentPdf(doc, liveCompany: live, layout: layout);
  final temp = await Directory.systemTemp.createTemp('synthetic-logo-pdf-');
  try {
    final file = File('${temp.path}/document.pdf');
    await file.writeAsBytes(bytes);
    final result = await Process.run('pdfimages', ['-list', file.path]);
    expect(result.exitCode, 0, reason: '${result.stderr}');
    return (result.stdout as String).split('\n').where((line) => RegExp(r'^\s*\d+\s+\d+\s+image\s').hasMatch(line)).length;
  } finally {
    await temp.delete(recursive: true);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('PDF has header image only when selected; finalized uses immutable snapshot', () async {
    const live = OnlineCompanyProfile(name: 'Synthetic Company', pdfLogoBase64: syntheticPng);
    expect(onlineDocumentPdfData(document('draft'), liveCompany: live).pdfLogoBase64, syntheticPng);
    expect(await imageCount(document('draft'), live: live), greaterThan(0));
    expect(await imageCount(document('finalized')), 0);
    expect(onlineDocumentPdfData(document('finalized', snapshot: syntheticPng), liveCompany: const OnlineCompanyProfile()).pdfLogoBase64, syntheticPng);
    expect(await imageCount(document('finalized', snapshot: syntheticPng), live: const OnlineCompanyProfile()), greaterThan(0));
    expect(await imageCount(document('finalized', snapshot: syntheticPng), layout: PdfLayout.nordLetterhead), greaterThan(0));
  });
}
