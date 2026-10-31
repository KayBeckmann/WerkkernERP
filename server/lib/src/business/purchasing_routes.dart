import 'package:decimal/decimal.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:uuid/uuid.dart';
import 'package:werkkern_core/werkkern_core.dart';

import '../auth.dart';
import '../util/responses.dart';
import 'models.dart';
import 'purchasing.dart';
import 'repository.dart';
import 'request_util.dart';

/// Bestellwesen (C5.2) — `purchaseOrders.read`/`purchaseOrders.write`,
/// Modul `bestellwesen`.
class PurchasingRoutes {
  PurchasingRoutes({required this.business, required this.auth});

  final BusinessRepository business;
  final SessionAuthenticator auth;
  static const _uuid = Uuid();

  void mount(Router router) {
    router.get('/purchase-orders', _list);
    router.post('/purchase-orders', _create);
    router.get('/purchase-orders/suggestions', _suggestions);
    router.post('/purchase-orders/from-suggestion', _fromSuggestion);
    router.get('/purchase-orders/<id>', _get);
    router.put('/purchase-orders/<id>', _update);
    router.delete('/purchase-orders/<id>', _delete);
    router.post('/purchase-orders/<id>/finalize', _finalize);
    router.post('/purchase-orders/<id>/receive', _receive);
    router.post('/documents/<id>/purchase-orders', _fromOrder);
  }

  Future<Response> _response(String companyId, PurchaseOrder order, {int status = 200}) async {
    final items = await business.purchaseOrderItems(companyId, order.id);
    final supplier = await business.findSupplier(companyId, order.supplierId);
    return jsonOk({
      ...order.toJson(),
      'supplierName': supplier?.name,
      'items': [for (final i in items) i.toJson()],
      'totalNetCents': _totalNetCents(items),
    }, status: status);
  }

  int _totalNetCents(List<PurchaseOrderItem> items) {
    var total = 0;
    for (final i in items) {
      if (i.purchasePriceCents != null) {
        total += Money.fromCents(i.purchasePriceCents!).multiplyByQuantity(Decimal.parse(i.quantity)).cents;
      }
    }
    return total;
  }

  /// Text für den Bestätigungsdialog einer Agent-Freigabe (C8).
  Future<String> _summary(String companyId, PurchaseOrder order) async {
    final supplier = await business.findSupplier(companyId, order.supplierId);
    final total = Money.fromCents(_totalNetCents(await business.purchaseOrderItems(companyId, order.id)));
    return 'Bestellung ${order.number ?? '(Entwurf)'} bei ${supplier?.name ?? 'unbekanntem Lieferanten'} über $total netto';
  }

  /// Positionen aus dem Body; Artikel müssen zur Firma gehören.
  Future<({List<PurchaseOrderItem>? items, Response? error})> _items(Object? raw, String companyId, String orderId) async {
    if (raw is! List) return (items: null, error: jsonError('items (Liste) ist Pflicht.'));
    final items = <PurchaseOrderItem>[];
    for (final (index, entry) in raw.indexed) {
      if (entry is! Map) return (items: null, error: jsonError('Position ${index + 1}: Objekt erwartet.'));
      final description = trimmedOrNull(entry['description']);
      final quantity = decimalOrNull(entry['quantity']);
      final price = entry['purchasePriceCents'];
      if (description == null || quantity == null || Decimal.parse(quantity) <= Decimal.zero) {
        return (items: null, error: jsonError('Position ${index + 1}: description und quantity (> 0) sind Pflicht.'));
      }
      if (price != null && (price is! int || price < 0)) {
        return (items: null, error: jsonError('Position ${index + 1}: purchasePriceCents muss >= 0 sein.'));
      }
      final articleId = trimmedOrNull(entry['articleId']);
      if (articleId != null && await business.findArticle(companyId, articleId) == null) {
        return (items: null, error: jsonError('Artikel nicht gefunden.', status: 404));
      }
      items.add(PurchaseOrderItem(
        id: _uuid.v4(),
        purchaseOrderId: orderId,
        articleId: articleId,
        description: description,
        quantity: quantity,
        purchasePriceCents: price as int?,
        sortOrder: index,
      ));
    }
    return (items: items, error: null);
  }

  Future<Response?> _validateRefs(String companyId, {required String? supplierId, String? projectId, String? categoryId}) async {
    if (supplierId == null) return jsonError('supplierId ist Pflicht.');
    if (await business.findSupplier(companyId, supplierId) == null) return jsonError('Lieferant nicht gefunden.', status: 404);
    if (projectId != null && await business.findProject(companyId, projectId) == null) {
      return jsonError('Projekt nicht gefunden.', status: 404);
    }
    if (categoryId != null && await business.findExpenseCategory(companyId, categoryId) == null) {
      return jsonError('Kategorie nicht gefunden.', status: 404);
    }
    return null;
  }

  Future<Response> _list(Request request) async {
    final check = await auth.requirePermission(request, 'purchaseOrders.read');
    if (check.error != null) return check.error!;
    final companyId = check.auth!.session.companyId;
    final orders = await business.listPurchaseOrders(
      companyId,
      status: trimmedOrNull(request.url.queryParameters['status']),
      sourceOrderId: trimmedOrNull(request.url.queryParameters['sourceOrderId']),
    );
    final names = {for (final s in await business.listSuppliers(companyId)) s.id: s.name};
    return jsonOk({
      'purchaseOrders': [
        for (final o in orders) {...o.toJson(), 'supplierName': o.supplierSnapshotName ?? names[o.supplierId]},
      ],
    });
  }

  Future<Response> _get(Request request, String id) async {
    final check = await auth.requirePermission(request, 'purchaseOrders.read');
    if (check.error != null) return check.error!;
    final companyId = check.auth!.session.companyId;
    final order = await business.findPurchaseOrder(companyId, id);
    if (order == null) return jsonError('Bestellung nicht gefunden.', status: 404);
    return _response(companyId, order);
  }

  Future<Response> _create(Request request) async {
    final check = await auth.requirePermission(request, 'purchaseOrders.write');
    if (check.error != null) return check.error!;
    final companyId = check.auth!.session.companyId;
    final body = await readJsonBody(request);
    final supplierId = trimmedOrNull(body['supplierId']);
    final projectId = trimmedOrNull(body['projectId']);
    final categoryId = trimmedOrNull(body['expenseCategoryId']);
    final invalid = await _validateRefs(companyId, supplierId: supplierId, projectId: projectId, categoryId: categoryId);
    if (invalid != null) return invalid;
    final id = _uuid.v4();
    final parsed = await _items(body['items'] ?? const [], companyId, id);
    if (parsed.error != null) return parsed.error!;
    final now = DateTime.now().toUtc();
    final order = PurchaseOrder(
      id: id,
      companyId: companyId,
      supplierId: supplierId!,
      status: 'draft',
      issueDate: dateOrNull(body['issueDate']) ?? DateTime.utc(now.year, now.month, now.day),
      notes: trimmedOrNull(body['notes']),
      projectId: projectId,
      expenseCategoryId: categoryId,
      createdByUserId: check.auth!.session.userId,
      createdAt: now,
      updatedAt: now,
      version: 1,
    );
    await business.createPurchaseOrder(order, parsed.items!);
    await auth.audit(check.auth!, 'purchaseOrder.create', 'purchaseOrder', id);
    return _response(companyId, order, status: 201);
  }

  Future<Response> _update(Request request, String id) async {
    final check = await auth.requirePermission(request, 'purchaseOrders.write');
    if (check.error != null) return check.error!;
    final companyId = check.auth!.session.companyId;
    final existing = await business.findPurchaseOrder(companyId, id);
    if (existing == null) return jsonError('Bestellung nicht gefunden.', status: 404);
    final body = await readJsonBody(request);
    final version = body['version'];
    if (version is! int) return jsonError('version (Ganzzahl) ist Pflicht.');
    final supplierId = trimmedOrNull(body['supplierId']) ?? existing.supplierId;
    final projectId = trimmedOrNull(body['projectId']);
    final categoryId = trimmedOrNull(body['expenseCategoryId']);
    final invalid = await _validateRefs(companyId, supplierId: supplierId, projectId: projectId, categoryId: categoryId);
    if (invalid != null) return invalid;
    final parsed = await _items(body['items'], companyId, id);
    if (parsed.error != null) return parsed.error!;
    try {
      final updated = await business.updatePurchaseOrderDraft(
        PurchaseOrder(
          id: id,
          companyId: companyId,
          supplierId: supplierId,
          status: 'draft',
          issueDate: dateOrNull(body['issueDate']) ?? existing.issueDate,
          notes: trimmedOrNull(body['notes']),
          projectId: projectId,
          expenseCategoryId: categoryId,
          createdByUserId: existing.createdByUserId,
          createdAt: existing.createdAt,
          updatedAt: DateTime.now().toUtc(),
          version: version,
        ),
        parsed.items!,
        expectedVersion: version,
      );
      if (updated == null) return jsonError('Bestellung nicht gefunden.', status: 404);
      await auth.audit(check.auth!, 'purchaseOrder.update', 'purchaseOrder', id);
      return await _response(companyId, updated);
    } on BusinessConflict catch (e) {
      return jsonError(e.message, status: 409);
    }
  }

  Future<Response> _delete(Request request, String id) async {
    final check = await auth.requirePermission(request, 'purchaseOrders.write');
    if (check.error != null) return check.error!;
    if (check.auth!.session.isAgent) {
      final order = await business.findPurchaseOrder(check.auth!.session.companyId, id);
      if (order == null) return jsonError('Bestellung nicht gefunden.', status: 404);
      if (!order.isDraft) return jsonError('Nur Entwürfe können gelöscht werden.', status: 409);
      return auth.requestApproval(
        check.auth!,
        method: 'DELETE',
        path: '/purchase-orders/$id',
        body: const {},
        summary: '${await _summary(check.auth!.session.companyId, order)} löschen',
      );
    }
    try {
      if (!await business.deletePurchaseOrderDraft(check.auth!.session.companyId, id)) {
        return jsonError('Bestellung nicht gefunden.', status: 404);
      }
    } on BusinessConflict catch (e) {
      return jsonError(e.message, status: 409);
    }
    await auth.audit(check.auth!, 'purchaseOrder.delete', 'purchaseOrder', id);
    return Response(204);
  }

  Future<Response> _finalize(Request request, String id) async {
    final check = await auth.requirePermission(request, 'purchaseOrders.write');
    if (check.error != null) return check.error!;
    final companyId = check.auth!.session.companyId;
    final body = await readJsonBody(request);
    final version = body['version'];
    if (version is! int) return jsonError('version (Ganzzahl) ist Pflicht.');
    if (check.auth!.session.isAgent) {
      final order = await business.findPurchaseOrder(companyId, id);
      if (order == null) return jsonError('Bestellung nicht gefunden.', status: 404);
      if (!order.isDraft) return jsonError('Bestellung ist bereits finalisiert.', status: 409);
      return auth.requestApproval(
        check.auth!,
        method: 'POST',
        path: '/purchase-orders/$id/finalize',
        body: body,
        summary: '${await _summary(companyId, order)} finalisieren (Version $version)',
      );
    }
    try {
      final order = await business.finalizePurchaseOrder(companyId, id, expectedVersion: version, now: DateTime.now().toUtc());
      if (order == null) return jsonError('Bestellung nicht gefunden.', status: 404);
      await auth.audit(check.auth!, 'purchaseOrder.finalize', 'purchaseOrder', id);
      return await _response(companyId, order);
    } on BusinessConflict catch (e) {
      return jsonError(e.message, status: 409);
    }
  }

  /// `{"receipts": {"<positionId>": "2.5", ...}}` — additive Mengen.
  Future<Response> _receive(Request request, String id) async {
    final check = await auth.requirePermission(request, 'purchaseOrders.write');
    if (check.error != null) return check.error!;
    final companyId = check.auth!.session.companyId;
    final body = await readJsonBody(request);
    final raw = body['receipts'];
    if (raw is! Map || raw.isEmpty) return jsonError('receipts (Position → Menge) ist Pflicht.');
    final receipts = <String, Decimal>{};
    for (final entry in raw.entries) {
      final quantity = decimalOrNull(entry.value);
      if (quantity == null || Decimal.parse(quantity) < Decimal.zero) return jsonError('Mengen müssen >= 0 sein.');
      receipts[entry.key as String] = Decimal.parse(quantity);
    }
    // Wareneingang bucht Lagerbewegungen — für Agenten nur per Freigabe.
    if (check.auth!.session.isAgent) {
      final order = await business.findPurchaseOrder(companyId, id);
      if (order == null) return jsonError('Bestellung nicht gefunden.', status: 404);
      return auth.requestApproval(
        check.auth!,
        method: 'POST',
        path: '/purchase-orders/$id/receive',
        body: body,
        summary: 'Wareneingang zu ${await _summary(companyId, order)} buchen (${receipts.length} Position(en))',
      );
    }
    try {
      final order = await business.receivePurchaseOrder(
        companyId,
        id,
        receipts: receipts,
        userId: check.auth!.session.userId,
        now: DateTime.now().toUtc(),
      );
      if (order == null) return jsonError('Bestellung nicht gefunden.', status: 404);
      await auth.audit(check.auth!, 'purchaseOrder.receive', 'purchaseOrder', id);
      return await _response(companyId, order);
    } on BusinessConflict catch (e) {
      return jsonError(e.message, status: 409);
    }
  }

  /// Entwürfe aus einem finalisierten Auftrag: `mode` = `oneSupplier`
  /// (mit `supplierId`) oder `cheapest` (je Artikel günstigster Lieferant,
  /// eine Bestellung je Lieferant). Artikel ohne Preis → `unassignable`.
  Future<Response> _fromOrder(Request request, String id) async {
    final check = await auth.requirePermission(request, 'purchaseOrders.write');
    if (check.error != null) return check.error!;
    if (!await auth.isGranted(check.auth!, 'invoices.read')) return jsonError('Keine Berechtigung: invoices.read', status: 403);
    final companyId = check.auth!.session.companyId;
    final document = await business.findDocument(companyId, id);
    if (document == null) return jsonError('Dokument nicht gefunden.', status: 404);
    if (document.kind != 'order' || document.isDraft) {
      return jsonError('Bestellungen nur aus einem finalisierten Auftrag.', status: 409);
    }
    final body = await readJsonBody(request);
    final mode = body['mode'];
    final supplierId = trimmedOrNull(body['supplierId']);
    if (mode != 'oneSupplier' && mode != 'cheapest') return jsonError('mode = oneSupplier oder cheapest.');
    if (mode == 'oneSupplier' && (supplierId == null || await business.findSupplier(companyId, supplierId) == null)) {
      return jsonError('Lieferant nicht gefunden.', status: 404);
    }
    final quantities = <String, Decimal>{};
    for (final i in await business.itemsFor(companyId, id)) {
      if (i.kind == 'article' && i.articleId != null) {
        quantities[i.articleId!] = (quantities[i.articleId!] ?? Decimal.zero) + Decimal.parse(i.quantity);
      }
    }
    final prices = await business.listArticlePrices(companyId);
    final bySupplier = <String, List<({String articleId, String name, Decimal quantity, int price})>>{};
    final unassignable = <Map<String, Object?>>[];
    for (final entry in quantities.entries) {
      final article = await business.findArticle(companyId, entry.key);
      if (article == null) continue;
      final candidates = prices.where((p) => p.articleId == entry.key && (mode == 'cheapest' || p.supplierId == supplierId)).toList();
      if (candidates.isEmpty) {
        unassignable.add({'articleId': article.id, 'articleName': article.name, 'quantity': entry.value.toString()});
        continue;
      }
      final chosen = candidates.reduce((a, b) => a.purchasePriceCents <= b.purchasePriceCents ? a : b);
      bySupplier.putIfAbsent(chosen.supplierId, () => []).add(
            (articleId: article.id, name: article.name, quantity: entry.value, price: chosen.purchasePriceCents),
          );
    }
    final created = <String>[];
    final now = DateTime.now().toUtc();
    for (final entry in bySupplier.entries) {
      created.add(await _draft(
        check.auth!,
        supplierId: entry.key,
        lines: entry.value,
        now: now,
        sourceOrderId: id,
        projectId: document.projectId,
      ));
    }
    return jsonOk({'purchaseOrderIds': created, 'unassignable': unassignable}, status: 201);
  }

  Future<String> _draft(
    AuthContext ctx, {
    required String supplierId,
    required List<({String articleId, String name, Decimal quantity, int price})> lines,
    required DateTime now,
    String? sourceOrderId,
    String? projectId,
  }) async {
    final id = _uuid.v4();
    await business.createPurchaseOrder(
      PurchaseOrder(
        id: id,
        companyId: ctx.session.companyId,
        supplierId: supplierId,
        status: 'draft',
        issueDate: DateTime.utc(now.year, now.month, now.day),
        sourceOrderId: sourceOrderId,
        projectId: projectId,
        createdByUserId: ctx.session.userId,
        createdAt: now,
        updatedAt: now,
        version: 1,
      ),
      [
        for (final (index, l) in lines.indexed)
          PurchaseOrderItem(
            id: _uuid.v4(),
            purchaseOrderId: id,
            articleId: l.articleId,
            description: l.name,
            quantity: l.quantity.toString(),
            purchasePriceCents: l.price,
            sortOrder: index,
          ),
      ],
    );
    await auth.audit(ctx, 'purchaseOrder.create', 'purchaseOrder', id);
    return id;
  }

  /// Unterbestand je Lieferant: Fehlmenge bis zum Mindestbestand, beim
  /// Standardlieferanten (falls mit Preis), sonst beim günstigsten.
  Future<({List<Map<String, Object?>> suggestions, List<Map<String, Object?>> unassignable})> _computeSuggestions(
    String companyId,
  ) async {
    final prices = await business.listArticlePrices(companyId);
    final suppliers = {for (final s in await business.listSuppliers(companyId)) s.id: s};
    final bySupplier = <String, List<Map<String, Object?>>>{};
    final unassignable = <Map<String, Object?>>[];
    for (final a in await business.listArticles(companyId)) {
      if (a.minimumStock == null) continue;
      final shortfall = Decimal.parse(a.minimumStock!) - Decimal.parse(a.stockQuantity);
      if (shortfall <= Decimal.zero) continue;
      final own = prices.where((p) => p.articleId == a.id).toList();
      final preferred = own.where((p) => p.supplierId == a.defaultSupplierId).firstOrNull ??
          (own.isEmpty ? null : own.reduce((x, y) => x.purchasePriceCents <= y.purchasePriceCents ? x : y));
      if (preferred == null) {
        unassignable.add({'articleId': a.id, 'articleName': a.name, 'quantity': shortfall.toString()});
        continue;
      }
      bySupplier.putIfAbsent(preferred.supplierId, () => []).add({
        'articleId': a.id,
        'description': a.name,
        'quantity': shortfall.toString(),
        'purchasePriceCents': preferred.purchasePriceCents,
      });
    }
    return (
      suggestions: [
        for (final entry in bySupplier.entries)
          if (suppliers[entry.key] != null)
            () {
              final total = entry.value.fold<Decimal>(Decimal.zero, (sum, i) => sum + Decimal.parse(i['quantity'] as String));
              final moq = suppliers[entry.key]!.minimumOrderQuantity;
              return {
                'supplierId': entry.key,
                'supplierName': suppliers[entry.key]!.name,
                'items': entry.value,
                'totalQuantity': total.toString(),
                'minimumOrderQuantity': moq,
                // Nur Hinweis, nicht blockierend (wie offline).
                'meetsMinimumOrderQuantity': moq == null || total >= Decimal.parse(moq),
              };
            }(),
      ],
      unassignable: unassignable,
    );
  }

  Future<Response> _suggestions(Request request) async {
    final check = await auth.requirePermission(request, 'purchaseOrders.read');
    if (check.error != null) return check.error!;
    final result = await _computeSuggestions(check.auth!.session.companyId);
    return jsonOk({'suggestions': result.suggestions, 'unassignable': result.unassignable});
  }

  /// Legt aus dem aktuellen Vorschlag für `supplierId` einen Entwurf an.
  Future<Response> _fromSuggestion(Request request) async {
    final check = await auth.requirePermission(request, 'purchaseOrders.write');
    if (check.error != null) return check.error!;
    final companyId = check.auth!.session.companyId;
    final supplierId = trimmedOrNull((await readJsonBody(request))['supplierId']);
    final suggestion =
        (await _computeSuggestions(companyId)).suggestions.where((s) => s['supplierId'] == supplierId).firstOrNull;
    if (suggestion == null) return jsonError('Kein Bestellvorschlag für diesen Lieferanten.', status: 404);
    final id = await _draft(
      check.auth!,
      supplierId: supplierId!,
      lines: [
        for (final i in (suggestion['items'] as List).cast<Map<String, Object?>>())
          (
            articleId: i['articleId'] as String,
            name: i['description'] as String,
            quantity: Decimal.parse(i['quantity'] as String),
            price: i['purchasePriceCents'] as int,
          ),
      ],
      now: DateTime.now().toUtc(),
    );
    return _response(companyId, (await business.findPurchaseOrder(companyId, id))!, status: 201);
  }
}
