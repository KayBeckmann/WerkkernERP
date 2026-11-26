import '../../data/database/database.dart';
import '../../data/database/tables.dart';
import '../../data/repositories/invoice_repository.dart' show DocumentTermsInput;

/// Unverbindlicher Beleg für die Entwurfsvorschau (`buildDraftPreviewPdf`)
/// aus dem aktuellen Editorstand und den Live-Stammdaten — vor der
/// Finalisierung gibt es noch keinen Schnappschuss.
///
/// Parität offline/online (Nachtrag 26.11.2026): Die Online-Vorschau zeigt
/// Zahlungsbedingung/Skonto und Bindefrist des Entwurfs; offline fehlten
/// sie bis dahin, weil die Vorschau sie nicht übernahm.
Invoice draftPreviewInvoice({
  required String id,
  required Company company,
  required Customer customer,
  required DocumentKind kind,
  required DateTime issueDate,
  required DateTime serviceDate,
  required DateTime now,
  String? paymentTerms,
  String? notes,
  bool isAdvancePayment = false,
  DateTime? dueDate,
  bool isFixedPrice = false,
  DocumentTermsInput? terms,
  int? quoteValidityDays,
  DateTime? quoteValidUntil,
}) =>
    Invoice(
      id: id,
      companyId: company.id,
      customerId: customer.id,
      kind: kind,
      status: InvoiceStatus.draft,
      invoiceNumber: null,
      numberYear: null,
      issueDate: issueDate,
      serviceDate: serviceDate,
      paymentTerms: paymentTerms,
      notes: notes,
      customerSnapshotName: customer.name,
      customerSnapshotAddress: customer.address,
      customerSnapshotVatId: customer.vatId,
      companySnapshotName: company.name,
      companySnapshotAddress: company.address,
      companySnapshotTaxNumber: company.taxNumber,
      companySnapshotVatId: company.vatId,
      companySnapshotIban: company.iban,
      companySnapshotBic: company.bic,
      paymentTermId: terms?.termId,
      paymentTermLabel: terms?.label,
      paymentNetDays: terms?.netDays,
      skontoPercent: terms?.skontoPercent,
      skontoDays: terms?.skontoDays,
      quoteValidityDays: quoteValidityDays,
      quoteValidUntil: quoteValidUntil,
      finalizedAt: null,
      createdAt: now,
      updatedAt: now,
      isAdvancePayment: isAdvancePayment,
      dueDate: dueDate,
      isFixedPrice: isFixedPrice,
      stockBooked: false,
      isCancellation: false,
      paymentStatus: PaymentStatus.open,
      paidAt: null,
    );
