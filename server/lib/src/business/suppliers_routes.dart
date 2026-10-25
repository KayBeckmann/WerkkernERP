import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:uuid/uuid.dart';
import 'package:werkkern_core/werkkern_core.dart';

import '../auth.dart';
import '../util/responses.dart';
import 'models.dart';
import 'repository.dart';
import 'request_util.dart';
import 'suppliers.dart';

/// Lieferanten, Artikelgruppen und Einkaufspreise — Lesen mit
/// `articles.read`, Pflege mit `articles.write` (Stammdaten des
/// Artikelbereichs, wie offline unter „Artikel“).
class SupplierRoutes {
  SupplierRoutes({required this.business, required this.auth});

  final BusinessRepository business;
  final SessionAuthenticator auth;
  static const _uuid = Uuid();

  void mount(Router router) {
    router.get('/suppliers', _listSuppliers);
    router.post('/suppliers', _createSupplier);
    router.get('/suppliers/<id>', _getSupplier);
    router.put('/suppliers/<id>', _updateSupplier);
    router.delete('/suppliers/<id>', _deleteSupplier);

    router.get('/article-groups', _listGroups);
    router.post('/article-groups', _createGroup);
    router.put('/article-groups/<id>', _updateGroup);
    router.delete('/article-groups/<id>', _deleteGroup);

    router.get('/articles/<id>/prices', _listPrices);
    router.put('/articles/<id>/prices/<supplierId>', _setPrice);
    router.delete('/articles/<id>/prices/<supplierId>', _removePrice);
  }

  // ---- Kalkulation ------------------------------------------------------------

  /// Artikel-JSON plus `calculatedSalePriceCents` (EK Standardlieferant ×
  /// Gruppenaufschlag) und `effectiveSalePriceCents` (manueller Preis
  /// vorrangig) — für Liste und Detail mit einer Abfrage je Tabelle.
  Future<List<Map<String, Object?>>> articlesJson(String companyId, List<Article> articles) async {
    final groups = {for (final g in await business.listArticleGroups(companyId)) g.id: g};
    final prices = {
      for (final p in await business.listArticlePrices(companyId)) '${p.articleId}|${p.supplierId}': p.purchasePriceCents,
    };
    return [
      for (final a in articles)
        () {
          final calculated = calculateSalePrice(
            defaultSupplierPurchasePriceCents:
                a.defaultSupplierId == null ? null : prices['${a.id}|${a.defaultSupplierId}'],
            articleGroupMarkupPercent: a.articleGroupId == null ? null : groups[a.articleGroupId]?.markupPercent,
          );
          return {
            ...a.toJson(),
            'articleGroupName': groups[a.articleGroupId]?.name,
            'calculatedSalePriceCents': calculated?.cents,
            'effectiveSalePriceCents': a.salePriceCents ?? calculated?.cents,
          };
        }(),
    ];
  }

  /// Prüft, dass Gruppe/Standardlieferant zur Firma gehören — eine fremde
  /// ID verhält sich wie eine nicht existierende (404).
  Future<Response?> validateArticleReferences(String companyId, {String? articleGroupId, String? defaultSupplierId}) async {
    if (articleGroupId != null && await business.findArticleGroup(companyId, articleGroupId) == null) {
      return jsonError('Artikelgruppe nicht gefunden.', status: 404);
    }
    if (defaultSupplierId != null && await business.findSupplier(companyId, defaultSupplierId) == null) {
      return jsonError('Lieferant nicht gefunden.', status: 404);
    }
    return null;
  }

  // ---- Lieferanten --------------------------------------------------------------

  Supplier? _supplierFromBody(Map<String, Object?> body, {required String id, required String companyId, required DateTime createdAt}) {
    final name = trimmedOrNull(body['name']);
    if (name == null) return null;
    return Supplier(
      id: id,
      companyId: companyId,
      name: name,
      address: trimmedOrNull(body['address']),
      email: trimmedOrNull(body['email']),
      phone: trimmedOrNull(body['phone']),
      vatId: trimmedOrNull(body['vatId']),
      contactPerson: trimmedOrNull(body['contactPerson']),
      notes: trimmedOrNull(body['notes']),
      minimumOrderQuantity: decimalOrNull(body['minimumOrderQuantity']),
      deliveryTerms: trimmedOrNull(body['deliveryTerms']),
      createdAt: createdAt,
    );
  }

  Future<Response> _listSuppliers(Request request) async {
    final check = await auth.requirePermission(request, 'articles.read');
    if (check.error != null) return check.error!;
    final suppliers = await business.listSuppliers(check.auth!.session.companyId, query: request.url.queryParameters['q']);
    return jsonOk({'suppliers': [for (final s in suppliers) s.toJson()]});
  }

  Future<Response> _getSupplier(Request request, String id) async {
    final check = await auth.requirePermission(request, 'articles.read');
    if (check.error != null) return check.error!;
    final supplier = await business.findSupplier(check.auth!.session.companyId, id);
    if (supplier == null) return jsonError('Lieferant nicht gefunden.', status: 404);
    return jsonOk(supplier.toJson());
  }

  Future<Response> _createSupplier(Request request) async {
    final check = await auth.requirePermission(request, 'articles.write');
    if (check.error != null) return check.error!;
    final supplier = _supplierFromBody(
      await readJsonBody(request),
      id: _uuid.v4(),
      companyId: check.auth!.session.companyId,
      createdAt: DateTime.now().toUtc(),
    );
    if (supplier == null) return jsonError('name ist Pflicht.');
    await business.createSupplier(supplier);
    await auth.audit(check.auth!, 'supplier.create', 'supplier', supplier.id);
    return jsonOk(supplier.toJson(), status: 201);
  }

  Future<Response> _updateSupplier(Request request, String id) async {
    final check = await auth.requirePermission(request, 'articles.write');
    if (check.error != null) return check.error!;
    final companyId = check.auth!.session.companyId;
    final existing = await business.findSupplier(companyId, id);
    if (existing == null) return jsonError('Lieferant nicht gefunden.', status: 404);
    final supplier = _supplierFromBody(await readJsonBody(request), id: id, companyId: companyId, createdAt: existing.createdAt);
    if (supplier == null) return jsonError('name ist Pflicht.');
    await business.updateSupplier(supplier);
    await auth.audit(check.auth!, 'supplier.update', 'supplier', id);
    return jsonOk(supplier.toJson());
  }

  Future<Response> _deleteSupplier(Request request, String id) async {
    final check = await auth.requirePermission(request, 'articles.write');
    if (check.error != null) return check.error!;
    try {
      if (!await business.deleteSupplier(check.auth!.session.companyId, id)) {
        return jsonError('Lieferant nicht gefunden.', status: 404);
      }
    } on BusinessConflict catch (e) {
      return jsonError(e.message, status: 409);
    }
    await auth.audit(check.auth!, 'supplier.delete', 'supplier', id);
    return Response(204);
  }

  // ---- Artikelgruppen -----------------------------------------------------------

  ({String? name, double? markup}) _groupFromBody(Map<String, Object?> body) {
    final markup = body['markupPercent'];
    return (name: trimmedOrNull(body['name']), markup: markup is num && markup >= 0 ? markup.toDouble() : null);
  }

  Future<Response> _listGroups(Request request) async {
    final check = await auth.requirePermission(request, 'articles.read');
    if (check.error != null) return check.error!;
    final groups = await business.listArticleGroups(check.auth!.session.companyId);
    return jsonOk({'articleGroups': [for (final g in groups) g.toJson()]});
  }

  Future<Response> _createGroup(Request request) async {
    final check = await auth.requirePermission(request, 'articles.write');
    if (check.error != null) return check.error!;
    final input = _groupFromBody(await readJsonBody(request));
    if (input.name == null || input.markup == null) return jsonError('name und markupPercent (>= 0) sind Pflicht.');
    final group = ArticleGroup(
      id: _uuid.v4(),
      companyId: check.auth!.session.companyId,
      name: input.name!,
      markupPercent: input.markup!,
      createdAt: DateTime.now().toUtc(),
    );
    await business.createArticleGroup(group);
    await auth.audit(check.auth!, 'articleGroup.create', 'articleGroup', group.id);
    return jsonOk(group.toJson(), status: 201);
  }

  Future<Response> _updateGroup(Request request, String id) async {
    final check = await auth.requirePermission(request, 'articles.write');
    if (check.error != null) return check.error!;
    final companyId = check.auth!.session.companyId;
    final existing = await business.findArticleGroup(companyId, id);
    if (existing == null) return jsonError('Artikelgruppe nicht gefunden.', status: 404);
    final input = _groupFromBody(await readJsonBody(request));
    if (input.name == null || input.markup == null) return jsonError('name und markupPercent (>= 0) sind Pflicht.');
    final group = ArticleGroup(
      id: id,
      companyId: companyId,
      name: input.name!,
      markupPercent: input.markup!,
      createdAt: existing.createdAt,
    );
    await business.updateArticleGroup(group);
    await auth.audit(check.auth!, 'articleGroup.update', 'articleGroup', id);
    return jsonOk(group.toJson());
  }

  Future<Response> _deleteGroup(Request request, String id) async {
    final check = await auth.requirePermission(request, 'articles.write');
    if (check.error != null) return check.error!;
    if (!await business.deleteArticleGroup(check.auth!.session.companyId, id)) {
      return jsonError('Artikelgruppe nicht gefunden.', status: 404);
    }
    await auth.audit(check.auth!, 'articleGroup.delete', 'articleGroup', id);
    return Response(204);
  }

  // ---- Einkaufspreise -------------------------------------------------------------

  Future<Response> _listPrices(Request request, String id) async {
    final check = await auth.requirePermission(request, 'articles.read');
    if (check.error != null) return check.error!;
    final companyId = check.auth!.session.companyId;
    if (await business.findArticle(companyId, id) == null) return jsonError('Artikel nicht gefunden.', status: 404);
    final suppliers = {for (final s in await business.listSuppliers(companyId)) s.id: s.name};
    final prices = await business.listArticlePrices(companyId, articleId: id);
    return jsonOk({
      'prices': [
        for (final p in prices) {...p.toJson(), 'supplierName': suppliers[p.supplierId]},
      ],
    });
  }

  Future<Response> _setPrice(Request request, String id, String supplierId) async {
    final check = await auth.requirePermission(request, 'articles.write');
    if (check.error != null) return check.error!;
    final companyId = check.auth!.session.companyId;
    if (await business.findArticle(companyId, id) == null) return jsonError('Artikel nicht gefunden.', status: 404);
    if (await business.findSupplier(companyId, supplierId) == null) {
      return jsonError('Lieferant nicht gefunden.', status: 404);
    }
    final cents = (await readJsonBody(request))['purchasePriceCents'];
    if (cents is! int || cents < 0) return jsonError('purchasePriceCents (Ganzzahl >= 0) ist Pflicht.');
    final price = ArticleSupplierPrice(articleId: id, supplierId: supplierId, purchasePriceCents: cents);
    await business.setArticlePrice(companyId, price);
    await auth.audit(check.auth!, 'article.price.set', 'article', id);
    return jsonOk(price.toJson());
  }

  Future<Response> _removePrice(Request request, String id, String supplierId) async {
    final check = await auth.requirePermission(request, 'articles.write');
    if (check.error != null) return check.error!;
    if (!await business.removeArticlePrice(check.auth!.session.companyId, id, supplierId)) {
      return jsonError('Preis nicht gefunden.', status: 404);
    }
    await auth.audit(check.auth!, 'article.price.remove', 'article', id);
    return Response(204);
  }
}
