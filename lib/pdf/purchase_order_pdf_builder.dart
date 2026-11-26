import 'dart:typed_data';
import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:werkkern_core/werkkern_core.dart' show decodeFooterColumns;

import '../data/database/database.dart';
import '../data/database/tables.dart';
import '../domain/models/money.dart';
import 'invoice_pdf_builder.dart'
    show PdfDocumentData, interpolateFooter, configuredFooterHasContent;

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
    throw StateError(
      'PDF kann nur für eine finalisierte Bestellung erzeugt werden.',
    );
  }
  return buildPurchaseOrderPdfFromData(
    PurchaseOrderPdfData(
      number: order.orderNumber!,
      issueDate: order.issueDate,
      notes: order.notes,
      supplierName: order.supplierSnapshotName ?? '',
      supplierAddress: order.supplierSnapshotAddress,
      ourCustomerNumber: order.supplierSnapshotCustomerNumber,
      companyName: company.name,
      companyAddress: company.address,
      companyEmail: company.email,
      companyPhone: company.phone,
      companyTaxNumber: company.taxNumber,
      companyVatId: company.vatId,
      companyIban: company.iban,
      companyBic: company.bic,
      footerText: company.pdfFooterText,
      // Parität offline/online: wie online aus den aktuellen Firmendaten.
      pdfLogoBase64: company.pdfLogoBase64,
      footerColumns: decodeFooterColumns(company.pdfFooterColumns),
      introText: company.pdfIntroTextPurchaseOrder,
      closingText: company.pdfClosingTextPurchaseOrder,
      items: [
        for (final i in items)
          (
            description: i.description,
            quantity: Decimal.parse(i.quantity.toString()),
            purchasePriceCents: i.purchasePriceCents,
            supplierArticleNumber: i.supplierArticleNumber,
          ),
      ],
    ),
  );
}

typedef PurchaseOrderPdfItem = ({
  String description,
  Decimal quantity,
  int? purchasePriceCents,
  String? supplierArticleNumber,
});

/// Neutrales Datenmodell des Bestellungs-PDFs — Offline-App und
/// Online-Modus erzeugen damit dasselbe Layout (wie `PdfDocumentData`).
class PurchaseOrderPdfData {
  const PurchaseOrderPdfData({
    required this.number,
    required this.issueDate,
    this.notes,
    required this.supplierName,
    this.supplierAddress,
    this.ourCustomerNumber,
    required this.companyName,
    this.companyAddress,
    this.companyEmail,
    this.companyPhone,
    this.pdfLogoBase64,
    this.companyTaxNumber,
    this.companyVatId,
    this.companyIban,
    this.companyBic,
    this.footerColumns,
    this.footerText,
    this.introText,
    this.closingText,
    required this.items,
  });
  final String number;
  final DateTime issueDate;
  final String? notes;
  final String supplierName;
  final String? supplierAddress;

  /// C5.2-Nachtrag: unsere Kundennummer beim Lieferanten (Schnappschuss);
  /// fehlt sie, erscheint keine leere Zeile.
  final String? ourCustomerNumber;
  final String companyName;
  final String? companyAddress;
  final String? companyEmail;
  final String? companyPhone;
  final String? pdfLogoBase64;
  final String? companyTaxNumber;
  final String? companyVatId;
  final String? companyIban;
  final String? companyBic;

  /// Same configured left/center/right templates as the other PDFs.
  final Map<String, String?>? footerColumns;
  final String? footerText;
  final String? introText;
  final String? closingText;

  /// C5.2-Nachtrag: `supplierArticleNumber` = Nummer beim Lieferanten
  /// (Schnappschuss), erscheint als „Ihre Art.-Nr.“ unter der Beschreibung.
  final List<PurchaseOrderPdfItem> items;
}

Future<Uint8List> buildPurchaseOrderPdfFromData(
  PurchaseOrderPdfData data,
) async {
  final regularFont = pw.Font.ttf(
    await rootBundle.load('assets/fonts/DejaVuSans.ttf'),
  );
  final boldFont = pw.Font.ttf(
    await rootBundle.load('assets/fonts/DejaVuSans-Bold.ttf'),
  );
  final logo = data.pdfLogoBase64 == null
      ? null
      : pw.MemoryImage(base64Decode(data.pdfLogoBase64!));
  final footerData = PdfDocumentData(
    kind: DocumentKind.order,
    invoiceNumber: data.number,
    issueDate: data.issueDate,
    serviceDate: data.issueDate,
    companySnapshotName: data.companyName,
    companySnapshotAddress: data.companyAddress,
    companySnapshotTaxNumber: data.companyTaxNumber,
    companySnapshotVatId: data.companyVatId,
    companySnapshotIban: data.companyIban,
    companySnapshotBic: data.companyBic,
    customerSnapshotName: data.supplierName,
    customerSnapshotAddress: data.supplierAddress,
    footerColumns: data.footerColumns,
    lines: const [],
  );

  final items = data.items;
  final total = items.fold(
    Money.zero(),
    (sum, item) =>
        sum +
        (item.purchasePriceCents == null
            ? Money.zero()
            : Money.fromCents(
                item.purchasePriceCents!,
              ).multiplyByQuantity(item.quantity)),
  );

  final doc = pw.Document(
    theme: pw.ThemeData.withFont(base: regularFont, bold: boldFont),
  );
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: pw.EdgeInsets.fromLTRB(
        40,
        34,
        40,
        data.footerColumns == null ? 110 : 75,
      ),
      footer: (context) => pw.Column(
        children: [
          if (data.footerColumns == null ||
              configuredFooterHasContent(footerData))
            pw.Divider(color: PdfColors.grey400, thickness: 0.4),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              for (final side in ['left', 'center', 'right']) ...[
                if (side != 'left') pw.SizedBox(width: 10),
                pw.Expanded(
                  child: pw.Text(
                    data.footerColumns == null
                        ? switch (side) {
                            'left' =>
                              [data.companyName, data.companyAddress]
                                  .whereType<String>()
                                  .where((value) => value.trim().isNotEmpty)
                                  .join('\n'),
                            'center' =>
                              data.companyIban?.trim().isNotEmpty ?? false
                                  ? 'IBAN: ${data.companyIban}'
                                  : '',
                            _ => [
                              if (data.companyTaxNumber?.trim().isNotEmpty ??
                                  false)
                                'Steuernummer: ${data.companyTaxNumber}',
                              if (data.companyVatId?.trim().isNotEmpty ?? false)
                                'USt-IdNr.: ${data.companyVatId}',
                            ].join('\n'),
                          }
                        : interpolateFooter(
                            data.footerColumns![side] ?? '',
                            footerData,
                          ),
                    textAlign: side == 'left'
                        ? pw.TextAlign.left
                        : side == 'right'
                        ? pw.TextAlign.right
                        : pw.TextAlign.center,
                    style: const pw.TextStyle(fontSize: 7),
                  ),
                ),
              ],
            ],
          ),
          if (data.footerColumns == null &&
              (data.footerText?.trim().isNotEmpty ?? false)) ...[
            pw.SizedBox(height: 12),
            pw.Text(
              interpolateFooter(data.footerText!, footerData),
              textAlign: pw.TextAlign.center,
              style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700),
            ),
          ],
          pw.SizedBox(height: 4),
          pw.Text(
            'Seite ${context.pageNumber} von ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
          ),
        ],
      ),
      header: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          if (logo != null)
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Container(
                height: 55,
                width: 215,
                alignment: pw.Alignment.centerRight,
                child: pw.Image(logo, fit: pw.BoxFit.contain),
              ),
            ),
          if (logo != null) pw.SizedBox(height: 8),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.SizedBox(
              width: 215,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    data.companyName,
                    textAlign: pw.TextAlign.right,
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  if (data.companyAddress?.trim().isNotEmpty ?? false)
                    pw.Text(
                      data.companyAddress!.trim(),
                      textAlign: pw.TextAlign.right,
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                ],
              ),
            ),
          ),
          if (context.pageNumber == 1) ...[
            pw.SizedBox(height: 28),
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        data.supplierName,
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                      if (data.supplierAddress?.trim().isNotEmpty ?? false)
                        pw.Text(
                          data.supplierAddress!.trim(),
                          style: const pw.TextStyle(fontSize: 10),
                        ),
                      if (data.ourCustomerNumber?.trim().isNotEmpty ?? false)
                        pw.Text(
                          'Unsere Kundennummer bei Ihnen: ${data.ourCustomerNumber}',
                          style: const pw.TextStyle(fontSize: 9),
                        ),
                    ],
                  ),
                ),
                pw.SizedBox(
                  width: 175,
                  child: pw.Align(
                    alignment: pw.Alignment.centerRight,
                    child: pw.Text(
                      'Bestelldatum: ${_formatDate(data.issueDate)}',
                      textAlign: pw.TextAlign.right,
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 25),
            pw.Text(
              'Bestellung ${data.number}',
              style: pw.TextStyle(fontSize: 17, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 14),
          ] else
            pw.SizedBox(height: 12),
        ],
      ),
      build: (context) => [
        if (data.introText?.trim().isNotEmpty ?? false) ...[
          pw.Text(data.introText!.trim(), style: const pw.TextStyle(fontSize: 9)),
          pw.SizedBox(height: 12),
        ],
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
              decoration: const pw.BoxDecoration(
                border: pw.Border(bottom: pw.BorderSide(width: 0.5)),
              ),
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
                  item.supplierArticleNumber == null ||
                          item.supplierArticleNumber!.trim().isEmpty
                      ? _cell(item.description)
                      : pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(vertical: 4),
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text(
                                item.description,
                                style: const pw.TextStyle(fontSize: 10),
                              ),
                              pw.Text(
                                'Ihre Art.-Nr.: ${item.supplierArticleNumber!.trim()}',
                                style: const pw.TextStyle(
                                  fontSize: 8,
                                  color: PdfColors.grey700,
                                ),
                              ),
                            ],
                          ),
                        ),
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
                        : Money.fromCents(
                            item.purchasePriceCents!,
                          ).multiplyByQuantity(item.quantity).toString(),
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
          pw.Text(
            data.notes!,
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          ),
        ],
        if (data.closingText?.trim().isNotEmpty ?? false) ...[
          pw.SizedBox(height: 16),
          pw.Text(data.closingText!.trim(), style: const pw.TextStyle(fontSize: 9)),
        ],
      ],
    ),
  );

  return doc.save();
}

String _formatQuantity(Decimal value) => value.toString().replaceAll('.', ',');

pw.Widget _cell(String text, {bool bold = false, bool alignRight = false}) =>
    pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Text(
        text,
        textAlign: alignRight ? pw.TextAlign.right : pw.TextAlign.left,
        style: pw.TextStyle(
          fontSize: 10,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );

String _formatDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
