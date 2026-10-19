import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../domain/models/money.dart';
import '../../domain/services/pricing_service.dart';
import '../database/database.dart';

/// Artikelstammdaten je Firma, inkl. Mehrlieferanten-Einkaufspreisen
/// (Brainstorming: "ein Artikel kann mehrere Lieferanten mit je eigenem
/// Einkaufspreis haben"). Gleiche companyId-Isolation wie
/// [CustomerRepository] — jede Methode verlangt die companyId und prüft
/// sie, auch bei den Lieferantenpreisen (sonst könnte eine erratene
/// articleId einer fremden Firma über eine andere Firmen-ID manipuliert
/// werden).
class ArticleRepository {
  ArticleRepository(this._db);

  final AppDatabase _db;
  static const _uuid = Uuid();

  Future<List<Article>> listForCompany(String companyId, {bool includeInactive = false}) {
    final query = _db.select(_db.articles)..where((a) => a.companyId.equals(companyId));
    if (!includeInactive) {
      query.where((a) => a.active.equals(true));
    }
    return query.get();
  }

  Future<Article?> findById({required String companyId, required String id}) =>
      (_db.select(_db.articles)
            ..where((a) => a.id.equals(id) & a.companyId.equals(companyId)))
          .getSingleOrNull();

  Future<Article> create({
    required String companyId,
    required String name,
    String? unit,
    String? articleGroupId,
    String? defaultSupplierId,
    int? manualSalePriceCents,
    // C5.1 Lagerbestand (Nachtrag 2026-10-19) — `null` = keine
    // Mindestbestand-Überwachung für diesen Artikel.
    double? minimumStock,
  }) async {
    final id = _uuid.v4();
    await _db.into(_db.articles).insert(
          ArticlesCompanion.insert(
            id: id,
            companyId: companyId,
            name: name,
            unit: Value(unit),
            articleGroupId: Value(articleGroupId),
            defaultSupplierId: Value(defaultSupplierId),
            manualSalePriceCents: Value(manualSalePriceCents),
            minimumStock: Value(minimumStock),
            createdAt: DateTime.now(),
          ),
        );
    return (await findById(companyId: companyId, id: id))!;
  }

  /// Nachtrag 2026-10-18: "Artikel können nicht nachträglich bearbeitet
  /// werden." Wie bei [CustomerRepository]/[SupplierRepository]:
  /// `Value.absent()` = unverändert, `Value(null)` = Zuordnung
  /// entfernen (bei [articleGroupId]/[defaultSupplierId]/
  /// [manualSalePriceCents]/[minimumStock]). **Nicht** für
  /// [stockQuantity] selbst — eine Bestandskorrektur ist ein eigener,
  /// gezielter Vorgang, siehe [setStock].
  Future<Article?> update({
    required String companyId,
    required String id,
    String? name,
    Value<String?> unit = const Value.absent(),
    Value<String?> articleGroupId = const Value.absent(),
    Value<String?> defaultSupplierId = const Value.absent(),
    Value<int?> manualSalePriceCents = const Value.absent(),
    Value<double?> minimumStock = const Value.absent(),
  }) async {
    final existing = await findById(companyId: companyId, id: id);
    if (existing == null) return null;
    await (_db.update(_db.articles)..where((a) => a.id.equals(id))).write(
      ArticlesCompanion(
        name: name == null ? const Value.absent() : Value(name),
        unit: unit,
        articleGroupId: articleGroupId,
        defaultSupplierId: defaultSupplierId,
        manualSalePriceCents: manualSalePriceCents,
        minimumStock: minimumStock,
      ),
    );
    return findById(companyId: companyId, id: id);
  }

  /// C5.1 Lagerbestand (Nachtrag 2026-10-19) — Bestandskorrektur
  /// (Inventur, Anfangsbestand, Korrektur außerhalb von Bestellungen/
  /// Dokumenten). Setzt den Lagerbestand auf [newQuantity] **absolut**,
  /// nicht relativ — bewusst anders als die Dokumenten-Buchung in
  /// `InvoiceRepository._bookStockOnFinalize()`, die einen Delta-Wert
  /// abzieht. Darf wie der Lagerbestand selbst negativ sein (keine
  /// zusätzliche Prüfung hier).
  Future<Article?> setStock({
    required String companyId,
    required String id,
    required double newQuantity,
  }) async {
    final rows = await (_db.update(_db.articles)
          ..where((a) => a.id.equals(id) & a.companyId.equals(companyId)))
        .write(ArticlesCompanion(stockQuantity: Value(newQuantity)));
    if (rows == 0) return null;
    return findById(companyId: companyId, id: id);
  }

  /// Deaktivieren statt löschen (Nachtrag 2026-10-18: "Artikel müssen
  /// deaktiviert werden können, wenn der Hersteller sie abkündigt") —
  /// bereits erfasste Positionen bleiben unverändert, der Artikel
  /// verschwindet nur aus Auswahllisten für neue Positionen.
  Future<bool> setActive({required String companyId, required String id, required bool active}) async {
    final rows = await (_db.update(_db.articles)
          ..where((a) => a.id.equals(id) & a.companyId.equals(companyId)))
        .write(ArticlesCompanion(active: Value(active)));
    return rows > 0;
  }

  /// Legt den Einkaufspreis eines Artikels bei einem Lieferanten an oder
  /// aktualisiert ihn (ein Artikel ↔ Lieferant-Paar hat genau einen
  /// Preis, siehe `uniqueKeys` auf [ArticleSupplierPrices]). Prüft, dass
  /// [articleId] tatsächlich zu [companyId] gehört, bevor geschrieben
  /// wird.
  Future<void> setSupplierPrice({
    required String companyId,
    required String articleId,
    required String supplierId,
    required int purchasePriceCents,
  }) async {
    final article = await findById(companyId: companyId, id: articleId);
    if (article == null) {
      throw StateError('Artikel $articleId gehört nicht zu Firma $companyId');
    }

    final existing = await (_db.select(_db.articleSupplierPrices)
          ..where((p) => p.articleId.equals(articleId) & p.supplierId.equals(supplierId)))
        .getSingleOrNull();

    if (existing != null) {
      await (_db.update(_db.articleSupplierPrices)..where((p) => p.id.equals(existing.id)))
          .write(ArticleSupplierPricesCompanion(purchasePriceCents: Value(purchasePriceCents)));
    } else {
      await _db.into(_db.articleSupplierPrices).insert(
            ArticleSupplierPricesCompanion.insert(
              id: _uuid.v4(),
              articleId: articleId,
              supplierId: supplierId,
              purchasePriceCents: purchasePriceCents,
              createdAt: DateTime.now(),
            ),
          );
    }
  }

  Future<List<ArticleSupplierPrice>> supplierPricesFor(String articleId) =>
      (_db.select(_db.articleSupplierPrices)..where((p) => p.articleId.equals(articleId))).get();

  /// Der tatsächlich zu verwendende Netto-Verkaufspreis: ein manuell
  /// gesetzter Preis überschreibt immer die Kalkulation aus
  /// Standardlieferant + Artikelgruppen-Aufschlag (siehe
  /// [calculateSalePrice] für die Randfall-Entscheidungen).
  Future<Money?> effectiveSalePrice({required String companyId, required String articleId}) async {
    final article = await findById(companyId: companyId, id: articleId);
    if (article == null) return null;
    if (article.manualSalePriceCents != null) {
      return Money.fromCents(article.manualSalePriceCents!);
    }

    int? defaultSupplierPurchasePriceCents;
    if (article.defaultSupplierId != null) {
      final price = await (_db.select(_db.articleSupplierPrices)
            ..where(
              (p) =>
                  p.articleId.equals(articleId) & p.supplierId.equals(article.defaultSupplierId!),
            ))
          .getSingleOrNull();
      defaultSupplierPurchasePriceCents = price?.purchasePriceCents;
    }

    double? markupPercent;
    if (article.articleGroupId != null) {
      final group = await (_db.select(_db.articleGroups)
            ..where((g) => g.id.equals(article.articleGroupId!)))
          .getSingleOrNull();
      markupPercent = group?.markupPercent;
    }

    return calculateSalePrice(
      defaultSupplierPurchasePriceCents: defaultSupplierPurchasePriceCents,
      articleGroupMarkupPercent: markupPercent,
    );
  }
}
