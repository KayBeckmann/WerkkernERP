import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../data/database/database.dart';
import '../data/database/tables.dart';
import '../domain/models/money.dart';
import '../domain/services/dunning_service.dart';

/// Eigenständig gestaltetes Mahnschreiben (C12, Kay-Feedback 2026-10-17:
/// "Mahngebühren und Mahnschreiben-PDF bitte umsetzen"). Bezieht sich
/// auf eine bereits finalisierte Rechnung — kein eigenständiges
/// Dokument mit eigenem Nummernkreis, kein [DocumentKind].
///
/// **Keine Rechtsprüfung** (wie überall in dieser App, siehe Roadmap
/// F1/F2/C12): Mahngebühr und Verzugszins kommen 1:1 aus Kays eigenen
/// Einstellungen ([DunningConfig]), diese Funktion behauptet nicht, dass
/// sie im konkreten Fall zulässig oder korrekt berechnet sind — nur dass
/// sie exakt den hinterlegten Werten entsprechen.
///
/// Wirft [StateError], wenn [invoice] nicht finalisiert ist oder kein
/// Fälligkeitsdatum trägt — ein Mahnschreiben ohne nachvollziehbare
/// Fälligkeit wäre kein sinnvolles Dokument (A3 Punkt 4: "PDF-Fehler
/// darf nicht als erfolgreich erstelltes PDF erscheinen").
Future<Uint8List> buildDunningLetterPdf({
  required Invoice invoice,
  required Company company,
  required DunningLevel level,
  required DunningConfig config,
  required Money invoiceGross,
}) async {
  if (invoice.status != InvoiceStatus.finalized || invoice.invoiceNumber == null) {
    throw StateError('Mahnschreiben kann nur für eine finalisierte Rechnung erzeugt werden.');
  }
  final dueDate = invoice.dueDate;
  if (dueDate == null || level == DunningLevel.none) {
    throw StateError('Mahnschreiben kann nur für eine überfällige Rechnung erzeugt werden.');
  }

  final now = DateTime.now();
  final overdueDays = now.difference(dueDate).inDays;
  final fee = config.feeFor(level);
  final interest = dunningInterestFor(
    principal: invoiceGross,
    overdueDays: overdueDays,
    ratePercent: config.interestRatePercent,
  );
  final totalDue = invoiceGross + fee + interest;

  final regularFont = pw.Font.ttf(await rootBundle.load('assets/fonts/DejaVuSans.ttf'));
  final boldFont = pw.Font.ttf(await rootBundle.load('assets/fonts/DejaVuSans-Bold.ttf'));

  final doc = pw.Document(theme: pw.ThemeData.withFont(base: regularFont, bold: boldFont));
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      footer: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          if (company.pdfFooterText != null) ...[
            pw.Divider(color: PdfColors.grey400),
            pw.Text(
              company.pdfFooterText!,
              textAlign: pw.TextAlign.center,
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
            ),
            pw.SizedBox(height: 4),
          ],
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              'Seite ${context.pageNumber} von ${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
            ),
          ),
        ],
      ),
      build: (context) => [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              invoice.companySnapshotName ?? '',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
            if (invoice.companySnapshotAddress != null) pw.Text(invoice.companySnapshotAddress!),
            pw.SizedBox(height: 16),
            pw.Text(invoice.customerSnapshotName ?? ''),
            if (invoice.customerSnapshotAddress != null) pw.Text(invoice.customerSnapshotAddress!),
            pw.SizedBox(height: 24),
            pw.Text(
              dunningLetterTitle(level),
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
            pw.Text('Datum: ${_formatDate(now)}'),
            pw.SizedBox(height: 16),
          ],
        ),
        if (company.pdfIntroTextDunning != null) ...[
          pw.Text(company.pdfIntroTextDunning!, style: const pw.TextStyle(fontSize: 10)),
          pw.SizedBox(height: 12),
        ],
        pw.Text(
          'Die Rechnung ${invoice.invoiceNumber} vom ${_formatDate(invoice.issueDate)} über '
          '$invoiceGross war fällig am ${_formatDate(dueDate)}. Trotz Fälligkeit liegt uns '
          'bisher kein Zahlungseingang vor.',
          style: const pw.TextStyle(fontSize: 10),
        ),
        pw.SizedBox(height: 16),
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.SizedBox(
            width: 260,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                _amountRow('Offener Rechnungsbetrag', invoiceGross),
                if (fee.cents > 0) _amountRow('Mahngebühr', fee),
                if (interest.cents > 0)
                  _amountRow('Verzugszinsen ($overdueDays Tage, ${config.interestRatePercent} %)', interest),
                pw.Divider(),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Zu zahlender Betrag', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.Text(totalDue.toString(), style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (company.pdfClosingTextDunning != null) ...[
          pw.SizedBox(height: 16),
          pw.Text(
            company.pdfClosingTextDunning!,
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          ),
        ],
        pw.SizedBox(height: 16),
        pw.Text(
          'Mahngebühr und Verzugszins entsprechen den in den Einstellungen hinterlegten eigenen '
          'Angaben — keine Rechtsprüfung durch diese Software, ob sie im Einzelfall zulässig oder '
          'korrekt sind.',
          style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey500),
        ),
      ],
    ),
  );

  return doc.save();
}

pw.Widget _amountRow(String label, Money amount) => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [pw.Text(label), pw.Text(amount.toString())],
      ),
    );

String _formatDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
