import 'package:decimal/decimal.dart';
import 'package:werkkern_client/werkkern_client.dart';
import 'package:werkkern_core/werkkern_core.dart';

import '../../data/database/database.dart';
import '../../data/repositories/invoice_repository.dart' show AdvancePaymentEntry;
import 'einvoice_parties.dart';

/// C15 E-Rechnung — Abbildung eines Dokuments (offline oder online) auf
/// [EInvoiceData]. Finalisierte Dokumente nutzen ausschließlich den beim
/// Finalisieren eingefrorenen Parteien-Schnappschuss; fehlt er (vor
/// Schema v36 finalisiert), dienen die aktuellen Stammdaten als
/// Fallback — nur dann mit [liveCompany]/[liveCustomer].
EInvoiceData? eInvoiceDataForInvoice({
  required Invoice invoice,
  required List<InvoiceItem> items,
  required Company company,
  Customer? customer,
  List<AdvancePaymentEntry> priorAdvancePayments = const [],
  String? referencedInvoiceNumber,
  DateTime? referencedInvoiceDate,
}) {
  if (!company.eInvoiceEnabled || !isEInvoiceKind(invoice.kind)) return null;
  final snapshot = decodeEInvoiceSnapshot(invoice.eInvoiceSnapshot);
  final seller = snapshot?.seller ?? sellerPartyFromCompany(company);
  final buyer = snapshot?.buyer ??
      (customer == null
          ? EInvoiceParty(
              name: invoice.customerSnapshotName ?? '',
              address: parsePostalAddress(invoice.customerSnapshotAddress),
              vatId: invoice.customerSnapshotVatId,
            )
          : buyerPartyFromCustomer(customer));
  final format = snapshot?.format ?? EInvoiceFormat.parse(customer?.eInvoiceFormat);
  return EInvoiceData(
    profile: EInvoiceProfile.forFormat(format),
    kind: invoice.kind.name,
    number: invoice.invoiceNumber,
    issueDate: invoice.issueDate,
    serviceDate: invoice.serviceDate,
    dueDate: invoice.dueDate,
    paymentTerms: invoice.paymentTerms,
    notes: invoice.notes,
    seller: seller,
    buyer: buyer,
    smallBusinessExempt: items.isNotEmpty && items.every((i) => i.vatRatePercent == 0) && company.isSmallBusinessExempt,
    isAdvancePayment: invoice.isAdvancePayment,
    priorPayments: [
      for (final p in priorAdvancePayments)
        EInvoicePriorPayment(invoiceNumber: p.invoiceNumber, grossCents: p.amountGross.cents),
    ],
    referencedInvoiceNumber: referencedInvoiceNumber,
    referencedInvoiceDate: referencedInvoiceDate,
    terms: invoice.paymentTermLabel == null || invoice.paymentNetDays == null
        ? null
        : DocumentPaymentTerms(
            label: invoice.paymentTermLabel!,
            netDays: invoice.paymentNetDays!,
            skontoPercent: invoice.skontoPercent,
            skontoDays: invoice.skontoDays,
          ),
    lines: [
      for (final item in items)
        EInvoiceLine(
          description: item.description,
          quantity: Decimal.parse(item.quantity),
          unit: item.unit,
          unitPriceCents: item.unitPriceCents,
          vatRatePercent: item.vatRatePercent,
          discountPercent: item.discountPercent,
          groupLabel: item.groupLabel,
        ),
    ],
  );
}

/// Online: Schnappschuss aus dem Server-Dokument; Entwürfe und
/// Altdokumente aus den Live-Stammdaten (Vorschau/Prüfung).
EInvoiceData? eInvoiceDataForOnlineDocument(
  OnlineDocument document, {
  required bool enabled,
  OnlineCompanyProfile? liveCompany,
  OnlineCustomer? liveCustomer,
}) {
  if (!enabled || !isEInvoiceDocumentKind(document.kind)) return null;
  final raw = document.eInvoiceSnapshot;
  final snapshot = raw == null ? null : EInvoiceSnapshot.fromJson(raw);
  final company = document.isDraft ? liveCompany : (document.companySnapshot ?? liveCompany);
  final seller = snapshot?.seller ??
      EInvoiceParty(
        name: company?.name ?? '',
        address: addressFromFields(
          street: company?.street,
          postalCode: company?.postalCode,
          city: company?.city,
          countryCode: company?.countryCode,
          freeText: company?.address,
        ),
        vatId: company?.vatId,
        taxNumber: company?.taxNumber,
        email: company?.email,
        phone: company?.phone,
        iban: company?.iban,
        bic: company?.bic,
      );
  final buyer = snapshot?.buyer ??
      (liveCustomer != null
          ? EInvoiceParty(
              name: liveCustomer.name,
              address: addressFromFields(
                street: liveCustomer.street,
                postalCode: liveCustomer.postalCode,
                city: liveCustomer.city,
                countryCode: liveCustomer.countryCode,
                freeText: liveCustomer.address,
              ),
              vatId: liveCustomer.vatId,
              email: liveCustomer.invoiceEmail ?? liveCustomer.email,
              phone: liveCustomer.phone,
              leitwegId: liveCustomer.leitwegId,
            )
          : EInvoiceParty(
              name: document.customerSnapshotName ?? document.customerName ?? '',
              address: parsePostalAddress(document.customerSnapshotAddress),
              vatId: document.customerSnapshotVatId,
            ));
  final format = snapshot?.format ?? EInvoiceFormat.parse(liveCustomer?.eInvoiceFormat);
  final exempt = document.isDraft ? (liveCompany?.smallBusinessExempt ?? false) : document.smallBusinessExemptSnapshot;
  return EInvoiceData(
    profile: EInvoiceProfile.forFormat(format),
    kind: document.kind,
    number: document.number,
    issueDate: document.issueDate,
    serviceDate: document.serviceDate,
    dueDate: document.dueDate,
    paymentTerms: document.paymentTerms,
    notes: document.notes,
    seller: seller,
    buyer: buyer,
    smallBusinessExempt: exempt && document.items.every((i) => i.vatRatePercent == 0),
    isAdvancePayment: document.isAdvancePayment,
    priorPayments: [
      for (final a in document.advancePayments)
        EInvoicePriorPayment(invoiceNumber: a.number ?? '', grossCents: a.grossCents),
    ],
    terms: document.paymentTerm == null
        ? null
        : DocumentPaymentTerms(
            label: document.paymentTerm!.label,
            netDays: document.paymentTerm!.netDays,
            skontoPercent: document.paymentTerm!.skontoPercent,
            skontoDays: document.paymentTerm!.skontoDays,
          ),
    referencedInvoiceNumber: document.kind == 'creditNote' ? document.convertedFromNumber : null,
    lines: [
      for (final item in document.items)
        EInvoiceLine(
          description: item.description,
          quantity: Decimal.parse(item.quantity),
          unit: item.unit,
          unitPriceCents: item.unitPriceCents,
          vatRatePercent: item.vatRatePercent,
          discountPercent: item.discountPercent,
          groupLabel: item.groupLabel,
        ),
    ],
  );
}
