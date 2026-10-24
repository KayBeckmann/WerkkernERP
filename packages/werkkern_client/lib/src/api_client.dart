import 'dart:convert';

import 'package:http/http.dart' as http;

import 'models.dart';

/// Fehlerantwort des Servers. [statusCode] 409 = Konflikt (z. B.
/// veraltete Version — der Client muss neu laden statt zu überschreiben),
/// 401 = Sitzung abgelaufen/beendet, 403 = Recht fehlt/Modul aus.
class ApiException implements Exception {
  const ApiException(this.statusCode, this.message);
  final int statusCode;
  final String message;

  bool get isConflict => statusCode == 409;
  bool get isUnauthorized => statusCode == 401;
  bool get isForbidden => statusCode == 403;

  @override
  String toString() => message;
}

/// Netzwerk nicht erreichbar — bewusst getrennt von [ApiException],
/// damit die UI "Server nicht erreichbar" ehrlich anzeigen kann statt
/// eines vermeintlichen Fachfehlers (Abnahme B: Offline-Grenzen ehrlich
/// anzeigen).
class ApiUnreachable implements Exception {
  const ApiUnreachable(this.cause);
  final Object cause;
  @override
  String toString() => 'Server nicht erreichbar ($cause)';
}

class WerkkernApiClient {
  WerkkernApiClient({required Uri baseUrl, http.Client? httpClient})
      : _baseUrl = baseUrl,
        _http = httpClient ?? http.Client();

  final Uri _baseUrl;
  final http.Client _http;

  /// Firmengebundenes Sitzungs-Token nach [selectCompany].
  String? token;

  Uri _uri(String path, [Map<String, String>? query]) {
    final base = _baseUrl.path.endsWith('/') ? _baseUrl.path.substring(0, _baseUrl.path.length - 1) : _baseUrl.path;
    return _baseUrl.replace(path: '$base$path', queryParameters: (query == null || query.isEmpty) ? null : query);
  }

  Future<Object?> _send(
    String method,
    String path, {
    Object? body,
    Map<String, String>? query,
    String? idempotencyKey,
  }) async {
    final request = http.Request(method, _uri(path, query));
    if (token != null) request.headers['authorization'] = 'Bearer $token';
    if (idempotencyKey != null) request.headers['idempotency-key'] = idempotencyKey;
    if (body != null) {
      request.headers['content-type'] = 'application/json; charset=utf-8';
      request.body = jsonEncode(body);
    }
    final http.Response response;
    try {
      response = await http.Response.fromStream(await _http.send(request));
    } on http.ClientException catch (e) {
      throw ApiUnreachable(e);
    }
    final text = utf8.decode(response.bodyBytes, allowMalformed: true);
    Object? decoded;
    try {
      decoded = text.isEmpty ? null : jsonDecode(text);
    } on FormatException {
      // Kein JSON — z. B. eine HTML-Fehlerseite eines Proxys (502) oder
      // "Route not found" eines älteren Servers. Als Fehler melden statt
      // mit einer FormatException abzustürzen.
      if (response.statusCode < 400) throw ApiException(response.statusCode, 'Unerwartete Antwort des Servers.');
      decoded = null;
    }
    if (response.statusCode >= 400) {
      final message = decoded is Map && decoded['error'] is String
          ? decoded['error'] as String
          : 'Fehler ${response.statusCode}${text.isNotEmpty && text.length < 120 ? ': $text' : ''}';
      throw ApiException(response.statusCode, message);
    }
    return decoded;
  }

  Map<String, Object?> _map(Object? o) => o as Map<String, Object?>;

  // ---- Anmeldung ----------------------------------------------------------

  Future<bool> health() async => _map(await _send('GET', '/health'))['status'] == 'ok';

  Future<OnlineLogin> login(String email, String password) async {
    final j = _map(await _send('POST', '/auth/login', body: {'email': email, 'password': password}));
    return OnlineLogin(
      identityToken: j['identityToken'] as String,
      memberships: [for (final m in j['memberships'] as List) OnlineMembership.fromJson(m as Map<String, Object?>)],
    );
  }

  /// Setzt [token] für alle folgenden Aufrufe.
  Future<void> selectCompany(String identityToken, String companyId) async {
    final j = _map(await _send('POST', '/auth/select-company', body: {'identityToken': identityToken, 'companyId': companyId}));
    token = j['token'] as String;
  }

  /// Eigenes Passwort ändern; beendet alle anderen Sitzungen des Kontos.
  Future<void> changePassword(String currentPassword, String newPassword) =>
      _send('POST', '/auth/change-password', body: {'currentPassword': currentPassword, 'newPassword': newPassword});

  Future<void> logout() async {
    try {
      await _send('POST', '/auth/logout');
    } finally {
      token = null;
    }
  }

  /// Wirksame Rechte der Sitzung — nur zur Anzeige (Aktionen
  /// ausblenden); der Server prüft jede Aktion selbst.
  Future<({bool isAdmin, Set<String> permissions})> myPermissions() async {
    final j = _map(await _send('GET', '/permissions/mine'));
    return (isAdmin: j['isAdmin'] as bool, permissions: {for (final p in j['permissions'] as List) p as String});
  }

  Future<Set<String>> modules() async {
    final j = _map(await _send('GET', '/company/modules'));
    return {for (final m in j['modules'] as List) m as String};
  }

  // ---- Kunden ---------------------------------------------------------------

  Future<List<OnlineCustomer>> customers({String? query}) async {
    final j = _map(await _send('GET', '/customers', query: {if (query != null && query.isNotEmpty) 'q': query}));
    return [for (final c in j['customers'] as List) OnlineCustomer.fromJson(c as Map<String, Object?>)];
  }

  Future<OnlineCustomer> createCustomer(OnlineCustomer draft) async =>
      OnlineCustomer.fromJson(_map(await _send('POST', '/customers', body: draft.toWriteJson())));

  Future<OnlineCustomer> updateCustomer(OnlineCustomer customer) async =>
      OnlineCustomer.fromJson(_map(await _send('PUT', '/customers/${customer.id}', body: customer.toWriteJson())));

  // ---- Artikel ----------------------------------------------------------------

  Future<List<OnlineArticle>> articles({String? query}) async {
    final j = _map(await _send('GET', '/articles', query: {if (query != null && query.isNotEmpty) 'q': query}));
    return [for (final a in j['articles'] as List) OnlineArticle.fromJson(a as Map<String, Object?>)];
  }

  // ---- Dokumente ------------------------------------------------------------------

  Future<List<OnlineDocument>> documents({String? kind, String? status, String? query}) async {
    final j = _map(await _send('GET', '/documents', query: {
      'kind': ?kind,
      'status': ?status,
      if (query != null && query.isNotEmpty) 'q': query,
    }));
    return [for (final d in j['documents'] as List) OnlineDocument.fromJson(d as Map<String, Object?>)];
  }

  Future<OnlineDocument> document(String id) async => OnlineDocument.fromJson(await documentJson(id));

  /// Rohe Serverantwort eines Dokuments (für den Offline-Bestand).
  Future<Map<String, Object?>> documentJson(String id) async => _map(await _send('GET', '/documents/$id'));

  Future<OnlineDocument> createDocument({
    required String customerId,
    String kind = 'invoice',
    List<OnlineDocumentItem> items = const [],
    String? notes,
    String? projectId,
  }) async =>
      OnlineDocument.fromJson(_map(await _send('POST', '/documents', body: {
        'kind': kind,
        'customerId': customerId,
        'items': [for (final i in items) i.toJson()],
        'notes': ?notes,
        'projectId': ?projectId,
      })));

  /// Wirft [ApiException] mit 409, wenn [version] veraltet ist — dann
  /// neu laden und erneut entscheiden, nie blind wiederholen.
  ///
  /// [idempotencyKey]: Operations-ID aus der Offline-Outbox — eine
  /// Wiederholung nach verlorener Antwort wirkt nicht doppelt.
  Future<OnlineDocument> updateDocument({
    required String id,
    required int version,
    required List<OnlineDocumentItem> items,
    String? customerId,
    String? notes,
    String? idempotencyKey,
    bool? isAdvancePayment,
    bool? isFixedPrice,
  }) async =>
      OnlineDocument.fromJson(_map(await _send('PUT', '/documents/$id', idempotencyKey: idempotencyKey, body: {
        'version': version,
        'items': [for (final i in items) i.toJson()],
        'customerId': ?customerId,
        'notes': notes,
        'isAdvancePayment': ?isAdvancePayment,
        'isFixedPrice': ?isFixedPrice,
      })));

  /// Gutschrift-Entwurf zu einer finalisierten Rechnung (Modul creditNotes).
  Future<OnlineDocument> createCreditNote(String invoiceId) async =>
      OnlineDocument.fromJson(_map(await _send('POST', '/documents/$invoiceId/credit-note')));

  Future<void> deleteDocument(String id) => _send('DELETE', '/documents/$id');

  Future<OnlineDocument> finalizeDocument(String id, {required int version}) async =>
      OnlineDocument.fromJson(_map(await _send('POST', '/documents/$id/finalize', body: {'version': version})));

  /// Neuer Entwurf der Zielart aus einem finalisierten Dokument.
  Future<OnlineDocument> convertDocument(String id, String targetKind) async =>
      OnlineDocument.fromJson(_map(await _send('POST', '/documents/$id/convert', body: {'kind': targetKind})));

  Future<OnlineDocument> setPaid(String id, {required bool paid}) async =>
      OnlineDocument.fromJson(_map(await _send('POST', '/documents/$id/payment', body: {'paid': paid})));

  Future<OnlineDocument> setDueDate(String id, DateTime? dueDate) async {
    String? iso(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
    return OnlineDocument.fromJson(
      _map(await _send('PUT', '/documents/$id/due-date', body: {'dueDate': dueDate == null ? null : iso(dueDate)})),
    );
  }

  // ---- Konto/Firma (ohne Firmensitzung) -----------------------------------------

  Future<void> register(String email, String password) =>
      _send('POST', '/auth/register', body: {'email': email, 'password': password});

  /// Legt eine neue Firma an, der Aufrufer wird deren Admin. Verbraucht
  /// das [identityToken] — für die Firmenwahl danach erneut [login].
  Future<String> createCompany(String identityToken, String name) async =>
      _map(await _send('POST', '/companies', body: {'identityToken': identityToken, 'name': name}))['companyId'] as String;

  /// Löst eine Einladung ein (neues Konto oder Nachweis des bestehenden
  /// per Passwort). Liefert die companyId.
  Future<String> acceptInvitation(String invitationToken, String password) async =>
      _map(await _send('POST', '/auth/accept-invitation', body: {'invitationToken': invitationToken, 'password': password}))['companyId']
          as String;

  // ---- Verwaltung (Firmen-Admin) ------------------------------------------------------

  Future<List<OnlineGroup>> groups() async {
    final j = _map(await _send('GET', '/groups'));
    return [
      for (final g in j['groups'] as List)
        OnlineGroup(id: (g as Map<String, Object?>)['id'] as String, name: g['name'] as String),
    ];
  }

  Future<OnlineGroup> createGroup(String name) async {
    final j = _map(await _send('POST', '/groups', body: {'name': name}));
    return OnlineGroup(id: j['id'] as String, name: j['name'] as String);
  }

  Future<Set<String>> groupPermissions(String groupId) async {
    final j = _map(await _send('GET', '/groups/$groupId/permissions'));
    return {for (final p in j['permissions'] as List) p as String};
  }

  Future<void> setGroupPermission(String groupId, String permission, {required bool granted}) =>
      _send('PUT', '/groups/$groupId/permissions/$permission', body: {'granted': granted});

  Future<List<OnlinePermissionInfo>> permissionCatalog() async {
    final j = _map(await _send('GET', '/permissions/catalog'));
    return [
      for (final p in j['permissions'] as List)
        OnlinePermissionInfo(key: (p as Map<String, Object?>)['key'] as String, module: p['module'] as String?),
    ];
  }

  Future<List<OnlineMember>> members() async {
    final j = _map(await _send('GET', '/memberships'));
    return [for (final m in j['memberships'] as List) OnlineMember.fromJson(m as Map<String, Object?>)];
  }

  /// 409 = letzter aktiver Admin würde ausgesperrt. [hourlyCostCents]:
  /// `null` = unverändert, `() => null` = Satz löschen.
  Future<void> updateMember(
    String id, {
    String? groupId,
    bool? active,
    bool? isAdmin,
    int? Function()? hourlyCostCents,
  }) =>
      _send('PATCH', '/memberships/$id', body: {
        'groupId': ?groupId,
        'active': ?active,
        'isAdmin': ?isAdmin,
        if (hourlyCostCents != null) 'hourlyCostCents': hourlyCostCents(),
      });

  /// Individuelle Ausnahmen: Schlüssel -> erlaubt (true) / gesperrt (false).
  Future<Map<String, bool>> memberOverrides(String id) async {
    final j = _map(await _send('GET', '/memberships/$id/overrides'));
    return {
      for (final o in j['overrides'] as List)
        (o as Map<String, Object?>)['permission'] as String: o['allowed'] as bool,
    };
  }

  /// [allowed] `null` entfernt die Ausnahme (zurück auf Gruppenvorgabe).
  Future<void> setMemberOverride(String id, String permission, bool? allowed) => allowed == null
      ? _send('DELETE', '/memberships/$id/overrides/$permission')
      : _send('PUT', '/memberships/$id/overrides/$permission', body: {'allowed': allowed});

  Future<List<OnlineInvitation>> invitations() async {
    final j = _map(await _send('GET', '/invitations'));
    return [
      for (final i in j['invitations'] as List)
        OnlineInvitation(
          id: (i as Map<String, Object?>)['id'] as String,
          email: i['email'] as String,
          groupId: i['groupId'] as String,
          expiresAt: DateTime.parse(i['expiresAt'] as String),
          expired: i['expired'] as bool,
        ),
    ];
  }

  /// Liefert das einmalig im Klartext ausgegebene Einladungs-Token.
  Future<String> createInvitation(String email, String groupId) async =>
      _map(await _send('POST', '/invitations', body: {'email': email, 'groupId': groupId}))['invitationToken'] as String;

  Future<void> revokeInvitation(String id) => _send('DELETE', '/invitations/$id');

  Future<void> setModules(Set<String> modules) => _send('PUT', '/company/modules', body: {'modules': modules.toList()});

  Future<OnlineCompanyProfile> companyProfile() async =>
      OnlineCompanyProfile.fromJson(_map(await _send('GET', '/company/profile')));

  Future<void> saveCompanyProfile(OnlineCompanyProfile profile) => _send('PUT', '/company/profile', body: profile.toJson());

  Future<List<OnlineAuditEntry>> audit({int limit = 200}) async {
    final j = _map(await _send('GET', '/audit', query: {'limit': '$limit'}));
    return [
      for (final e in j['entries'] as List)
        OnlineAuditEntry(
          at: DateTime.parse((e as Map<String, Object?>)['at'] as String),
          userEmail: e['userEmail'] as String?,
          action: e['action'] as String,
          entityType: e['entityType'] as String,
        ),
    ];
  }

  // ---- Zeiterfassung (C3 online) ------------------------------------------------

  /// Eigene Buchungen bzw. (mit `timeTracking.read`) die der ganzen Firma.
  Future<({List<OnlineTimeEntry> entries, String totalHours, bool companyScope})> timeEntries({
    bool mineOnly = false,
    String? documentId,
  }) async {
    final j = _map(await _send('GET', '/time-entries', query: {
      if (mineOnly) 'mine': 'true',
      'documentId': ?documentId,
    }));
    return (
      entries: [for (final e in j['entries'] as List) OnlineTimeEntry.fromJson(e as Map<String, Object?>)],
      totalHours: j['totalHours'] as String,
      companyScope: j['scope'] == 'company',
    );
  }

  /// Bezug: [documentId] und/oder [projectId] (mindestens eines).
  Future<OnlineTimeEntry> saveTimeEntry({
    String? id,
    required DateTime date,
    required String hours,
    String? documentId,
    String? projectId,
    String? note,
  }) async {
    final body = {
      'date': '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
      'hours': hours,
      'documentId': ?documentId,
      'projectId': ?projectId,
      'note': note,
    };
    return OnlineTimeEntry.fromJson(
      _map(await (id == null ? _send('POST', '/time-entries', body: body) : _send('PUT', '/time-entries/$id', body: body))),
    );
  }

  Future<void> deleteTimeEntry(String id) => _send('DELETE', '/time-entries/$id');

  // ---- Projekte (C1 online) -----------------------------------------------------

  Future<List<OnlineProject>> projects({bool includeArchived = false}) async {
    final j = _map(await _send('GET', '/projects', query: {if (includeArchived) 'includeArchived': 'true'}));
    return [for (final p in j['projects'] as List) OnlineProject.fromJson(p as Map<String, Object?>)];
  }

  Future<OnlineProject> createProject(String name, {String? customerId}) async =>
      OnlineProject.fromJson(_map(await _send('POST', '/projects', body: {'name': name, 'customerId': ?customerId})));

  Future<OnlineProject> updateProject(String id, {String? name, String? status}) async =>
      OnlineProject.fromJson(_map(await _send('PUT', '/projects/$id', body: {'name': ?name, 'status': ?status})));

  Future<OnlineProjectDetail> projectDetail(String id) async =>
      OnlineProjectDetail.fromJson(_map(await _send('GET', '/projects/$id')));

  /// Projekt eines Entwurfs setzen/entfernen ([projectId] `null`).
  Future<OnlineDocument> setDocumentProject(String id, {required int version, String? projectId}) async =>
      OnlineDocument.fromJson(_map(await _send('PUT', '/documents/$id/project', body: {'version': version, 'projectId': projectId})));

  // ---- KI-Agenten (C8) ------------------------------------------------------------

  /// Neues Agent-Token (nur aus einer App-Sitzung; Firmenmodul
  /// `aiAgents` muss aktiv sein). Das Token wird genau einmal geliefert.
  Future<({String id, String token})> createAgentToken(String label) async {
    final j = _map(await _send('POST', '/agent-tokens', body: {'label': label}));
    return (id: j['id'] as String, token: j['token'] as String);
  }

  Future<List<({String id, String label, DateTime createdAt, DateTime? lastUsedAt})>> agentTokens() async {
    final j = _map(await _send('GET', '/agent-tokens'));
    return [
      for (final t in j['tokens'] as List)
        (
          id: (t as Map<String, Object?>)['id'] as String,
          label: t['label'] as String,
          createdAt: DateTime.parse(t['createdAt'] as String),
          lastUsedAt: t['lastUsedAt'] == null ? null : DateTime.parse(t['lastUsedAt'] as String),
        ),
    ];
  }

  Future<void> revokeAgentToken(String id) => _send('DELETE', '/agent-tokens/$id');

  /// Freigabe-Anfragen irreversibler Agent-Aktionen.
  Future<List<({String id, String summary, String status, DateTime createdAt, int? resultStatus})>> approvals({
    String? status,
  }) async {
    final j = _map(await _send('GET', '/approvals', query: {'status': ?status}));
    return [
      for (final a in j['approvals'] as List)
        (
          id: (a as Map<String, Object?>)['id'] as String,
          summary: a['summary'] as String,
          status: a['status'] as String,
          createdAt: DateTime.parse(a['createdAt'] as String),
          resultStatus: a['resultStatus'] as int?,
        ),
    ];
  }

  /// Führt die angefragte Aktion mit der eigenen Sitzung aus (Server
  /// prüft dabei alles neu) und liefert dessen Antwort.
  Future<Object?> confirmApproval(String id) => _send('POST', '/approvals/$id/confirm');

  Future<void> rejectApproval(String id) => _send('POST', '/approvals/$id/reject');

  /// Roh-Aufruf für dünne Adapter (MCP): Server-JSON unverändert, Fehler
  /// wie gewohnt als [ApiException]/[ApiUnreachable].
  Future<Object?> request(String method, String path, {Object? body, Map<String, String>? query}) =>
      _send(method, path, body: body, query: query);

  void close() => _http.close();
}
