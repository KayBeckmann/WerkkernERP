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
}) async {
  if (order.status == PurchaseOrderStatus.draft || order.orderNumber == null) {
    throw StateError('PDF kann nur für eine finalisierte Bestellung erzeugt werden.');
  }

  final regularFont = pw.Font.ttf(await rootBundle.load('assets/fonts/DejaVuSans.ttf'));
  final boldFont = pw.Font.ttf(await rootBundle.load('assets/fonts/DejaVuSans-Bold.ttf'));

  final total = items.fold(
    Money.zero(),
    (sum, item) => sum +
        (item.purchasePriceCents == null
            ? Money.zero()
            : Money.fromCents(item.purchasePriceCents!)
                .multiplyByQuantity(Decimal.parse(item.quantity.toString()))),
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
                pw.Text(company.name, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                if (company.address != null) pw.Text(company.address!),
                if (company.email != null) pw.Text(company.email!),
                if (company.phone != null) pw.Text(company.phone!),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  'Bestellung ${order.orderNumber}',
                  style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
                ),
                pw.Text('Bestelldatum: ${_formatDate(order.issueDate)}'),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 16),
        pw.Text('An:', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
        pw.Text(order.supplierSnapshotName ?? '', style: const pw.TextStyle(fontSize: 11)),
        if (order.supplierSnapshotAddress != null)
          pw.Text(order.supplierSnapshotAddress!, style: const pw.TextStyle(fontSize: 11)),
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
                        : Money.fromCents(item.purchasePriceCents!)
                            .multiplyByQuantity(Decimal.parse(item.quantity.toString()))
                            .toString(),
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
        if (order.notes != null) ...[
          pw.SizedBox(height: 16),
          pw.Text(order.notes!, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
        ],
      ],
    ),
  );

  return doc.save();
}

String _formatQuantity(double value) =>
    value == value.roundToDouble() ? value.toStringAsFixed(0) : value.toString();

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
