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
    router.post('/inventory-counts/<id>/found', _addFound);

    // C5.4 Lagerorte und Plätze.
    router.get('/storage-locations', _listLocations);
    router.post('/storage-locations', _saveLocation);
    router.put('/storage-locations/<id>', _saveLocation);
    router.delete('/storage-locations/<id>', _deleteLocation);
    router.post('/storage-locations/<id>/bins', _saveBin);
    router.put('/storage-bins/<binId>', _updateBin);
    router.delete('/storage-bins/<binId>', _deleteBin);
    router.get('/articles/<id>/bin-stock', _articleBinStock);
    router.put('/articles/<id>/default-bin', _setDefaultBin);
    router.post('/articles/<id>/stock-transfer', _transfer);
  }

  // ---- C5.4 Lagerorte und Plätze ----------------------------------------------

  /// Plätze mit Lagerort, in Laufreihenfolge.
  Future<List<({StorageLocation location, StorageBin bin})>> _binsWithLocation(String companyId) async {
    final locations = await business.listStorageLocations(companyId);
    final bins = await business.listStorageBins(companyId);
    return [
      for (final l in locations)
        for (final b in bins.where((b) => b.locationId == l.id)) (location: l, bin: b),
    ];
  }

  Future<Map<String, String>> _binLabels(String companyId) async => {
        for (final e in await _binsWithLocation(companyId)) e.bin.id: '${e.location.name} · ${e.bin.label}',
        unassignedBinKey: 'Platz noch nicht zugeordnet',
      };

  Future<Response> _listLocations(Request request) async {
    final check = await auth.requirePermission(request, 'stock.read');
    if (check.error != null) return check.error!;
    final companyId = check.auth!.session.companyId;
    final locations = await business.listStorageLocations(companyId);
    final bins = await business.listStorageBins(companyId);
    final stocks = await business.listBinStocks(companyId);
    final defaults = await business.defaultBins(companyId);
    Set<String> articlesIn(Set<String> binIds) => {
          for (final s in stocks)
            if (binIds.contains(s.binKey) && Decimal.parse(s.quantity) != Decimal.zero) s.articleId,
          for (final e in defaults.entries)
            if (binIds.contains(e.value)) e.key,
        };
    return jsonOk({
      'locations': [
        for (final l in locations)
          {
            'id': l.id,
            'name': l.name,
            'sortOrder': l.sortOrder,
            'bins': [for (final b in bins.where((b) => b.locationId == l.id)) b.toJson()],
            'articleIds': articlesIn({for (final b in bins.where((b) => b.locationId == l.id)) b.id}).toList(),
          },
      ],
      'unassignedArticleIds': articlesIn({unassignedBinKey}).toList(),
    });
  }

  Future<Response> _saveLocation(Request request, [String? id]) async {
    final check = await auth.requirePermission(request, 'stock.write');
    if (check.error != null) return check.error!;
    final companyId = check.auth!.session.companyId;
    final name = trimmedOrNull((await readJsonBody(request))['name']);
    if (name == null) return jsonError('name ist Pflicht.');
    final existing = await business.listStorageLocations(companyId);
    final current = id == null ? null : existing.where((l) => l.id == id).firstOrNull;
    if (id != null && current == null) return jsonError('Lagerort nicht gefunden.', status: 404);
    final location = StorageLocation(
      id: current?.id ?? _uuid.v4(),
      companyId: companyId,
      name: name,
      sortOrder: current?.sortOrder ?? existing.length,
      createdAt: current?.createdAt ?? DateTime.now().toUtc(),
    );
    await business.saveStorageLocation(location);
    await auth.audit(check.auth!, id == null ? 'storageLocation.create' : 'storageLocation.update', 'storageLocation', location.id);
    return jsonOk({'id': location.id, 'name': location.name}, status: id == null ? 201 : 200);
  }

  Future<Response> _deleteLocation(Request request, String id) async {
    final check = await auth.requirePermission(request, 'stock.write');
    if (check.error != null) return check.error!;
    if (!await business.deleteStorageLocation(check.auth!.session.companyId, id)) {
      return jsonError('An einem Platz liegt noch Bestand — erst umlagern oder per Inventur ausbuchen.', status: 409);
    }
    await auth.audit(check.auth!, 'storageLocation.delete', 'storageLocation', id);
    return Response(204);
  }

  Future<Response> _saveBin(Request request, String id) => _writeBin(request, locationId: id);
  Future<Response> _updateBin(Request request, String binId) => _writeBin(request, binId: binId);

  Future<Response> _writeBin(Request request, {String? locationId, String? binId}) async {
    final check = await auth.requirePermission(request, 'stock.write');
    if (check.error != null) return check.error!;
    final companyId = check.auth!.session.companyId;
    final body = await readJsonBody(request);
    String text(String key) => (body[key] is String ? body[key] as String : '').trim();
    final row = text('row');
    final shelf = text('shelf');
    final compartment = text('compartment');
    if (row.isEmpty && shelf.isEmpty && compartment.isEmpty) return jsonError('Mindestens Reihe, Regal oder Fach angeben.');
    final bins = await business.listStorageBins(companyId);
    final current = binId == null ? null : bins.where((b) => b.id == binId).firstOrNull;
    if (binId != null && current == null) return jsonError('Platz nicht gefunden.', status: 404);
    final targetLocation = (body['locationId'] is String ? body['locationId'] as String : null) ?? locationId ?? current!.locationId;
    if (!(await business.listStorageLocations(companyId)).any((l) => l.id == targetLocation)) {
      return jsonError('Lagerort nicht gefunden.', status: 404);
    }
    final bin = StorageBin(
      id: current?.id ?? _uuid.v4(),
      companyId: companyId,
      locationId: targetLocation,
      row: row,
      shelf: shelf,
      compartment: compartment,
      sortOrder: body['sortOrder'] is int ? body['sortOrder'] as int : current?.sortOrder ?? 0,
    );
    await business.saveStorageBin(bin);
    await auth.audit(check.auth!, current == null ? 'storageBin.create' : 'storageBin.update', 'storageBin', bin.id);
    return jsonOk(bin.toJson(), status: current == null ? 201 : 200);
  }

  Future<Response> _deleteBin(Request request, String binId) async {
    final check = await auth.requirePermission(request, 'stock.write');
    if (check.error != null) return check.error!;
    if (!await business.deleteStorageBin(check.auth!.session.companyId, binId)) {
      return jsonError('An diesem Platz liegt noch Bestand — erst umlagern oder per Inventur ausbuchen.', status: 409);
    }
    await auth.audit(check.auth!, 'storageBin.delete', 'storageBin', binId);
    return Response(204);
  }

  /// Platzbestände eines Artikels, Standardplatz und Entnahme-Vorschlag.
  Future<Map<String, Object?>> _binStockJson(String companyId, String articleId) async {
    final labels = await _binLabels(companyId);
    final order = [for (final e in await _binsWithLocation(companyId)) e.bin.id];
    final defaultBin = (await business.defaultBins(companyId))[articleId];
    final stocks = {
      for (final s in await business.listBinStocks(companyId, articleId: articleId)) s.binKey: Decimal.parse(s.quantity),
    };
    final shown = [
      for (final binId in order)
        if ((stocks[binId] ?? Decimal.zero) != Decimal.zero || binId == defaultBin) binId,
      if ((stocks[unassignedBinKey] ?? Decimal.zero) != Decimal.zero) unassignedBinKey,
    ];
    return {
      'articleId': articleId,
      'defaultBinId': defaultBin,
      'suggestedBinKey': suggestWithdrawalBin(stocks, defaultBin),
      'stocks': [
        for (final key in shown)
          {'binKey': key, 'label': labels[key], 'quantity': (stocks[key] ?? Decimal.zero).toString()},
      ],
    };
  }

  Future<Response> _articleBinStock(Request request, String id) async {
    final check = await auth.requirePermission(request, 'stock.read');
    if (check.error != null) return check.error!;
    final companyId = check.auth!.session.companyId;
    if (await business.findArticle(companyId, id) == null) return jsonError('Artikel nicht gefunden.', status: 404);
    return jsonOk(await _binStockJson(companyId, id));
  }

  Future<Response> _setDefaultBin(Request request, String id) async {
    final check = await auth.requirePermission(request, 'stock.write');
    if (check.error != null) return check.error!;
    final companyId = check.auth!.session.companyId;
    if (await business.findArticle(companyId, id) == null) return jsonError('Artikel nicht gefunden.', status: 404);
    final raw = (await readJsonBody(request))['binId'];
    final binId = raw is String && raw.isNotEmpty ? raw : null;
    if (binId != null && !(await business.listStorageBins(companyId)).any((b) => b.id == binId)) {
      return jsonError('Platz nicht gefunden.', status: 404);
    }
    await business.setDefaultBin(companyId, id, binId);
    await auth.audit(check.auth!, 'article.defaultBin', 'article', id);
    return jsonOk(await _binStockJson(companyId, id));
  }

  /// Umlagerung: zwei Bewegungen `transfer`, Gesamtbestand bleibt.
  Future<Response> _transfer(Request request, String id) async {
    final check = await auth.requirePermission(request, 'stock.write');
    if (check.error != null) return check.error!;
    final companyId = check.auth!.session.companyId;
    if (await business.findArticle(companyId, id) == null) return jsonError('Artikel nicht gefunden.', status: 404);
    final body = await readJsonBody(request);
    final from = body['fromBinKey'];
    final to = body['toBinKey'];
    final quantity = decimalOrNull(body['quantity']);
    if (from is! String || to is! String || from == to) return jsonError('fromBinKey und toBinKey (verschieden) sind Pflicht.');
    if (quantity == null || Decimal.parse(quantity) <= Decimal.zero) return jsonError('quantity muss größer 0 sein.');
    final known = {for (final b in await business.listStorageBins(companyId)) b.id, unassignedBinKey};
    if (!known.contains(from) || !known.contains(to)) return jsonError('Platz nicht gefunden.', status: 404);
    final q = Decimal.parse(quantity);
    await business.bookStock(
      companyId,
      [StockDelta(id, -q, binKey: from), StockDelta(id, q, binKey: to)],
      StockBookingContext(
        type: 'transfer',
        userId: check.auth!.session.userId,
        now: DateTime.now().toUtc(),
        referenceLabel: 'Umlagerung',
        note: trimmedOrNull(body['note']),
      ),
    );
    await auth.audit(check.auth!, 'stock.transfer', 'article', id);
    return jsonOk(await _binStockJson(companyId, id));
  }

  /// Fund an einem Platz während einer Platz-Inventur.
  Future<Response> _addFound(Request request, String id) async {
    final check = await auth.requirePermission(request, 'stock.write');
    if (check.error != null) return check.error!;
    final companyId = check.auth!.session.companyId;
    final body = await readJsonBody(request);
    final articleId = body['articleId'];
    final binKey = body['binKey'];
    if (articleId is! String || binKey is! String) return jsonError('articleId und binKey sind Pflicht.');
    if (await business.findArticle(companyId, articleId) == null) return jsonError('Artikel nicht gefunden.', status: 404);
    final known = {for (final b in await business.listStorageBins(companyId)) b.id, unassignedBinKey};
    if (!known.contains(binKey)) return jsonError('Platz nicht gefunden.', status: 404);
    if (!await business.addInventoryBinItems(companyId, id, [(articleId: articleId, binKey: binKey)], newId: _uuid.v4)) {
      return _draftCountOr404(companyId, id);
    }
    return _countResponse(companyId, (await business.findInventoryCount(companyId, id))!);
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
    // Bucht sofort eine Lagerbewegung — für Agenten nur per Freigabe.
    if (check.auth!.session.isAgent) {
      return auth.requestApproval(
        check.auth!,
        method: 'POST',
        path: '/articles/$id/stock-correction',
        body: body,
        summary: 'Bestand von "${article.name}" auf $counted korrigieren ($reason)',
      );
    }
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
    final withdrawals = <Map<String, Object?>>[];
    final hasBins = books && (await business.listStorageBins(companyId)).isNotEmpty;
    if (books) {
      final quantities = articleQuantities(
        (await business.itemsFor(companyId, id)).map((i) => (articleId: i.articleId, quantity: i.quantity)),
      );
      for (final e in quantities.entries) {
        final article = await business.findArticle(companyId, e.key);
        if (article == null) continue;
        final available = Decimal.parse(article.stockQuantity);
        // C5.4 (Kay, 16.11.2026): Entnahmeplatz vorschlagen.
        if (hasBins) {
          withdrawals.add({
            'articleId': article.id,
            'articleName': article.name,
            'quantity': e.value.toString(),
            ...await _binStockJson(companyId, article.id),
          });
        }
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
    return jsonOk({'booksStock': books, 'warnings': warnings, 'withdrawals': withdrawals});
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
    final labels = await _binLabels(companyId);
    final binOrder = {
      for (final (i, e) in (await _binsWithLocation(companyId)).indexed) e.bin.id: i,
    };
    final items = await business.inventoryItems(companyId, count.id);
    // C5.4: Platz-Inventur in Laufreihenfolge, Klärfälle zuletzt.
    if (count.locationId != null) {
      int rank(InventoryCountItem i) => binOrder[i.binKey] ?? 1 << 30;
      items.sort((a, b) {
        final r = rank(a).compareTo(rank(b));
        return r != 0 ? r : (names[a.articleId]?.name ?? '').compareTo(names[b.articleId]?.name ?? '');
      });
    }
    return jsonOk({
      ...count.toJson(),
      if (count.locationId != null)
        'bins': [
          for (final e in await _binsWithLocation(companyId))
            if (e.location.id == count.locationId) {...e.bin.toJson(), 'label': e.bin.label},
        ],
      'items': [
        for (final i in items)
          {
            ...i.toJson(),
            'binLabel': i.binKey == null ? null : labels[i.binKey],
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
    final locationId = trimmedOrNull(body['locationId']);
    if (locationId != null && !(await business.listStorageLocations(companyId)).any((l) => l.id == locationId)) {
      return jsonError('Lagerort nicht gefunden.', status: 404);
    }
    final now = DateTime.now().toUtc();
    final count = InventoryCount(
      id: _uuid.v4(),
      companyId: companyId,
      label: label,
      date: dateOrNull(body['date']) ?? DateTime.utc(now.year, now.month, now.day),
      status: 'draft',
      createdAt: now,
      locationId: locationId,
    );
    await business.createInventoryCount(count);
    if (locationId != null) {
      // C5.4: Platz für Platz — Bestand oder Standardplatz dort, dazu die
      // Klärfälle ohne Platz.
      final binIds = {
        for (final b in await business.listStorageBins(companyId))
          if (b.locationId == locationId) b.id,
      };
      final active = {for (final a in await business.listArticles(companyId)) a.id};
      final stocks = await business.listBinStocks(companyId);
      final entries = <({String articleId, String binKey})>{
        for (final e in (await business.defaultBins(companyId)).entries)
          if (binIds.contains(e.value) && active.contains(e.key)) (articleId: e.key, binKey: e.value),
        for (final s in stocks)
          if ((binIds.contains(s.binKey) || s.binKey == unassignedBinKey) && Decimal.parse(s.quantity) != Decimal.zero)
            (articleId: s.articleId, binKey: s.binKey),
      };
      await business.addInventoryBinItems(companyId, count.id, entries.toList(), newId: _uuid.v4);
    }
    // Optional sofort alle aktiven Artikel aufnehmen ("volle Inventur").
    if (body['allArticles'] == true && locationId == null) {
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
    if (check.auth!.session.isAgent) {
      final count = await business.findInventoryCount(companyId, id);
      if (count == null || count.status != 'draft') return _draftCountOr404(companyId, id);
      return auth.requestApproval(
        check.auth!,
        method: 'POST',
        path: '/inventory-counts/$id/complete',
        body: const {},
        summary: 'Inventur "${count.label}" abschließen und Differenzen buchen',
      );
    }
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
