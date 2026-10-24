import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:uuid/uuid.dart';

import 'models.dart';
import 'auth.dart';
import 'business/repository.dart';
import 'business/router.dart';
import 'login_throttle.dart';
import 'permission_catalog.dart';
import 'repository.dart';
import 'util/passwords.dart';
import 'util/responses.dart';
import 'util/tokens.dart';

/// Startvorlagen laut Roadmap B1 Punkt 1 — bewusst nur Namen, keine
/// vorbelegten Rechte (siehe Klassendoc bei [Group]).
const _starterGroupNames = ['Projektleiter', 'Monteur', 'Buchhaltung'];

/// B1 Mitgliedschaften, Gruppen, Backend-Isolation. Siehe
/// Roadmap-Abnahme: "Admin A erstellt/deaktiviert Zeichner in Firma A,
/// kann keine Nutzer in Firma B sehen/ändern" (hier: Mitgliedschaften/
/// Gruppen statt Zeichner) — "Negativtests mit erratenen IDs, direkten
/// URLs ... Cross-Tenant-Tests".
class PhaseBRouter {
  PhaseBRouter({
    required this.repository,
    this.business,
    this.sessionTtl = const Duration(hours: 8),
    this.invitationTtl = const Duration(days: 7),
    this.corsAllowedOrigins = const {},
    LoginThrottle? loginThrottle,
    this.trustForwardedFor = false,
  }) : loginThrottle = loginThrottle ?? LoginThrottle();

  /// Schutz gegen Passwort-Durchprobieren (Login, Einladung mit
  /// bestehendem Konto, Passwortänderung).
  final LoginThrottle loginThrottle;

  /// Nur hinter einem eigenen Reverse-Proxy (TLS) setzen — dann gilt die
  /// erste Adresse aus `X-Forwarded-For` als Absender, sonst die direkte
  /// Verbindung (ein Client könnte den Header sonst frei fälschen).
  final bool trustForwardedFor;

  /// Origins, die den Server aus dem Browser ansprechen dürfen (Flutter-
  /// Web-Build). Leer = kein CORS (nur native Apps). `*` erlaubt alle —
  /// vertretbar, weil die Authentifizierung über den
  /// Authorization-Header läuft, den ein Browser nie automatisch
  /// mitsendet (keine Cookies, kein CSRF-Risiko).
  final Set<String> corsAllowedOrigins;

  /// Router ohne CORS/Idempotenz-Hülle — für die Ausführung bestätigter
  /// Freigaben (C8) mit der Sitzung des bestätigenden Nutzers.
  late final Handler _innerHandler;

  final PhaseBRepository repository;

  /// Fachdaten (B1 Punkt 3) — optional, damit reine Mitgliedschafts-
  /// Tests ohne Fach-Repository auskommen.
  final BusinessRepository? business;
  late final SessionAuthenticator _auth = SessionAuthenticator(repository);
  final Duration sessionTtl;
  final Duration invitationTtl;
  static const _uuid = Uuid();

  /// Fehlerhaftes JSON bzw. falsche Feldtypen im Request-Body sind ein
  /// Client-Fehler (400), kein Serverabsturz (500) — fängt
  /// [FormatException] aus `jsonDecode` und [TypeError] aus den
  /// `as String?`-Casts zentral ab, statt jeden Endpunkt einzeln
  /// abzusichern.
  Handler get handler {
    final router = _buildRouter();
    Future<Response> handle(Request request) async {
      try {
        return await router.call(request);
      } on FormatException {
        return jsonError('Ungültiger JSON-Body.');
      } on TypeError {
        return jsonError('Ungültiger Feldtyp im JSON-Body.');
      }
    }

    _innerHandler = handle;
    final idempotent = _withIdempotency(handle);
    return (Request request) async {
      final origin = request.headers['origin'];
      final allowed = origin != null &&
          (corsAllowedOrigins.contains('*') || corsAllowedOrigins.contains(origin));
      if (!allowed) return idempotent(request);
      final corsHeaders = {
        'access-control-allow-origin': corsAllowedOrigins.contains('*') ? '*' : origin,
        'access-control-allow-methods': 'GET, POST, PUT, PATCH, DELETE, OPTIONS',
        'access-control-allow-headers': 'authorization, content-type',
        'access-control-max-age': '600',
        'vary': 'origin',
      };
      if (request.method == 'OPTIONS') return Response(204, headers: corsHeaders);
      return (await idempotent(request)).change(headers: corsHeaders);
    };
  }

  /// B2: Schreibaufrufe mit `Idempotency-Key`-Header (z. B. aus der
  /// Offline-Outbox) wirken höchstens einmal. Der Schlüssel gilt je
  /// Firma + Nutzer; dieselbe Anfrage erneut -> gespeicherte Antwort
  /// (`idempotent-replay: true`), anderer Inhalt unter demselben
  /// Schlüssel -> 422, noch in Bearbeitung -> 409. Ohne gültige Sitzung
  /// wird nichts gespeichert (der Aufruf scheitert ohnehin mit 401).
  Handler _withIdempotency(Handler inner) => (Request request) async {
        final key = request.headers['idempotency-key'];
        if (key == null || request.method == 'GET' || request.method == 'OPTIONS') return inner(request);
        if (key.isEmpty || key.length > 200) return jsonError('Idempotency-Key ungültig.');
        final auth = await _auth.requireSession(request);
        if (auth == null) return inner(request);
        final companyId = auth.session.companyId;
        final userId = auth.session.userId;

        final body = await request.readAsString();
        final fingerprint = sha256.convert(utf8.encode('${request.method} ${request.url.path}\n$body')).toString();
        final replay = request.change(body: body);

        final existing = await repository.findIdempotentResponse(companyId: companyId, userId: userId, key: key);
        if (existing != null) return _replay(existing, fingerprint);
        final claimed = await repository.claimIdempotencyKey(
          companyId: companyId,
          userId: userId,
          key: key,
          requestFingerprint: fingerprint,
        );
        if (!claimed) {
          final raced = await repository.findIdempotentResponse(companyId: companyId, userId: userId, key: key);
          return raced == null ? jsonError('Bitte erneut senden.', status: 409) : _replay(raced, fingerprint);
        }

        final Response response;
        try {
          response = await inner(replay);
        } catch (_) {
          await repository.releaseIdempotencyKey(companyId: companyId, userId: userId, key: key);
          rethrow;
        }
        final responseBody = await response.readAsString();
        if (response.statusCode >= 500) {
          await repository.releaseIdempotencyKey(companyId: companyId, userId: userId, key: key);
        } else {
          await repository.completeIdempotencyKey(
            companyId: companyId,
            userId: userId,
            key: key,
            status: response.statusCode,
            body: responseBody,
          );
        }
        return Response(response.statusCode, body: responseBody, headers: response.headers);
      };

  Response _replay(StoredResponse stored, String fingerprint) {
    if (stored.requestFingerprint != fingerprint) {
      return jsonError('Idempotency-Key wurde bereits für eine andere Anfrage verwendet.', status: 422);
    }
    if (stored.status == 0) return jsonError('Anfrage mit diesem Idempotency-Key wird noch verarbeitet.', status: 409);
    return Response(
      stored.status,
      body: stored.body,
      headers: {'content-type': 'application/json; charset=utf-8', 'idempotent-replay': 'true'},
    );
  }

  Router _buildRouter() {
    final router = Router();
    router.get('/health', (Request request) => healthResponse());

    router.post('/auth/register', _register);
    router.post('/auth/login', _login);
    router.post('/auth/select-company', _selectCompany);
    router.post('/auth/logout', _logout);
    router.post('/auth/change-password', _changePassword);
    router.post('/auth/accept-invitation', _acceptInvitation);
    router.get('/me', _me);

    router.post('/companies', _createCompany);
    router.get('/company/modules', _getModules);
    router.get('/company/profile', _getProfile);
    router.put('/company/profile', _setProfile);
    router.get('/audit', _listAudit);
    router.put('/company/modules', _setModules);

    router.get('/groups', _listGroups);
    router.post('/groups', _createGroup);
    router.get('/groups/<groupId>/permissions', _listGroupPermissions);
    router.put('/groups/<groupId>/permissions/<permission>', _setGroupPermission);

    router.get('/memberships', _listMemberships);
    router.post('/memberships', _createMembership);
    router.patch('/memberships/<id>', _updateMembership);
    router.get('/memberships/<id>/overrides', _listOverrides);
    router.put('/memberships/<id>/overrides/<permission>', _setOverride);
    router.delete('/memberships/<id>/overrides/<permission>', _removeOverride);

    router.post('/invitations', _createInvitation);
    router.get('/invitations', _listInvitations);
    router.delete('/invitations/<id>', _revokeInvitation);

    router.post('/agent-tokens', _createAgentToken);
    router.get('/agent-tokens', _listAgentTokens);
    router.delete('/agent-tokens/<id>', _revokeAgentToken);
    router.get('/approvals', _listApprovals);
    router.post('/approvals/<id>/confirm', _confirmApproval);
    router.post('/approvals/<id>/reject', _rejectApproval);

    router.get('/permissions/catalog', _permissionCatalog);
    router.get('/permissions/effective', _effectivePermission);
    router.get('/permissions/mine', _myPermissions);

    if (business != null) {
      BusinessRoutes(repository: repository, business: business!, auth: _auth).mount(router);
    }

    return router;
  }

  Future<Map<String, Object?>> _bodyJson(Request request) async {
    final raw = await request.readAsString();
    if (raw.isEmpty) return const {};
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, Object?>) throw const FormatException('JSON-Objekt erwartet');
    return decoded;
  }

  // ---- Auth ----------------------------------------------------------------

  Future<Response> _register(Request request) async {
    final body = await _bodyJson(request);
    final email = (body['email'] as String?)?.trim();
    final password = body['password'] as String?;
    if (email == null || email.isEmpty || password == null || password.length < 8) {
      return jsonError('email und password (mind. 8 Zeichen) sind Pflicht.');
    }
    if (await repository.findUserByEmail(email) != null) {
      return jsonError('E-Mail bereits registriert.', status: 409);
    }
    final user = await repository.createUser(id: _uuid.v4(), email: email, passwordHash: Passwords.hash(password));
    return jsonOk({'userId': user.id, 'email': user.email}, status: 201);
  }

  String? _clientAddress(Request request) {
    if (trustForwardedFor) {
      final forwarded = request.headers['x-forwarded-for'];
      if (forwarded != null && forwarded.isNotEmpty) return forwarded.split(',').first.trim();
    }
    final info = request.context['shelf.io.connection_info'];
    return info is HttpConnectionInfo ? info.remoteAddress.address : null;
  }

  Response? _throttled(String account, Request request) {
    final wait = loginThrottle.blockedFor(account: account, address: _clientAddress(request));
    if (wait == null) return null;
    final seconds = wait.inSeconds < 1 ? 1 : wait.inSeconds;
    return jsonOk(
      {'error': 'Zu viele Fehlversuche — bitte in ${(seconds / 60).ceil()} Minute(n) erneut versuchen.'},
      status: 429,
    ).change(headers: {'retry-after': '$seconds'});
  }

  Future<Response> _login(Request request) async {
    final body = await _bodyJson(request);
    final email = body['email'] as String?;
    final password = body['password'] as String?;
    if (email == null || password == null) return jsonError('email und password sind Pflicht.');
    final throttled = _throttled(email, request);
    if (throttled != null) return throttled;

    final user = await repository.findUserByEmail(email);
    if (user == null || !Passwords.verify(password, user.passwordHash)) {
      loginThrottle.recordFailure(account: email, address: _clientAddress(request));
      return jsonError('E-Mail oder Passwort falsch.', status: 401);
    }
    loginThrottle.recordSuccess(account: email);

    final memberships = await repository.listMembershipsForUser(user.id);
    final visibleMemberships = <Map<String, Object?>>[];
    for (final membership in memberships.where((m) => m.active)) {
      final company = await repository.findCompanyById(membership.companyId);
      final group = await repository.findGroupById(membership.groupId);
      if (company == null || group == null) continue;
      visibleMemberships.add({
        'companyId': company.id,
        'companyName': company.name,
        'groupName': group.name,
        'isAdmin': membership.isAdmin,
      });
    }

    final pendingToken = Tokens.generate();
    await repository.savePendingLogin(
      tokenHash: Tokens.hashOf(pendingToken),
      userId: user.id,
      expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 10)),
    );
    return jsonOk({'identityToken': pendingToken, 'memberships': visibleMemberships});
  }

  Future<Response> _selectCompany(Request request) async {
    final body = await _bodyJson(request);
    final identityToken = body['identityToken'] as String?;
    final companyId = body['companyId'] as String?;
    if (identityToken == null || companyId == null) {
      return jsonError('identityToken und companyId sind Pflicht.');
    }

    final userId = await repository.consumePendingLogin(Tokens.hashOf(identityToken), DateTime.now().toUtc());
    if (userId == null) {
      return jsonError('identityToken ungültig oder abgelaufen — bitte erneut anmelden.', status: 401);
    }

    final membership = await repository.findMembership(userId: userId, companyId: companyId);
    if (membership == null || !membership.active) {
      return jsonError('Keine aktive Mitgliedschaft in dieser Firma.', status: 403);
    }
    final company = await repository.findCompanyById(companyId);
    final group = await repository.findGroupById(membership.groupId);
    if (company == null || group == null) return jsonError('Firma oder Gruppe nicht gefunden.', status: 404);

    final rawToken = Tokens.generate();
    final now = DateTime.now().toUtc();
    await repository.saveSession(
      CompanySession(
        tokenHash: Tokens.hashOf(rawToken),
        membershipId: membership.id,
        userId: userId,
        companyId: companyId,
        createdAt: now,
        expiresAt: now.add(sessionTtl),
      ),
    );
    return jsonOk({
      'token': rawToken,
      'companyName': company.name,
      'groupName': group.name,
      'isAdmin': membership.isAdmin,
    });
  }

  /// Eigenes Passwort ändern (nur aus einer App-Sitzung, aktuelles
  /// Passwort nötig). Beendet alle ANDEREN Sitzungen des Kontos — ein
  /// Gerät mit möglicherweise kompromittiertem Zugang fliegt sofort raus.
  /// Agent-Token bleiben bestehen (eigene Zugangsdaten, separat widerrufbar).
  Future<Response> _changePassword(Request request) async {
    final auth = await _auth.requireHumanSession(request);
    if (auth == null) return jsonError('Nicht angemeldet.', status: 401);
    final user = await repository.findUserById(auth.session.userId);
    if (user == null) return jsonError('Nicht angemeldet.', status: 401);
    final body = await _bodyJson(request);
    final current = body['currentPassword'] as String?;
    final next = body['newPassword'] as String?;
    if (current == null || next == null || next.length < 8) {
      return jsonError('currentPassword und newPassword (mind. 8 Zeichen) sind Pflicht.');
    }
    final throttled = _throttled(user.email, request);
    if (throttled != null) return throttled;
    if (!Passwords.verify(current, user.passwordHash)) {
      loginThrottle.recordFailure(account: user.email, address: _clientAddress(request));
      return jsonError('Aktuelles Passwort ist falsch.', status: 403);
    }
    await repository.updatePasswordHash(user.id, Passwords.hash(next));
    await repository.deleteSessionsForUser(user.id, exceptTokenHash: auth.session.tokenHash);
    await _auth.audit(auth, 'user.passwordChange', 'user', user.id);
    return Response(204);
  }

  Future<Response> _logout(Request request) async {
    final token = _bearerToken(request);
    if (token != null) await repository.deleteSession(Tokens.hashOf(token));
    return Response(204);
  }

  Future<Response> _me(Request request) async {
    final auth = await _requireSession(request);
    if (auth == null) return jsonError('Nicht angemeldet.', status: 401);
    final user = await repository.findUserById(auth.session.userId);
    final company = await repository.findCompanyById(auth.session.companyId);
    final group = await repository.findGroupById(auth.membership.groupId);
    return jsonOk({
      'email': user?.email,
      'companyName': company?.name,
      'groupId': auth.membership.groupId,
      'groupName': group?.name,
      'isAdmin': auth.membership.isAdmin,
    });
  }

  // ---- Firmen ----------------------------------------------------------------

  /// Erfordert einen `identityToken` (angemeldeter Nutzer ohne
  /// Firmenkontext) statt eines Super-Admin-Gatekeepers, wie
  /// LibreECAD ihn hat — die Roadmap beschreibt für WerkkernERP Phase
  /// B keinen solchen Gatekeeper, Firmenanlage bleibt hier bewusst
  /// einfacher (siehe docs/phase-b-server.md, "Erstadmin/Recovery
  /// offen" laut Roadmap). Der anlegende Nutzer wird automatisch
  /// Admin, zugeordnete Gruppe per Default "Projektleiter" (reine
  /// technische Vorbelegung, keine fachliche Aussage).
  Future<Response> _createCompany(Request request) async {
    final body = await _bodyJson(request);
    final identityToken = body['identityToken'] as String?;
    final name = (body['name'] as String?)?.trim();
    if (identityToken == null || name == null || name.isEmpty) {
      return jsonError('identityToken und name sind Pflicht.');
    }
    final userId = await repository.consumePendingLogin(Tokens.hashOf(identityToken), DateTime.now().toUtc());
    if (userId == null) return jsonError('identityToken ungültig oder abgelaufen.', status: 401);

    final company = await repository.createCompany(id: _uuid.v4(), name: name);
    Group? defaultGroup;
    for (final groupName in _starterGroupNames) {
      final group = await repository.createGroup(id: _uuid.v4(), companyId: company.id, name: groupName);
      defaultGroup ??= group;
    }
    await repository.createMembership(
      id: _uuid.v4(),
      userId: userId,
      companyId: company.id,
      groupId: defaultGroup!.id,
      isAdmin: true,
    );
    await repository.recordAudit(AuditEntry(
      companyId: company.id,
      userId: userId,
      action: 'company.create',
      entityType: 'company',
      entityId: company.id,
      at: DateTime.now().toUtc(),
    ));
    return jsonOk({'companyId': company.id, 'name': company.name}, status: 201);
  }

  // ---- Gruppen ----------------------------------------------------------------

  Future<Response> _listGroups(Request request) async {
    final auth = await _requireSession(request);
    if (auth == null) return jsonError('Nicht angemeldet.', status: 401);
    final groups = await repository.listGroupsForCompany(auth.session.companyId);
    return jsonOk({'groups': [for (final g in groups) {'id': g.id, 'name': g.name}]});
  }

  Future<Response> _createGroup(Request request) async {
    final auth = await _requireAdmin(request);
    if (auth == null) return jsonError('Nicht angemeldet oder keine Admin-Rechte.', status: 403);
    final body = await _bodyJson(request);
    final name = (body['name'] as String?)?.trim();
    if (name == null || name.isEmpty) return jsonError('name ist Pflicht.');
    final group = await repository.createGroup(id: _uuid.v4(), companyId: auth.session.companyId, name: name);
    await _auth.audit(auth, 'group.create', 'group', group.id);
    return jsonOk({'id': group.id, 'name': group.name}, status: 201);
  }

  Future<Response> _listGroupPermissions(Request request, String groupId) async {
    final auth = await _requireSession(request);
    if (auth == null) return jsonError('Nicht angemeldet.', status: 401);
    final group = await repository.findGroupById(groupId);
    if (group == null || group.companyId != auth.session.companyId) {
      return jsonError('Gruppe nicht gefunden.', status: 404);
    }
    final permissions = await repository.listGroupPermissions(groupId);
    return jsonOk({'permissions': permissions.map((p) => p.permission).toList()});
  }

  Future<Response> _setGroupPermission(Request request, String groupId, String permission) async {
    final auth = await _requireAdmin(request);
    if (auth == null) return jsonError('Nicht angemeldet oder keine Admin-Rechte.', status: 403);
    final group = await repository.findGroupById(groupId);
    if (group == null || group.companyId != auth.session.companyId) {
      return jsonError('Gruppe nicht gefunden.', status: 404);
    }
    if (!isKnownPermission(permission)) return jsonError('Unbekannte Berechtigung: $permission');
    final body = await _bodyJson(request);
    final granted = body['granted'] as bool?;
    if (granted == null) return jsonError('granted (bool) ist Pflicht.');
    await repository.setGroupPermission(groupId: groupId, permission: permission, granted: granted);
    await _auth.audit(auth, granted ? 'group.permission.grant:$permission' : 'group.permission.revoke:$permission', 'group', groupId);
    return jsonOk({'groupId': groupId, 'permission': permission, 'granted': granted});
  }

  // ---- Mitgliedschaften ---------------------------------------------------------

  Future<Response> _listMemberships(Request request) async {
    final auth = await _requireAdmin(request);
    if (auth == null) return jsonError('Nicht angemeldet oder keine Admin-Rechte.', status: 403);
    final memberships = await repository.listMembershipsForCompany(auth.session.companyId);
    final result = <Map<String, Object?>>[];
    for (final m in memberships) {
      final user = await repository.findUserById(m.userId);
      final group = await repository.findGroupById(m.groupId);
      result.add({
        'id': m.id,
        'email': user?.email,
        'groupId': m.groupId,
        'groupName': group?.name,
        'isAdmin': m.isAdmin,
        'active': m.active,
        'hourlyCostCents': m.hourlyCostCents,
      });
    }
    return jsonOk({'memberships': result});
  }

  /// Fügt einen **bereits registrierten** Nutzer (siehe `/auth/register`)
  /// der eigenen Firma hinzu — bewusst kein Einladungs-/
  /// Aktivierungstoken-Mechanismus in diesem B1-Grundgerüst (siehe
  /// docs/phase-b-server.md für die bewusst zurückgestellte
  /// Onboarding-UX).
  Future<Response> _createMembership(Request request) async {
    final auth = await _requireAdmin(request);
    if (auth == null) return jsonError('Nicht angemeldet oder keine Admin-Rechte.', status: 403);
    final body = await _bodyJson(request);
    final email = body['email'] as String?;
    final groupId = body['groupId'] as String?;
    if (email == null || groupId == null) return jsonError('email und groupId sind Pflicht.');

    final user = await repository.findUserByEmail(email);
    if (user == null) return jsonError('Kein registrierter Nutzer mit dieser E-Mail.', status: 404);
    final group = await repository.findGroupById(groupId);
    if (group == null || group.companyId != auth.session.companyId) {
      return jsonError('Gruppe nicht gefunden.', status: 404);
    }
    if (await repository.findMembership(userId: user.id, companyId: auth.session.companyId) != null) {
      return jsonError('Nutzer ist bereits Mitglied dieser Firma.', status: 409);
    }

    final membership = await repository.createMembership(
      id: _uuid.v4(),
      userId: user.id,
      companyId: auth.session.companyId,
      groupId: groupId,
      isAdmin: false,
    );
    await _auth.audit(auth, 'membership.create', 'membership', membership.id);
    return jsonOk({'id': membership.id, 'email': user.email, 'groupId': groupId}, status: 201);
  }

  Future<Response> _updateMembership(Request request, String id) async {
    final auth = await _requireAdmin(request);
    if (auth == null) return jsonError('Nicht angemeldet oder keine Admin-Rechte.', status: 403);

    final target = await repository.findMembershipById(id);
    if (target == null || target.companyId != auth.session.companyId) {
      // Gleiche Antwort für "existiert nicht" und "fremde Firma" — kein
      // Oracle für fremde Mitgliedschafts-IDs (Cross-Tenant-Schutz).
      return jsonError('Mitgliedschaft nicht gefunden.', status: 404);
    }

    final body = await _bodyJson(request);
    final newGroupId = body['groupId'] as String?;
    final newActive = body['active'] as bool?;
    final newIsAdmin = body['isAdmin'] as bool?;
    // Stundenkostensatz (Cent) — nur wenn im Body enthalten; null löscht.
    final hasRate = body.containsKey('hourlyCostCents');
    final newRate = body['hourlyCostCents'] as int?;
    if (newRate != null && newRate < 0) return jsonError('hourlyCostCents darf nicht negativ sein.');

    if (newGroupId != null) {
      final group = await repository.findGroupById(newGroupId);
      if (group == null || group.companyId != auth.session.companyId) {
        return jsonError('Gruppe nicht gefunden.', status: 404);
      }
    }

    // "Letzten aktiven Admin nicht aussperren" greift bei JEDER
    // Änderung, die die Mitgliedschaft aus der Admin-Zählung
    // herausnehmen würde — Deaktivieren UND Admin-Entzug.
    final wasCountedAsAdmin = target.isAdmin && target.active;
    final willBeCountedAsAdmin = (newIsAdmin ?? target.isAdmin) && (newActive ?? target.active);
    if (wasCountedAsAdmin && !willBeCountedAsAdmin) {
      final activeAdmins = await repository.countActiveAdmins(auth.session.companyId);
      if (activeAdmins <= 1) {
        return jsonError('Letzte aktive Admin-Mitgliedschaft der Firma kann niemand ändern.', status: 409);
      }
    }

    await repository.updateMembership(
      id: id,
      groupId: newGroupId,
      active: newActive,
      isAdmin: newIsAdmin,
      hourlyCostCents: hasRate ? () => newRate : null,
    );
    await _auth.audit(auth, 'membership.update', 'membership', id);
    return jsonOk({'id': id});
  }

  Future<Response> _listOverrides(Request request, String id) async {
    final auth = await _requireAdmin(request);
    if (auth == null) return jsonError('Nicht angemeldet oder keine Admin-Rechte.', status: 403);
    final target = await repository.findMembershipById(id);
    if (target == null || target.companyId != auth.session.companyId) {
      return jsonError('Mitgliedschaft nicht gefunden.', status: 404);
    }
    final overrides = await repository.listMembershipOverrides(id);
    return jsonOk({
      'overrides': [for (final o in overrides) {'permission': o.permission, 'allowed': o.allowed}],
    });
  }

  Future<Response> _setOverride(Request request, String id, String permission) async {
    final auth = await _requireAdmin(request);
    if (auth == null) return jsonError('Nicht angemeldet oder keine Admin-Rechte.', status: 403);
    final target = await repository.findMembershipById(id);
    if (target == null || target.companyId != auth.session.companyId) {
      return jsonError('Mitgliedschaft nicht gefunden.', status: 404);
    }
    if (!isKnownPermission(permission)) return jsonError('Unbekannte Berechtigung: $permission');
    final body = await _bodyJson(request);
    final allowed = body['allowed'] as bool?;
    if (allowed == null) return jsonError('allowed (bool) ist Pflicht.');
    await repository.setMembershipOverride(membershipId: id, permission: permission, allowed: allowed);
    await _auth.audit(auth, '${allowed ? 'membership.override.allow' : 'membership.override.deny'}:$permission', 'membership', id);
    return jsonOk({'id': id, 'permission': permission, 'allowed': allowed});
  }

  Future<Response> _removeOverride(Request request, String id, String permission) async {
    final auth = await _requireAdmin(request);
    if (auth == null) return jsonError('Nicht angemeldet oder keine Admin-Rechte.', status: 403);
    final target = await repository.findMembershipById(id);
    if (target == null || target.companyId != auth.session.companyId) {
      return jsonError('Mitgliedschaft nicht gefunden.', status: 404);
    }
    await repository.removeMembershipOverride(membershipId: id, permission: permission);
    await _auth.audit(auth, 'membership.override.remove:$permission', 'membership', id);
    return Response(204);
  }

  // ---- Effektives Recht (für die eigene Sitzung) -------------------------------

  Future<Response> _effectivePermission(Request request) async {
    final auth = await _requireSession(request);
    if (auth == null) return jsonError('Nicht angemeldet.', status: 401);
    final permission = request.url.queryParameters['permission'];
    if (permission == null) return jsonError('permission ist Pflicht.');
    // Ein explizit übergebenes Modul bleibt möglich (Abwärtskompatibilität
    // zum B1-Grundgerüst), sonst gilt die Zuordnung aus dem Katalog.
    final requiredModule = request.url.queryParameters['module'] ?? requiredModuleFor(permission);
    final granted = await _isGranted(auth, permission, requiredModule: requiredModule);
    return jsonOk({'permission': permission, 'granted': granted});
  }

  /// Alle für die eigene Sitzung wirksamen Rechte — damit ein Client
  /// Aktionen ausblenden kann, ohne jede einzeln abzufragen. Rein zur
  /// Anzeige: jeder Fach-Endpunkt prüft serverseitig trotzdem selbst.
  Future<Response> _myPermissions(Request request) async {
    final auth = await _requireSession(request);
    if (auth == null) return jsonError('Nicht angemeldet.', status: 401);
    final granted = <String>[];
    for (final permission in permissionCatalog.keys) {
      if (await _isGranted(auth, permission)) granted.add(permission);
    }
    return jsonOk({'isAdmin': auth.membership.isAdmin, 'permissions': granted});
  }

  Future<Response> _permissionCatalog(Request request) async {
    final auth = await _requireSession(request);
    if (auth == null) return jsonError('Nicht angemeldet.', status: 401);
    return jsonOk({
      'permissions': [
        for (final entry in permissionCatalog.entries) {'key': entry.key, 'module': entry.value},
      ],
      'modules': knownModules.toList()..sort(),
    });
  }

  Future<bool> _isGranted(AuthContext auth, String permission, {String? requiredModule}) =>
      _auth.isGranted(auth, permission, requiredModule: requiredModule);

  // ---- Firmenmodule ----------------------------------------------------------

  Future<Response> _getModules(Request request) async {
    final auth = await _requireSession(request);
    if (auth == null) return jsonError('Nicht angemeldet.', status: 401);
    final company = await repository.findCompanyById(auth.session.companyId);
    return jsonOk({'modules': (company?.enabledModules.toList() ?? <String>[])..sort()});
  }

  /// Nur Firmenadmin — Modul-Schalter sind wie Gruppen/Ausnahmen eine
  /// strukturelle Firmeneinstellung, keine delegierbare Einzelberechtigung.
  Future<Response> _setModules(Request request) async {
    final auth = await _requireAdmin(request);
    if (auth == null) return jsonError('Nicht angemeldet oder keine Admin-Rechte.', status: 403);
    final body = await _bodyJson(request);
    final rawModules = body['modules'];
    if (rawModules is! List) return jsonError('modules (Liste) ist Pflicht.');
    final modules = rawModules.cast<String>().toSet();
    final unknown = modules.difference(knownModules);
    if (unknown.isNotEmpty) return jsonError('Unbekannte Module: ${unknown.join(', ')}');
    // Gleiche Abhängigkeit wie in der Offline-App
    // (`CompanyRepository.setModules()`): Bestellwesen braucht Lagerbestand.
    if (modules.contains('bestellwesen') && !modules.contains('lagerbestand')) {
      return jsonError('Modul "bestellwesen" setzt "lagerbestand" voraus.');
    }
    await repository.setCompanyModules(companyId: auth.session.companyId, enabledModules: modules);
    await _auth.audit(auth, 'company.modules', 'company', auth.session.companyId);
    return jsonOk({'modules': modules.toList()..sort()});
  }

  // ---- Agent-Token und Freigaben (C8) ---------------------------------------------

  /// Eigenes Token für einen LLM-Agenten (MCP/API) — nur aus einer echten
  /// App-Sitzung, nur bei aktiviertem Modul `aiAgents`. Der Agent hat
  /// genau die wirksamen Rechte dieses Nutzers, aber nie Admin-Funktionen.
  Future<Response> _createAgentToken(Request request) async {
    final auth = await _auth.requireHumanSession(request);
    if (auth == null) return jsonError('Nur aus einer angemeldeten App-Sitzung möglich.', status: 403);
    final company = await repository.findCompanyById(auth.session.companyId);
    if (company == null || !company.enabledModules.contains('aiAgents')) {
      return jsonError('Modul "aiAgents" ist für diese Firma nicht aktiviert.', status: 403);
    }
    final label = ((await _bodyJson(request))['label'] as String?)?.trim();
    if (label == null || label.isEmpty) return jsonError('label ist Pflicht (z. B. "Claude Desktop").');
    final raw = '$agentTokenPrefix${Tokens.generate()}';
    final token = AgentToken(
      id: _uuid.v4(),
      tokenHash: Tokens.hashOf(raw),
      membershipId: auth.membership.id,
      userId: auth.session.userId,
      companyId: auth.session.companyId,
      label: label,
      createdAt: DateTime.now().toUtc(),
    );
    await repository.createAgentToken(token);
    await _auth.audit(auth, 'agentToken.create', 'agentToken', token.id);
    return jsonOk({'id': token.id, 'label': label, 'token': raw}, status: 201);
  }

  Future<Response> _listAgentTokens(Request request) async {
    final auth = await _auth.requireHumanSession(request);
    if (auth == null) return jsonError('Nur aus einer angemeldeten App-Sitzung möglich.', status: 403);
    final tokens = await repository.listAgentTokens(companyId: auth.session.companyId, userId: auth.session.userId);
    return jsonOk({
      'tokens': [
        for (final t in tokens)
          {
            'id': t.id,
            'label': t.label,
            'createdAt': t.createdAt.toIso8601String(),
            'lastUsedAt': t.lastUsedAt?.toIso8601String(),
          },
      ],
    });
  }

  Future<Response> _revokeAgentToken(Request request, String id) async {
    final auth = await _auth.requireHumanSession(request);
    if (auth == null) return jsonError('Nur aus einer angemeldeten App-Sitzung möglich.', status: 403);
    final revoked = await repository.revokeAgentToken(companyId: auth.session.companyId, userId: auth.session.userId, id: id);
    if (!revoked) return jsonError('Token nicht gefunden.', status: 404);
    await _auth.audit(auth, 'agentToken.revoke', 'agentToken', id);
    return Response(204);
  }

  Map<String, Object?> _approvalJson(PendingApproval a) => {
        'id': a.id,
        'summary': a.summary,
        'status': a.status,
        'createdAt': a.createdAt.toIso8601String(),
        'decidedAt': a.decidedAt?.toIso8601String(),
        'resultStatus': a.resultStatus,
      };

  /// Eigene Freigabe-Anfragen — auch für das Agent-Token lesbar, damit
  /// der Agent den Stand abfragen kann (bestätigen kann er nie).
  Future<Response> _listApprovals(Request request) async {
    final auth = await _requireSession(request);
    if (auth == null) return jsonError('Nicht angemeldet.', status: 401);
    final approvals = await repository.listApprovals(
      companyId: auth.session.companyId,
      userId: auth.session.userId,
      status: request.url.queryParameters['status'],
    );
    return jsonOk({'approvals': [for (final a in approvals) _approvalJson(a)]});
  }

  /// Führt die angefragte Aktion mit der Sitzung des Nutzers aus — Recht,
  /// Modul, Version usw. werden dabei vollständig neu geprüft. Eine
  /// Freigabe wirkt höchstens einmal (atomarer Statuswechsel).
  Future<Response> _confirmApproval(Request request, String id) async {
    final auth = await _auth.requireHumanSession(request);
    if (auth == null) return jsonError('Freigaben bestätigt nur der Nutzer selbst in der App.', status: 403);
    final approval = await repository.findApproval(companyId: auth.session.companyId, userId: auth.session.userId, id: id);
    if (approval == null) return jsonError('Freigabe nicht gefunden.', status: 404);
    final now = DateTime.now().toUtc();
    if (!await repository.decideApproval(id: id, status: 'executing', at: now)) {
      return jsonError('Freigabe wurde bereits entschieden.', status: 409);
    }
    final response = await _innerHandler(Request(
      approval.method,
      request.requestedUri.replace(path: approval.path, query: ''),
      body: approval.body,
      headers: {'authorization': request.headers['authorization']!},
    ));
    final body = await response.readAsString();
    await repository.decideApproval(
      id: id,
      status: 'confirmed',
      at: now,
      resultStatus: response.statusCode,
      resultBody: body,
      fromStatus: 'executing',
    );
    await _auth.audit(auth, 'approval.confirm', 'approval', id);
    return Response(response.statusCode, body: body, headers: {'content-type': 'application/json; charset=utf-8'});
  }

  Future<Response> _rejectApproval(Request request, String id) async {
    final auth = await _auth.requireHumanSession(request);
    if (auth == null) return jsonError('Freigaben entscheidet nur der Nutzer selbst in der App.', status: 403);
    final approval = await repository.findApproval(companyId: auth.session.companyId, userId: auth.session.userId, id: id);
    if (approval == null) return jsonError('Freigabe nicht gefunden.', status: 404);
    if (!await repository.decideApproval(id: id, status: 'rejected', at: DateTime.now().toUtc())) {
      return jsonError('Freigabe wurde bereits entschieden.', status: 409);
    }
    await _auth.audit(auth, 'approval.reject', 'approval', id);
    return Response(204);
  }

  // ---- Firmen-Stammdaten / Audit ------------------------------------------------

  Future<Response> _getProfile(Request request) async {
    final auth = await _requireSession(request);
    if (auth == null) return jsonError('Nicht angemeldet.', status: 401);
    final company = await repository.findCompanyById(auth.session.companyId);
    final profile = await repository.getCompanyProfile(auth.session.companyId);
    return jsonOk({'name': company?.name, ...profile.toJson()});
  }

  /// Nur Admin — Stammdaten landen beim Finalisieren unveränderlich in
  /// jedem Dokument.
  Future<Response> _setProfile(Request request) async {
    final auth = await _requireAdmin(request);
    if (auth == null) return jsonError('Nicht angemeldet oder keine Admin-Rechte.', status: 403);
    final body = await _bodyJson(request);
    String? field(String key) {
      final value = (body[key] as String?)?.trim();
      return (value == null || value.isEmpty) ? null : value;
    }

    final profile = CompanyProfile(
      companyId: auth.session.companyId,
      address: field('address'),
      taxNumber: field('taxNumber'),
      vatId: field('vatId'),
      iban: field('iban'),
      email: field('email'),
      phone: field('phone'),
    );
    await repository.saveCompanyProfile(profile);
    await _auth.audit(auth, 'company.profile', 'company', auth.session.companyId);
    return jsonOk(profile.toJson());
  }

  Future<Response> _listAudit(Request request) async {
    final auth = await _requireAdmin(request);
    if (auth == null) return jsonError('Nicht angemeldet oder keine Admin-Rechte.', status: 403);
    final limit = (int.tryParse(request.url.queryParameters['limit'] ?? '') ?? 100).clamp(1, 1000);
    final entries = await repository.listAudit(auth.session.companyId, limit: limit);
    final emails = <String, String?>{};
    final result = <Map<String, Object?>>[];
    for (final e in entries) {
      final userId = e.userId;
      if (userId != null && !emails.containsKey(userId)) {
        emails[userId] = (await repository.findUserById(userId))?.email;
      }
      result.add({
        'at': e.at.toIso8601String(),
        'userEmail': userId == null ? null : emails[userId],
        'action': e.action,
        'entityType': e.entityType,
        'entityId': e.entityId,
      });
    }
    return jsonOk({'entries': result});
  }

  // ---- Einladungen -------------------------------------------------------------

  Future<Response> _createInvitation(Request request) async {
    final auth = await _requireAdmin(request);
    if (auth == null) return jsonError('Nicht angemeldet oder keine Admin-Rechte.', status: 403);
    final body = await _bodyJson(request);
    final email = (body['email'] as String?)?.trim();
    final groupId = body['groupId'] as String?;
    if (email == null || email.isEmpty || groupId == null) return jsonError('email und groupId sind Pflicht.');
    final group = await repository.findGroupById(groupId);
    if (group == null || group.companyId != auth.session.companyId) {
      return jsonError('Gruppe nicht gefunden.', status: 404);
    }
    final existingUser = await repository.findUserByEmail(email);
    if (existingUser != null &&
        await repository.findMembership(userId: existingUser.id, companyId: auth.session.companyId) != null) {
      return jsonError('Nutzer ist bereits Mitglied dieser Firma.', status: 409);
    }

    final rawToken = Tokens.generate();
    final expiresAt = DateTime.now().toUtc().add(invitationTtl);
    await repository.saveInvitation(
      Invitation(
        tokenHash: Tokens.hashOf(rawToken),
        companyId: auth.session.companyId,
        email: email,
        groupId: groupId,
        invitedByUserId: auth.session.userId,
        expiresAt: expiresAt,
      ),
    );
    await _auth.audit(auth, 'invitation.create', 'invitation');
    // Der Server versendet bewusst selbst keine E-Mail (kein SMTP im
    // Server-Dienst) — der Admin gibt das Token/den Link selbst weiter.
    // Es wird genau einmal im Klartext ausgeliefert, danach nur noch
    // als Hash gespeichert.
    return jsonOk({
      'invitationToken': rawToken,
      'email': email,
      'groupId': groupId,
      'expiresAt': expiresAt.toIso8601String(),
    }, status: 201);
  }

  Future<Response> _listInvitations(Request request) async {
    final auth = await _requireAdmin(request);
    if (auth == null) return jsonError('Nicht angemeldet oder keine Admin-Rechte.', status: 403);
    final invitations = await repository.listInvitationsForCompany(auth.session.companyId);
    final now = DateTime.now().toUtc();
    return jsonOk({
      'invitations': [
        for (final i in invitations)
          {
            // Der Hash taugt nicht zum Einlösen (nur das Klartext-Token)
            // und dient daher gefahrlos als ID zum Widerrufen.
            'id': i.tokenHash,
            'email': i.email,
            'groupId': i.groupId,
            'expiresAt': i.expiresAt.toIso8601String(),
            'expired': i.isExpired(now),
          },
      ],
    });
  }

  Future<Response> _revokeInvitation(Request request, String id) async {
    final auth = await _requireAdmin(request);
    if (auth == null) return jsonError('Nicht angemeldet oder keine Admin-Rechte.', status: 403);
    final invitations = await repository.listInvitationsForCompany(auth.session.companyId);
    if (!invitations.any((i) => i.tokenHash == id)) {
      return jsonError('Einladung nicht gefunden.', status: 404);
    }
    await repository.consumeInvitation(id, DateTime.now().toUtc());
    await _auth.audit(auth, 'invitation.revoke', 'invitation');
    return Response(204);
  }

  /// Löst eine Einladung ein. Neue E-Mail -> Nutzer wird mit dem
  /// angegebenen Passwort angelegt. Bereits registrierte E-Mail -> das
  /// Passwort muss zum bestehenden Konto passen (Nachweis, dass die
  /// einlösende Person das Konto besitzt — sonst könnte jeder mit dem
  /// Token ein fremdes Konto in die Firma ziehen).
  Future<Response> _acceptInvitation(Request request) async {
    final body = await _bodyJson(request);
    final token = body['invitationToken'] as String?;
    final password = body['password'] as String?;
    if (token == null || password == null) return jsonError('invitationToken und password sind Pflicht.');

    final invitation = await repository.consumeInvitation(Tokens.hashOf(token), DateTime.now().toUtc());
    if (invitation == null) return jsonError('Einladung ungültig, abgelaufen oder bereits verwendet.', status: 404);

    var user = await repository.findUserByEmail(invitation.email);
    if (user == null) {
      if (password.length < 8) {
        // Einladung bleibt gültig — ein zu kurzes Passwort ist ein
        // Eingabefehler, kein Grund, das Token zu verbrennen.
        await repository.saveInvitation(invitation);
        return jsonError('password muss mind. 8 Zeichen haben.');
      }
      user = await repository.createUser(
        id: _uuid.v4(),
        email: invitation.email,
        passwordHash: Passwords.hash(password),
      );
    } else {
      final throttled = _throttled(invitation.email, request);
      if (throttled != null) {
        await repository.saveInvitation(invitation);
        return throttled;
      }
      if (!Passwords.verify(password, user.passwordHash)) {
        loginThrottle.recordFailure(account: invitation.email, address: _clientAddress(request));
        await repository.saveInvitation(invitation);
        return jsonError('Passwort passt nicht zum bestehenden Konto dieser E-Mail.', status: 401);
      }
    }

    if (await repository.findMembership(userId: user.id, companyId: invitation.companyId) != null) {
      return jsonError('Bereits Mitglied dieser Firma.', status: 409);
    }
    final group = await repository.findGroupById(invitation.groupId);
    if (group == null || group.companyId != invitation.companyId) {
      return jsonError('Die eingeladene Gruppe existiert nicht mehr.', status: 409);
    }
    final membership = await repository.createMembership(
      id: _uuid.v4(),
      userId: user.id,
      companyId: invitation.companyId,
      groupId: invitation.groupId,
      isAdmin: false,
    );
    await repository.recordAudit(AuditEntry(
      companyId: invitation.companyId,
      userId: user.id,
      action: 'invitation.accept',
      entityType: 'membership',
      entityId: membership.id,
      at: DateTime.now().toUtc(),
    ));
    return jsonOk({'membershipId': membership.id, 'companyId': invitation.companyId}, status: 201);
  }

  // ---- Auth-Helfer (siehe SessionAuthenticator) ---------------------------------

  String? _bearerToken(Request request) => _auth.bearerToken(request);
  Future<AuthContext?> _requireSession(Request request) => _auth.requireSession(request);
  Future<AuthContext?> _requireAdmin(Request request) => _auth.requireAdmin(request);
}
