import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:uuid/uuid.dart';
import 'package:werkkern_core/werkkern_core.dart';

import '../auth.dart';
import '../models.dart' show PendingApproval;
import '../repository.dart';
import '../util/responses.dart';
import 'models.dart';
import 'repository.dart';

/// Fach-Endpunkte (B1 Punkt 3). Jeder Endpunkt prüft serverseitig
/// Sitzung → Recht → Modul, bevor er die (ausnahmslos firmengebundene)
/// Repository-Methode aufruft. Eine fremde ID ergibt dieselbe 404 wie
/// eine nicht existierende.
class BusinessRoutes {
  BusinessRoutes({required this.repository, required this.business, required this.auth});

  final PhaseBRepository repository;
  final BusinessRepository business;
  final SessionAuthenticator auth;
  static const _uuid = Uuid();

  void mount(Router router) {
    router.get('/customers', _listCustomers);
    router.post('/customers', _createCustomer);
    router.get('/customers/<id>', _getCustomer);
    router.put('/customers/<id>', _updateCustomer);
    router.delete('/customers/<id>', _deleteCustomer);

    router.get('/articles', _listArticles);
    router.post('/articles', _createArticle);
    router.get('/articles/<id>', _getArticle);
    router.put('/articles/<id>', _updateArticle);

    router.get('/documents', _listDocuments);
    router.post('/documents', _createDocument);
    router.get('/documents/<id>', _getDocument);
    router.put('/documents/<id>', _updateDocument);
    router.delete('/documents/<id>', _deleteDocument);
    router.post('/documents/<id>/finalize', _finalizeDocument);
    router.post('/documents/<id>/convert', _convertDocument);
    router.post('/documents/<id>/credit-note', _createCreditNote);
    router.post('/documents/<id>/payment', _setPayment);
    router.put('/documents/<id>/due-date', _setDueDate);

    router.put('/documents/<id>/project', _setDocumentProject);

    router.get('/projects', _listProjects);
    router.post('/projects', _createProject);
    router.get('/projects/<id>', _getProject);
    router.put('/projects/<id>', _updateProject);
    router.delete('/projects/<id>', _deleteProject);

    router.get('/time-entries', _listTimeEntries);
    router.post('/time-entries', _createTimeEntry);
    router.put('/time-entries/<id>', _updateTimeEntry);
    router.delete('/time-entries/<id>', _deleteTimeEntry);
  }

  Future<Map<String, Object?>> _body(Request request) async {
    final raw = await request.readAsString();
    if (raw.isEmpty) return const {};
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, Object?>) throw const FormatException('JSON-Objekt erwartet');
    return decoded;
  }

  String? _trimmed(Object? value) {
    final s = (value as String?)?.trim();
    return (s == null || s.isEmpty) ? null : s;
  }

  // ---- Kunden -------------------------------------------------------------

  Future<Response> _listCustomers(Request request) async {
    final check = await auth.requirePermission(request, 'customers.read');
    if (check.error != null) return check.error!;
    final customers = await business.listCustomers(
      check.auth!.session.companyId,
      query: request.url.queryParameters['q'],
    );
    return jsonOk({'customers': [for (final c in customers) c.toJson()]});
  }

  Future<Response> _getCustomer(Request request, String id) async {
    final check = await auth.requirePermission(request, 'customers.read');
    if (check.error != null) return check.error!;
    final customer = await business.findCustomer(check.auth!.session.companyId, id);
    if (customer == null) return jsonError('Kunde nicht gefunden.', status: 404);
    return jsonOk(customer.toJson());
  }

  Customer? _customerFromBody(Map<String, Object?> body, {required String id, required String companyId, required DateTime createdAt}) {
    final name = _trimmed(body['name']);
    if (name == null) return null;
    return Customer(
      id: id,
      companyId: companyId,
      name: name,
      address: _trimmed(body['address']),
      email: _trimmed(body['email']),
      phone: _trimmed(body['phone']),
      vatId: _trimmed(body['vatId']),
      contactPerson: _trimmed(body['contactPerson']),
      notes: _trimmed(body['notes']),
      createdAt: createdAt,
    );
  }

  Future<Response> _createCustomer(Request request) async {
    final check = await auth.requirePermission(request, 'customers.write');
    if (check.error != null) return check.error!;
    final customer = _customerFromBody(
      await _body(request),
      id: _uuid.v4(),
      companyId: check.auth!.session.companyId,
      createdAt: DateTime.now().toUtc(),
    );
    if (customer == null) return jsonError('name ist Pflicht.');
    await business.createCustomer(customer);
    await auth.audit(check.auth!, 'customer.create', 'customer', customer.id);
    return jsonOk(customer.toJson(), status: 201);
  }

  Future<Response> _updateCustomer(Request request, String id) async {
    final check = await auth.requirePermission(request, 'customers.write');
    if (check.error != null) return check.error!;
    final companyId = check.auth!.session.companyId;
    final existing = await business.findCustomer(companyId, id);
    if (existing == null) return jsonError('Kunde nicht gefunden.', status: 404);
    final customer = _customerFromBody(await _body(request), id: id, companyId: companyId, createdAt: existing.createdAt);
    if (customer == null) return jsonError('name ist Pflicht.');
    await business.updateCustomer(customer);
    await auth.audit(check.auth!, 'customer.update', 'customer', id);
    return jsonOk(customer.toJson());
  }

  Future<Response> _deleteCustomer(Request request, String id) async {
    final check = await auth.requirePermission(request, 'customers.write');
    if (check.error != null) return check.error!;
    try {
      final deleted = await business.deleteCustomer(check.auth!.session.companyId, id);
      if (!deleted) return jsonError('Kunde nicht gefunden.', status: 404);
      await auth.audit(check.auth!, 'customer.delete', 'customer', id);
      return Response(204);
    } on BusinessConflict catch (e) {
      return jsonError(e.message, status: 409);
    }
  }

  // ---- Artikel --------------------------------------------------------------

  Future<Response> _listArticles(Request request) async {
    final check = await auth.requirePermission(request, 'articles.read');
    if (check.error != null) return check.error!;
    final articles = await business.listArticles(
      check.auth!.session.companyId,
      query: request.url.queryParameters['q'],
      includeInactive: request.url.queryParameters['includeInactive'] == 'true',
    );
    return jsonOk({'articles': [for (final a in articles) a.toJson()]});
  }

  Future<Response> _getArticle(Request request, String id) async {
    final check = await auth.requirePermission(request, 'articles.read');
    if (check.error != null) return check.error!;
    final article = await business.findArticle(check.auth!.session.companyId, id);
    if (article == null) return jsonError('Artikel nicht gefunden.', status: 404);
    return jsonOk(article.toJson());
  }

  Article? _articleFromBody(Map<String, Object?> body, {required String id, required String companyId, required DateTime createdAt, required bool defaultActive}) {
    final name = _trimmed(body['name']);
    if (name == null) return null;
    final price = body['salePriceCents'] as int?;
    if (price != null && price < 0) return null;
    return Article(
      id: id,
      companyId: companyId,
      name: name,
      unit: _trimmed(body['unit']),
      salePriceCents: price,
      active: body['active'] as bool? ?? defaultActive,
      createdAt: createdAt,
    );
  }

  Future<Response> _createArticle(Request request) async {
    final check = await auth.requirePermission(request, 'articles.write');
    if (check.error != null) return check.error!;
    final article = _articleFromBody(
      await _body(request),
      id: _uuid.v4(),
      companyId: check.auth!.session.companyId,
      createdAt: DateTime.now().toUtc(),
      defaultActive: true,
    );
    if (article == null) return jsonError('name ist Pflicht, salePriceCents (falls gesetzt) >= 0.');
    await business.createArticle(article);
    await auth.audit(check.auth!, 'article.create', 'article', article.id);
    return jsonOk(article.toJson(), status: 201);
  }

  Future<Response> _updateArticle(Request request, String id) async {
    final check = await auth.requirePermission(request, 'articles.write');
    if (check.error != null) return check.error!;
    final companyId = check.auth!.session.companyId;
    final existing = await business.findArticle(companyId, id);
    if (existing == null) return jsonError('Artikel nicht gefunden.', status: 404);
    final article = _articleFromBody(
      await _body(request),
      id: id,
      companyId: companyId,
      createdAt: existing.createdAt,
      defaultActive: existing.active,
    );
    if (article == null) return jsonError('name ist Pflicht, salePriceCents (falls gesetzt) >= 0.');
    await business.updateArticle(article);
    await auth.audit(check.auth!, 'article.update', 'article', id);
    return jsonOk(article.toJson());
  }

  // ---- Dokumente --------------------------------------------------------------

  /// Prüft Recht UND das Modul der Dokumentart (z. B. "quotes" für ein
  /// Angebot) — eine deaktivierte Firmenfunktion bleibt vorrangig.
  Future<({AuthContext? auth, Response? error})> _requireDocumentPermission(
    Request request,
    String permission,
    String kind,
  ) =>
      auth.requirePermission(request, permission, requiredModule: documentKindModules[kind]);

  Future<Set<String>> _enabledModules(AuthContext ctx) async =>
      (await repository.findCompanyById(ctx.session.companyId))?.enabledModules ?? const {};

  Future<Response> _listDocuments(Request request) async {
    final check = await auth.requirePermission(request, 'invoices.read');
    if (check.error != null) return check.error!;
    final params = request.url.queryParameters;
    final kind = params['kind'];
    if (kind != null && !documentKindModules.containsKey(kind)) return jsonError('Unbekannte Dokumentart: $kind');
    final status = params['status'];
    if (status != null && !documentStatuses.contains(status)) return jsonError('Unbekannter Status: $status');

    final modules = await _enabledModules(check.auth!);
    bool kindVisible(String k) => documentKindModules[k] == null || modules.contains(documentKindModules[k]);
    if (kind != null && !kindVisible(kind)) {
      return jsonError('Modul "${documentKindModules[kind]}" ist für diese Firma nicht aktiviert.', status: 403);
    }

    final projectFilter = params['projectId'];
    final documents = [
      for (final d in await business.listDocuments(check.auth!.session.companyId, kind: kind, status: status, query: params['q']))
        if (projectFilter == null || d.projectId == projectFilter) d,
    ];
    final result = <Map<String, Object?>>[];
    final customerNames = {
      for (final c in await business.listCustomers(check.auth!.session.companyId)) c.id: c.name,
    };
    for (final d in documents.where((d) => kindVisible(d.kind))) {
      final items = await business.itemsFor(check.auth!.session.companyId, d.id);
      result.add({
        ...d.toJson(),
        'customerName': customerNames[d.customerId],
        'totalGrossCents': _totals(items).totalGross.cents,
      });
    }
    return jsonOk({'documents': result});
  }

  InvoiceTotals _totals(List<DocumentItem> items) => calculateInvoiceTotals([
        for (final i in items)
          InvoiceLineInput(
            quantity: Decimal.parse(i.quantity),
            unitPriceCents: i.unitPriceCents,
            vatRatePercent: i.vatRatePercent,
            discountPercent: i.discountPercent,
          ),
      ]);

  Map<String, Object?> _totalsJson(InvoiceTotals totals) => {
        'netCents': totals.totalNet.cents,
        'taxCents': totals.totalTax.cents,
        'grossCents': totals.totalGross.cents,
        'byRate': [
          for (final rate in totals.sortedRates)
            {'vatRatePercent': rate, 'netCents': totals.netByRate[rate]!.cents, 'taxCents': totals.taxByRate[rate]!.cents},
        ],
      };

  Future<Response> _documentResponse(String companyId, Document document, {int status = 200}) async {
    final items = await business.itemsFor(companyId, document.id);
    // Aktueller Kundenname zur Anzeige (Entwürfe haben noch keinen
    // Schnappschuss); maßgeblich für finalisierte Dokumente bleibt
    // customerSnapshot.
    final customer = await business.findCustomer(companyId, document.customerId);
    final convertedTo = await business.listConvertedFrom(companyId, document.id);
    final booked = await business.listTimeEntries(companyId, documentId: document.id);
    final totals = _totals(items);
    final source = document.convertedFromId == null ? null : await business.findDocument(companyId, document.convertedFromId!);

    Future<List<Map<String, Object?>>> finalizedSummaries(Iterable<Document> docs) async => [
          for (final d in docs.where((d) => !d.isDraft))
            {'id': d.id, 'number': d.number, 'grossCents': _totals(await business.itemsFor(companyId, d.id)).totalGross.cents},
        ];
    // C13: Schlussrechnung (aus demselben Auftrag, selbst kein Abschlag)
    // listet jede finalisierte Abschlagsrechnung einzeln mit Nummer.
    final advancePayments = (document.kind == 'invoice' && !document.isAdvancePayment && source != null)
        ? await finalizedSummaries(
            (await business.listConvertedFrom(companyId, source.id))
                .where((d) => d.kind == 'invoice' && d.isAdvancePayment && d.id != document.id),
          )
        : const <Map<String, Object?>>[];
    final creditNotes = document.kind == 'invoice'
        ? await finalizedSummaries((await business.listConvertedFrom(companyId, document.id)).where((d) => d.kind == 'creditNote'))
        : const <Map<String, Object?>>[];
    final advanceSum = advancePayments.fold<int>(0, (sum, a) => sum + (a['grossCents'] as int));
    return jsonOk({
      ...document.toJson(),
      'customerName': customer?.name,
      // C3: "Geplant laut Angebot vs. gebucht" — Summe aller auf dieses
      // Dokument gebuchten Stunden (Firmensicht, ohne Personenbezug).
      'bookedHours': booked.fold<Decimal>(Decimal.zero, (sum, t) => sum + Decimal.parse(t.hours)).toString(),
      'convertedTo': [
        for (final d in convertedTo) {'id': d.id, 'kind': d.kind, 'number': d.number, 'status': d.status},
      ],
      'items': [for (final i in items) i.toJson()],
      'totals': _totalsJson(totals),
      'convertedFromNumber': source?.number,
      'advancePayments': advancePayments,
      if (advancePayments.isNotEmpty) 'remainingCents': totals.totalGross.cents - advanceSum,
      'creditNotes': creditNotes,
    }, status: status);
  }

  Future<Response> _getDocument(Request request, String id) async {
    final session = await auth.requireSession(request);
    if (session == null) return jsonError('Nicht angemeldet.', status: 401);
    // Erst laden (firmengebunden), dann Recht + Modul der konkreten Art
    // prüfen. Fremd/nicht vorhanden -> 404 VOR der Rechteprüfung wäre
    // ein Oracle für Nutzer ohne Leserecht nicht nötig: beide Fälle
    // bleiben 404, egal ob mit oder ohne Recht.
    final document = await business.findDocument(session.session.companyId, id);
    if (document == null) return jsonError('Dokument nicht gefunden.', status: 404);
    final check = await _requireDocumentPermission(request, 'invoices.read', document.kind);
    if (check.error != null) return check.error!;
    return _documentResponse(session.session.companyId, document);
  }

  DateTime? _parseDate(Object? value) {
    if (value is! String) return null;
    final parsed = DateTime.tryParse(value);
    return parsed == null ? null : DateTime.utc(parsed.year, parsed.month, parsed.day);
  }

  /// Validiert die Positionen inkl. Firmenbindung referenzierter
  /// Artikel. Liefert entweder die Positionen oder eine Fehlermeldung.
  Future<({List<DocumentItem>? items, String? error})> _parseItems(
    Object? raw,
    String companyId,
    String documentId,
  ) async {
    if (raw == null) return (items: <DocumentItem>[], error: null);
    if (raw is! List) return (items: null, error: 'items muss eine Liste sein.');
    // § 19 UStG: Kleinunternehmer weisen keine USt aus — serverseitig
    // erzwungen statt nur in der Oberfläche (Arbeitsvorgabe, keine
    // Rechtsprüfung).
    final smallBusiness = (await repository.getCompanyProfile(companyId)).smallBusinessExempt;
    final items = <DocumentItem>[];
    for (var index = 0; index < raw.length; index++) {
      final entry = raw[index];
      if (entry is! Map<String, Object?>) return (items: null, error: 'Position ${index + 1}: Objekt erwartet.');
      final kind = entry['kind'] as String?;
      if (!itemKinds.contains(kind)) return (items: null, error: 'Position ${index + 1}: kind article|hours|text.');
      final description = _trimmed(entry['description']);
      if (description == null) return (items: null, error: 'Position ${index + 1}: description ist Pflicht.');
      final rawQuantity = entry['quantity'];
      final quantity = rawQuantity is num
          ? Decimal.tryParse(rawQuantity.toString())
          : rawQuantity is String
              ? Decimal.tryParse(rawQuantity.replaceAll(',', '.'))
              : null;
      if (quantity == null) return (items: null, error: 'Position ${index + 1}: quantity ist keine Zahl.');
      final price = entry['unitPriceCents'];
      if (price is! int) return (items: null, error: 'Position ${index + 1}: unitPriceCents (Cent, Ganzzahl) ist Pflicht.');
      final vat = entry['vatRatePercent'];
      if (vat is! num || vat < 0 || vat > 100) {
        return (items: null, error: 'Position ${index + 1}: vatRatePercent 0–100 ist Pflicht.');
      }
      if (smallBusiness && vat != 0) {
        return (items: null, error: 'Position ${index + 1}: Kleinunternehmerregelung (§ 19 UStG) — USt muss 0 % sein.');
      }
      final discount = entry['discountPercent'] ?? 0;
      if (discount is! num || discount < 0 || discount > 100) {
        return (items: null, error: 'Position ${index + 1}: discountPercent 0–100.');
      }
      final articleId = entry['articleId'] as String?;
      if (articleId != null && await business.findArticle(companyId, articleId) == null) {
        // Fremder Artikel wird exakt wie ein nicht existierender behandelt.
        return (items: null, error: 'Position ${index + 1}: Artikel nicht gefunden.');
      }
      items.add(DocumentItem(
        id: _uuid.v4(),
        documentId: documentId,
        kind: kind!,
        articleId: articleId,
        description: description,
        quantity: quantity.toString(),
        unitPriceCents: price,
        vatRatePercent: vat.toDouble(),
        unit: _trimmed(entry['unit']),
        discountPercent: discount.toDouble(),
        groupLabel: _trimmed(entry['groupLabel']),
        sortOrder: index,
      ));
    }
    return (items: items, error: null);
  }

  Future<Response> _createDocument(Request request) async {
    final body = await _body(request);
    final kind = body['kind'] as String? ?? 'invoice';
    if (!documentKindModules.containsKey(kind)) return jsonError('Unbekannte Dokumentart: $kind');
    final check = await _requireDocumentPermission(request, 'invoices.write', kind);
    if (check.error != null) return check.error!;
    final companyId = check.auth!.session.companyId;

    final customerId = body['customerId'] as String?;
    if (customerId == null || await business.findCustomer(companyId, customerId) == null) {
      return jsonError('Kunde nicht gefunden.', status: 404);
    }
    final now = DateTime.now().toUtc();
    final today = DateTime.utc(now.year, now.month, now.day);
    final issueDate = body['issueDate'] == null ? today : _parseDate(body['issueDate']);
    final serviceDate = body['serviceDate'] == null ? issueDate : _parseDate(body['serviceDate']);
    if (issueDate == null || serviceDate == null) return jsonError('issueDate/serviceDate im Format JJJJ-MM-TT.');

    final id = _uuid.v4();
    final parsed = await _parseItems(body['items'], companyId, id);
    if (parsed.error != null) return jsonError(parsed.error!);
    final projectId = body['projectId'] as String?;
    if (projectId != null) {
      final projectError = await _checkProjectReference(check.auth!, projectId);
      if (projectError != null) return projectError;
    }

    final document = Document(
      id: id,
      companyId: companyId,
      customerId: customerId,
      kind: kind,
      status: 'draft',
      issueDate: issueDate,
      serviceDate: serviceDate,
      paymentTerms: _trimmed(body['paymentTerms']),
      notes: _trimmed(body['notes']),
      createdByUserId: check.auth!.session.userId,
      createdAt: now,
      updatedAt: now,
      version: 1,
      projectId: projectId,
    );
    await business.createDocument(document, parsed.items!);
    await auth.audit(check.auth!, 'document.create', document.kind, id);
    return _documentResponse(companyId, document, status: 201);
  }

  Future<Response> _updateDocument(Request request, String id) async {
    final session = await auth.requireSession(request);
    if (session == null) return jsonError('Nicht angemeldet.', status: 401);
    final companyId = session.session.companyId;
    final existing = await business.findDocument(companyId, id);
    if (existing == null) return jsonError('Dokument nicht gefunden.', status: 404);
    final check = await _requireDocumentPermission(request, 'invoices.write', existing.kind);
    if (check.error != null) return check.error!;

    final body = await _body(request);
    final version = body['version'];
    if (version is! int) return jsonError('version (Ganzzahl) ist Pflicht — Schutz vor stillem Überschreiben.');
    final customerId = body['customerId'] as String? ?? existing.customerId;
    if (await business.findCustomer(companyId, customerId) == null) {
      return jsonError('Kunde nicht gefunden.', status: 404);
    }
    final issueDate = body['issueDate'] == null ? existing.issueDate : _parseDate(body['issueDate']);
    final serviceDate = body['serviceDate'] == null ? existing.serviceDate : _parseDate(body['serviceDate']);
    if (issueDate == null || serviceDate == null) return jsonError('issueDate/serviceDate im Format JJJJ-MM-TT.');
    final parsed = await _parseItems(body['items'], companyId, id);
    if (parsed.error != null) return jsonError(parsed.error!);
    final isAdvancePayment = body['isAdvancePayment'] as bool?;
    if (isAdvancePayment == true) {
      if (existing.kind != 'invoice') return jsonError('Abschlagsrechnung gibt es nur bei Rechnungen.');
      if (!(await _enabledModules(check.auth!)).contains('advancePaymentInvoices')) {
        return jsonError('Modul "advancePaymentInvoices" ist für diese Firma nicht aktiviert.', status: 403);
      }
    }
    final isFixedPrice = body['isFixedPrice'] as bool?;
    if (isFixedPrice != null && !{'quote', 'order'}.contains(existing.kind)) {
      return jsonError('Festpreis-Kennzeichen gibt es nur bei Angebot/Auftrag.');
    }

    try {
      final updated = await business.updateDraft(
        companyId: companyId,
        id: id,
        expectedVersion: version,
        customerId: customerId,
        issueDate: issueDate,
        serviceDate: serviceDate,
        paymentTerms: body.containsKey('paymentTerms') ? _trimmed(body['paymentTerms']) : existing.paymentTerms,
        notes: body.containsKey('notes') ? _trimmed(body['notes']) : existing.notes,
        items: parsed.items!,
        now: DateTime.now().toUtc(),
        isAdvancePayment: isAdvancePayment,
        isFixedPrice: isFixedPrice,
      );
      if (updated == null) return jsonError('Dokument nicht gefunden.', status: 404);
      await auth.audit(check.auth!, 'document.update', existing.kind, id);
      return await _documentResponse(companyId, updated);
    } on BusinessConflict catch (e) {
      return jsonError(e.message, status: 409);
    }
  }

  Future<Response> _deleteDocument(Request request, String id) async {
    final session = await auth.requireSession(request);
    if (session == null) return jsonError('Nicht angemeldet.', status: 401);
    final existing = await business.findDocument(session.session.companyId, id);
    if (existing == null) return jsonError('Dokument nicht gefunden.', status: 404);
    final check = await _requireDocumentPermission(request, 'invoices.write', existing.kind);
    if (check.error != null) return check.error!;
    if (check.auth!.session.isAgent) {
      return _requestApproval(
        check.auth!,
        method: 'DELETE',
        path: '/documents/$id',
        body: const {},
        summary: '${await _documentSummary(session.session.companyId, existing)} (Entwurf) löschen',
      );
    }
    try {
      await business.deleteDraft(session.session.companyId, id);
      await auth.audit(check.auth!, 'document.delete', existing.kind, id);
      return Response(204);
    } on BusinessConflict catch (e) {
      return jsonError(e.message, status: 409);
    }
  }

  static const _kindLabels = {
    'invoice': 'Rechnung',
    'quote': 'Angebot',
    'order': 'Auftrag',
    'deliveryNote': 'Lieferschein',
    'proforma': 'Proforma-Rechnung',
    'creditNote': 'Gutschrift',
  };

  /// C8: irreversible Aktion eines Agenten -> nur Freigabe-Anfrage
  /// (202). Ausgeführt wird erst, wenn der Nutzer sie in der App
  /// bestätigt — dann mit SEINER Sitzung und erneuter Rechteprüfung.
  Future<Response> _requestApproval(
    AuthContext ctx, {
    required String method,
    required String path,
    required Map<String, Object?> body,
    required String summary,
  }) async {
    final agent = await repository.findAgentTokenByHash(ctx.session.tokenHash);
    final approval = PendingApproval(
      id: _uuid.v4(),
      companyId: ctx.session.companyId,
      userId: ctx.session.userId,
      agentTokenId: agent?.id ?? '',
      method: method,
      path: path,
      body: jsonEncode(body),
      summary: summary,
      status: 'pending',
      createdAt: DateTime.now().toUtc(),
    );
    await repository.createApproval(approval);
    await auth.audit(ctx, 'approval.request', 'approval', approval.id);
    return jsonOk({
      'approvalId': approval.id,
      'status': 'pending',
      'summary': summary,
      'message': 'Irreversible Aktion: wartet auf Bestätigung durch den Nutzer in der App.',
    }, status: 202);
  }

  Future<String> _documentSummary(String companyId, Document d) async {
    final customer = await business.findCustomer(companyId, d.customerId);
    final gross = _totals(await business.itemsFor(companyId, d.id)).totalGross;
    return '${_kindLabels[d.kind] ?? d.kind} für ${customer?.name ?? 'unbekannten Kunden'} über $gross';
  }

  Future<Response> _finalizeDocument(Request request, String id) async {
    final session = await auth.requireSession(request);
    if (session == null) return jsonError('Nicht angemeldet.', status: 401);
    final companyId = session.session.companyId;
    final existing = await business.findDocument(companyId, id);
    if (existing == null) return jsonError('Dokument nicht gefunden.', status: 404);
    final check = await _requireDocumentPermission(request, 'invoices.finalize', existing.kind);
    if (check.error != null) return check.error!;

    final body = await _body(request);
    final version = body['version'];
    if (version is! int) return jsonError('version (Ganzzahl) ist Pflicht — bestätigt den geprüften Stand.');
    if ((await business.itemsFor(companyId, id)).isEmpty) {
      return jsonError('Ein Dokument ohne Positionen kann nicht finalisiert werden.');
    }
    if (!existing.isDraft) return jsonError('Dokument ist finalisiert und unveränderlich.', status: 409);
    if (check.auth!.session.isAgent) {
      return _requestApproval(
        check.auth!,
        method: 'POST',
        path: '/documents/$id/finalize',
        body: body,
        summary: '${await _documentSummary(companyId, existing)} finalisieren (Version $version)',
      );
    }
    final company = await repository.findCompanyById(companyId);
    final profile = await repository.getCompanyProfile(companyId);
    if (profile.smallBusinessExempt && (await business.itemsFor(companyId, id)).any((i) => i.vatRatePercent != 0)) {
      return jsonError(
        'Kleinunternehmerregelung (§ 19 UStG) aktiv, aber Positionen enthalten USt — Entwurf vorher auf 0 % ändern.',
        status: 409,
      );
    }
    try {
      final finalized = await business.finalize(
        companyId: companyId,
        id: id,
        expectedVersion: version,
        company: CompanySnapshot(
          name: company?.name ?? '',
          address: profile.address,
          taxNumber: profile.taxNumber,
          vatId: profile.vatId,
          iban: profile.iban,
          introText: profile.documentTexts[existing.kind]?.intro,
          closingText: profile.documentTexts[existing.kind]?.closing,
          footerText: profile.footerText,
          smallBusinessExempt: profile.smallBusinessExempt,
        ),
        now: DateTime.now().toUtc(),
      );
      if (finalized == null) return jsonError('Dokument nicht gefunden.', status: 404);
      await auth.audit(check.auth!, 'document.finalize', existing.kind, id);
      return await _documentResponse(companyId, finalized);
    } on BusinessConflict catch (e) {
      return jsonError(e.message, status: 409);
    }
  }

  /// Umwandlung (Angebot -> Auftrag -> Lieferschein/Rechnung, Proforma ->
  /// Rechnung) nach derselben Tabelle wie offline (`werkkern_core`).
  /// Erzeugt einen neuen **Entwurf** mit kopierten Positionen — nie
  /// automatisch finalisiert. Lieferscheine übernehmen keine Stunden.
  ///
  /// **Bewusste Abweichung von offline:** dort bleibt ein finalisiertes
  /// Angebot/Auftrag bis zur ersten Umwandlung editierbar (F3-
  /// Verfeinerung). Online ist jedes finalisierte Dokument sofort
  /// unveränderlich — bei mehreren Bearbeitern wäre ein nachträglich
  /// geändertes, bereits verschicktes Angebot nicht nachvollziehbar.
  Future<Response> _convertDocument(Request request, String id) async {
    final session = await auth.requireSession(request);
    if (session == null) return jsonError('Nicht angemeldet.', status: 401);
    final companyId = session.session.companyId;
    final source = await business.findDocument(companyId, id);
    if (source == null) return jsonError('Dokument nicht gefunden.', status: 404);
    final body = await _body(request);
    final targetKind = body['kind'] as String?;
    if (targetKind == null || !documentKindModules.containsKey(targetKind)) {
      return jsonError('kind (Zieldokumentart) ist Pflicht.');
    }
    // Recht + Modul für Quelle UND Ziel.
    for (final kind in {source.kind, targetKind}) {
      final check = await _requireDocumentPermission(request, 'invoices.write', kind);
      if (check.error != null) return check.error!;
    }
    if (source.isDraft) return jsonError('Nur finalisierte Dokumente können umgewandelt werden.', status: 409);
    if (!(documentConversionTargets[source.kind]?.contains(targetKind) ?? false)) {
      return jsonError('Umwandlung von ${source.kind} nach $targetKind ist nicht erlaubt.', status: 409);
    }

    final now = DateTime.now().toUtc();
    final newId = _uuid.v4();
    final sourceItems = await business.itemsFor(companyId, id);
    // C3.2 Zeit und Material: Auftrag ohne Festpreis -> Rechnung ersetzt
    // die geplanten Stunden-Positionen durch EINE Position mit den
    // gebuchten Ist-Stunden (Preis/USt/Einheit der ersten Stunden-
    // Position) — wie offline, nur bei aktiver Zeiterfassung.
    final hoursItems = sourceItems.where((i) => i.kind == 'hours').toList();
    final timeAndMaterial = source.kind == 'order' &&
        targetKind == 'invoice' &&
        !source.isFixedPrice &&
        hoursItems.isNotEmpty &&
        (await _enabledModules(session)).contains('timeTracking');
    Decimal? bookedHours;
    if (timeAndMaterial) {
      bookedHours = (await business.listTimeEntries(companyId, documentId: id))
          .fold<Decimal>(Decimal.zero, (sum, t) => sum + Decimal.parse(t.hours));
    }
    var sortOrder = 0;
    final items = [
      for (final item in sourceItems)
        if (!(targetKind == 'deliveryNote' && item.kind == 'hours') && !(timeAndMaterial && item.kind == 'hours'))
          DocumentItem(
            id: _uuid.v4(),
            documentId: newId,
            kind: item.kind,
            articleId: item.articleId,
            description: item.description,
            quantity: item.quantity,
            unitPriceCents: item.unitPriceCents,
            vatRatePercent: item.vatRatePercent,
            unit: item.unit,
            discountPercent: item.discountPercent,
            groupLabel: item.groupLabel,
            sortOrder: sortOrder++,
          ),
      if (timeAndMaterial)
        DocumentItem(
          id: _uuid.v4(),
          documentId: newId,
          kind: 'hours',
          description: 'Geleistete Stunden (Ist-Zeit)',
          quantity: bookedHours.toString(),
          unitPriceCents: hoursItems.first.unitPriceCents,
          vatRatePercent: hoursItems.first.vatRatePercent,
          unit: hoursItems.first.unit,
          groupLabel: hoursItems.first.groupLabel,
          sortOrder: sortOrder++,
        ),
    ];
    final draft = Document(
      id: newId,
      companyId: companyId,
      customerId: source.customerId,
      kind: targetKind,
      status: 'draft',
      issueDate: DateTime.utc(now.year, now.month, now.day),
      serviceDate: source.serviceDate,
      paymentTerms: source.paymentTerms,
      notes: source.notes,
      createdByUserId: session.session.userId,
      createdAt: now,
      updatedAt: now,
      version: 1,
      convertedFromId: source.id,
      // Projektzuordnung und Festpreis wandern mit (wie offline convertTo()).
      projectId: source.projectId,
      isFixedPrice: source.isFixedPrice,
    );
    await business.createDocument(draft, items);
    await auth.audit(session, 'document.convert', targetKind, newId);
    return _documentResponse(companyId, draft, status: 201);
  }

  /// Zahlungseingang erfassen/zurücknehmen (`{"paid": true|false}`) —
  /// eigenes Recht `invoices.payment`, nur für finalisierte Rechnungen.
  /// Nie automatisch (kein Bankabgleich online).
  Future<Response> _setPayment(Request request, String id) async {
    final check = await auth.requirePermission(request, 'invoices.payment');
    if (check.error != null) return check.error!;
    final companyId = check.auth!.session.companyId;
    final existing = await business.findDocument(companyId, id);
    if (existing == null) return jsonError('Dokument nicht gefunden.', status: 404);
    if (existing.kind != 'invoice') return jsonError('Zahlungsstatus gibt es nur für Rechnungen.', status: 409);
    final paid = (await _body(request))['paid'];
    if (paid is! bool) return jsonError('paid (bool) ist Pflicht.');
    try {
      final updated = await business.setPaymentInfo(
        companyId: companyId,
        id: id,
        paymentStatus: paid ? 'paid' : 'open',
        now: DateTime.now().toUtc(),
      );
      await auth.audit(check.auth!, paid ? 'document.paid' : 'document.unpaid', existing.kind, id);
      return await _documentResponse(companyId, updated!);
    } on BusinessConflict catch (e) {
      return jsonError(e.message, status: 409);
    }
  }

  Future<Response> _setDueDate(Request request, String id) async {
    final check = await auth.requirePermission(request, 'invoices.payment');
    if (check.error != null) return check.error!;
    final companyId = check.auth!.session.companyId;
    final existing = await business.findDocument(companyId, id);
    if (existing == null) return jsonError('Dokument nicht gefunden.', status: 404);
    final body = await _body(request);
    if (!body.containsKey('dueDate')) return jsonError('dueDate (JJJJ-MM-TT oder null) ist Pflicht.');
    final raw = body['dueDate'];
    final dueDate = raw == null ? null : _parseDate(raw);
    if (raw != null && dueDate == null) return jsonError('dueDate im Format JJJJ-MM-TT.');
    try {
      final updated = await business.setPaymentInfo(
        companyId: companyId,
        id: id,
        dueDate: () => dueDate,
        now: DateTime.now().toUtc(),
      );
      await auth.audit(check.auth!, 'document.dueDate', existing.kind, id);
      return await _documentResponse(companyId, updated!);
    } on BusinessConflict catch (e) {
      return jsonError(e.message, status: 409);
    }
  }

  // ---- Zeiterfassung (C3 online) -------------------------------------------------

  /// Sichtbarkeit: mit `timeTracking.read` alle Buchungen der Firma, mit
  /// nur `timeTracking.write` ausschließlich die eigenen.
  Future<({AuthContext? auth, bool seesAll, Response? error})> _timeAccess(Request request) async {
    final session = await auth.requireSession(request);
    if (session == null) return (auth: null, seesAll: false, error: jsonError('Nicht angemeldet.', status: 401));
    final seesAll = await auth.isGranted(session, 'timeTracking.read');
    final canBook = await auth.isGranted(session, 'timeTracking.write');
    if (!seesAll && !canBook) {
      return (auth: null, seesAll: false, error: jsonError('Keine Berechtigung für die Zeiterfassung (oder Modul aus).', status: 403));
    }
    return (auth: session, seesAll: seesAll, error: null);
  }

  Future<Map<String, Object?>> _timeEntryJson(TimeEntry t) async => {
        ...t.toJson(),
        'userEmail': (await repository.findUserById(t.userId))?.email,
      };

  Future<Response> _listTimeEntries(Request request) async {
    final access = await _timeAccess(request);
    if (access.error != null) return access.error!;
    final ctx = access.auth!;
    final params = request.url.queryParameters;
    final mineOnly = !access.seesAll || params['mine'] == 'true';
    final entries = await business.listTimeEntries(
      ctx.session.companyId,
      userId: mineOnly ? ctx.session.userId : params['userId'],
      documentId: params['documentId'],
      projectId: params['projectId'],
      from: _parseDate(params['from']),
      to: _parseDate(params['to']),
    );
    final total = entries.fold<Decimal>(Decimal.zero, (sum, t) => sum + Decimal.parse(t.hours));
    return jsonOk({
      'entries': [for (final t in entries) await _timeEntryJson(t)],
      'totalHours': total.toString(),
      'scope': mineOnly ? 'mine' : 'company',
    });
  }

  /// Validiert Datum/Stunden/Bezug. Bezug: Auftrag/Rechnung und/oder
  /// Projekt — mindestens eines (wie offline). Gehört das Dokument zu
  /// einem Projekt und ist keins angegeben, wird es übernommen.
  Future<({DateTime? date, Decimal? hours, String? documentId, String? projectId, String? error})> _parseTimeBody(
    Map<String, Object?> body,
    AuthContext ctx,
  ) async {
    final companyId = ctx.session.companyId;
    ({DateTime? date, Decimal? hours, String? documentId, String? projectId, String? error}) fail(String e) =>
        (date: null, hours: null, documentId: null, projectId: null, error: e);
    final date = _parseDate(body['date']);
    if (date == null) return fail('date (JJJJ-MM-TT) ist Pflicht.');
    final rawHours = body['hours'];
    final hours = rawHours is num
        ? Decimal.tryParse(rawHours.toString())
        : rawHours is String
            ? Decimal.tryParse(rawHours.replaceAll(',', '.'))
            : null;
    if (hours == null || hours <= Decimal.zero || hours > Decimal.fromInt(24)) {
      return fail('hours muss größer 0 und höchstens 24 sein.');
    }
    final documentId = body['documentId'] as String?;
    var projectId = body['projectId'] as String?;
    if (documentId == null && projectId == null) return fail('documentId (Auftrag/Rechnung) oder projectId ist Pflicht.');
    if (documentId != null) {
      final document = await business.findDocument(companyId, documentId);
      if (document == null || !{'order', 'invoice'}.contains(document.kind)) {
        return fail('Auftrag/Rechnung nicht gefunden.');
      }
      if (!body.containsKey('projectId')) projectId = document.projectId;
    }
    if (projectId != null) {
      final company = await repository.findCompanyById(companyId);
      final project = await business.findProject(companyId, projectId);
      if (project == null || !(company?.enabledModules.contains('projects') ?? false)) {
        return fail('Projekt nicht gefunden.');
      }
    }
    return (date: date, hours: hours, documentId: documentId, projectId: projectId, error: null);
  }

  Future<Response> _createTimeEntry(Request request) async {
    final check = await auth.requirePermission(request, 'timeTracking.write');
    if (check.error != null) return check.error!;
    final ctx = check.auth!;
    final body = await _body(request);
    final parsed = await _parseTimeBody(body, ctx);
    if (parsed.error != null) {
      return jsonError(parsed.error!, status: parsed.error!.contains('nicht gefunden') ? 404 : 400);
    }
    final now = DateTime.now().toUtc();
    final entry = TimeEntry(
      id: _uuid.v4(),
      companyId: ctx.session.companyId,
      userId: ctx.session.userId,
      documentId: parsed.documentId,
      projectId: parsed.projectId,
      workDate: parsed.date!,
      hours: parsed.hours!.toString(),
      note: _trimmed(body['note']),
      hourlyCostCents: ctx.membership.hourlyCostCents,
      createdAt: now,
      updatedAt: now,
    );
    await business.createTimeEntry(entry);
    await auth.audit(ctx, 'timeEntry.create', 'timeEntry', entry.id);
    return jsonOk(await _timeEntryJson(entry), status: 201);
  }

  /// Nur eigene Buchungen ändern/löschen. Fremde, aber sichtbare -> 403;
  /// nicht sichtbare (ohne Leserecht) -> 404 wie nicht existierend.
  Future<({AuthContext? auth, TimeEntry? entry, Response? error})> _ownEntry(Request request, String id) async {
    final check = await auth.requirePermission(request, 'timeTracking.write');
    if (check.error != null) return (auth: null, entry: null, error: check.error);
    final ctx = check.auth!;
    final entry = await business.findTimeEntry(ctx.session.companyId, id);
    if (entry == null) return (auth: null, entry: null, error: jsonError('Buchung nicht gefunden.', status: 404));
    if (entry.userId != ctx.session.userId) {
      final seesAll = await auth.isGranted(ctx, 'timeTracking.read');
      return (
        auth: null,
        entry: null,
        error: seesAll
            ? jsonError('Nur eigene Buchungen können geändert werden.', status: 403)
            : jsonError('Buchung nicht gefunden.', status: 404),
      );
    }
    return (auth: ctx, entry: entry, error: null);
  }

  Future<Response> _updateTimeEntry(Request request, String id) async {
    final own = await _ownEntry(request, id);
    if (own.error != null) return own.error!;
    final body = await _body(request);
    final parsed = await _parseTimeBody(body, own.auth!);
    if (parsed.error != null) {
      return jsonError(parsed.error!, status: parsed.error!.contains('nicht gefunden') ? 404 : 400);
    }
    final e = own.entry!;
    final updated = TimeEntry(
      id: e.id,
      companyId: e.companyId,
      userId: e.userId,
      documentId: parsed.documentId,
      projectId: parsed.projectId,
      workDate: parsed.date!,
      hours: parsed.hours!.toString(),
      note: _trimmed(body['note']),
      hourlyCostCents: e.hourlyCostCents,
      createdAt: e.createdAt,
      updatedAt: DateTime.now().toUtc(),
    );
    await business.updateTimeEntry(updated);
    await auth.audit(own.auth!, 'timeEntry.update', 'timeEntry', id);
    return jsonOk(await _timeEntryJson(updated));
  }

  Future<Response> _deleteTimeEntry(Request request, String id) async {
    final own = await _ownEntry(request, id);
    if (own.error != null) return own.error!;
    await business.deleteTimeEntry(own.auth!.session.companyId, id);
    await auth.audit(own.auth!, 'timeEntry.delete', 'timeEntry', id);
    return Response(204);
  }

  // ---- Projekte (C1 online) --------------------------------------------------------

  /// Ein Dokument/eine Zeit darf nur auf ein existierendes Projekt der
  /// eigenen Firma verweisen; das Projekt muss für den Nutzer sichtbar sein.
  Future<Response?> _checkProjectReference(AuthContext ctx, String projectId) async {
    if (!await auth.isGranted(ctx, 'projects.read')) {
      return jsonError('Keine Berechtigung: projects.read', status: 403);
    }
    if (await business.findProject(ctx.session.companyId, projectId) == null) {
      return jsonError('Projekt nicht gefunden.', status: 404);
    }
    return null;
  }

  Future<Response> _setDocumentProject(Request request, String id) async {
    final session = await auth.requireSession(request);
    if (session == null) return jsonError('Nicht angemeldet.', status: 401);
    final existing = await business.findDocument(session.session.companyId, id);
    if (existing == null) return jsonError('Dokument nicht gefunden.', status: 404);
    final check = await _requireDocumentPermission(request, 'invoices.write', existing.kind);
    if (check.error != null) return check.error!;
    final body = await _body(request);
    final version = body['version'];
    if (version is! int) return jsonError('version (Ganzzahl) ist Pflicht.');
    final projectId = body['projectId'] as String?;
    if (projectId != null) {
      final error = await _checkProjectReference(check.auth!, projectId);
      if (error != null) return error;
    }
    try {
      final updated = await business.setDocumentProject(
        companyId: session.session.companyId,
        id: id,
        expectedVersion: version,
        projectId: projectId,
        now: DateTime.now().toUtc(),
      );
      if (updated == null) return jsonError('Dokument nicht gefunden.', status: 404);
      await auth.audit(check.auth!, 'document.project', existing.kind, id);
      return await _documentResponse(session.session.companyId, updated);
    } on BusinessConflict catch (e) {
      return jsonError(e.message, status: 409);
    }
  }

  Future<Response> _listProjects(Request request) async {
    final check = await auth.requirePermission(request, 'projects.read');
    if (check.error != null) return check.error!;
    final projects = await business.listProjects(
      check.auth!.session.companyId,
      includeArchived: request.url.queryParameters['includeArchived'] == 'true',
    );
    return jsonOk({'projects': [for (final p in projects) p.toJson()]});
  }

  Future<Response> _createProject(Request request) async {
    final check = await auth.requirePermission(request, 'projects.write');
    if (check.error != null) return check.error!;
    final companyId = check.auth!.session.companyId;
    final body = await _body(request);
    final name = _trimmed(body['name']);
    if (name == null) return jsonError('name ist Pflicht.');
    final customerId = body['customerId'] as String?;
    if (customerId != null && await business.findCustomer(companyId, customerId) == null) {
      return jsonError('Kunde nicht gefunden.', status: 404);
    }
    final project = await business.createProject(
      id: _uuid.v4(),
      companyId: companyId,
      name: name,
      customerId: customerId,
      now: DateTime.now().toUtc(),
    );
    await auth.audit(check.auth!, 'project.create', 'project', project.id);
    return jsonOk(project.toJson(), status: 201);
  }

  /// Projekt mit zugeordneten Dokumenten und einfacher Ergebnisrechnung
  /// wie offline (C1/C3.3): Erlöse = Brutto finalisierter Rechnungen,
  /// geplant = Stunden-Positionen aus Angeboten/Aufträgen, Ist/Kosten aus
  /// Zeitbuchungen. Jede Teilsumme nur mit dem passenden Leserecht.
  Future<Response> _getProject(Request request, String id) async {
    final check = await auth.requirePermission(request, 'projects.read');
    if (check.error != null) return check.error!;
    final ctx = check.auth!;
    final companyId = ctx.session.companyId;
    final project = await business.findProject(companyId, id);
    if (project == null) return jsonError('Projekt nicht gefunden.', status: 404);

    final canReadDocuments = await auth.isGranted(ctx, 'invoices.read');
    final modules = await _enabledModules(ctx);
    final documents = <Map<String, Object?>>[];
    int? invoiceGross;
    Decimal? plannedHours;
    if (canReadDocuments) {
      invoiceGross = 0;
      plannedHours = Decimal.zero;
      for (final d in await business.listDocumentsForProject(companyId, id)) {
        final module = documentKindModules[d.kind];
        if (module != null && !modules.contains(module)) continue;
        final items = await business.itemsFor(companyId, d.id);
        final gross = _totals(items).totalGross.cents;
        documents.add({...d.toJson(), 'totalGrossCents': gross});
        if (d.kind == 'invoice' && !d.isDraft) invoiceGross = invoiceGross! + gross;
        if (d.kind == 'quote' || d.kind == 'order') {
          for (final i in items.where((i) => i.kind == 'hours')) {
            plannedHours = plannedHours! + Decimal.parse(i.quantity);
          }
        }
      }
    }

    Decimal? bookedHours;
    int? hoursCost;
    if (await auth.isGranted(ctx, 'timeTracking.read')) {
      bookedHours = Decimal.zero;
      hoursCost = 0;
      for (final t in await business.listTimeEntries(companyId, projectId: id)) {
        final h = Decimal.parse(t.hours);
        bookedHours = bookedHours! + h;
        if (t.hourlyCostCents != null) {
          hoursCost = hoursCost! + Money.fromCents(t.hourlyCostCents!).multiplyByQuantity(h).cents;
        }
      }
    }
    return jsonOk({
      ...project.toJson(),
      'documents': documents,
      'result': {
        'invoiceGrossCents': invoiceGross,
        'plannedHours': plannedHours?.toString(),
        'bookedHours': bookedHours?.toString(),
        'hoursCostCents': hoursCost,
        'resultCents': (invoiceGross != null && hoursCost != null) ? invoiceGross - hoursCost : null,
      },
    });
  }

  Future<Response> _updateProject(Request request, String id) async {
    final check = await auth.requirePermission(request, 'projects.write');
    if (check.error != null) return check.error!;
    final companyId = check.auth!.session.companyId;
    final existing = await business.findProject(companyId, id);
    if (existing == null) return jsonError('Projekt nicht gefunden.', status: 404);
    final body = await _body(request);
    final name = _trimmed(body['name']) ?? existing.name;
    final status = body['status'] as String? ?? existing.status;
    if (!{'active', 'archived'}.contains(status)) return jsonError('status active|archived.');
    final customerId = body.containsKey('customerId') ? body['customerId'] as String? : existing.customerId;
    if (customerId != null && await business.findCustomer(companyId, customerId) == null) {
      return jsonError('Kunde nicht gefunden.', status: 404);
    }
    final updated = Project(
      id: existing.id,
      companyId: companyId,
      name: name,
      customerId: customerId,
      status: status,
      foundingYear: existing.foundingYear,
      projectNumber: existing.projectNumber,
      createdAt: existing.createdAt,
    );
    await business.updateProject(updated);
    await auth.audit(check.auth!, 'project.update', 'project', id);
    return jsonOk(updated.toJson());
  }

  Future<Response> _deleteProject(Request request, String id) async {
    final check = await auth.requirePermission(request, 'projects.write');
    if (check.error != null) return check.error!;
    try {
      if (!await business.deleteProject(check.auth!.session.companyId, id)) {
        return jsonError('Projekt nicht gefunden.', status: 404);
      }
      await auth.audit(check.auth!, 'project.delete', 'project', id);
      return Response(204);
    } on BusinessConflict catch (e) {
      return jsonError(e.message, status: 409);
    }
  }

  /// Gutschrift zu einer finalisierten Rechnung (eigener Kreis "G",
  /// Modul creditNotes): kopiert alle Positionen als Entwurf, der vor dem
  /// Finalisieren auf eine Teil-Gutschrift gekürzt werden kann — wie
  /// offline, bewusst nicht über die allgemeine Umwandlung.
  Future<Response> _createCreditNote(Request request, String id) async {
    final check = await auth.requirePermission(request, 'invoices.write', requiredModule: 'creditNotes');
    if (check.error != null) return check.error!;
    final ctx = check.auth!;
    final companyId = ctx.session.companyId;
    final source = await business.findDocument(companyId, id);
    if (source == null) return jsonError('Dokument nicht gefunden.', status: 404);
    if (source.kind != 'invoice') return jsonError('Eine Gutschrift gibt es nur zu einer Rechnung.', status: 409);
    if (source.isDraft) return jsonError('Nur eine finalisierte Rechnung kann eine Gutschrift erhalten.', status: 409);
    final now = DateTime.now().toUtc();
    final newId = _uuid.v4();
    final items = [
      for (final item in await business.itemsFor(companyId, id))
        DocumentItem(
          id: _uuid.v4(),
          documentId: newId,
          kind: item.kind,
          articleId: item.articleId,
          description: item.description,
          quantity: item.quantity,
          unitPriceCents: item.unitPriceCents,
          vatRatePercent: item.vatRatePercent,
          unit: item.unit,
          discountPercent: item.discountPercent,
          groupLabel: item.groupLabel,
          sortOrder: item.sortOrder,
        ),
    ];
    final draft = Document(
      id: newId,
      companyId: companyId,
      customerId: source.customerId,
      kind: 'creditNote',
      status: 'draft',
      issueDate: DateTime.utc(now.year, now.month, now.day),
      serviceDate: source.serviceDate,
      createdByUserId: ctx.session.userId,
      createdAt: now,
      updatedAt: now,
      version: 1,
      convertedFromId: source.id,
      projectId: source.projectId,
    );
    await business.createDocument(draft, items);
    await auth.audit(ctx, 'document.creditNote', 'creditNote', newId);
    return _documentResponse(companyId, draft, status: 201);
  }
}
