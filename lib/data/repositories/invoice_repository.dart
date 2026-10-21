import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../domain/models/money.dart';
import '../../domain/services/document_text_resolver.dart';
import '../../domain/services/invoice_totals_service.dart';
import '../../domain/services/stock_booking_service.dart';
import '../database/database.dart';
import '../database/tables.dart';
import 'number_sequence_repository.dart';
import 'time_entry_repository.dart';

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

/// C13 Abschlagsrechnungen — eine einzelne, bereits finalisierte
/// Abschlagsrechnung zum selben Quelldokument wie die Schlussrechnung
/// (Kay-Nachtrag 2026-10-21: "Diese müssen aufgeschlüsselt werden und
/// die Rechnungsnummern der Teilzahlungen müssen aufgelistet werden" —
/// vorher nur als eine Summe ohne Herkunft gezeigt, siehe Doc-Kommentar
/// bei `InvoiceRepository.listAdvancePaymentsForOrder`).
class AdvancePaymentEntry {
  const AdvancePaymentEntry({required this.invoiceNumber, required this.amountGross});
  final String invoiceNumber;
  final Money amountGross;
}

/// C5.1 Lagerbestand (Nachtrag 2026-10-19) — ein Artikel, der beim
/// Finalisieren unter 0 Lagerbestand fallen würde. Reine Anzeige-
/// Information für einen Warnhinweis, kein Blocker (siehe
/// `InvoiceRepository.checkStockBeforeFinalize`).
class StockWarning {
  const StockWarning({
    required this.articleId,
    required this.articleName,
    required this.availableQuantity,
    required this.requestedQuantity,
  });
  final String articleId;
  final String articleName;
  final double availableQuantity;
  final double requestedQuantity;
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
    // C13 Abschlagsrechnungen (Kay-Priorisierungsentscheidung 2026-10-17):
    // nur bei kind == invoice sinnvoll, sonst ignoriert — siehe Doc-
    // Kommentar bei `Invoices.isAdvancePayment`.
    bool isAdvancePayment = false,
    // C12 Mahnwesen (Kay-Priorisierungsentscheidung 2026-10-17): nur bei
    // kind == invoice sinnvoll, sonst ignoriert.
    DateTime? dueDate,
    // C3.2 Festpreis-Kennzeichen (Nachtrag 2026-10-20): nur bei kind ==
    // quote/order sinnvoll, siehe Doc-Kommentar bei
    // `Invoices.isFixedPrice`.
    bool isFixedPrice = false,
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
              isAdvancePayment: Value(isAdvancePayment),
              dueDate: Value(dueDate),
              isFixedPrice: Value(isFixedPrice),
              createdAt: now,
              updatedAt: now,
            ),
          );
      await _replaceItems(id, items);
      return (await findById(companyId: companyId, id: id))!;
    });
  }

  /// Ob ein Dokument noch über [update] bearbeitet werden darf.
  ///
  /// Kay-Entscheidung 2026-10-17 (siehe `Abweichungen.md` Abschnitt 1,
  /// Vault): "Ein intern 'finalisiertes' Angebot ist nicht automatisch
  /// derselbe unveränderliche Zustand wie eine finalisierte Rechnung."
  /// Ein Entwurf ist immer editierbar. Ein **finalisiertes** Dokument
  /// einer Art, die laut [allowedConversionTargets] überhaupt als Quelle
  /// einer Umwandlung dienen kann (aktuell Angebot/Auftrag/Proforma),
  /// bleibt editierbar, **solange noch keine Umwandlung daraus
  /// entstanden ist**. Rechnung und Lieferschein sind keine Quellen und
  /// bleiben deshalb wie bisher ab Finalisierung sofort unveränderlich.
  /// Nummer, Jahr, Status und Schnappschuss-Felder ändert [update]
  /// ohnehin nie — nur Felder/Positionen.
  Future<bool> isEditable(Invoice invoice) async {
    if (invoice.status == InvoiceStatus.draft) return true;
    if (!allowedConversionTargets.containsKey(invoice.kind)) return false;
    final converted = await listConvertedFrom(invoice.id);
    return converted.isEmpty;
  }

  /// Aktualisiert ein Dokument — siehe [isEditable] für die genaue Regel,
  /// wann das noch erlaubt ist. Finalisierungsdaten (Nummer, Jahr,
  /// Status, Schnappschüsse) bleiben davon unberührt; nur Felder/
  /// Positionen ändern sich.
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
    bool? isAdvancePayment,
    // C12 Mahnwesen: wie bei projectId braucht ein Fälligkeitsdatum ein
    // echtes "wieder entfernen".
    Value<DateTime?> dueDate = const Value.absent(),
    bool? isFixedPrice,
    List<InvoiceItemInput>? items,
  }) async {
    return _db.transaction(() async {
      final existing = await findById(companyId: companyId, id: id);
      if (existing == null || !(await isEditable(existing))) return null;
      if (items != null) _validateItemsForKind(existing.kind, items);

      await (_db.update(_db.invoices)..where((i) => i.id.equals(id)))
          .write(
        InvoicesCompanion(
          issueDate: issueDate == null ? const Value.absent() : Value(issueDate),
          serviceDate: serviceDate == null ? const Value.absent() : Value(serviceDate),
          paymentTerms: Value(paymentTerms ?? existing.paymentTerms),
          notes: Value(notes ?? existing.notes),
          projectId: projectId,
          isAdvancePayment: Value(isAdvancePayment ?? existing.isAdvancePayment),
          dueDate: dueDate,
          isFixedPrice: Value(isFixedPrice ?? existing.isFixedPrice),
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
          // Audit-Befund 2026-10-17 (Abweichungen.md Abschnitt 2.1):
          // Texte zum Finalisierungszeitpunkt einfrieren, damit eine
          // spätere Änderung an den Firmeneinstellungen das PDF dieser
          // Rechnung nicht mehr verändert (siehe `invoice_pdf_builder.dart`).
          pdfIntroTextSnapshot: Value(introTextFor(company, invoice.kind)),
          pdfClosingTextSnapshot: Value(closingTextFor(company, invoice.kind)),
          pdfFooterTextSnapshot: Value(company.pdfFooterText),
        ),
      );

      if (company.lagerbestandEnabled) {
        await _bookStockOnFinalize(
          companyId: companyId,
          invoice: invoice,
          items: items,
          referenceLabel: invoiceNumber,
        );
      }

      return findById(companyId: companyId, id: id);
    });
  }

  Future<DocumentKind?> _predecessorKind(Invoice invoice) async {
    if (invoice.convertedFromId == null) return null;
    final predecessor = await (_db.select(_db.invoices)
          ..where((i) => i.id.equals(invoice.convertedFromId!)))
        .getSingleOrNull();
    return predecessor?.kind;
  }

  /// Nur Positionen vom Typ Artikel (`InvoiceItemKind.article`) mit
  /// gesetzter `articleId` haben einen Lagerbestand — Stunden/Freitext
  /// werden ignoriert. Mehrere Positionen desselben Artikels in einem
  /// Dokument werden aufsummiert (eine Lese-/Schreib-Runde pro Artikel
  /// statt pro Position).
  Map<String, Decimal> _aggregateArticleQuantities(List<InvoiceItem> items) {
    final quantityByArticle = <String, Decimal>{};
    for (final item in items) {
      if (item.kind == InvoiceItemKind.article && item.articleId != null) {
        quantityByArticle[item.articleId!] =
            (quantityByArticle[item.articleId!] ?? Decimal.zero) + Decimal.parse(item.quantity);
      }
    }
    return quantityByArticle;
  }

  /// C5.1 Lagerbestand (Nachtrag 2026-10-19) — siehe
  /// `stock_booking_service.dart` für die Entscheidungsregel, wann
  /// überhaupt gebucht wird. Schreibt seit C5.3 ("Das muss alles
  /// dokumentiert werden") zusätzlich eine unveränderliche
  /// [StockMovements]-Zeile je gebuchtem Artikel, in derselben
  /// Transaktion wie die eigentliche Bestandsänderung.
  Future<void> _bookStockOnFinalize({
    required String companyId,
    required Invoice invoice,
    required List<InvoiceItem> items,
    required String referenceLabel,
  }) async {
    final predecessorKind = await _predecessorKind(invoice);
    if (!shouldBookStockOnFinalize(kind: invoice.kind, predecessorKind: predecessorKind)) {
      return;
    }

    for (final entry in _aggregateArticleQuantities(items).entries) {
      final article =
          await (_db.select(_db.articles)..where((a) => a.id.equals(entry.key))).getSingleOrNull();
      if (article == null) continue;
      final delta = -entry.value.toDouble();
      final newStock = article.stockQuantity + delta;
      await (_db.update(_db.articles)..where((a) => a.id.equals(entry.key)))
          .write(ArticlesCompanion(stockQuantity: Value(newStock)));
      await _db.into(_db.stockMovements).insert(
            StockMovementsCompanion.insert(
              id: _uuid.v4(),
              companyId: companyId,
              articleId: entry.key,
              type: StockMovementType.documentBooking,
              quantityDelta: delta,
              resultingQuantity: newStock,
              referenceLabel: Value(referenceLabel),
              createdAt: DateTime.now(),
            ),
          );
    }
  }

  /// Prüft **ohne zu buchen**, ob das Finalisieren von [id] einen oder
  /// mehrere Artikel unter 0 bringen würde — für einen Warnhinweis vor
  /// dem eigentlichen Finalisieren (Kay-Entscheidung: "Nur warnen,
  /// trotzdem erlauben", nicht blockieren). Liefert eine leere Liste,
  /// wenn das Modul aus ist, das Dokument laut
  /// `shouldBookStockOnFinalize()` ohnehin nicht buchen würde, oder
  /// überall genug Bestand vorhanden ist.
  Future<List<StockWarning>> checkStockBeforeFinalize({
    required String companyId,
    required String id,
  }) async {
    final company =
        await (_db.select(_db.companies)..where((c) => c.id.equals(companyId))).getSingleOrNull();
    if (company == null || !company.lagerbestandEnabled) return const [];

    final invoice = await findById(companyId: companyId, id: id);
    if (invoice == null) return const [];
    final predecessorKind = await _predecessorKind(invoice);
    if (!shouldBookStockOnFinalize(kind: invoice.kind, predecessorKind: predecessorKind)) {
      return const [];
    }

    final items = await itemsFor(id);
    final warnings = <StockWarning>[];
    for (final entry in _aggregateArticleQuantities(items).entries) {
      final article =
          await (_db.select(_db.articles)..where((a) => a.id.equals(entry.key))).getSingleOrNull();
      if (article == null) continue;
      final requested = entry.value.toDouble();
      if (article.stockQuantity - requested < 0) {
        warnings.add(
          StockWarning(
            articleId: article.id,
            articleName: article.name,
            availableQuantity: article.stockQuantity,
            requestedQuantity: requested,
          ),
        );
      }
    }
    return warnings;
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
  /// [timeEntryRepository] ist optional (`null` bei ausgeschaltetem
  /// Zeiterfassungs-Modul oder in bestehenden Aufrufern, die das noch
  /// nicht kennen) — ist er gesetzt UND wird ein Auftrag ohne Festpreis
  /// (`!source.isFixedPrice`) in eine Rechnung gewandelt, ersetzt
  /// [convertTo] alle Stunden-Positionen durch **eine** zusammengefasste
  /// Position mit den tatsächlich gebuchten Ist-Stunden (siehe Doc-
  /// Kommentar bei `Invoices.isFixedPrice`, Nachtrag 2026-10-20: "Sofern
  /// keine Festpreise vereinbart sind, müssen am Ende aber gebuchte
  /// Zeiten in die Rechnung überführt werden"). Vereinfachung, bewusst
  /// dokumentiert: Preis/Einheit/MwSt./Gruppe der ERSTEN Stunden-
  /// Position werden übernommen — bei mehreren unterschiedlich
  /// bepreisten Stunden-Positionen im Auftrag ist das eine bewusste
  /// Vereinfachung für diesen ersten Entwurf, vor dem Finalisieren im
  /// Rechnungseditor frei korrigierbar.
  Future<Invoice> convertTo({
    required String companyId,
    required String sourceId,
    required DocumentKind targetKind,
    TimeEntryRepository? timeEntryRepository,
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

      double? actualBookedHours;
      if (timeEntryRepository != null &&
          source.kind == DocumentKind.order &&
          targetKind == DocumentKind.invoice &&
          !source.isFixedPrice &&
          sourceItems.any((i) => i.kind == InvoiceItemKind.hours)) {
        actualBookedHours = await timeEntryRepository.totalHoursForInvoice(sourceId);
      }

      final newItems = <InvoiceItemInput>[];
      InvoiceItem? firstHoursItem;
      for (final item in sourceItems) {
        if (targetKind == DocumentKind.deliveryNote && item.kind == InvoiceItemKind.hours) {
          continue; // Lieferschein enthält nie Stunden (bestehende Regel).
        }
        if (actualBookedHours != null && item.kind == InvoiceItemKind.hours) {
          firstHoursItem ??= item;
          continue;
        }
        newItems.add(
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
        );
      }
      if (firstHoursItem != null) {
        newItems.add(
          InvoiceItemInput(
            kind: InvoiceItemKind.hours,
            description: 'Geleistete Stunden (Ist-Zeit)',
            quantity: Decimal.parse(actualBookedHours!.toString()),
            unitPriceCents: firstHoursItem.unitPriceCents,
            vatRatePercent: firstHoursItem.vatRatePercent,
            unit: firstHoursItem.unit,
            groupLabel: firstHoursItem.groupLabel,
          ),
        );
      }

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
              // C3.2: Festpreis-Kennzeichen wandert mit, gleiches Prinzip
              // wie projectId.
              isFixedPrice: Value(source.isFixedPrice),
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

  /// C13 Abschlagsrechnungen (Kay-Priorisierungsentscheidung 2026-10-17,
  /// aufgeschlüsselt seit Nachtrag 2026-10-21: "Diese müssen
  /// aufgeschlüsselt werden und die Rechnungsnummern der Teilzahlungen
  /// müssen aufgelistet werden") — alle **finalisierten**
  /// Abschlagsrechnungen, die per [convertTo] aus demselben
  /// Quelldokument (typischerweise ein Auftrag) wie [orderId] entstanden
  /// sind, einzeln mit ihrer Rechnungsnummer und ihrem Bruttobetrag —
  /// für die Abzugszeilen in einer Schlussrechnung (PDF + Editor zeigen
  /// jede Teilzahlung einzeln, statt nur eine Summe ohne Herkunft).
  /// Arbeitsvorgabe (siehe Doc-Kommentar bei `Invoices.isAdvancePayment`):
  /// jeder Betrag enthält die volle USt der jeweiligen Abschlagsrechnung,
  /// keine Nettobetrachtung. Sortiert nach Rechnungsnummer, damit die
  /// Reihenfolge nicht von der (für den Leser bedeutungslosen)
  /// internen Erstellungsreihenfolge abhängt.
  Future<List<AdvancePaymentEntry>> listAdvancePaymentsForOrder(String orderId) async {
    final converted = await listConvertedFrom(orderId);
    final entries = <AdvancePaymentEntry>[];
    for (final doc in converted) {
      if (doc.kind == DocumentKind.invoice &&
          doc.isAdvancePayment &&
          doc.status == InvoiceStatus.finalized) {
        final total = (await totalsFor(doc.id)).totalGross;
        entries.add(AdvancePaymentEntry(invoiceNumber: doc.invoiceNumber!, amountGross: total));
      }
    }
    entries.sort((a, b) => a.invoiceNumber.compareTo(b.invoiceNumber));
    return entries;
  }

  /// Summe von [listAdvancePaymentsForOrder] — für Stellen, die nur den
  /// Gesamtbetrag brauchen, nicht die Aufschlüsselung.
  Future<Money> sumAdvancePaymentsForOrder(String orderId) async {
    final entries = await listAdvancePaymentsForOrder(orderId);
    return entries.fold<Money>(Money.zero(), (sum, e) => sum + e.amountGross);
  }

  /// Materialabschlagsrechnung (C3.2, Nachtrag 2026-10-20: "Für einen
  /// Auftrag möchte ich eine Materialabschlagsrechnung erstellen können:
  /// Alle Artikel / Ausgewählte Freitexte"). Nutzt bewusst die
  /// bestehende Abschlagsrechnung (`isAdvancePayment`, C13) wieder statt
  /// eines eigenen Dokumenttyps (Kay-Entscheidung auf Rückfrage) — der
  /// entstehende Entwurf ist technisch eine ganz normale
  /// Abschlagsrechnung, nur mit einer **Teilmenge** der Positionen
  /// vorausgefüllt (anders als [createCreditNoteDraft]/[convertTo], die
  /// immer ALLE Positionen kopieren), und bleibt vor dem Finalisieren
  /// frei editierbar. [includeAllArticles] übernimmt jede Artikel-
  /// Position vollständig; [selectedFreetextItemIds] übernimmt gezielt
  /// einzelne Freitext-Positionen (Stunden-Positionen werden nie
  /// übernommen — eine Materialabschlagsrechnung ist per Definition
  /// Material, siehe Nachtrag). Wirft [ArgumentError], wenn danach keine
  /// einzige Position übrig bleibt (sonst ein stiller Leer-Entwurf ohne
  /// erkennbaren Grund).
  Future<Invoice> createMaterialAdvanceDraft({
    required String companyId,
    required String sourceOrderId,
    bool includeAllArticles = false,
    Set<String> selectedFreetextItemIds = const {},
  }) async {
    return _db.transaction(() async {
      final source = await findById(companyId: companyId, id: sourceOrderId);
      if (source == null) {
        throw StateError('Auftrag $sourceOrderId existiert nicht in Firma $companyId.');
      }
      if (source.kind != DocumentKind.order) {
        throw ArgumentError('Eine Materialabschlagsrechnung kann nur zu einem Auftrag erstellt werden.');
      }
      if (source.status != InvoiceStatus.finalized) {
        throw StateError('Nur ein finalisierter Auftrag kann eine Materialabschlagsrechnung erhalten.');
      }

      final sourceItems = await itemsFor(sourceOrderId);
      final newItems = [
        for (final item in sourceItems)
          if ((includeAllArticles && item.kind == InvoiceItemKind.article) ||
              (item.kind == InvoiceItemKind.text && selectedFreetextItemIds.contains(item.id)))
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
      if (newItems.isEmpty) {
        throw ArgumentError(
          'Materialabschlagsrechnung ohne jede gewählte Position — "Alle Artikel" oder '
          'mindestens einen Freitext auswählen.',
        );
      }

      final id = _uuid.v4();
      final now = DateTime.now();
      await _db.into(_db.invoices).insert(
            InvoicesCompanion.insert(
              id: id,
              companyId: companyId,
              customerId: source.customerId,
              kind: const Value(DocumentKind.invoice),
              status: InvoiceStatus.draft,
              issueDate: now,
              serviceDate: source.serviceDate,
              projectId: Value(source.projectId),
              isAdvancePayment: const Value(true),
              convertedFromId: Value(sourceOrderId),
              createdAt: now,
              updatedAt: now,
            ),
          );
      await _replaceItems(id, newItems);
      return (await findById(companyId: companyId, id: id))!;
    });
  }

  /// Gutschriften (Kay-Entscheidung 2026-10-19: "Gutschriften bekommen
  /// einen eigenen Nummernkreis"). **Bewusst NICHT über [convertTo]**,
  /// obwohl die Mechanik (Positionen kopieren, Entwurf mit
  /// `convertedFromId` anlegen) identisch wäre: [convertTo] setzt
  /// voraus, dass die Quelle ein Eintrag in [allowedConversionTargets]
  /// ist, und genau DAS würde [isEditable] für JEDE Rechnung bis zur
  /// ersten Gutschrift wieder aufschließen (siehe Doc-Kommentar dort) —
  /// eine finalisierte Rechnung muss aber immer sofort unveränderlich
  /// bleiben. Deshalb eine eigenständige, schlankere Methode, die
  /// `invoices.kind` nie in [allowedConversionTargets] einträgt.
  ///
  /// Kopiert die Positionen 1:1 (volle Gutschrift) — Kay kann den
  /// entstandenen Entwurf vor dem Finalisieren wie jeden anderen
  /// Entwurf auf eine Teil-Gutschrift herunterkürzen. Arbeitsvorgabe
  /// wie bei C13: volle USt der Originalpositionen, keine
  /// Nettobetrachtung.
  Future<Invoice> createCreditNoteDraft({
    required String companyId,
    required String invoiceId,
  }) async {
    return _db.transaction(() async {
      final source = await findById(companyId: companyId, id: invoiceId);
      if (source == null) {
        throw StateError('Rechnung $invoiceId existiert nicht in Firma $companyId.');
      }
      if (source.kind != DocumentKind.invoice) {
        throw ArgumentError('Eine Gutschrift kann nur zu einer Rechnung erstellt werden.');
      }
      if (source.status != InvoiceStatus.finalized) {
        throw StateError('Nur eine finalisierte Rechnung kann eine Gutschrift erhalten.');
      }

      final sourceItems = await itemsFor(invoiceId);
      final newItems = [
        for (final item in sourceItems)
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
              kind: const Value(DocumentKind.creditNote),
              status: InvoiceStatus.draft,
              issueDate: now,
              serviceDate: source.serviceDate,
              projectId: Value(source.projectId),
              convertedFromId: Value(invoiceId),
              createdAt: now,
              updatedAt: now,
            ),
          );
      await _replaceItems(id, newItems);
      return (await findById(companyId: companyId, id: id))!;
    });
  }

  /// Alle **finalisierten** Gutschriften zu einer Rechnung — für die
  /// Anzeige im Rechnungseditor ("Gutschriften zu diesem Dokument") und
  /// als Abzug in Offene-Posten/EÜR (siehe `open_items_service.dart`/
  /// `euer_service.dart`). Arbeitsvorgabe wie bei
  /// [sumAdvancePaymentsForOrder]: volle USt der Gutschrift.
  Future<List<Invoice>> listCreditNotesForInvoice(String invoiceId) async {
    final converted = await listConvertedFrom(invoiceId);
    return [
      for (final doc in converted)
        if (doc.kind == DocumentKind.creditNote && doc.status == InvoiceStatus.finalized) doc,
    ];
  }

  Future<Money> sumCreditNotesForInvoice(String invoiceId) async {
    var sum = Money.zero();
    for (final doc in await listCreditNotesForInvoice(invoiceId)) {
      sum = sum + (await totalsFor(doc.id)).totalGross;
    }
    return sum;
  }

  /// C12 Mahnwesen: manuell "als bezahlt markieren"/wieder zurücksetzen
  /// — kein Bankabgleich, keine Teilzahlungen (siehe Doc-Kommentar bei
  /// `Invoices.paymentStatus`). Nur für **finalisierte** Dokumente
  /// sinnvoll; ein Entwurf kennt keinen Zahlungsstatus im fachlichen
  /// Sinne.
  Future<Invoice?> markPaid({required String companyId, required String id}) async {
    final existing = await findById(companyId: companyId, id: id);
    if (existing == null || existing.status != InvoiceStatus.finalized) return null;
    await (_db.update(_db.invoices)..where((i) => i.id.equals(id))).write(
      InvoicesCompanion(
        paymentStatus: const Value(PaymentStatus.paid),
        paidAt: Value(DateTime.now()),
      ),
    );
    return findById(companyId: companyId, id: id);
  }

  Future<Invoice?> markOpen({required String companyId, required String id}) async {
    final existing = await findById(companyId: companyId, id: id);
    if (existing == null || existing.status != InvoiceStatus.finalized) return null;
    await (_db.update(_db.invoices)..where((i) => i.id.equals(id))).write(
      const InvoicesCompanion(
        paymentStatus: Value(PaymentStatus.open),
        paidAt: Value(null),
      ),
    );
    return findById(companyId: companyId, id: id);
  }

  /// C12 Mahnwesen — Nachbesserung (Kay-Feedback 2026-10-17): das
  /// Fälligkeitsdatum muss sich **auch nachträglich an einer bereits
  /// finalisierten Rechnung** setzen/ändern lassen. Ursprünglich lief
  /// das ausschließlich über [update], das aber wie jedes andere Feld
  /// durch [isEditable] blockiert wird — eine Rechnung ist ab
  /// Finalisierung sofort gesperrt (siehe Doc-Kommentar dort), wodurch
  /// ein erst NACH der Finalisierung aktiviertes Mahnwesen-Modul für
  /// bereits bestehende Rechnungen nie ein Fälligkeitsdatum bekommen
  /// konnte — der eigentliche Grund für "es wird nirgends etwas
  /// angezeigt". Das Fälligkeitsdatum ist reine Nachverfolgung, kein
  /// Teil des festgeschriebenen Rechnungsinhalts (Positionen/Summen/
  /// Nummer bleiben unberührt) — deshalb hier bewusst **ohne**
  /// [isEditable]-Prüfung, analog zu [markPaid]/[markOpen].
  Future<Invoice?> setDueDate({required String companyId, required String id, DateTime? dueDate}) async {
    final existing = await findById(companyId: companyId, id: id);
    if (existing == null) return null;
    await (_db.update(_db.invoices)..where((i) => i.id.equals(id)))
        .write(InvoicesCompanion(dueDate: Value(dueDate)));
    return findById(companyId: companyId, id: id);
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
