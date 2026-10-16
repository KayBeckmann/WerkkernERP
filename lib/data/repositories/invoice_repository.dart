import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../domain/services/invoice_totals_service.dart';
import '../database/database.dart';
import '../database/tables.dart';

/// Eine einzugebende Rechnungsposition (noch ohne ID — die vergibt das
/// Repository beim Speichern).
class InvoiceItemInput {
  const InvoiceItemInput({
    this.id,
    required this.kind,
    this.articleId,
    required this.description,
    required this.quantity,
    required this.unitPriceCents,
    required this.vatRatePercent,
    this.groupLabel,
  });

  final String? id;
  final InvoiceItemKind kind;
  final String? articleId;
  final String description;
  final Decimal quantity;
  final int unitPriceCents;
  final double vatRatePercent;
  final String? groupLabel;
}

/// Rechnungen als Entwurf (A2) — Finalisierung/Nummernvergabe kommt erst
/// mit A3. Jede Methode verlangt companyId und prüft sie (gleiche
/// Isolation wie die übrigen A0/A1-Repositories).
class InvoiceRepository {
  InvoiceRepository(this._db);

  final AppDatabase _db;
  static const _uuid = Uuid();

  Future<List<Invoice>> listDraftsForCompany(String companyId) =>
      (_db.select(_db.invoices)
            ..where((i) => i.companyId.equals(companyId) & i.status.equalsValue(InvoiceStatus.draft))
            ..orderBy([(i) => OrderingTerm.desc(i.updatedAt)]))
          .get();

  Future<Invoice?> findById({required String companyId, required String id}) =>
      (_db.select(_db.invoices)..where((i) => i.id.equals(id) & i.companyId.equals(companyId)))
          .getSingleOrNull();

  Future<List<InvoiceItem>> itemsFor(String invoiceId) =>
      (_db.select(_db.invoiceItems)
            ..where((i) => i.invoiceId.equals(invoiceId))
            ..orderBy([(i) => OrderingTerm.asc(i.sortOrder)]))
          .get();

  /// Legt einen neuen Entwurf an — **nummernlos**, Status `draft` (F3).
  Future<Invoice> createDraft({
    required String companyId,
    required String customerId,
    required DateTime issueDate,
    required DateTime serviceDate,
    String? paymentTerms,
    String? notes,
    List<InvoiceItemInput> items = const [],
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now();
    return _db.transaction(() async {
      await _db.into(_db.invoices).insert(
            InvoicesCompanion.insert(
              id: id,
              companyId: companyId,
              customerId: customerId,
              status: InvoiceStatus.draft,
              issueDate: issueDate,
              serviceDate: serviceDate,
              paymentTerms: Value(paymentTerms),
              notes: Value(notes),
              createdAt: now,
              updatedAt: now,
            ),
          );
      await _replaceItems(id, items);
      return (await findById(companyId: companyId, id: id))!;
    });
  }

  /// Aktualisiert einen **Entwurf** (finalisierte Rechnungen sind über
  /// diesen Pfad nicht änderbar, siehe [update]s Status-Guard — die
  /// eigentliche Finalisierungs-Transaktion kommt mit A3).
  Future<Invoice?> update({
    required String companyId,
    required String id,
    DateTime? issueDate,
    DateTime? serviceDate,
    String? paymentTerms,
    String? notes,
    List<InvoiceItemInput>? items,
  }) async {
    return _db.transaction(() async {
      final existing = await findById(companyId: companyId, id: id);
      if (existing == null || existing.status != InvoiceStatus.draft) return null;

      await (_db.update(_db.invoices)..where((i) => i.id.equals(id)))
          .write(
        InvoicesCompanion(
          issueDate: issueDate == null ? const Value.absent() : Value(issueDate),
          serviceDate: serviceDate == null ? const Value.absent() : Value(serviceDate),
          paymentTerms: Value(paymentTerms ?? existing.paymentTerms),
          notes: Value(notes ?? existing.notes),
          updatedAt: Value(DateTime.now()),
        ),
      );
      if (items != null) {
        await _replaceItems(id, items);
      }
      return findById(companyId: companyId, id: id);
    });
  }

  Future<bool> deleteDraft({required String companyId, required String id}) async {
    final existing = await findById(companyId: companyId, id: id);
    if (existing == null || existing.status != InvoiceStatus.draft) return false;
    final rows = await (_db.delete(_db.invoices)
          ..where((i) => i.id.equals(id) & i.companyId.equals(companyId)))
        .go();
    return rows > 0;
  }

  Future<InvoiceTotals> totalsFor(String invoiceId) async {
    final items = await itemsFor(invoiceId);
    return calculateInvoiceTotals([
      for (final item in items)
        InvoiceLineInput(
          quantity: Decimal.parse(item.quantity),
          unitPriceCents: item.unitPriceCents,
          vatRatePercent: item.vatRatePercent,
        ),
    ]);
  }

  Future<void> _replaceItems(String invoiceId, List<InvoiceItemInput> items) async {
    await (_db.delete(_db.invoiceItems)..where((i) => i.invoiceId.equals(invoiceId))).go();
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      await _db.into(_db.invoiceItems).insert(
            InvoiceItemsCompanion.insert(
              id: item.id ?? _uuid.v4(),
              invoiceId: invoiceId,
              kind: item.kind,
              articleId: Value(item.articleId),
              description: item.description,
              quantity: item.quantity.toString(),
              unitPriceCents: item.unitPriceCents,
              vatRatePercent: item.vatRatePercent,
              groupLabel: Value(item.groupLabel),
              sortOrder: i,
            ),
          );
    }
  }
}
