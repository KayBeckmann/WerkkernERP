import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../ui/widgets/signature_pad.dart' show signatureDisclaimer;

/// Transport-neutral snapshot for a signed time sheet. Callers must persist
/// the returned bytes before exposing a send action; never rebuild for mail.
class TimeSheetPdfData {
  const TimeSheetPdfData({
    required this.id,
    required this.date,
    required this.signedAt,
    required this.signaturePng,
    required this.companyName,
    required this.reference,
    required this.entries,
    this.customerName,
    this.signerName,
    this.supersedesId,
  });

  final String id;
  final DateTime date;
  final DateTime? signedAt;
  final Uint8List? signaturePng;
  final String companyName;
  final String reference;
  final String? customerName;
  final String? signerName;
  final String? supersedesId;
  final List<TimeSheetPdfEntry> entries;

  TimeSheetPdfData copyWith({DateTime? signedAt, Uint8List? signaturePng}) => TimeSheetPdfData(
    id: id,
    date: date,
    signedAt: signedAt,
    signaturePng: signaturePng,
    companyName: companyName,
    reference: reference,
    customerName: customerName,
    signerName: signerName,
    supersedesId: supersedesId,
    entries: entries,
  );
}

class TimeSheetPdfEntry {
  const TimeSheetPdfEntry({required this.date, required this.hours, this.note});
  final DateTime date;
  final double hours;
  final String? note;
}

String _date(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}.${value.month.toString().padLeft(2, '0')}.${value.year}';

Future<Uint8List> buildTimeSheetPdf(TimeSheetPdfData data) async {
  if (data.signedAt == null || data.signaturePng == null || data.signaturePng!.isEmpty) {
    throw StateError('PDF nur für unterschriebene Stundenzettel mit Unterschrift.');
  }
  if (data.entries.isEmpty) throw StateError('Unterschriebener Stundenzettel ohne Buchungen.');
  final regular = pw.Font.ttf(await rootBundle.load('assets/fonts/DejaVuSans.ttf'));
  final bold = pw.Font.ttf(await rootBundle.load('assets/fonts/DejaVuSans-Bold.ttf'));
  final document = pw.Document(theme: pw.ThemeData.withFont(base: regular, bold: bold));
  final image = pw.MemoryImage(data.signaturePng!);
  document.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.all(40),
    build: (_) => [
      pw.Text(data.companyName, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 22),
      pw.Text('Stundenzettel', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 12),
      pw.Text('Datum: ${_date(data.date)}'),
      pw.Text('Bezug: ${data.reference}'),
      if (data.customerName != null) pw.Text('Kunde: ${data.customerName}'),
      if (data.supersedesId != null) pw.Text('Korrektur zu: ${data.supersedesId}'),
      pw.SizedBox(height: 16),
      pw.TableHelper.fromTextArray(
        headers: ['Datum', 'Tätigkeit', 'Stunden'],
        data: [
          for (final entry in data.entries)
            [_date(entry.date), entry.note ?? '', entry.hours.toStringAsFixed(1).replaceAll('.', ',')],
        ],
        headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
        cellStyle: const pw.TextStyle(fontSize: 9),
        cellAlignment: pw.Alignment.centerLeft,
      ),
      pw.SizedBox(height: 8),
      pw.Text('Gesamt: ${data.entries.fold<double>(0, (sum, e) => sum + e.hours).toStringAsFixed(1).replaceAll('.', ',')} Std.',
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 20),
      pw.Text('Unterschrieben am ${_date(data.signedAt!)}${data.signerName == null ? '' : ' von ${data.signerName}'}'),
      pw.SizedBox(height: 8),
      pw.Image(image, width: 190, height: 75, fit: pw.BoxFit.contain),
      pw.SizedBox(height: 6),
      pw.Text(signatureDisclaimer, style: const pw.TextStyle(fontSize: 8)),
    ],
  ));
  return document.save();
}
