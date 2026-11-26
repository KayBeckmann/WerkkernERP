import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:werkkern_core/werkkern_core.dart' show decodeFooterColumns;

import '../data/database/database.dart';
import '../data/database/tables.dart';
import '../domain/models/money.dart';
import '../domain/services/dunning_service.dart';
import 'invoice_pdf_builder.dart' show PdfDocumentData, buildConfiguredFooter;

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
}) {
  if (invoice.status != InvoiceStatus.finalized || invoice.invoiceNumber == null) {
    throw StateError('Mahnschreiben kann nur für eine finalisierte Rechnung erzeugt werden.');
  }
  final dueDate = invoice.dueDate;
  if (dueDate == null || level == DunningLevel.none) {
    throw StateError('Mahnschreiben kann nur für eine überfällige Rechnung erzeugt werden.');
  }
  final now = DateTime.now();
  final overdueDays = now.difference(dueDate).inDays;
  return buildDunningLetterPdfFromData(DunningLetterPdfData(
    level: level,
    date: now,
    companyName: invoice.companySnapshotName ?? '',
    companyAddress: invoice.companySnapshotAddress,
    customerName: invoice.customerSnapshotName ?? '',
    customerAddress: invoice.customerSnapshotAddress,
    invoiceNumber: invoice.invoiceNumber!,
    invoiceDate: invoice.issueDate,
    dueDate: dueDate,
    invoiceGross: invoiceGross,
    fee: config.feeFor(level),
    interest: dunningInterestFor(principal: invoiceGross, overdueDays: overdueDays, ratePercent: config.interestRatePercent),
    overdueDays: overdueDays,
    interestRatePercent: config.interestRatePercent,
    introText: company.pdfIntroTextDunning,
    closingText: company.pdfClosingTextDunning,
    // Wie online: Fußzeilentext der Rechnung, sonst der aktuelle.
    footerText: invoice.pdfFooterTextSnapshot ?? company.pdfFooterText,
    // Parität offline/online (26.11.2026): Logo und dreispaltige Fußzeile
    // aus den aktuellen Firmendaten — das Mahnschreiben entsteht jetzt.
    pdfLogoBase64: company.pdfLogoBase64,
    footerColumns: decodeFooterColumns(company.pdfFooterColumns),
    companyTaxNumber: invoice.companySnapshotTaxNumber,
    companyVatId: invoice.companySnapshotVatId,
    companyIban: invoice.companySnapshotIban,
    companyBic: invoice.companySnapshotBic,
  ));
}

/// Neutrales Datenmodell des Mahnschreibens — Offline-App und Online-
/// Modus erzeugen damit dasselbe Layout; Beträge sind bereits berechnet.
class DunningLetterPdfData {
  const DunningLetterPdfData({
    required this.level,
    required this.date,
    required this.companyName,
    this.companyAddress,
    required this.customerName,
    this.customerAddress,
    required this.invoiceNumber,
    required this.invoiceDate,
    required this.dueDate,
    required this.invoiceGross,
    required this.fee,
    required this.interest,
    required this.overdueDays,
    required this.interestRatePercent,
    this.introText,
    this.closingText,
    this.footerText,
    this.pdfLogoBase64,
    this.footerColumns,
    this.companyTaxNumber,
    this.companyVatId,
    this.companyIban,
    this.companyBic,
  });
  final DunningLevel level;
  final DateTime date;
  final String companyName;
  final String? companyAddress;
  final String customerName;
  final String? customerAddress;
  final String invoiceNumber;
  final DateTime invoiceDate;
  final DateTime dueDate;
  final Money invoiceGross;
  final Money fee;
  final Money interest;
  final int overdueDays;
  final double interestRatePercent;
  final String? introText;
  final String? closingText;
  final String? footerText;

  /// Kopflogo und dreispaltige Fußzeile wie bei den übrigen Belegen;
  /// Steuer-/Bankdaten nur für die Platzhalter der Fußzeile.
  final String? pdfLogoBase64;
  final Map<String, String?>? footerColumns;
  final String? companyTaxNumber;
  final String? companyVatId;
  final String? companyIban;
  final String? companyBic;

  Money get totalDue => invoiceGross + fee + interest;
}

Future<Uint8List> buildDunningLetterPdfFromData(DunningLetterPdfData data) async {
  final invoiceGross = data.invoiceGross;
  final fee = data.fee;
  final interest = data.interest;
  final totalDue = data.totalDue;
  final overdueDays = data.overdueDays;
  final now = data.date;
  final dueDate = data.dueDate;

  final regularFont = pw.Font.ttf(await rootBundle.load('assets/fonts/DejaVuSans.ttf'));
  final boldFont = pw.Font.ttf(await rootBundle.load('assets/fonts/DejaVuSans-Bold.ttf'));

  final logo = data.pdfLogoBase64 == null ? null : pw.MemoryImage(base64Decode(data.pdfLogoBase64!));
  final footerData = PdfDocumentData(
    kind: DocumentKind.invoice,
    invoiceNumber: data.invoiceNumber,
    issueDate: data.date,
    serviceDate: data.date,
    companySnapshotName: data.companyName,
    companySnapshotAddress: data.companyAddress,
    companySnapshotTaxNumber: data.companyTaxNumber,
    companySnapshotVatId: data.companyVatId,
    companySnapshotIban: data.companyIban,
    companySnapshotBic: data.companyBic,
    customerSnapshotName: data.customerName,
    customerSnapshotAddress: data.customerAddress,
    footerColumns: data.footerColumns,
    lines: const [],
  );

  final doc = pw.Document(theme: pw.ThemeData.withFont(base: regularFont, bold: boldFont));
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      footer: (context) => data.footerColumns != null
          ? buildConfiguredFooter(footerData, context.pageNumber, context.pagesCount)
          : pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          if (data.footerText != null) ...[
            pw.Divider(color: PdfColors.grey400),
            pw.Text(
              data.footerText!,
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
            if (logo != null) ...[
              pw.Container(height: 55, width: 180, alignment: pw.Alignment.centerLeft,
                  child: pw.Image(logo, fit: pw.BoxFit.contain)),
              pw.SizedBox(height: 8),
            ],
            pw.Text(
              data.companyName,
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
            if (data.companyAddress != null) pw.Text(data.companyAddress!),
            pw.SizedBox(height: 16),
            pw.Text(data.customerName),
            if (data.customerAddress != null) pw.Text(data.customerAddress!),
            pw.SizedBox(height: 24),
            pw.Text(
              dunningLetterTitle(data.level),
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
            pw.Text('Datum: ${_formatDate(now)}'),
            pw.SizedBox(height: 16),
          ],
        ),
        if (data.introText != null) ...[
          pw.Text(data.introText!, style: const pw.TextStyle(fontSize: 10)),
          pw.SizedBox(height: 12),
        ],
        pw.Text(
          'Die Rechnung ${data.invoiceNumber} vom ${_formatDate(data.invoiceDate)} über '
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
                  _amountRow('Verzugszinsen ($overdueDays Tage, ${data.interestRatePercent.toString().replaceAll('.', ',')} %)', interest),
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
        if (data.closingText != null) ...[
          pw.SizedBox(height: 16),
          pw.Text(
            data.closingText!,
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
