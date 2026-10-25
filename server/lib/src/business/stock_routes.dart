import 'package:decimal/decimal.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:uuid/uuid.dart';
import 'package:werkkern_core/werkkern_core.dart';

import '../auth.dart';
import '../repository.dart';
import '../util/responses.dart';
import 'repository.dart';
import 'request_util.dart';
import 'stock.dart';

/// Lager (C5.1/C5.3) — `stock.read`/`stock.write`, Modul `lagerbestand`.
/// Abbuchungen durch Dokumente laufen über das Finalisieren (siehe
/// `BusinessRoutes`), hier nur Einsicht, Inventur und Einzelkorrektur.
class StockRoutes {
  StockRoutes({required this.repository, required this.business, required this.auth});

  final PhaseBRepository repository;
  final BusinessRepository business;
  final SessionAuthenticator auth;
  static const _uuid = Uuid();

  void mount(Router router) {
    router.get('/stock/movements', _listMovements);
    router.get('/stock/low', _lowStock);
    router.post('/articles/<id>/stock-correction', _correct);
    router.get('/documents/<id>/stock-check', _stockCheck);

    router.get('/inventory-counts', _listCounts);
    router.post('/inventory-counts', _createCount);
    router.get('/inventory-counts/<id>', _getCount);
    router.post('/inventory-counts/<id>/articles', _addArticles);
    router.delete('/inventory-counts/<id>/items/<itemId>', _removeItem);
    router.put('/inventory-counts/<id>/items/<itemId>', _setCounted);
    router.post('/inventory-counts/<id>/complete', _complete);
  }

  Future<Response> _listMovements(Request request) async {
    final check = await auth.requirePermission(request, 'stock.read');
    if (check.error != null) return check.error!;
    final companyId = check.auth!.session.companyId;
    final movements = await business.listStockMovements(
      companyId,
      articleId: trimmedOrNull(request.url.queryParameters['articleId']),
    );
    final names = {for (final a in await business.listArticles(companyId, includeInactive: true)) a.id: a.name};
    return jsonOk({
      'movements': [
        for (final m in movements) {...m.toJson(), 'articleName': names[m.articleId]},
      ],
    });
  }

  /// Aktive Artikel mit Mindestbestand, deren Bestand darunter liegt.
  Future<Response> _lowStock(Request request) async {
    final check = await auth.requirePermission(request, 'stock.read');
    if (check.error != null) return check.error!;
    final articles = await business.listArticles(check.auth!.session.companyId);
    return jsonOk({
      'articles': [
        for (final a in articles)
          if (a.minimumStock != null && Decimal.parse(a.stockQuantity) < Decimal.parse(a.minimumStock!))
            {
              ...a.toJson(),
              'shortfall': (Decimal.parse(a.minimumStock!) - Decimal.parse(a.stockQuantity)).toString(),
            },
      ],
    });
  }

  /// Einzelkorrektur = Inventurlauf mit genau einem Artikel, damit jede
  /// Korrektur dokumentiert ist (wie offline). Grund ist Pflicht.
  Future<Response> _correct(Request request, String id) async {
    final check = await auth.requirePermission(request, 'stock.write');
    if (check.error != null) return check.error!;
    final companyId = check.auth!.session.companyId;
    final article = await business.findArticle(companyId, id);
    if (article == null) return jsonError('Artikel nicht gefunden.', status: 404);
    final body = await readJsonBody(request);
    final counted = decimalOrNull(body['countedQuantity']);
    final reason = trimmedOrNull(body['reason']);
    if (counted == null || reason == null) return jsonError('countedQuantity und reason sind Pflicht.');
    final now = DateTime.now().toUtc();
    final count = InventoryCount(
      id: _uuid.v4(),
      companyId: companyId,
      label: reason,
      date: DateTime.utc(now.year, now.month, now.day),
      status: 'draft',
      createdAt: now,
    );
    await business.createInventoryCount(count);
    await business.addInventoryArticles(companyId, count.id, [id], newId: _uuid.v4);
    final item = (await business.inventoryItems(companyId, count.id)).single;
    await business.setInventoryCounted(companyId, count.id, item.id, counted, now);
    final movements = await business.completeInventoryCount(companyId, count.id, userId: check.auth!.session.userId, now: now);
    await auth.audit(check.auth!, 'stock.correct', 'article', id);
    return jsonOk({
      'article': (await business.findArticle(companyId, id))!.toJson(),
      'movements': [for (final m in movements ?? const <StockMovement>[]) m.toJson()],
    });
  }

  /// Warnhinweise vor dem Finalisieren (nicht blockierend, wie offline):
  /// Artikel, deren Bestand für dieses Dokument nicht reicht.
  Future<Response> _stockCheck(Request request, String id) async {
    final check = await auth.requirePermission(request, 'invoices.read');
    if (check.error != null) return check.error!;
    final companyId = check.auth!.session.companyId;
    final document = await business.findDocument(companyId, id);
    if (document == null) return jsonError('Dokument nicht gefunden.', status: 404);
    final modules = (await repository.findCompanyById(companyId))?.enabledModules ?? const {};
    final predecessor =
        document.convertedFromId == null ? null : await business.findDocument(companyId, document.convertedFromId!);
    final books = modules.contains('lagerbestand') &&
        document.isDraft &&
        shouldBookStockOnFinalizeKind(kind: document.kind, predecessorKind: predecessor?.kind);
    final warnings = <Map<String, Object?>>[];
    if (books) {
      final quantities = articleQuantities(
        (await business.itemsFor(companyId, id)).map((i) => (articleId: i.articleId, quantity: i.quantity)),
      );
      for (final e in quantities.entries) {
        final article = await business.findArticle(companyId, e.key);
        if (article == null) continue;
        final available = Decimal.parse(article.stockQuantity);
        if (available < e.value) {
          warnings.add({
            'articleId': article.id,
            'articleName': article.name,
            'requested': e.value.toString(),
            'available': available.toString(),
          });
        }
      }
    }
    return jsonOk({'booksStock': books, 'warnings': warnings});
  }

  // ---- Inventur ---------------------------------------------------------------

  Future<Response> _listCounts(Request request) async {
    final check = await auth.requirePermission(request, 'stock.read');
    if (check.error != null) return check.error!;
    final counts = await business.listInventoryCounts(check.auth!.session.companyId);
    return jsonOk({'inventoryCounts': [for (final c in counts) c.toJson()]});
  }

  Future<Response> _countResponse(String companyId, InventoryCount count, {int status = 200}) async {
    final names = {for (final a in await business.listArticles(companyId, includeInactive: true)) a.id: a};
    return jsonOk({
      ...count.toJson(),
      'items': [
        for (final i in await business.inventoryItems(companyId, count.id))
          {
            ...i.toJson(),
            'articleName': names[i.articleId]?.name,
            'unit': names[i.articleId]?.unit,
            'currentQuantity': names[i.articleId]?.stockQuantity,
          },
      ],
    }, status: status);
  }

  Future<Response> _createCount(Request request) async {
    final check = await auth.requirePermission(request, 'stock.write');
    if (check.error != null) return check.error!;
    final companyId = check.auth!.session.companyId;
    final body = await readJsonBody(request);
    final label = trimmedOrNull(body['label']);
    if (label == null) return jsonError('label ist Pflicht.');
    final now = DateTime.now().toUtc();
    final count = InventoryCount(
      id: _uuid.v4(),
      companyId: companyId,
      label: label,
      date: dateOrNull(body['date']) ?? DateTime.utc(now.year, now.month, now.day),
      status: 'draft',
      createdAt: now,
    );
    await business.createInventoryCount(count);
    // Optional sofort alle aktiven Artikel aufnehmen ("volle Inventur").
    if (body['allArticles'] == true) {
      await business.addInventoryArticles(
        companyId,
        count.id,
        [for (final a in await business.listArticles(companyId)) a.id],
        newId: _uuid.v4,
      );
    }
    await auth.audit(check.auth!, 'inventory.create', 'inventoryCount', count.id);
    return _countResponse(companyId, count, status: 201);
  }

  Future<Response> _getCount(Request request, String id) async {
    final check = await auth.requirePermission(request, 'stock.read');
    if (check.error != null) return check.error!;
    final companyId = check.auth!.session.companyId;
    final count = await business.findInventoryCount(companyId, id);
    if (count == null) return jsonError('Inventur nicht gefunden.', status: 404);
    return _countResponse(companyId, count);
  }

  Future<Response> _draftCountOr404(String companyId, String id) async {
    final count = await business.findInventoryCount(companyId, id);
    if (count == null) return jsonError('Inventur nicht gefunden.', status: 404);
    return jsonError('Inventur ist abgeschlossen und unveränderlich.', status: 409);
  }

  Future<Response> _addArticles(Request request, String id) async {
    final check = await auth.requirePermission(request, 'stock.write');
    if (check.error != null) return check.error!;
    final companyId = check.auth!.session.companyId;
    final ids = (await readJsonBody(request))['articleIds'];
    if (ids is! List || ids.isEmpty) return jsonError('articleIds (Liste) ist Pflicht.');
    for (final articleId in ids) {
      if (articleId is! String || await business.findArticle(companyId, articleId) == null) {
        return jsonError('Artikel nicht gefunden.', status: 404);
      }
    }
    if (!await business.addInventoryArticles(companyId, id, ids.cast<String>(), newId: _uuid.v4)) {
      return _draftCountOr404(companyId, id);
    }
    return _countResponse(companyId, (await business.findInventoryCount(companyId, id))!);
  }

  Future<Response> _removeItem(Request request, String id, String itemId) async {
    final check = await auth.requirePermission(request, 'stock.write');
    if (check.error != null) return check.error!;
    final companyId = check.auth!.session.companyId;
    if (!await business.removeInventoryItem(companyId, id, itemId)) {
      final count = await business.findInventoryCount(companyId, id);
      if (count != null && count.isDraft) return jsonError('Position nicht gefunden.', status: 404);
      return _draftCountOr404(companyId, id);
    }
    return Response(204);
  }

  Future<Response> _setCounted(Request request, String id, String itemId) async {
    final check = await auth.requirePermission(request, 'stock.write');
    if (check.error != null) return check.error!;
    final companyId = check.auth!.session.companyId;
    final counted = decimalOrNull((await readJsonBody(request))['countedQuantity']);
    if (counted != null && Decimal.parse(counted) < Decimal.zero) return jsonError('Zählmenge darf nicht negativ sein.');
    if (!await business.setInventoryCounted(companyId, id, itemId, counted, DateTime.now().toUtc())) {
      final count = await business.findInventoryCount(companyId, id);
      if (count != null && count.isDraft) return jsonError('Position nicht gefunden.', status: 404);
      return _draftCountOr404(companyId, id);
    }
    return _countResponse(companyId, (await business.findInventoryCount(companyId, id))!);
  }

  Future<Response> _complete(Request request, String id) async {
    final check = await auth.requirePermission(request, 'stock.write');
    if (check.error != null) return check.error!;
    final companyId = check.auth!.session.companyId;
    final movements = await business.completeInventoryCount(
      companyId,
      id,
      userId: check.auth!.session.userId,
      now: DateTime.now().toUtc(),
    );
    if (movements == null) return _draftCountOr404(companyId, id);
    await auth.audit(check.auth!, 'inventory.complete', 'inventoryCount', id);
    return _countResponse(companyId, (await business.findInventoryCount(companyId, id))!);
  }
}
