import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:uuid/uuid.dart';

import 'models.dart';
import 'permission_resolver.dart';
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
  PhaseBRouter({required this.repository, this.sessionTtl = const Duration(hours: 8)});

  final PhaseBRepository repository;
  final Duration sessionTtl;
  static const _uuid = Uuid();

  Router get handler {
    final router = Router();
    router.get('/health', (Request request) => healthResponse());

    router.post('/auth/register', _register);
    router.post('/auth/login', _login);
    router.post('/auth/select-company', _selectCompany);
    router.post('/auth/logout', _logout);
    router.get('/me', _me);

    router.post('/companies', _createCompany);

    router.get('/groups', _listGroups);
    router.post('/groups', _createGroup);
    router.get('/groups/<groupId>/permissions', _listGroupPermissions);
    router.put('/groups/<groupId>/permissions/<permission>', _setGroupPermission);

    router.get('/memberships', _listMemberships);
    router.post('/memberships', _createMembership);
    router.patch('/memberships/<id>', _updateMembership);
    router.put('/memberships/<id>/overrides/<permission>', _setOverride);
    router.delete('/memberships/<id>/overrides/<permission>', _removeOverride);

    router.get('/permissions/effective', _effectivePermission);

    return router;
  }

  Future<Map<String, Object?>> _bodyJson(Request request) async {
    final raw = await request.readAsString();
    if (raw.isEmpty) return const {};
    return jsonDecode(raw) as Map<String, Object?>;
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

  Future<Response> _login(Request request) async {
    final body = await _bodyJson(request);
    final email = body['email'] as String?;
    final password = body['password'] as String?;
    if (email == null || password == null) return jsonError('email und password sind Pflicht.');

    final user = await repository.findUserByEmail(email);
    if (user == null || !Passwords.verify(password, user.passwordHash)) {
      return jsonError('E-Mail oder Passwort falsch.', status: 401);
    }

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
    final body = await _bodyJson(request);
    final granted = body['granted'] as bool?;
    if (granted == null) return jsonError('granted (bool) ist Pflicht.');
    await repository.setGroupPermission(groupId: groupId, permission: permission, granted: granted);
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

    await repository.updateMembership(id: id, groupId: newGroupId, active: newActive, isAdmin: newIsAdmin);
    return jsonOk({'id': id});
  }

  Future<Response> _setOverride(Request request, String id, String permission) async {
    final auth = await _requireAdmin(request);
    if (auth == null) return jsonError('Nicht angemeldet oder keine Admin-Rechte.', status: 403);
    final target = await repository.findMembershipById(id);
    if (target == null || target.companyId != auth.session.companyId) {
      return jsonError('Mitgliedschaft nicht gefunden.', status: 404);
    }
    final body = await _bodyJson(request);
    final allowed = body['allowed'] as bool?;
    if (allowed == null) return jsonError('allowed (bool) ist Pflicht.');
    await repository.setMembershipOverride(membershipId: id, permission: permission, allowed: allowed);
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
    return Response(204);
  }

  // ---- Effektives Recht (für die eigene Sitzung) -------------------------------

  Future<Response> _effectivePermission(Request request) async {
    final auth = await _requireSession(request);
    if (auth == null) return jsonError('Nicht angemeldet.', status: 401);
    final permission = request.url.queryParameters['permission'];
    if (permission == null) return jsonError('permission ist Pflicht.');
    final requiredModule = request.url.queryParameters['module'];

    final company = await repository.findCompanyById(auth.session.companyId);
    if (company == null) return jsonError('Firma nicht gefunden.', status: 404);
    final groupPermissions = await repository.listGroupPermissions(auth.membership.groupId);
    final overrides = await repository.listMembershipOverrides(auth.membership.id);

    final granted = PermissionResolver.hasPermission(
      membership: auth.membership,
      company: company,
      permission: permission,
      groupPermissions: groupPermissions,
      overrides: overrides,
      requiredModule: requiredModule,
    );
    return jsonOk({'permission': permission, 'granted': granted});
  }

  // ---- Auth-Helfer --------------------------------------------------------------

  String? _bearerToken(Request request) {
    final header = request.headers['authorization'];
    if (header == null || !header.startsWith('Bearer ')) return null;
    return header.substring('Bearer '.length);
  }

  Future<({CompanySession session, Membership membership})?> _requireSession(Request request) async {
    final token = _bearerToken(request);
    if (token == null) return null;
    final session = await repository.findSession(Tokens.hashOf(token));
    if (session == null) return null;
    if (session.isExpired(DateTime.now().toUtc())) {
      await repository.deleteSession(session.tokenHash);
      return null;
    }
    final membership = await repository.findMembershipById(session.membershipId);
    if (membership == null || !membership.active) return null;
    return (session: session, membership: membership);
  }

  Future<({CompanySession session, Membership membership})?> _requireAdmin(Request request) async {
    final auth = await _requireSession(request);
    if (auth == null || !auth.membership.isAdmin) return null;
    return auth;
  }
}
