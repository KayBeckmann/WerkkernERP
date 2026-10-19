import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../database/database.dart';
import '../database/tables.dart';
import 'number_sequence_repository.dart';

/// Eine einzugebende Bestellposition (noch ohne ID — die vergibt das
/// Repository beim Speichern), analog zu `InvoiceItemInput`.
class PurchaseOrderItemInput {
  const PurchaseOrderItemInput({
    this.id,
    this.articleId,
    required this.description,
    required this.quantity,
    this.purchasePriceCents,
  });

  final String? id;
  final String? articleId;
  final String description;
  final double quantity;
  final int? purchasePriceCents;
}

/// Ein Artikel, der beim automatischen Erzeugen aus einem Auftrag oder
/// einer Mindestbestand-Meldung keinem Lieferanten/Preis zugeordnet
/// werden konnte (Roadmap: "Artikel ohne hinterlegten Lieferantenpreis
/// werden ausgeschlossen und separat als 'nicht zuordenbar'
/// aufgelistet"). Rein informativ für die UI — führt zu keinem Fehler.
class UnassignableArticle {
  const UnassignableArticle({
    required this.articleId,
    required this.articleName,
    required this.quantity,
  });
  final String articleId;
  final String articleName;
  final double quantity;
}

/// Ergebnis von [PurchaseOrderRepository.createDraftsFromOrder]: die
/// tatsächlich angelegten Entwürfe (ein oder mehrere, je nach
/// [PurchaseOrderCreationMode]) plus die Artikel, die dabei
/// ausgeschlossen wurden.
class PurchaseOrderDraftResult {
  const PurchaseOrderDraftResult({required this.drafts, required this.unassignable});
  final List<PurchaseOrder> drafts;
  final List<UnassignableArticle> unassignable;
}

/// Die beiden Wege, aus einem finalisierten Auftrag Bestellungen zu
/// erzeugen (Roadmap C5.2): entweder alles über einen frei gewählten
/// Lieferanten, oder je Artikel automatisch der günstigste bekannte
/// Lieferant — zusammengefasst zu **einer** Bestellung pro Lieferant,
/// nicht pro Artikel.
enum PurchaseOrderCreationMode { oneSupplierForAll, cheapestPerSupplier }

/// Eine Mindestbestand-Meldung, bereits nach Lieferant gruppiert und
/// automatisch mit allen anderen aktuell unterdeckten Artikeln desselben
/// Lieferanten zusammengefasst (Nachtrag 2026-10-19: "...schlägt vor,
/// mehrere Mindestbestand-Meldungen für denselben Lieferanten
/// zusammenzufassen, bevor eine Bestellung möglich ist" — Kay-
/// Entscheidung "gleich vollständig", nicht erst später). Live
/// berechnet, kein eigenes persistiertes Meldungs-Objekt (gleiches
/// Prinzip wie die TÜV-fällig-Anzeige bei Fahrzeugen).
class SupplierPurchaseSuggestion {
  const SupplierPurchaseSuggestion({
    required this.supplierId,
    required this.supplierName,
    required this.items,
    required this.minimumOrderQuantity,
  });
  final String supplierId;
  final String supplierName;
  final List<PurchaseOrderItemInput> items;

  /// `null` = keine Mindestbestellmenge für diesen Lieferanten
  /// hinterlegt — dann ist [meetsMinimumOrderQuantity] immer `true`.
  final double? minimumOrderQuantity;

  double get totalQuantity => items.fold(0.0, (sum, item) => sum + item.quantity);

  /// **Nicht blockierend** geprüft (gleiches "nur warnen"-Prinzip wie
  /// der Lagerbestand-Warnhinweis bei C5.1) — der Entwurf lässt sich
  /// trotzdem anlegen und vor dem Finalisieren noch von Hand auf die
  /// Mindestmenge anheben oder mit weiteren Positionen ergänzen. Eine
  /// harte Sperre hätte hier keinen Ausweg: alle aktuell unterdeckten
  /// Artikel dieses Lieferanten sind in [items] bereits automatisch
  /// zusammengefasst — mehr zum Zusammenfassen gibt es im Moment nicht.
  bool get meetsMinimumOrderQuantity =>
      minimumOrderQuantity == null || totalQuantity >= minimumOrderQuantity!;
}

class LowStockSuggestions {
  const LowStockSuggestions({required this.bySupplier, required this.unassignable});
  final List<SupplierPurchaseSuggestion> bySupplier;
  final List<UnassignableArticle> unassignable;
}

/// Bestellungen an Lieferanten (C5.2 Bestellwesen, Nachtrag 2026-10-19).
/// Gleiche companyId-Isolation wie alle übrigen Repositories. Bewusst
/// **kein** eigenes `convertTo()` — die beiden Entstehungswege
/// ([createDraftsFromOrder]/[createDraftFromSuggestion]) sind fachlich
/// zu verschieden von der generischen Angebot→Auftrag→Rechnung-Kette
/// (siehe Doc-Kommentar bei [PurchaseOrders] in tables.dart).
class PurchaseOrderRepository {
  PurchaseOrderRepository(this._db, this._numberSequences);

  final AppDatabase _db;
  final NumberSequenceRepository _numberSequences;
  static const _uuid = Uuid();

  Future<List<PurchaseOrder>> listForCompany(String companyId) =>
      (_db.select(_db.purchaseOrders)
            ..where((p) => p.companyId.equals(companyId))
            ..orderBy([(p) => OrderingTerm.desc(p.updatedAt)]))
          .get();

  Future<PurchaseOrder?> findById({required String companyId, required String id}) =>
      (_db.select(_db.purchaseOrders)
            ..where((p) => p.id.equals(id) & p.companyId.equals(companyId)))
          .getSingleOrNull();

  Future<List<PurchaseOrderItem>> itemsFor(String purchaseOrderId) =>
      (_db.select(_db.purchaseOrderItems)
            ..where((i) => i.purchaseOrderId.equals(purchaseOrderId)))
          .get();

  Future<void> _replaceItems(String purchaseOrderId, List<PurchaseOrderItemInput> items) async {
    await (_db.delete(_db.purchaseOrderItems)
          ..where((i) => i.purchaseOrderId.equals(purchaseOrderId)))
        .go();
    for (final item in items) {
      await _db.into(_db.purchaseOrderItems).insert(
            PurchaseOrderItemsCompanion.insert(
              id: item.id ?? _uuid.v4(),
              purchaseOrderId: purchaseOrderId,
              articleId: Value(item.articleId),
              description: item.description,
              quantity: item.quantity,
              purchasePriceCents: Value(item.purchasePriceCents),
            ),
          );
    }
  }

  /// Legt einen neuen Entwurf an — nummernlos, Status `draft` (gleiches
  /// F3-Prinzip wie bei einer Rechnung). [sourceOrderId] ist die reine
  /// Nachvollziehbarkeits-Markierung aus [createDraftsFromOrder]; beim
  /// eigenständigen Anlegen bleibt sie `null`.
  Future<PurchaseOrder> createDraft({
    required String companyId,
    required String supplierId,
    required DateTime issueDate,
    String? notes,
    String? sourceOrderId,
    // C5.3 Projekt-Ergebnisrechnung/SKR03-Kontierung (Nachtrag
    // 2026-10-19) — beides optional, `null` = keine Zuordnung
    // ("Lagerbestellung", siehe Doc-Kommentar bei
    // `PurchaseOrders.sourceOrderId`).
    String? projectId,
    String? expenseCategoryId,
    List<PurchaseOrderItemInput> items = const [],
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now();
    return _db.transaction(() async {
      await _db.into(_db.purchaseOrders).insert(
            PurchaseOrdersCompanion.insert(
              id: id,
              companyId: companyId,
              supplierId: supplierId,
              issueDate: issueDate,
              notes: Value(notes),
              sourceOrderId: Value(sourceOrderId),
              projectId: Value(projectId),
              expenseCategoryId: Value(expenseCategoryId),
              createdAt: now,
              updatedAt: now,
            ),
          );
      await _replaceItems(id, items);
      return (await findById(companyId: companyId, id: id))!;
    });
  }

  /// `null`, wenn die Bestellung nicht existiert oder bereits
  /// finalisiert ist (gleiches Verhalten wie `InvoiceRepository.update`
  /// bei einem nicht mehr editierbaren Dokument). [projectId]/
  /// [expenseCategoryId]/[relatedDocumentId] folgen dem `Value`-Muster
  /// (`Value.absent()` = unverändert, `Value(null)` = Zuordnung
  /// entfernen) — anders als die übrigen Felder hier brauchen optionale
  /// Zuordnungen ein echtes "wieder entfernen".
  Future<PurchaseOrder?> updateDraft({
    required String companyId,
    required String id,
    DateTime? issueDate,
    String? notes,
    String? supplierId,
    Value<String?> projectId = const Value.absent(),
    Value<String?> expenseCategoryId = const Value.absent(),
    Value<String?> relatedDocumentId = const Value.absent(),
    List<PurchaseOrderItemInput>? items,
  }) async {
    return _db.transaction(() async {
      final existing = await findById(companyId: companyId, id: id);
      if (existing == null || existing.status != PurchaseOrderStatus.draft) return null;
      await (_db.update(_db.purchaseOrders)..where((p) => p.id.equals(id))).write(
        PurchaseOrdersCompanion(
          issueDate: issueDate == null ? const Value.absent() : Value(issueDate),
          notes: Value(notes ?? existing.notes),
          supplierId: supplierId == null ? const Value.absent() : Value(supplierId),
          projectId: projectId,
          expenseCategoryId: expenseCategoryId,
          sourceOrderId: relatedDocumentId,
          updatedAt: Value(DateTime.now()),
        ),
      );
      if (items != null) await _replaceItems(id, items);
      return findById(companyId: companyId, id: id);
    });
  }

  Future<bool> deleteDraft({required String companyId, required String id}) async {
    final existing = await findById(companyId: companyId, id: id);
    if (existing == null || existing.status != PurchaseOrderStatus.draft) return false;
    final rows = await (_db.delete(_db.purchaseOrders)..where((p) => p.id.equals(id))).go();
    return rows > 0;
  }

  /// Finalisiert einen Entwurf: vergibt die nächste Nummer im Firmen-/
  /// Jahreskreis (`purchaseOrderDocumentType`, Präfix "B") und friert
  /// den Lieferanten-Schnappschuss ein — gleiches F3-Prinzip wie
  /// `InvoiceRepository.finalize()`. `null`, wenn die Bestellung nicht
  /// existiert oder bereits finalisiert ist. Wirft [StateError] bei
  /// einem Entwurf ohne Positionen.
  Future<PurchaseOrder?> finalize({required String companyId, required String id}) async {
    return _db.transaction(() async {
      final order = await findById(companyId: companyId, id: id);
      if (order == null || order.status != PurchaseOrderStatus.draft) return null;

      final items = await itemsFor(id);
      if (items.isEmpty) {
        throw StateError('Eine Bestellung ohne Positionen kann nicht finalisiert werden.');
      }

      final supplier =
          await (_db.select(_db.suppliers)..where((s) => s.id.equals(order.supplierId))).getSingle();

      final now = DateTime.now();
      final year = now.year;
      final number = await _numberSequences.allocateNext(
        companyId: companyId,
        documentType: purchaseOrderDocumentType,
        year: year,
      );
      final orderNumber = formatPurchaseOrderNumber(year: year, number: number);

      await (_db.update(_db.purchaseOrders)..where((p) => p.id.equals(id))).write(
        PurchaseOrdersCompanion(
          status: const Value(PurchaseOrderStatus.finalized),
          orderNumber: Value(orderNumber),
          numberYear: Value(year),
          finalizedAt: Value(now),
          updatedAt: Value(now),
          supplierSnapshotName: Value(supplier.name),
          supplierSnapshotAddress: Value(supplier.address),
        ),
      );
      return findById(companyId: companyId, id: id);
    });
  }

  /// Wareneingang, auch als Teillieferung (Roadmap: "Wareneingang (auch
  /// Teillieferungen) wird separat je Bestellung erfasst und erhöht den
  /// Lagerbestand entsprechend"). [receipts] ist eine **additive** Menge
  /// je `PurchaseOrderItem.id` (nicht absolut — gleiches Delta-Prinzip
  /// wie die dokumentgetriebene Buchung in `InvoiceRepository`), mehrere
  /// Aufrufe über die Zeit summieren sich auf. Erhöht bei jeder Position
  /// mit gesetzter `articleId` zusätzlich direkt den Lagerbestand des
  /// Artikels. `null`, wenn die Bestellung nicht existiert oder noch ein
  /// Entwurf ist (ein Entwurf wurde nie an den Lieferanten übermittelt,
  /// ein Wareneingang dazu ergibt fachlich keinen Sinn). Wirft
  /// [StateError]/[ArgumentError] bei einer zu hohen oder unbekannten
  /// Position — anders als die "nur warnen"-Entscheidung bei C5.1 ist
  /// ein Wareneingang über die bestellte Menge hinaus kein plausibler
  /// Geschäftsvorgang, sondern ein Eingabefehler, der blockiert gehört.
  ///
  /// C5.3 (Nachtrag 2026-10-19, Kay-Entscheidung auf Rückfrage "Beim
  /// Wareneingang, über Beleg-Kategorien"): bucht zusätzlich — in
  /// derselben Transaktion — je bewegtem Artikel eine unveränderliche
  /// [StockMovements]-Zeile sowie, wenn mindestens eine Position einen
  /// bekannten Einkaufspreis hat, **einen** automatischen Beleg
  /// (`Expenses`) über den Wert genau DIESES Wareneingangs (nicht der
  /// gesamten Bestellung — eine Teillieferung bucht nur ihren eigenen
  /// Anteil, im richtigen Zeitraum). Übernimmt `expenseCategoryId`
  /// (SKR03-Konto) und `projectId` 1:1 von der Bestellung — Letzteres
  /// ist der Mechanismus, über den eine zugeordnete Bestellung ECHT in
  /// die Projekt-Ergebnisrechnung einfließt (`ProjectDetailScreen`
  /// summiert Belege nach `projectId` bereits, kein neuer
  /// Berechnungscode nötig). Vereinfachung, bewusst dokumentiert: der
  /// Beleg wird ohne Umsatzsteuer gebucht (`vatRatePercent: 0`), da
  /// Bestellungen in diesem ersten Entwurf keine USt. erfassen (siehe
  /// `purchase_order_pdf_builder.dart`) — der erzeugte Beleg ist wie
  /// jeder andere danach frei editierbar, falls eine Korrektur nötig
  /// ist (anders als eine finalisierte Rechnung).
  Future<PurchaseOrder?> receiveGoods({
    required String companyId,
    required String id,
    required Map<String, double> receipts,
  }) async {
    return _db.transaction(() async {
      final order = await findById(companyId: companyId, id: id);
      if (order == null ||
          (order.status != PurchaseOrderStatus.finalized &&
              order.status != PurchaseOrderStatus.partiallyReceived)) {
        return null;
      }

      final items = await itemsFor(id);
      final itemsById = {for (final item in items) item.id: item};
      var receivedValueCents = 0;
      final now = DateTime.now();

      for (final entry in receipts.entries) {
        if (entry.value <= 0) continue;
        final item = itemsById[entry.key];
        if (item == null) {
          throw ArgumentError('Position ${entry.key} gehört nicht zu dieser Bestellung.');
        }
        final newReceived = item.receivedQuantity + entry.value;
        if (newReceived > item.quantity) {
          throw StateError(
            'Wareneingang für "${item.description}" ($newReceived) übersteigt die bestellte '
            'Menge (${item.quantity}).',
          );
        }
        await (_db.update(_db.purchaseOrderItems)..where((i) => i.id.equals(item.id)))
            .write(PurchaseOrderItemsCompanion(receivedQuantity: Value(newReceived)));
        if (item.purchasePriceCents != null) {
          receivedValueCents += (item.purchasePriceCents! * entry.value).round();
        }

        if (item.articleId != null) {
          final article = await (_db.select(_db.articles)..where((a) => a.id.equals(item.articleId!)))
              .getSingleOrNull();
          if (article != null) {
            final newStock = article.stockQuantity + entry.value;
            await (_db.update(_db.articles)..where((a) => a.id.equals(article.id)))
                .write(ArticlesCompanion(stockQuantity: Value(newStock)));
            await _db.into(_db.stockMovements).insert(
                  StockMovementsCompanion.insert(
                    id: _uuid.v4(),
                    companyId: companyId,
                    articleId: article.id,
                    type: StockMovementType.purchaseOrderReceipt,
                    quantityDelta: entry.value,
                    resultingQuantity: newStock,
                    referenceLabel: Value(order.orderNumber),
                    createdAt: now,
                  ),
                );
          }
        }
      }

      if (receivedValueCents > 0) {
        await _db.into(_db.expenses).insert(
              ExpensesCompanion.insert(
                id: _uuid.v4(),
                companyId: companyId,
                date: now,
                description: 'Wareneingang zu Bestellung ${order.orderNumber ?? order.id}',
                amountGrossCents: receivedValueCents,
                vatRatePercent: 0,
                categoryId: Value(order.expenseCategoryId),
                supplierReference: Value(order.orderNumber),
                projectId: Value(order.projectId),
                createdAt: now,
                updatedAt: now,
              ),
            );
      }

      final updatedItems = await itemsFor(id);
      final allReceived = updatedItems.every((i) => i.receivedQuantity >= i.quantity);
      final anyReceived = updatedItems.any((i) => i.receivedQuantity > 0);
      final newStatus = allReceived
          ? PurchaseOrderStatus.fullyReceived
          : anyReceived
              ? PurchaseOrderStatus.partiallyReceived
              : order.status;
      await (_db.update(_db.purchaseOrders)..where((p) => p.id.equals(id))).write(
        PurchaseOrdersCompanion(status: Value(newStatus), updatedAt: Value(now)),
      );
      return findById(companyId: companyId, id: id);
    });
  }

  /// Weg (a) aus der Roadmap: Bestellungen aus einem finalisierten
  /// Auftrag erstellen. Summiert zuerst die Artikel-Mengen über alle
  /// Positionen des Auftrags (mehrere Positionen desselben Artikels
  /// zählen zusammen, Stunden/Freitext werden ignoriert — kein
  /// Lagerbestand), dann je [mode] entweder eine einzige Bestellung bei
  /// [supplierId] oder eine Bestellung je günstigstem bekannten
  /// Lieferanten. Artikel ohne hinterlegten Preis beim jeweils
  /// relevanten Lieferanten werden ausgeschlossen und in
  /// [PurchaseOrderDraftResult.unassignable] aufgelistet statt die
  /// gesamte Operation abzubrechen.
  Future<PurchaseOrderDraftResult> createDraftsFromOrder({
    required String companyId,
    required String sourceOrderId,
    required PurchaseOrderCreationMode mode,
    String? supplierId,
  }) async {
    if (mode == PurchaseOrderCreationMode.oneSupplierForAll && supplierId == null) {
      throw ArgumentError('supplierId ist bei "Alles über einen Lieferanten" erforderlich.');
    }

    final order = await (_db.select(_db.invoices)
          ..where((i) => i.id.equals(sourceOrderId) & i.companyId.equals(companyId)))
        .getSingleOrNull();
    if (order == null || order.kind != DocumentKind.order || order.status != InvoiceStatus.finalized) {
      throw StateError('Bestellungen können nur aus einem finalisierten Auftrag erstellt werden.');
    }

    final sourceItems =
        await (_db.select(_db.invoiceItems)..where((i) => i.invoiceId.equals(sourceOrderId))).get();
    final quantityByArticle = <String, double>{};
    for (final item in sourceItems) {
      if (item.kind == InvoiceItemKind.article && item.articleId != null) {
        quantityByArticle[item.articleId!] =
            (quantityByArticle[item.articleId!] ?? 0) + double.parse(item.quantity);
      }
    }
    if (quantityByArticle.isEmpty) {
      return const PurchaseOrderDraftResult(drafts: [], unassignable: []);
    }

    return _db.transaction(() async {
      final unassignable = <UnassignableArticle>[];
      final drafts = <PurchaseOrder>[];

      if (mode == PurchaseOrderCreationMode.oneSupplierForAll) {
        final itemInputs = <PurchaseOrderItemInput>[];
        for (final entry in quantityByArticle.entries) {
          final article =
              await (_db.select(_db.articles)..where((a) => a.id.equals(entry.key))).getSingleOrNull();
          if (article == null) continue;
          final price = await (_db.select(_db.articleSupplierPrices)
                ..where((p) => p.articleId.equals(entry.key) & p.supplierId.equals(supplierId!)))
              .getSingleOrNull();
          if (price == null) {
            unassignable.add(
              UnassignableArticle(articleId: entry.key, articleName: article.name, quantity: entry.value),
            );
            continue;
          }
          itemInputs.add(
            PurchaseOrderItemInput(
              articleId: entry.key,
              description: article.name,
              quantity: entry.value,
              purchasePriceCents: price.purchasePriceCents,
            ),
          );
        }
        if (itemInputs.isNotEmpty) {
          drafts.add(
            await createDraft(
              companyId: companyId,
              supplierId: supplierId!,
              issueDate: DateTime.now(),
              sourceOrderId: sourceOrderId,
              projectId: order.projectId,
              items: itemInputs,
            ),
          );
        }
      } else {
        final itemsBySupplier = <String, List<PurchaseOrderItemInput>>{};
        for (final entry in quantityByArticle.entries) {
          final article =
              await (_db.select(_db.articles)..where((a) => a.id.equals(entry.key))).getSingleOrNull();
          if (article == null) continue;
          final prices = await (_db.select(_db.articleSupplierPrices)
                ..where((p) => p.articleId.equals(entry.key)))
              .get();
          if (prices.isEmpty) {
            unassignable.add(
              UnassignableArticle(articleId: entry.key, articleName: article.name, quantity: entry.value),
            );
            continue;
          }
          final cheapest = prices.reduce(
            (a, b) => a.purchasePriceCents <= b.purchasePriceCents ? a : b,
          );
          itemsBySupplier.putIfAbsent(cheapest.supplierId, () => []).add(
            PurchaseOrderItemInput(
              articleId: entry.key,
              description: article.name,
              quantity: entry.value,
              purchasePriceCents: cheapest.purchasePriceCents,
            ),
          );
        }
        for (final supplierEntry in itemsBySupplier.entries) {
          drafts.add(
            await createDraft(
              companyId: companyId,
              supplierId: supplierEntry.key,
              issueDate: DateTime.now(),
              sourceOrderId: sourceOrderId,
              projectId: order.projectId,
              items: supplierEntry.value,
            ),
          );
        }
      }

      return PurchaseOrderDraftResult(drafts: drafts, unassignable: unassignable);
    });
  }

  /// Weg (b) aus der Roadmap: live berechnete Mindestbestand-Meldungen
  /// (`stockQuantity < minimumStock`), automatisch nach Lieferant
  /// gruppiert (siehe [SupplierPurchaseSuggestion]). Bestellmenge je
  /// Artikel ist bewusst **der Fehlbetrag bis zum Mindestbestand**
  /// (`minimumStock - stockQuantity`, aufgefüllt auf genau die
  /// Schwelle) — eine einfache, nachvollziehbare und in der Vorschau vor
  /// dem Finalisieren noch frei änderbare Arbeitsvorgabe, keine
  /// Bedarfsprognose. Der zu bestellende Lieferant je Artikel ist der
  /// Standardlieferant, falls er einen hinterlegten Preis hat, sonst der
  /// günstigste bekannte (Roadmap: "sonst 'nicht zuordenbar' wie bei
  /// Modus (a)").
  Future<LowStockSuggestions> suggestFromLowStock(String companyId) async {
    final articles = await (_db.select(_db.articles)
          ..where((a) => a.companyId.equals(companyId) & a.active.equals(true)))
        .get();
    final lowStock =
        articles.where((a) => a.minimumStock != null && a.stockQuantity < a.minimumStock!);

    final itemsBySupplier = <String, List<PurchaseOrderItemInput>>{};
    final unassignable = <UnassignableArticle>[];

    for (final article in lowStock) {
      final shortfall = article.minimumStock! - article.stockQuantity;

      ArticleSupplierPrice? chosenPrice;
      if (article.defaultSupplierId != null) {
        chosenPrice = await (_db.select(_db.articleSupplierPrices)
              ..where(
                (p) => p.articleId.equals(article.id) & p.supplierId.equals(article.defaultSupplierId!),
              ))
            .getSingleOrNull();
      }
      if (chosenPrice == null) {
        final prices = await (_db.select(_db.articleSupplierPrices)
              ..where((p) => p.articleId.equals(article.id)))
            .get();
        if (prices.isNotEmpty) {
          chosenPrice = prices.reduce((a, b) => a.purchasePriceCents <= b.purchasePriceCents ? a : b);
        }
      }
      if (chosenPrice == null) {
        unassignable.add(
          UnassignableArticle(articleId: article.id, articleName: article.name, quantity: shortfall),
        );
        continue;
      }

      itemsBySupplier.putIfAbsent(chosenPrice.supplierId, () => []).add(
            PurchaseOrderItemInput(
              articleId: article.id,
              description: article.name,
              quantity: shortfall,
              purchasePriceCents: chosenPrice.purchasePriceCents,
            ),
          );
    }

    final suggestions = <SupplierPurchaseSuggestion>[];
    for (final entry in itemsBySupplier.entries) {
      final supplier =
          await (_db.select(_db.suppliers)..where((s) => s.id.equals(entry.key))).getSingleOrNull();
      if (supplier == null) continue;
      suggestions.add(
        SupplierPurchaseSuggestion(
          supplierId: supplier.id,
          supplierName: supplier.name,
          items: entry.value,
          minimumOrderQuantity: supplier.minimumOrderQuantity,
        ),
      );
    }
    return LowStockSuggestions(bySupplier: suggestions, unassignable: unassignable);
  }

  /// Materialisiert eine [SupplierPurchaseSuggestion] als echten Entwurf
  /// — bewusst unabhängig von [meetsMinimumOrderQuantity] (siehe
  /// Doc-Kommentar dort, "nur warnen"-Prinzip); die aufrufende UI zeigt
  /// den Hinweis vorher an und lässt den Nutzer bestätigen.
  Future<PurchaseOrder> createDraftFromSuggestion({
    required String companyId,
    required SupplierPurchaseSuggestion suggestion,
  }) =>
      createDraft(
        companyId: companyId,
        supplierId: suggestion.supplierId,
        issueDate: DateTime.now(),
        items: suggestion.items,
      );
}
