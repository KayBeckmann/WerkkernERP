import 'package:werkkern_core/werkkern_core.dart' show isInvoiceClosedByCredit;

import 'accounting_routes.dart' show documentGrossCents;
import 'models.dart';
import 'repository.dart';

void validateCancellation(Document source, int expectedVersion, bool hasCreditNotes) {
  if (source.kind != 'invoice' || source.isDraft) {
    throw const BusinessConflict('Nur eine finalisierte Rechnung kann storniert werden.');
  }
  if (source.version != expectedVersion) {
    throw const BusinessConflict('Rechnung wurde zwischenzeitlich geändert — bitte neu laden.');
  }
  if (hasCreditNotes) {
    throw const BusinessConflict(
      'Es existiert bereits eine Gutschrift oder ein Gutschriftentwurf. Bitte zuerst prüfen.',
    );
  }
}

Document cancellationDocument(
  Document source, {
  required String id,
  required String userId,
  required DateTime now,
  required String number,
  required int year,
}) => Document(
  id: id,
  companyId: source.companyId,
  customerId: source.customerId,
  kind: 'creditNote',
  status: 'finalized',
  isCancellation: true,
  number: number,
  numberYear: year,
  issueDate: DateTime.utc(now.year, now.month, now.day),
  serviceDate: source.serviceDate,
  notes: 'Storno zu Rechnung ${source.number}.',
  convertedFromId: source.id,
  projectId: source.projectId,
  contactId: source.contactId,
  createdByUserId: userId,
  createdAt: now,
  updatedAt: now,
  finalizedAt: now,
  version: 1,
  customerSnapshotName: source.customerSnapshotName,
  customerSnapshotAddress: source.customerSnapshotAddress,
  customerSnapshotVatId: source.customerSnapshotVatId,
  companySnapshotName: source.companySnapshotName,
  companySnapshotAddress: source.companySnapshotAddress,
  companySnapshotTaxNumber: source.companySnapshotTaxNumber,
  companySnapshotVatId: source.companySnapshotVatId,
  companySnapshotIban: source.companySnapshotIban,
  companySnapshotBic: source.companySnapshotBic,
  eInvoiceSnapshot: source.eInvoiceSnapshot,
  smallBusinessExemptSnapshot: source.smallBusinessExemptSnapshot,
  introTextSnapshot: 'Storno zu Rechnung ${source.number}.',
  footerTextSnapshot: source.footerTextSnapshot,
  footerColumnsSnapshot: source.footerColumnsSnapshot,
  pdfLayoutSnapshot: source.pdfLayoutSnapshot,
  pdfLogoSnapshot: source.pdfLogoSnapshot,
);

List<DocumentItem> copyDocumentItems(List<DocumentItem> items, String documentId, String Function() newId) => [
  for (final i in items)
    DocumentItem(
      id: newId(),
      documentId: documentId,
      kind: i.kind,
      articleId: i.articleId,
      description: i.description,
      quantity: i.quantity,
      unitPriceCents: i.unitPriceCents,
      vatRatePercent: i.vatRatePercent,
      unit: i.unit,
      discountPercent: i.discountPercent,
      groupLabel: i.groupLabel,
      staffRoleId: i.staffRoleId,
      sortOrder: i.sortOrder,
    ),
];

/// Storniert oder durch finalisierte Gutschriften voll ausgeglichen — keine
/// offene Forderung mehr (siehe `isInvoiceClosedByCredit` in `werkkern_core`).
Future<bool> isInvoiceClosed(BusinessRepository business, String companyId, String invoiceId) async {
  final credits = [
    for (final d in await business.listConvertedFrom(companyId, invoiceId))
      if (d.kind == 'creditNote' && !d.isDraft) d,
  ];
  if (credits.isEmpty) return false;
  if (credits.any((d) => d.isCancellation)) return true;
  var credited = 0;
  for (final c in credits) {
    credited += documentGrossCents(await business.itemsFor(companyId, c.id));
  }
  return isInvoiceClosedByCredit(
    cancelled: false,
    invoiceGrossCents: documentGrossCents(await business.itemsFor(companyId, invoiceId)),
    creditedGrossCents: credited,
  );
}
