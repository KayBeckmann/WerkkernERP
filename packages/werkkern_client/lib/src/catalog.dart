import 'api_client.dart';
import 'models.dart';

/// Lieferanten, Artikelgruppen und Einkaufspreise (A1 online).
class OnlineSupplier {
  const OnlineSupplier({
    required this.id,
    required this.name,
    this.address,
    this.email,
    this.phone,
    this.vatId,
    this.contactPerson,
    this.notes,
    this.minimumOrderQuantity,
    this.deliveryTerms,
  });
  factory OnlineSupplier.fromJson(Map<String, Object?> j) => OnlineSupplier(
        id: j['id'] as String,
        name: j['name'] as String,
        address: j['address'] as String?,
        email: j['email'] as String?,
        phone: j['phone'] as String?,
        vatId: j['vatId'] as String?,
        contactPerson: j['contactPerson'] as String?,
        notes: j['notes'] as String?,
        minimumOrderQuantity: j['minimumOrderQuantity'] as String?,
        deliveryTerms: j['deliveryTerms'] as String?,
      );
  final String id;
  final String name;
  final String? address;
  final String? email;
  final String? phone;
  final String? vatId;
  final String? contactPerson;
  final String? notes;
  final String? minimumOrderQuantity;
  final String? deliveryTerms;

  Map<String, Object?> toWriteJson() => {
        'name': name,
        'address': address,
        'email': email,
        'phone': phone,
        'vatId': vatId,
        'contactPerson': contactPerson,
        'notes': notes,
        'minimumOrderQuantity': minimumOrderQuantity,
        'deliveryTerms': deliveryTerms,
      };
}

class OnlineArticleGroup {
  const OnlineArticleGroup({required this.id, required this.name, required this.markupPercent});
  factory OnlineArticleGroup.fromJson(Map<String, Object?> j) => OnlineArticleGroup(
        id: j['id'] as String,
        name: j['name'] as String,
        markupPercent: (j['markupPercent'] as num).toDouble(),
      );
  final String id;
  final String name;
  final double markupPercent;
}

class OnlineArticlePrice {
  const OnlineArticlePrice({required this.supplierId, this.supplierName, required this.purchasePriceCents});
  factory OnlineArticlePrice.fromJson(Map<String, Object?> j) => OnlineArticlePrice(
        supplierId: j['supplierId'] as String,
        supplierName: j['supplierName'] as String?,
        purchasePriceCents: j['purchasePriceCents'] as int,
      );
  final String supplierId;
  final String? supplierName;
  final int purchasePriceCents;
}

Map<String, Object?> _map(Object? value) => value as Map<String, Object?>;

extension CatalogApi on WerkkernApiClient {
  Future<OnlineArticle> article(String id) async => OnlineArticle.fromJson(_map(await request('GET', '/articles/$id')));

  Future<OnlineArticle> saveArticle(OnlineArticle article) async => OnlineArticle.fromJson(_map(article.id.isEmpty
      ? await request('POST', '/articles', body: article.toWriteJson())
      : await request('PUT', '/articles/${article.id}', body: article.toWriteJson())));

  Future<List<OnlineSupplier>> suppliers({String? query}) async {
    final j = _map(await request('GET', '/suppliers', query: {if (query != null && query.isNotEmpty) 'q': query}));
    return [for (final s in j['suppliers'] as List) OnlineSupplier.fromJson(s as Map<String, Object?>)];
  }

  Future<OnlineSupplier> saveSupplier(OnlineSupplier supplier) async => OnlineSupplier.fromJson(_map(supplier.id.isEmpty
      ? await request('POST', '/suppliers', body: supplier.toWriteJson())
      : await request('PUT', '/suppliers/${supplier.id}', body: supplier.toWriteJson())));

  Future<void> deleteSupplier(String id) => request('DELETE', '/suppliers/$id');

  Future<List<OnlineArticleGroup>> articleGroups() async {
    final j = _map(await request('GET', '/article-groups'));
    return [for (final g in j['articleGroups'] as List) OnlineArticleGroup.fromJson(g as Map<String, Object?>)];
  }

  Future<OnlineArticleGroup> saveArticleGroup({String? id, required String name, required double markupPercent}) async {
    final body = {'name': name, 'markupPercent': markupPercent};
    return OnlineArticleGroup.fromJson(_map(id == null
        ? await request('POST', '/article-groups', body: body)
        : await request('PUT', '/article-groups/$id', body: body)));
  }

  Future<void> deleteArticleGroup(String id) => request('DELETE', '/article-groups/$id');

  Future<List<OnlineArticlePrice>> articlePrices(String articleId) async {
    final j = _map(await request('GET', '/articles/$articleId/prices'));
    return [for (final p in j['prices'] as List) OnlineArticlePrice.fromJson(p as Map<String, Object?>)];
  }

  Future<void> setArticlePrice(String articleId, String supplierId, int purchasePriceCents) =>
      request('PUT', '/articles/$articleId/prices/$supplierId', body: {'purchasePriceCents': purchasePriceCents});

  Future<void> removeArticlePrice(String articleId, String supplierId) =>
      request('DELETE', '/articles/$articleId/prices/$supplierId');
}
