import 'dart:typed_data';

import 'package:decimal/decimal.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../data/database/database.dart';
import '../data/database/tables.dart';
import '../domain/models/money.dart';

/// Eigenständig gestaltetes Bestellungs-PDF (C5.2 Bestellwesen, Nachtrag
/// 2026-10-19) — bewusst einfacher als `invoice_pdf_builder.dart`: eine
/// Bestellung an einen Lieferanten braucht keine Positionsgruppen, keine
/// MwSt.-Aufschlüsselung (der Einkaufspreis ist hier ein reiner
/// Netto-Richtwert, keine umsatzsteuerlich relevante Angabe) und keinen
/// Vorschau-/Entwurfsmodus mit Wasserzeichen — ein Bestellungsentwurf
/// wird nie als PDF geteilt, nur die finalisierte Fassung (konsistent
/// mit `buildInvoicePdf`: Wirft [StateError], wenn [order] nicht
/// finalisiert ist).
Future<Uint8List> buildPurchaseOrderPdf({
  required PurchaseOrder order,
  required List<PurchaseOrderItem> items,
  required Company company,
}) {
  if (order.status == PurchaseOrderStatus.draft || order.orderNumber == null) {
    throw StateError('PDF kann nur für eine finalisierte Bestellung erzeugt werden.');
  }
  return buildPurchaseOrderPdfFromData(PurchaseOrderPdfData(
    number: order.orderNumber!,
    issueDate: order.issueDate,
    notes: order.notes,
    supplierName: order.supplierSnapshotName ?? '',
    supplierAddress: order.supplierSnapshotAddress,
    companyName: company.name,
    companyAddress: company.address,
    companyEmail: company.email,
    companyPhone: company.phone,
    items: [
      for (final i in items)
        (description: i.description, quantity: Decimal.parse(i.quantity.toString()), purchasePriceCents: i.purchasePriceCents),
    ],
  ));
}

/// Neutrales Datenmodell des Bestellungs-PDFs — Offline-App und
/// Online-Modus erzeugen damit dasselbe Layout (wie `PdfDocumentData`).
class PurchaseOrderPdfData {
  const PurchaseOrderPdfData({
    required this.number,
    required this.issueDate,
    this.notes,
    required this.supplierName,
    this.supplierAddress,
    required this.companyName,
    this.companyAddress,
    this.companyEmail,
    this.companyPhone,
    required this.items,
  });
  final String number;
  final DateTime issueDate;
  final String? notes;
  final String supplierName;
  final String? supplierAddress;
  final String companyName;
  final String? companyAddress;
  final String? companyEmail;
  final String? companyPhone;
  final List<({String description, Decimal quantity, int? purchasePriceCents})> items;
}

Future<Uint8List> buildPurchaseOrderPdfFromData(PurchaseOrderPdfData data) async {

  final regularFont = pw.Font.ttf(await rootBundle.load('assets/fonts/DejaVuSans.ttf'));
  final boldFont = pw.Font.ttf(await rootBundle.load('assets/fonts/DejaVuSans-Bold.ttf'));

  final items = data.items;
  final total = items.fold(
    Money.zero(),
    (sum, item) => sum +
        (item.purchasePriceCents == null
            ? Money.zero()
            : Money.fromCents(item.purchasePriceCents!).multiplyByQuantity(item.quantity)),
  );

  final doc = pw.Document(theme: pw.ThemeData.withFont(base: regularFont, bold: boldFont));
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      footer: (context) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text(
          'Seite ${context.pageNumber} von ${context.pagesCount}',
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
        ),
      ),
      build: (context) => [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(data.companyName, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                if (data.companyAddress != null) pw.Text(data.companyAddress!),
                if (data.companyEmail != null) pw.Text(data.companyEmail!),
                if (data.companyPhone != null) pw.Text(data.companyPhone!),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  'Bestellung ${data.number}',
                  style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
                ),
                pw.Text('Bestelldatum: ${_formatDate(data.issueDate)}'),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 16),
        pw.Text('An:', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
        pw.Text(data.supplierName, style: const pw.TextStyle(fontSize: 11)),
        if (data.supplierAddress != null) pw.Text(data.supplierAddress!, style: const pw.TextStyle(fontSize: 11)),
        pw.Divider(),
        pw.SizedBox(height: 16),
        pw.Table(
          border: null,
          columnWidths: const {
            0: pw.FlexColumnWidth(4),
            1: pw.FlexColumnWidth(1.2),
            2: pw.FlexColumnWidth(1.5),
            3: pw.FlexColumnWidth(1.5),
          },
          children: [
            pw.TableRow(
              decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(width: 0.5))),
              children: [
                _cell('Beschreibung', bold: true),
                _cell('Menge', bold: true, alignRight: true),
                _cell('Einzelpreis', bold: true, alignRight: true),
                _cell('Gesamt', bold: true, alignRight: true),
              ],
            ),
            for (final item in items)
              pw.TableRow(
                children: [
                  _cell(item.description),
                  _cell(_formatQuantity(item.quantity), alignRight: true),
                  _cell(
                    item.purchasePriceCents == null
                        ? '–'
                        : Money.fromCents(item.purchasePriceCents!).toString(),
                    alignRight: true,
                  ),
                  _cell(
                    item.purchasePriceCents == null
                        ? '–'
                        : Money.fromCents(item.purchasePriceCents!).multiplyByQuantity(item.quantity).toString(),
                    alignRight: true,
                  ),
                ],
              ),
          ],
        ),
        pw.SizedBox(height: 16),
        pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Gesamtbetrag (netto, Richtwert): $total',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
        ),
        if (data.notes != null) ...[
          pw.SizedBox(height: 16),
          pw.Text(data.notes!, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
        ],
      ],
    ),
  );

  return doc.save();
}

String _formatQuantity(Decimal value) => value.toString().replaceAll('.', ',');

pw.Widget _cell(String text, {bool bold = false, bool alignRight = false}) => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Text(
        text,
        textAlign: alignRight ? pw.TextAlign.right : pw.TextAlign.left,
        style: pw.TextStyle(fontSize: 10, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal),
      ),
    );

String _formatDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
