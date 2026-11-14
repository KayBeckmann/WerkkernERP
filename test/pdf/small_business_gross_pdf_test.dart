import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:werkkernerp/data/database/tables.dart' show DocumentKind;
import 'package:werkkernerp/pdf/invoice_pdf_builder.dart';

Future<String> renderedText({required bool smallBusiness}) async {
  final data = PdfDocumentData(
    kind: DocumentKind.quote,
    invoiceNumber: 'A-TEST',
    issueDate: DateTime.utc(2026, 11, 14),
    serviceDate: DateTime.utc(2026, 11, 14),
    companySnapshotName: 'Testbetrieb',
    customerSnapshotName: 'Testkunde',
    isSmallBusinessExempt: smallBusiness,
    lines: [
      PdfLine(
        description: 'Montage',
        quantity: '2',
        unitPriceCents: 6500,
        vatRatePercent: smallBusiness ? 0 : 19,
      ),
    ],
  );
  final bytes = await renderDocumentPdf(data, isPreview: false);
  final dir = await Directory.systemTemp.createTemp('werkkern-pdf-regression-');
  try {
    final file = File('${dir.path}/quote.pdf');
    await file.writeAsBytes(bytes);
    final result = await Process.run('pdftotext', ['-layout', file.path, '-']);
    expect(result.exitCode, 0, reason: '${result.stderr}');
    return result.stdout as String;
  } finally {
    await dir.delete(recursive: true);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'Kleinunternehmerangebot zeigt Bruttopreise ohne separaten Steuerausweis',
    () async {
      final text = await renderedText(smallBusiness: true);
      expect(text, contains('Bruttopreis'));
      expect(text, contains('Gesamtbetrag'));
      expect(text, contains('130,00'));
      expect(text, contains('§ 19 Abs. 1 UStG'));
      expect(text, isNot(contains('MwSt. 0 %')));
      expect(text, isNot(contains('Netto 0 %')));
      expect(text, isNot(contains('0 %')));
    },
  );

  test('Normalbesteuerung behält Steueraufschlüsselung', () async {
    final text = await renderedText(smallBusiness: false);
    expect(text, contains('MwSt. 19 %'));
    expect(text, contains('Netto 19 %'));
    expect(text, contains('154,70'));
  });

  test('Kleinunternehmer-PDF verweigert Positionen mit Umsatzsteuer', () async {
    final data = PdfDocumentData(
      kind: DocumentKind.quote,
      issueDate: DateTime.utc(2026, 11, 14),
      serviceDate: DateTime.utc(2026, 11, 14),
      isSmallBusinessExempt: true,
      lines: const [
        PdfLine(
          description: 'Montage',
          quantity: '1',
          unitPriceCents: 10000,
          vatRatePercent: 19,
        ),
      ],
    );
    await expectLater(
      renderDocumentPdf(data, isPreview: true),
      throwsA(isA<StateError>()),
    );
  });
}
