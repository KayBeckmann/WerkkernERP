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
  test('Nord logo sits right-aligned directly above the company name', () async {
    final bytes = await buildOnlineDocumentPdf(document('draft'),
      liveCompany: const OnlineCompanyProfile(name: 'Synthetic Company', pdfLogoBase64: syntheticPng),
      layout: PdfLayout.nordLetterhead);
    final temp = await Directory.systemTemp.createTemp('synthetic-logo-position-');
    try {
      final file = File('${temp.path}/document.pdf');
      await file.writeAsBytes(bytes);
      final previewDir = Platform.environment['PDF_PREVIEW_DIR'];
      if (previewDir != null) {
        await Directory(previewDir).create(recursive: true);
        await File('$previewDir/nord-logo-right-aligned.pdf').writeAsBytes(bytes);
      }
      final result = await Process.run('pdftohtml', ['-xml', '-stdout', '-f', '1', '-l', '1', file.path]);
      expect(result.exitCode, 0, reason: '${result.stderr}');
      final xml = result.stdout as String;
      final image = xml.split('\n').firstWhere((line) => line.contains('<image '));
      final company = xml.split('\n').firstWhere((line) => line.contains('Synthetic Company'));
      int coord(String element, String name) => int.parse(RegExp('$name="([0-9]+)"').firstMatch(element)!.group(1)!);
      final imageRight = coord(image, 'left') + coord(image, 'width');
      final companyRight = coord(company, 'left') + coord(company, 'width');
      expect((imageRight - companyRight).abs(), lessThan(20), reason: 'Logo and company name must share the right edge');
      expect(coord(company, 'top') - coord(image, 'top') - coord(image, 'height'), greaterThanOrEqualTo(8),
        reason: 'Leave a visible gap between the logo and company name');
    } finally {
      await temp.delete(recursive: true);
    }
  });

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
