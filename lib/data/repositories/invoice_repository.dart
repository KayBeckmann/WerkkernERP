import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../domain/services/invoice_totals_service.dart';
import '../database/database.dart';
import '../database/tables.dart';
import 'number_sequence_repository.dart';

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
  InvoiceRepository(this._db, this._numberSequences);

  final AppDatabase _db;
  final NumberSequenceRepository _numberSequences;
  static const _uuid = Uuid();

  Future<List<Invoice>> listDraftsForCompany(
    String companyId, {
    DocumentKind kind = DocumentKind.invoice,
  }) =>
      (_db.select(_db.invoices)
            ..where(
              (i) =>
                  i.companyId.equals(companyId) &
                  i.status.equalsValue(InvoiceStatus.draft) &
                  i.kind.equalsValue(kind),
            )
            ..orderBy([(i) => OrderingTerm.desc(i.updatedAt)]))
          .get();

  /// Alle Dokumente einer Art (Entwürfe **und** finalisierte) für die
  /// Liste — A2/A3-Abnahme verlangt ausdrücklich, Status/Kunde/Betrag in
  /// einer Liste wiederzufinden, nicht nur Entwürfe. `kind` filtert auf
  /// Rechnung/Angebot/Auftrag (A5) — die drei Listen vermischen sich nie.
  Future<List<Invoice>> listAllForCompany(
    String companyId, {
    DocumentKind kind = DocumentKind.invoice,
  }) =>
      (_db.select(_db.invoices)
            ..where((i) => i.companyId.equals(companyId) & i.kind.equalsValue(kind))
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
  /// `kind` legt die Dokumentart fest (A5: Rechnung/Angebot/Auftrag) und
  /// ist nach dem Anlegen nicht mehr änderbar (kein Umwandeln zwischen
  /// den Arten in A5 — siehe Doc-Kommentar bei [DocumentKind]).
  Future<Invoice> createDraft({
    required String companyId,
    required String customerId,
    required DateTime issueDate,
    required DateTime serviceDate,
    DocumentKind kind = DocumentKind.invoice,
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
              kind: Value(kind),
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

  /// Finalisiert einen Entwurf: vergibt die nächste Nummer im Firmen-/
  /// Typ-/Jahreskreis, friert Kunden- und Firmendaten als Schnappschuss
  /// ein (spätere Stammdatenänderungen dürfen das PDF nicht verändern,
  /// A1/F3) und setzt den Status unveränderlich auf `finalized` — alles
  /// in **einer** Transaktion (F3: "atomar persistieren", keine doppelte
  /// Nummer auch bei Prozessabbruch/erneutem Antippen).
  ///
  /// Das Jahr des Nummernkreises ist das Jahr des **Finalisierungs-
  /// zeitpunkts** (serverseitig/client-seitig durch `DateTime.now()`
  /// bestimmt, nie ein vom Nutzer eingegebenes Datum) — das war die in
  /// F3 offen gelassene Frage "welches Datum/Jahr steuert JJ".
  ///
  /// `null`, wenn die Rechnung nicht existiert oder bereits finalisiert
  /// ist (kein Fehler — Aufrufer behandeln das wie "nichts zu tun").
  /// Wirft [StateError], wenn der Entwurf keine Positionen hat.
  Future<Invoice?> finalize({required String companyId, required String id}) async {
    return _db.transaction(() async {
      final invoice = await findById(companyId: companyId, id: id);
      if (invoice == null || invoice.status != InvoiceStatus.draft) return null;

      final items = await itemsFor(id);
      if (items.isEmpty) {
        throw StateError('Eine Rechnung ohne Positionen kann nicht finalisiert werden.');
      }

      final company = await (_db.select(_db.companies)..where((c) => c.id.equals(companyId)))
          .getSingle();
      final customer = await (_db.select(_db.customers)
            ..where((c) => c.id.equals(invoice.customerId)))
          .getSingle();

      final now = DateTime.now();
      final year = now.year;
      final number = await _numberSequences.allocateNext(
        companyId: companyId,
        documentType: invoice.kind.name,
        year: year,
      );
      final invoiceNumber = formatDocumentNumber(kind: invoice.kind, year: year, number: number);

      await (_db.update(_db.invoices)..where((i) => i.id.equals(id))).write(
        InvoicesCompanion(
          status: const Value(InvoiceStatus.finalized),
          invoiceNumber: Value(invoiceNumber),
          numberYear: Value(year),
          finalizedAt: Value(now),
          updatedAt: Value(now),
          customerSnapshotName: Value(customer.name),
          customerSnapshotAddress: Value(customer.address),
          customerSnapshotVatId: Value(customer.vatId),
          companySnapshotName: Value(company.name),
          companySnapshotAddress: Value(company.address),
          companySnapshotTaxNumber: Value(company.taxNumber),
          companySnapshotVatId: Value(company.vatId),
          companySnapshotIban: Value(company.iban),
        ),
      );
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
