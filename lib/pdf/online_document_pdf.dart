import 'dart:typed_data';

import 'package:werkkern_client/werkkern_client.dart';
import 'package:werkkern_core/werkkern_core.dart' show DocumentPaymentTerms, quoteValidityText;

import '../data/database/tables.dart' show DocumentKind;
import '../data/repositories/invoice_repository.dart' show AdvancePaymentEntry;
import '../domain/models/money.dart';
import '../domain/services/einvoice_builder.dart';
import 'invoice_pdf_builder.dart';

/// PDF eines Online-Dokuments (Phase B) — derselbe Generator wie
/// offline ([renderDocumentPdf]), damit beide Modi identische Belege
/// erzeugen. Die Daten stammen aus einer serverseitig rechtegeprüften
/// Abfrage (B1.3: auch PDF-Zugriff nur mit `invoices.read`).
///
/// Finalisiert: ausschließlich die eingefrorenen Schnappschüsse.
/// Entwurf: Vorschau mit ENTWURF-Banner aus den aktuellen Stammdaten
/// ([liveCompany]/[liveCustomer]) — wie offline nie teilbar.
Future<Uint8List> buildOnlineDocumentPdf(
  OnlineDocument document, {
  OnlineCompanyProfile? liveCompany,
  OnlineCustomer? liveCustomer,
  // C15: Firmenmodul „E-Rechnung“ aktiv → finalisierte Rechnungen/
  // Gutschriften als ZUGFeRD-Hybrid-PDF.
  bool eInvoiceEnabled = false,
}) => renderDocumentPdf(
  onlineDocumentPdfData(
    document,
    liveCompany: liveCompany,
    liveCustomer: liveCustomer,
    eInvoiceEnabled: eInvoiceEnabled,
  ),
  isPreview: document.isDraft,
  // C13: Schlussrechnung listet jede Abschlagsrechnung einzeln (wie offline).
  priorAdvancePayments: [
    for (final a in document.advancePayments)
      AdvancePaymentEntry(invoiceNumber: a.number ?? '', amountGross: Money.fromCents(a.grossCents)),
  ],
  // Gutschrift: "Gutschrift zur Rechnung <Nummer>" im Kopf.
  referencedDocumentNumber: document.kind == 'creditNote' ? document.convertedFromNumber : null,
);

/// Abbildung auf das neutrale PDF-Modell — separat, damit testbar ist,
/// dass ein finalisiertes Dokument nie Live-Stammdaten verwendet.
PdfDocumentData onlineDocumentPdfData(
  OnlineDocument document, {
  OnlineCompanyProfile? liveCompany,
  OnlineCustomer? liveCustomer,
  bool eInvoiceEnabled = false,
}) {
  final isPreview = document.isDraft;
  final company = isPreview ? liveCompany : document.companySnapshot;
  return PdfDocumentData(
    kind: DocumentKind.values.byName(document.kind),
    isAdvancePayment: document.isAdvancePayment,
    invoiceNumber: document.number,
    issueDate: document.issueDate,
    serviceDate: document.serviceDate,
    companySnapshotName: company?.name,
    companySnapshotAddress: company?.address,
    companySnapshotTaxNumber: company?.taxNumber,
    companySnapshotVatId: company?.vatId,
    companySnapshotIban: company?.iban,
    customerSnapshotName: isPreview
        ? (liveCustomer?.name ?? document.customerName)
        : document.customerSnapshotName,
    customerSnapshotAddress: isPreview
        ? liveCustomer?.address
        : document.customerSnapshotAddress,
    customerSnapshotVatId: isPreview
        ? liveCustomer?.vatId
        : document.customerSnapshotVatId,
    paymentTerms: document.paymentTerms,
    notes: document.notes,
    // Finalisiert nur aus den Schnappschüssen, Entwurf aus den aktuellen Firmendaten.
    introText: isPreview ? liveCompany?.documentTexts[document.kind]?.intro : document.introTextSnapshot,
    closingText: isPreview ? liveCompany?.documentTexts[document.kind]?.closing : document.closingTextSnapshot,
    footerText: isPreview ? liveCompany?.footerText : document.footerTextSnapshot,
    isSmallBusinessExempt: isPreview ? (liveCompany?.smallBusinessExempt ?? false) : document.smallBusinessExemptSnapshot,
    lines: [
      for (final item in document.items)
        PdfLine(
          description: item.description,
          quantity: item.quantity,
          unit: item.unit,
          unitPriceCents: item.unitPriceCents,
          vatRatePercent: item.vatRatePercent,
          discountPercent: item.discountPercent,
          groupLabel: item.groupLabel,
        ),
    ],
    quoteValidity: document.kind == 'quote'
        ? quoteValidityText(days: document.quoteValidityDays, validUntil: document.quoteValidUntil)
        : null,
    terms: document.paymentTerm == null || document.kind == 'creditNote'
        ? null
        : DocumentPaymentTerms(
            label: document.paymentTerm!.label,
            netDays: document.paymentTerm!.netDays,
            skontoPercent: document.paymentTerm!.skontoPercent,
            skontoDays: document.paymentTerm!.skontoDays,
          ),
    eInvoice: isPreview
        ? null
        : eInvoiceDataForOnlineDocument(document, enabled: eInvoiceEnabled, liveCompany: liveCompany, liveCustomer: liveCustomer),
  );
}
