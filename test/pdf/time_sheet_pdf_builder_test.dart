import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:werkkernerp/pdf/time_sheet_pdf_builder.dart';

final _signature = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final signed = TimeSheetPdfData(
    id: 'synthetic-sheet',
    date: DateTime(2026, 11, 17),
    signedAt: DateTime(2026, 11, 17, 14, 30),
    signaturePng: Uint8List.fromList(_signature),
    companyName: 'Fiktive Elektrotechnik',
    reference: 'Projekt TEST-42',
    customerName: 'Musterkunde',
    signerName: 'Test Unterzeichner',
    entries: [TimeSheetPdfEntry(date: DateTime(2026, 11, 17), hours: 2.5, note: 'Montage Testanlage')],
  );

  test('signed PDF carries reference, entries, total, signer and disclaimer', () async {
    final bytes = await buildTimeSheetPdf(signed);
    final dir = await Directory.systemTemp.createTemp('time-sheet-pdf-test-');
    addTearDown(() => dir.delete(recursive: true));
    final path = '${dir.path}/sheet.pdf';
    await File(path).writeAsBytes(bytes);
    final result = await Process.run('pdftotext', ['-layout', path, '-']);
    expect(result.exitCode, 0, reason: '${result.stderr}');
    final text = result.stdout as String;
    for (final part in ['Stundenzettel', 'Fiktive Elektrotechnik', 'Projekt TEST-42', 'Musterkunde', 'Montage Testanlage', '2,5', 'Test Unterzeichner', 'qualifizierte elektronische Signatur']) {
      expect(text, contains(part));
    }
    final images = await Process.run('pdfimages', ['-list', path]);
    expect(images.exitCode, 0);
    expect((images.stdout as String).split('\n').length, greaterThan(2), reason: 'signature PNG must be embedded');
  });

  test('unsigned or missing signature PDF is rejected', () async {
    await expectLater(buildTimeSheetPdf(signed.copyWith(signedAt: null)), throwsStateError);
    await expectLater(buildTimeSheetPdf(signed.copyWith(signaturePng: Uint8List(0))), throwsStateError);
  });
}
