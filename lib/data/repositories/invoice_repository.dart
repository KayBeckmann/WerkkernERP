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
    this.unit,
    this.discountPercent = 0,
    this.groupLabel,
  });

  final String? id;
  final InvoiceItemKind kind;
  final String? articleId;
  final String description;
  final Decimal quantity;
  final int unitPriceCents;
  final double vatRatePercent;

  /// Einheit (z. B. "Stk", "h", "m") — Kay-Nachtrag 2026-10-16.
  final String? unit;

  /// Rabatt in Prozent auf diese Position — Kay-Nachtrag 2026-10-16.
  final double discountPercent;
  final String? groupLabel;
}

/// Erlaubte Umwandlungsziele je Quell-Dokumentart (Kay-Nachtrag
/// 2026-10-16: "Angebot in Auftrag, Lieferschein oder Rechnung" /
/// "Auftrag in Lieferschein oder Rechnung"). Rechnung und Lieferschein
/// sind selbst keine gültigen Quellen — sie sind das Ende der Kette.
/// Öffentlich (nicht `_`-privat), damit die UI dieselbe Zuordnung für
/// das "Umwandeln"-Menü nutzen kann statt sie zu duplizieren.
/// C10 (Kay-Priorisierungsentscheidung 2026-10-17): eine finalisierte
/// Proforma-Rechnung ist in eine echte Rechnung umwandelbar — anders als
/// Angebot/Auftrag ist sie aber selbst kein gültiges Umwandlungsziel
/// (eine Rechnung wird nicht "zu einer Proforma zurückgewandelt").
const allowedConversionTargets = <DocumentKind, Set<DocumentKind>>{
  DocumentKind.quote: {DocumentKind.order, DocumentKind.deliveryNote, DocumentKind.invoice},
  DocumentKind.order: {DocumentKind.deliveryNote, DocumentKind.invoice},
  DocumentKind.proforma: {DocumentKind.invoice},
};

/// Rechnungen als Entwurf (A2) — Finalisierung/Nummernvergabe kommt erst
/// mit A3. Jede Methode verlangt companyId und prüft sie (gleiche
/// Isolation wie die übrigen A0/A1-Repositories).
class InvoiceRepository {
  InvoiceRepository(this._db, this._numberSequences);

  final AppDatabase _db;
  final NumberSequenceRepository _numberSequences;
  static const _uuid = Uuid();

  /// Lieferscheine dürfen keine Stunden-Positionen enthalten (Kay:
  /// "Lieferscheine sollen KEINE Stunden enthalten!!!") — hier statt
  /// nur in der UI durchgesetzt, damit kein Aufrufer das versehentlich
  /// umgehen kann.
  void _validateItemsForKind(DocumentKind kind, List<InvoiceItemInput> items) {
    if (kind == DocumentKind.deliveryNote && items.any((i) => i.kind == InvoiceItemKind.hours)) {
      throw ArgumentError('Ein Lieferschein darf keine Stunden-Positionen enthalten.');
    }
  }

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
    // C1 Projekte (Kay-Priorisierungsentscheidung 2026-10-17): optionale
    // Zuordnung — die erste Rechnung bleibt ausdrücklich projektfrei
    // möglich (Brainstorming).
    String? projectId,
    List<InvoiceItemInput> items = const [],
  }) async {
    _validateItemsForKind(kind, items);
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
              projectId: Value(projectId),
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
    // C1 Projekte: `Value.absent()` = unverändert lassen, `Value(null)` =
    // Zuordnung entfernen, `Value(id)` = (neu) zuordnen — anders als die
    // übrigen Felder hier braucht die Projektzuordnung ein echtes
    // "wieder entfernen", kein reines "überschreiben oder unverändert".
    Value<String?> projectId = const Value.absent(),
    List<InvoiceItemInput>? items,
  }) async {
    return _db.transaction(() async {
      final existing = await findById(companyId: companyId, id: id);
      if (existing == null || existing.status != InvoiceStatus.draft) return null;
      if (items != null) _validateItemsForKind(existing.kind, items);

      await (_db.update(_db.invoices)..where((i) => i.id.equals(id)))
          .write(
        InvoicesCompanion(
          issueDate: issueDate == null ? const Value.absent() : Value(issueDate),
          serviceDate: serviceDate == null ? const Value.absent() : Value(serviceDate),
          paymentTerms: Value(paymentTerms ?? existing.paymentTerms),
          notes: Value(notes ?? existing.notes),
          projectId: projectId,
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

  /// Wandelt ein **finalisiertes** Angebot/Auftrag in einen neuen
  /// **Entwurf** einer anderen Dokumentart um (Kay-Nachtrag
  /// 2026-10-16). Erzeugt bewusst einen Entwurf statt direkt zu
  /// finalisieren — der Nutzer kann Positionen/Daten vor dem endgültigen
  /// Abschluss noch prüfen und anpassen, exakt wie bei jedem anderen
  /// neuen Dokument. Stunden-Positionen werden beim Umwandeln in einen
  /// Lieferschein automatisch **weggelassen** statt die Umwandlung ganz
  /// zu verweigern (Kay: "Lieferscheine ... KEINE Stunden" ist eine
  /// Regel für den Lieferschein selbst, keine Blockade der Umwandlung).
  ///
  /// Wirft [ArgumentError] bei einer nicht erlaubten Umwandlung (siehe
  /// [allowedConversionTargets]) und [StateError], wenn die Quelle
  /// nicht existiert oder noch nicht finalisiert ist. `null` wird nie
  /// zurückgegeben — anders als bei [finalize] ist ein ungültiger
  /// Aufruf hier immer ein Programmfehler des Aufrufers, kein normaler
  /// "nichts zu tun"-Fall.
  Future<Invoice> convertTo({
    required String companyId,
    required String sourceId,
    required DocumentKind targetKind,
  }) async {
    return _db.transaction(() async {
      final source = await findById(companyId: companyId, id: sourceId);
      if (source == null) {
        throw StateError('Quelldokument $sourceId existiert nicht in Firma $companyId.');
      }
      if (source.status != InvoiceStatus.finalized) {
        throw StateError('Nur finalisierte Dokumente können umgewandelt werden.');
      }
      final allowed = allowedConversionTargets[source.kind] ?? const {};
      if (!allowed.contains(targetKind)) {
        throw ArgumentError(
          'Umwandlung von ${source.kind.name} nach ${targetKind.name} ist nicht erlaubt.',
        );
      }

      final sourceItems = await itemsFor(sourceId);
      final newItems = [
        for (final item in sourceItems)
          if (!(targetKind == DocumentKind.deliveryNote && item.kind == InvoiceItemKind.hours))
            InvoiceItemInput(
              kind: item.kind,
              articleId: item.articleId,
              description: item.description,
              quantity: Decimal.parse(item.quantity),
              unitPriceCents: item.unitPriceCents,
              vatRatePercent: item.vatRatePercent,
              unit: item.unit,
              discountPercent: item.discountPercent,
              groupLabel: item.groupLabel,
            ),
      ];

      final id = _uuid.v4();
      final now = DateTime.now();
      await _db.into(_db.invoices).insert(
            InvoicesCompanion.insert(
              id: id,
              companyId: companyId,
              customerId: source.customerId,
              kind: Value(targetKind),
              status: InvoiceStatus.draft,
              issueDate: now,
              serviceDate: source.serviceDate,
              paymentTerms: Value(source.paymentTerms),
              notes: Value(source.notes),
              // C1 Projekte: Umwandlung bleibt im selben Projektkontext —
              // der Nutzer kann die Zuordnung danach wie jedes andere
              // Entwurfsfeld ändern.
              projectId: Value(source.projectId),
              convertedFromId: Value(sourceId),
              createdAt: now,
              updatedAt: now,
            ),
          );
      await _replaceItems(id, newItems);
      return (await findById(companyId: companyId, id: id))!;
    });
  }

  /// Alle Dokumente, die per [convertTo] aus [sourceId] entstanden sind
  /// — für die Anzeige "Daraus erstellt: ..." auf dem Quelldokument.
  Future<List<Invoice>> listConvertedFrom(String sourceId) =>
      (_db.select(_db.invoices)..where((i) => i.convertedFromId.equals(sourceId))).get();

  /// Alle einem Projekt zugeordneten Dokumente, **über alle
  /// [DocumentKind]s hinweg** (C1) — die Projektansicht zeigt bewusst
  /// Angebot/Auftrag/Rechnung/Lieferschein/Proforma gemeinsam, nicht nur
  /// Rechnungen.
  Future<List<Invoice>> listForProject({required String companyId, required String projectId}) =>
      (_db.select(_db.invoices)
            ..where((i) => i.companyId.equals(companyId) & i.projectId.equals(projectId))
            ..orderBy([(i) => OrderingTerm.desc(i.updatedAt)]))
          .get();

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
          discountPercent: item.discountPercent,
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
              unit: Value(item.unit),
              discountPercent: Value(item.discountPercent),
              groupLabel: Value(item.groupLabel),
              sortOrder: i,
            ),
          );
    }
  }
}
