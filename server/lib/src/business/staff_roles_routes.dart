import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:uuid/uuid.dart';

import '../auth.dart';
import '../repository.dart';
import '../util/responses.dart';
import 'repository.dart';
import 'request_util.dart';
import 'staff_roles.dart';

/// Rollen & Stundensätze (Modul `timeTracking`). Lesen darf, wer Zeiten
/// bucht oder sieht (Rolle beim Buchen wählen); pflegen nur der
/// Firmen-Admin — wie der Stundensatz je Mitglied.
class StaffRoleRoutes {
  StaffRoleRoutes({required this.repository, required this.business, required this.auth});

  final PhaseBRepository repository;
  final BusinessRepository business;
  final SessionAuthenticator auth;
  static const _uuid = Uuid();

  void mount(Router router) {
    router.get('/staff-roles', _list);
    router.post('/staff-roles', _create);
    router.put('/staff-roles/<id>', _update);
    router.delete('/staff-roles/<id>', _delete);
  }

  Future<bool> _moduleEnabled(AuthContext ctx) async =>
      (await repository.findCompanyById(ctx.session.companyId))?.enabledModules.contains('timeTracking') ?? false;

  /// Admin der Firma mit aktivem Modul — sonst 403 bzw. 401.
  Future<({AuthContext? auth, Response? error})> _admin(Request request) async {
    final session = await auth.requireSession(request);
    if (session == null) return (auth: null, error: jsonError('Nicht angemeldet.', status: 401));
    final admin = await auth.requireAdmin(request);
    if (admin == null) return (auth: null, error: jsonError('Nur für Firmen-Admins.', status: 403));
    if (!await _moduleEnabled(admin)) {
      return (auth: null, error: jsonError('Modul "timeTracking" ist für diese Firma nicht aktiviert.', status: 403));
    }
    return (auth: admin, error: null);
  }

  ({String? name, int? rate, String? error}) _parse(Map<String, Object?> body, {StaffRole? existing}) {
    final name = trimmedOrNull(body['name']) ?? existing?.name;
    if (name == null) return (name: null, rate: null, error: 'name ist Pflicht.');
    final raw = body.containsKey('hourlyCostCents') ? body['hourlyCostCents'] : existing?.hourlyCostCents ?? 0;
    if (raw is! int || raw < 0) return (name: null, rate: null, error: 'hourlyCostCents (Cent, ≥ 0) ist Pflicht.');
    return (name: name, rate: raw, error: null);
  }

  Future<Response> _list(Request request) async {
    final ctx = await auth.requireSession(request);
    if (ctx == null) return jsonError('Nicht angemeldet.', status: 401);
    final mayRead = ctx.membership.isAdmin ||
        await auth.isGranted(ctx, 'timeTracking.write') ||
        await auth.isGranted(ctx, 'timeTracking.read');
    if (!mayRead || !await _moduleEnabled(ctx)) return jsonError('Keine Berechtigung: timeTracking.', status: 403);
    final companyId = ctx.session.companyId;
    var roles = await business.listStaffRoles(companyId);
    // Wie offline: Vorschläge beim ersten Öffnen durch den Admin anlegen.
    if (roles.isEmpty && ctx.membership.isAdmin && !ctx.session.isAgent) {
      final now = DateTime.now().toUtc();
      for (final name in defaultStaffRoleNames) {
        await business.createStaffRole(
          StaffRole(id: _uuid.v4(), companyId: companyId, name: name, hourlyCostCents: 0, createdAt: now),
        );
      }
      roles = await business.listStaffRoles(companyId);
    }
    return jsonOk({'staffRoles': [for (final r in roles) r.toJson()]});
  }

  Future<Response> _create(Request request) async {
    final admin = await _admin(request);
    if (admin.error != null) return admin.error!;
    final parsed = _parse(await readJsonBody(request));
    if (parsed.error != null) return jsonError(parsed.error!);
    final role = StaffRole(
      id: _uuid.v4(),
      companyId: admin.auth!.session.companyId,
      name: parsed.name!,
      hourlyCostCents: parsed.rate!,
      createdAt: DateTime.now().toUtc(),
    );
    await business.createStaffRole(role);
    await auth.audit(admin.auth!, 'staffRole.create', 'staffRole', role.id);
    return jsonOk(role.toJson(), status: 201);
  }

  Future<Response> _update(Request request, String id) async {
    final admin = await _admin(request);
    if (admin.error != null) return admin.error!;
    final companyId = admin.auth!.session.companyId;
    final existing = await business.findStaffRole(companyId, id);
    if (existing == null) return jsonError('Rolle nicht gefunden.', status: 404);
    final parsed = _parse(await readJsonBody(request), existing: existing);
    if (parsed.error != null) return jsonError(parsed.error!);
    final role = StaffRole(
      id: id,
      companyId: companyId,
      name: parsed.name!,
      hourlyCostCents: parsed.rate!,
      createdAt: existing.createdAt,
    );
    await business.updateStaffRole(role);
    await auth.audit(admin.auth!, 'staffRole.update', 'staffRole', id);
    return jsonOk(role.toJson());
  }

  Future<Response> _delete(Request request, String id) async {
    final admin = await _admin(request);
    if (admin.error != null) return admin.error!;
    if (!await business.deleteStaffRole(admin.auth!.session.companyId, id)) {
      return jsonError('Rolle nicht gefunden.', status: 404);
    }
    await auth.audit(admin.auth!, 'staffRole.delete', 'staffRole', id);
    return Response(204);
  }
}
