/// Lieferanten, Artikelgruppen und Einkaufspreise je Lieferant online
/// (A1 der Offline-App). Kalkulation des Verkaufspreises über
/// `calculateSalePrice` aus `werkkern_core` — identisch zur Offline-App.
library;

class Supplier {
  const Supplier({
    required this.id,
    required this.companyId,
    required this.name,
    this.address,
    this.email,
    this.phone,
    this.vatId,
    this.contactPerson,
    this.notes,
    this.minimumOrderQuantity,
    this.deliveryTerms,
    required this.createdAt,
  });
  final String id;
  final String companyId;
  final String name;
  final String? address;
  final String? email;
  final String? phone;
  final String? vatId;
  final String? contactPerson;
  final String? notes;

  /// Dezimal als String (wie Mengen in Positionen), z. B. "10" oder "2.5".
  final String? minimumOrderQuantity;
  final String? deliveryTerms;
  final DateTime createdAt;

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'address': address,
        'email': email,
        'phone': phone,
        'vatId': vatId,
        'contactPerson': contactPerson,
        'notes': notes,
        'minimumOrderQuantity': minimumOrderQuantity,
        'deliveryTerms': deliveryTerms,
        'createdAt': createdAt.toIso8601String(),
      };
}

/// Artikelgruppe mit prozentualem Aufschlag (≠ Positionsgruppe im Dokument).
class ArticleGroup {
  const ArticleGroup({
    required this.id,
    required this.companyId,
    required this.name,
    required this.markupPercent,
    required this.createdAt,
  });
  final String id;
  final String companyId;
  final String name;
  final double markupPercent;
  final DateTime createdAt;

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'markupPercent': markupPercent,
        'createdAt': createdAt.toIso8601String(),
      };
}

/// Einkaufspreis eines Artikels bei genau einem Lieferanten (je Paar
/// höchstens ein Preis).
class ArticleSupplierPrice {
  const ArticleSupplierPrice({
    required this.articleId,
    required this.supplierId,
    required this.purchasePriceCents,
  });
  final String articleId;
  final String supplierId;
  final int purchasePriceCents;

  Map<String, Object?> toJson() => {
        'articleId': articleId,
        'supplierId': supplierId,
        'purchasePriceCents': purchasePriceCents,
      };
}

/// Teil von `BusinessRepository` — wie dort ist jede Methode
/// firmengebunden; eine fremde ID verhält sich wie eine nicht existierende.
abstract interface class SupplierStore {
  Future<List<Supplier>> listSuppliers(String companyId, {String? query});
  Future<Supplier?> findSupplier(String companyId, String id);
  Future<void> createSupplier(Supplier supplier);
  Future<bool> updateSupplier(Supplier supplier);

  /// Entfernt auch seine Einkaufspreise; Artikel verlieren ihn als
  /// Standardlieferanten (wie offline `onDelete: setNull`).
  Future<bool> deleteSupplier(String companyId, String id);

  Future<List<ArticleGroup>> listArticleGroups(String companyId);
  Future<ArticleGroup?> findArticleGroup(String companyId, String id);
  Future<void> createArticleGroup(ArticleGroup group);
  Future<bool> updateArticleGroup(ArticleGroup group);

  /// Artikel der Gruppe bleiben erhalten, nur ohne Gruppe.
  Future<bool> deleteArticleGroup(String companyId, String id);

  /// Alle Einkaufspreise der Firma, optional nur eines Artikels.
  Future<List<ArticleSupplierPrice>> listArticlePrices(String companyId, {String? articleId});

  /// Legt den Preis an oder ersetzt ihn (je Artikel/Lieferant einer).
  /// Aufrufer prüft vorher, dass Artikel und Lieferant zur Firma gehören.
  Future<void> setArticlePrice(String companyId, ArticleSupplierPrice price);
  Future<bool> removeArticlePrice(String companyId, String articleId, String supplierId);
}
