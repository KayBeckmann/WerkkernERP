import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:werkkernerp/data/database/tables.dart';
import 'package:werkkernerp/pdf/invoice_pdf_builder.dart';

Future<List<String>> pages(Uint8List bytes, String name) async {
  final directory = await Directory.systemTemp.createTemp('pdf-layout-');
  try {
    final file = File('${directory.path}/$name.pdf');
    await file.writeAsBytes(bytes);
    final result = await Process.run('pdftotext', ['-layout', file.path, '-']);
    expect(result.exitCode, 0, reason: '${result.stderr}');
    if (Platform.environment['PDF_PREVIEW_DIR'] case final String outputDir) {
      await File('$outputDir/$name.pdf').writeAsBytes(bytes);
    }
    return (result.stdout as String).split('\f').where((s) => s.trim().isNotEmpty).toList();
  } finally {
    await directory.delete(recursive: true);
  }
}

PdfDocumentData fixture({DocumentKind kind = DocumentKind.quote, int count = 2, String? footerText}) => PdfDocumentData(
      kind: kind,
      invoiceNumber: 'SYN-001',
      issueDate: DateTime(2026, 1, 2),
      serviceDate: DateTime(2026, 1, 1),
      companySnapshotName: 'Synthetische Elektrotechnik GmbH',
      companySnapshotAddress: 'Teststraße 10\n12345 Beispielstadt',
      companySnapshotTaxNumber: 'TEST-123',
      companySnapshotIban: 'DE00 0000 0000 0000 0000 00',
      customerSnapshotName: 'Beispielkunde',
      customerSnapshotAddress: 'Kundenweg 7\n54321 Musterstadt',
      isSmallBusinessExempt: true,
      footerText: footerText,
      lines: [
        for (var index = 0; index < count; index++)
          PdfLine(
            description: 'Leistung ${index + 1} ${'mit längerer Beschreibung und Umlauten äöü ' * 3}',
            quantity: '1',
            unitPriceCents: 12500,
            vatRatePercent: 0,
            groupLabel: index < count ~/ 2 ? 'Zuerst' : 'Danach',
          ),
      ],
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Nord letterhead puts recipient and title only on page one, repeats company and table headings', () async {
    final text = await pages(await renderDocumentPdf(fixture(count: 75), isPreview: false, layout: PdfLayout.nordLetterhead), 'quote-long');
    expect(text.length, greaterThan(1));
    expect(text.first, contains('Beispielkunde'));
    expect(text.first, contains('Angebot SYN-001'));
    for (final continuation in text.skip(1)) {
      expect(continuation, isNot(contains('Beispielkunde')));
      expect(continuation, isNot(contains('Angebot SYN-001')));
    }
    for (var i = 0; i < text.length; i++) {
      expect(text[i], contains('Synthetische Elektrotechnik GmbH'));
      if (text[i].contains('Leistung ')) expect(text[i], contains('Beschreibung'));
      expect(text[i], contains('Seite ${i + 1} von ${text.length}'));
      expect(text[i], isNot(contains('Material')));
      expect(text[i], isNot(contains('Lohn')));
      expect(text[i], contains('IBAN:'));
    }
    expect(text.join(' '), contains('Gemäß § 19'));
    expect(text.join(' '), isNot(contains('MwSt.')));
  });

  test('Nord letterhead preserves input chapter order rather than sorting labels', () async {
    final text = (await pages(await renderDocumentPdf(fixture(), isPreview: false, layout: PdfLayout.nordLetterhead), 'quote-short')).join(' ');
    expect(text.indexOf('Zuerst'), lessThan(text.indexOf('Danach')));
    expect(text, contains('Gruppensumme'));
  });

  test('Classic fallback retains its established alphabetical group order', () async {
    final text = (await pages(await renderDocumentPdf(fixture(), isPreview: false), 'classic-short')).join(' ');
    expect(text.indexOf('Danach'), lessThan(text.indexOf('Zuerst')));
  });

  test('Long custom footer text is preserved instead of silently truncated', () async {
    final text = (await pages(await renderDocumentPdf(
      fixture(footerText: '${'Zusatzinformation ' * 22}Schlussmarke'),
      isPreview: false, layout: PdfLayout.nordLetterhead), 'long-footer')).join(' ');
    expect(text, contains('Schlussmarke'));
  });

  test('Custom footer text clears the structured address vertically', () async {
    final bytes = await renderDocumentPdf(
      fixture(footerText: '${'Zusatzinformation ' * 22}Schlussmarke'),
      isPreview: false, layout: PdfLayout.nordLetterhead);
    final dir = await Directory.systemTemp.createTemp('footer-bbox-');
    try {
      final file = File('${dir.path}/footer.pdf');
      await file.writeAsBytes(bytes);
      final result = await Process.run('pdftotext', ['-bbox', file.path, '-']);
      expect(result.exitCode, 0);
      final xml = result.stdout as String;
      double wordY(String word, {bool last = false}) => double.parse((last ? RegExp(
        '<word[^>]*yMin="([0-9.]+)"[^>]*>$word</word>')
        .allMatches(xml).last : RegExp('<word[^>]*yMin="([0-9.]+)"[^>]*>$word</word>')
        .allMatches(xml).first).group(1)!);
      expect(wordY('Zusatzinformation') - wordY('Beispielstadt', last: true), greaterThan(18));
    } finally {
      await dir.delete(recursive: true);
    }
  });

  test('Nord delivery note never prints prices and keeps draft warning', () async {
    final text = (await pages(await renderDocumentPdf(
      fixture(kind: DocumentKind.deliveryNote, count: 3),
      isPreview: true, layout: PdfLayout.nordLetterhead), 'delivery-preview')).join(' ');
    expect(text, contains('ENTWURF'));
    expect(text, contains('Lieferschein'));
    expect(text, isNot(contains('Bruttopreis')));
    expect(text, isNot(contains('Gesamtbetrag')));
  });

  test('Nord invoice displays gross price but not VAT under §19', () async {
    final text = (await pages(await renderDocumentPdf(
      fixture(kind: DocumentKind.invoice, count: 24),
      isPreview: false, layout: PdfLayout.nordLetterhead), 'invoice-long')).join(' ');
    expect(text, contains('Rechnung SYN-001'));
    expect(text, contains('Bruttopreis'));
    expect(text, contains('Gesamtbetrag'));
    expect(text, isNot(contains('Netto 0 %')));
  });

}
