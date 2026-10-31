import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:uuid/uuid.dart';

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

/// Präfix der Agent-Token — unterscheidet sie ohne DB-Zugriff von
/// App-Sitzungstoken.
const agentTokenPrefix = 'wka_';

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
    if (token.startsWith(agentTokenPrefix)) return _agentSession(token);
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

  /// C8: Agent-Token wirkt nur bei aktiver Mitgliedschaft UND
  /// aktiviertem Firmenmodul `aiAgents`; beides wird bei jedem Aufruf
  /// neu geprüft (Entzug wirkt sofort).
  Future<AuthContext?> _agentSession(String token) async {
    final agent = await repository.findAgentTokenByHash(Tokens.hashOf(token));
    if (agent == null) return null;
    final membership = await repository.findMembershipById(agent.membershipId);
    if (membership == null || !membership.active) return null;
    final company = await repository.findCompanyById(agent.companyId);
    if (company == null || !company.enabledModules.contains('aiAgents')) return null;
    final now = DateTime.now().toUtc();
    await repository.touchAgentToken(agent.id, now);
    return (
      session: CompanySession(
        tokenHash: agent.tokenHash,
        membershipId: agent.membershipId,
        userId: agent.userId,
        companyId: agent.companyId,
        createdAt: agent.createdAt,
        expiresAt: now.add(const Duration(minutes: 1)),
        isAgent: true,
      ),
      membership: membership,
    );
  }

  /// Admin-Funktionen sind über ein Agent-Token nie erreichbar.
  Future<AuthContext?> requireAdmin(Request request) async {
    final auth = await requireSession(request);
    if (auth == null || !auth.membership.isAdmin || auth.session.isAgent) return null;
    return auth;
  }

  /// Nur eine echte App-Sitzung (kein Agent-Token) — z. B. zum
  /// Bestätigen von Freigaben oder Verwalten von Agent-Token.
  Future<AuthContext?> requireHumanSession(Request request) async {
    final auth = await requireSession(request);
    if (auth == null || auth.session.isAgent) return null;
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
        // Agent-Aktionen bleiben im Protokoll klar erkennbar (C8 Audit).
        action: auth.session.isAgent ? '$action [agent]' : action,
        entityType: entityType,
        entityId: entityId,
        at: DateTime.now().toUtc(),
      ));

  /// C8: irreversible Aktion eines Agenten -> nur Freigabe-Anfrage
  /// (202). Ausgeführt wird erst, wenn der Nutzer sie in der App
  /// bestätigt — dann mit SEINER Sitzung und erneuter Rechteprüfung
  /// (dieselbe Anfrage [method]/[path]/[body] wird erneut ausgeführt).
  Future<Response> requestApproval(
    AuthContext ctx, {
    required String method,
    required String path,
    required Map<String, Object?> body,
    required String summary,
  }) async {
    final agent = await repository.findAgentTokenByHash(ctx.session.tokenHash);
    final approval = PendingApproval(
      id: const Uuid().v4(),
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
    await audit(ctx, 'approval.request', 'approval', approval.id);
    return jsonOk({
      'approvalId': approval.id,
      'status': 'pending',
      'summary': summary,
      'message': 'Irreversible Aktion: wartet auf Bestätigung durch den Nutzer in der App.',
    }, status: 202);
  }
}
