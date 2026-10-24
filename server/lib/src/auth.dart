import 'package:shelf/shelf.dart';

import 'models.dart';
import 'permission_catalog.dart';
import 'permission_resolver.dart';
import 'repository.dart';
import 'util/responses.dart';
import 'util/tokens.dart';

/// Angemeldete, firmengebundene Sitzung inkl. der (bei jedem Request
/// frisch geladenen) Mitgliedschaft — Berechtigungsentzug wirkt damit
/// sofort, nicht erst nach Ablauf der Sitzung (Abnahme B).
typedef AuthContext = ({CompanySession session, Membership membership});

/// Gemeinsame Sitzungs-/Rechteprüfung für alle Router (B1 Punkt 3:
/// "Jede API-... Aktion serverseitig auf Firma, Mitgliedschaft,
/// Funktion und wirksames Recht prüfen").
class SessionAuthenticator {
  SessionAuthenticator(this.repository);
  final PhaseBRepository repository;

  String? bearerToken(Request request) {
    final header = request.headers['authorization'];
    if (header == null || !header.startsWith('Bearer ')) return null;
    return header.substring('Bearer '.length);
  }

  Future<AuthContext?> requireSession(Request request) async {
    final token = bearerToken(request);
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

  Future<AuthContext?> requireAdmin(Request request) async {
    final auth = await requireSession(request);
    if (auth == null || !auth.membership.isAdmin) return null;
    return auth;
  }

  Future<bool> isGranted(AuthContext auth, String permission, {String? requiredModule}) async {
    final company = await repository.findCompanyById(auth.session.companyId);
    if (company == null) return false;
    return PermissionResolver.hasPermission(
      membership: auth.membership,
      company: company,
      permission: permission,
      groupPermissions: await repository.listGroupPermissions(auth.membership.groupId),
      overrides: await repository.listMembershipOverrides(auth.membership.id),
      requiredModule: requiredModule ?? requiredModuleFor(permission),
    );
  }

  /// Sitzung + Recht in einem Schritt: liefert entweder den
  /// [AuthContext] oder die fertige Fehlerantwort (401 ohne Sitzung,
  /// 403 ohne Recht). [requiredModule] zusätzlich zum Katalog-Modul,
  /// z. B. "quotes" für ein Angebot, das unter `invoices.*` läuft.
  Future<({AuthContext? auth, Response? error})> requirePermission(
    Request request,
    String permission, {
    String? requiredModule,
  }) async {
    final auth = await requireSession(request);
    if (auth == null) return (auth: null, error: jsonError('Nicht angemeldet.', status: 401));
    if (!await isGranted(auth, permission)) {
      return (auth: null, error: jsonError('Keine Berechtigung: $permission', status: 403));
    }
    if (requiredModule != null) {
      final company = await repository.findCompanyById(auth.session.companyId);
      if (company == null || !company.enabledModules.contains(requiredModule)) {
        return (auth: null, error: jsonError('Modul "$requiredModule" ist für diese Firma nicht aktiviert.', status: 403));
      }
    }
    return (auth: auth, error: null);
  }

  /// Protokolliert eine schreibende Aktion der Sitzung (ohne Inhalte,
  /// siehe [AuditEntry]).
  Future<void> audit(AuthContext auth, String action, String entityType, [String? entityId]) =>
      repository.recordAudit(AuditEntry(
        companyId: auth.session.companyId,
        userId: auth.session.userId,
        action: action,
        entityType: entityType,
        entityId: entityId,
        at: DateTime.now().toUtc(),
      ));
}
