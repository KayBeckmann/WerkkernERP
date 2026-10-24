import 'dart:convert';

import 'package:postgres/postgres.dart';

import 'models.dart';
import 'repository.dart';

class PostgresPhaseBRepository implements PhaseBRepository {
  PostgresPhaseBRepository(this._db);
  // Session: im Betrieb ein Pool, in Tests eine einzelne Connection.
  final Session _db;

  @override
  Future<AppUser> createUser({required String id, required String email, required String passwordHash}) async {
    await _db.execute(
      Sql.named('INSERT INTO app_users (id, email, password_hash) VALUES (@id, @email, @hash)'),
      parameters: {'id': id, 'email': email, 'hash': passwordHash},
    );
    return AppUser(id: id, email: email, passwordHash: passwordHash);
  }

  @override
  Future<AppUser?> findUserByEmail(String email) async {
    final result = await _db.execute(
      Sql.named('SELECT id, email, password_hash FROM app_users WHERE email = @email'),
      parameters: {'email': email},
    );
    if (result.isEmpty) return null;
    final row = result.first;
    return AppUser(id: row[0] as String, email: row[1] as String, passwordHash: row[2] as String);
  }

  @override
  Future<AppUser?> findUserById(String id) async {
    final result = await _db.execute(
      Sql.named('SELECT id, email, password_hash FROM app_users WHERE id = @id'),
      parameters: {'id': id},
    );
    if (result.isEmpty) return null;
    final row = result.first;
    return AppUser(id: row[0] as String, email: row[1] as String, passwordHash: row[2] as String);
  }

  @override
  Future<Company> createCompany({required String id, required String name}) async {
    await _db.execute(
      Sql.named("INSERT INTO companies (id, name, enabled_modules) VALUES (@id, @name, '')"),
      parameters: {'id': id, 'name': name},
    );
    return Company(id: id, name: name, enabledModules: const {});
  }

  @override
  Future<Company?> findCompanyById(String id) async {
    final result = await _db.execute(
      Sql.named('SELECT id, name, enabled_modules FROM companies WHERE id = @id'),
      parameters: {'id': id},
    );
    if (result.isEmpty) return null;
    return _toCompany(result.first);
  }

  @override
  Future<void> setCompanyModules({required String companyId, required Set<String> enabledModules}) async {
    await _db.execute(
      Sql.named('UPDATE companies SET enabled_modules = @modules WHERE id = @id'),
      parameters: {'modules': enabledModules.join(','), 'id': companyId},
    );
  }

  @override
  Future<CompanyProfile> getCompanyProfile(String companyId) async {
    final result = await _db.execute(
      Sql.named(
        'SELECT address, tax_number, vat_id, iban, email, phone, pdf_footer_text, document_texts, small_business_exempt '
        'FROM companies WHERE id = @id',
      ),
      parameters: {'id': companyId},
    );
    if (result.isEmpty) return CompanyProfile(companyId: companyId);
    final r = result.first;
    return CompanyProfile(
      companyId: companyId,
      address: r[0] as String?,
      taxNumber: r[1] as String?,
      vatId: r[2] as String?,
      iban: r[3] as String?,
      email: r[4] as String?,
      phone: r[5] as String?,
      footerText: r[6] as String?,
      documentTexts: {
        for (final e in (jsonDecode(r[7] as String) as Map<String, Object?>).entries)
          e.key: (
            intro: (e.value as Map<String, Object?>)['intro'] as String?,
            closing: (e.value as Map<String, Object?>)['closing'] as String?,
          ),
      },
      smallBusinessExempt: r[8] as bool,
    );
  }

  @override
  Future<void> saveCompanyProfile(CompanyProfile p) async {
    await _db.execute(
      Sql.named(
        'UPDATE companies SET address = @address, tax_number = @taxNumber, vat_id = @vatId, iban = @iban, '
        'email = @email, phone = @phone, pdf_footer_text = @footer, document_texts = @texts, '
        'small_business_exempt = @exempt WHERE id = @id',
      ),
      parameters: {
        'address': p.address,
        'taxNumber': p.taxNumber,
        'vatId': p.vatId,
        'iban': p.iban,
        'email': p.email,
        'phone': p.phone,
        'footer': p.footerText,
        'texts': jsonEncode({
          for (final e in p.documentTexts.entries) e.key: {'intro': e.value.intro, 'closing': e.value.closing},
        }),
        'exempt': p.smallBusinessExempt,
        'id': p.companyId,
      },
    );
  }

  @override
  Future<void> recordAudit(AuditEntry e) async {
    await _db.execute(
      Sql.named(
        'INSERT INTO audit_log (company_id, user_id, action, entity_type, entity_id, at) '
        'VALUES (@companyId, @userId, @action, @entityType, @entityId, @at)',
      ),
      parameters: {
        'companyId': e.companyId,
        'userId': e.userId,
        'action': e.action,
        'entityType': e.entityType,
        'entityId': e.entityId,
        'at': e.at,
      },
    );
  }

  @override
  Future<List<AuditEntry>> listAudit(String companyId, {int limit = 100}) async {
    final result = await _db.execute(
      Sql.named(
        'SELECT company_id, user_id, action, entity_type, entity_id, at FROM audit_log '
        'WHERE company_id = @companyId ORDER BY at DESC, id DESC LIMIT @limit',
      ),
      parameters: {'companyId': companyId, 'limit': limit},
    );
    return [
      for (final r in result)
        AuditEntry(
          companyId: r[0] as String,
          userId: r[1] as String?,
          action: r[2] as String,
          entityType: r[3] as String,
          entityId: r[4] as String?,
          at: r[5] as DateTime,
        ),
    ];
  }

  @override
  Future<StoredResponse?> findIdempotentResponse({
    required String companyId,
    required String userId,
    required String key,
  }) async {
    final result = await _db.execute(
      Sql.named(
        'SELECT request_fingerprint, status, body FROM idempotency_keys '
        'WHERE company_id = @companyId AND user_id = @userId AND key = @key',
      ),
      parameters: {'companyId': companyId, 'userId': userId, 'key': key},
    );
    if (result.isEmpty) return null;
    final r = result.first;
    return StoredResponse(requestFingerprint: r[0] as String, status: r[1] as int, body: r[2] as String);
  }

  static const _agentColumns = 'id, token_hash, membership_id, user_id, company_id, label, created_at, last_used_at';

  AgentToken _toAgentToken(ResultRow r) => AgentToken(
        id: r[0] as String,
        tokenHash: r[1] as String,
        membershipId: r[2] as String,
        userId: r[3] as String,
        companyId: r[4] as String,
        label: r[5] as String,
        createdAt: r[6] as DateTime,
        lastUsedAt: r[7] as DateTime?,
      );

  @override
  Future<void> createAgentToken(AgentToken t) async {
    await _db.execute(
      Sql.named(
        'INSERT INTO agent_tokens ($_agentColumns) VALUES '
        '(@id, @hash, @membershipId, @userId, @companyId, @label, @createdAt, NULL)',
      ),
      parameters: {
        'id': t.id,
        'hash': t.tokenHash,
        'membershipId': t.membershipId,
        'userId': t.userId,
        'companyId': t.companyId,
        'label': t.label,
        'createdAt': t.createdAt,
      },
    );
  }

  @override
  Future<AgentToken?> findAgentTokenByHash(String tokenHash) async {
    final r = await _db.execute(
      Sql.named('SELECT $_agentColumns FROM agent_tokens WHERE token_hash = @hash'),
      parameters: {'hash': tokenHash},
    );
    return r.isEmpty ? null : _toAgentToken(r.first);
  }

  @override
  Future<List<AgentToken>> listAgentTokens({required String companyId, required String userId}) async {
    final r = await _db.execute(
      Sql.named('SELECT $_agentColumns FROM agent_tokens WHERE company_id = @companyId AND user_id = @userId ORDER BY created_at'),
      parameters: {'companyId': companyId, 'userId': userId},
    );
    return [for (final row in r) _toAgentToken(row)];
  }

  @override
  Future<bool> revokeAgentToken({required String companyId, required String userId, required String id}) async {
    final r = await _db.execute(
      Sql.named('DELETE FROM agent_tokens WHERE id = @id AND company_id = @companyId AND user_id = @userId'),
      parameters: {'id': id, 'companyId': companyId, 'userId': userId},
    );
    return r.affectedRows > 0;
  }

  @override
  Future<void> touchAgentToken(String id, DateTime at) async {
    await _db.execute(Sql.named('UPDATE agent_tokens SET last_used_at = @at WHERE id = @id'), parameters: {'at': at, 'id': id});
  }

  static const _approvalColumns =
      'id, company_id, user_id, agent_token_id, method, path, body, summary, status, created_at, decided_at, result_status, result_body';

  PendingApproval _toApproval(ResultRow r) => PendingApproval(
        id: r[0] as String,
        companyId: r[1] as String,
        userId: r[2] as String,
        agentTokenId: r[3] as String,
        method: r[4] as String,
        path: r[5] as String,
        body: r[6] as String,
        summary: r[7] as String,
        status: r[8] as String,
        createdAt: r[9] as DateTime,
        decidedAt: r[10] as DateTime?,
        resultStatus: r[11] as int?,
        resultBody: r[12] as String?,
      );

  @override
  Future<void> createApproval(PendingApproval a) async {
    await _db.execute(
      Sql.named(
        'INSERT INTO pending_approvals ($_approvalColumns) VALUES (@id, @companyId, @userId, @agentTokenId, @method, '
        '@path, @body, @summary, @status, @createdAt, NULL, NULL, NULL)',
      ),
      parameters: {
        'id': a.id,
        'companyId': a.companyId,
        'userId': a.userId,
        'agentTokenId': a.agentTokenId,
        'method': a.method,
        'path': a.path,
        'body': a.body,
        'summary': a.summary,
        'status': a.status,
        'createdAt': a.createdAt,
      },
    );
  }

  @override
  Future<PendingApproval?> findApproval({required String companyId, required String userId, required String id}) async {
    final r = await _db.execute(
      Sql.named('SELECT $_approvalColumns FROM pending_approvals WHERE id = @id AND company_id = @companyId AND user_id = @userId'),
      parameters: {'id': id, 'companyId': companyId, 'userId': userId},
    );
    return r.isEmpty ? null : _toApproval(r.first);
  }

  @override
  Future<List<PendingApproval>> listApprovals({required String companyId, required String userId, String? status}) async {
    final r = await _db.execute(
      Sql.named(
        'SELECT $_approvalColumns FROM pending_approvals WHERE company_id = @companyId AND user_id = @userId '
        "AND (@status = '' OR status = @status) ORDER BY created_at DESC",
      ),
      parameters: {'companyId': companyId, 'userId': userId, 'status': status ?? ''},
    );
    return [for (final row in r) _toApproval(row)];
  }

  @override
  Future<bool> decideApproval({
    required String id,
    required String status,
    required DateTime at,
    int? resultStatus,
    String? resultBody,
    String fromStatus = 'pending',
  }) async {
    final r = await _db.execute(
      Sql.named(
        'UPDATE pending_approvals SET status = @status, decided_at = @at, result_status = @resultStatus, '
        'result_body = @resultBody WHERE id = @id AND status = @fromStatus',
      ),
      parameters: {
        'status': status,
        'at': at,
        'resultStatus': resultStatus,
        'resultBody': resultBody,
        'id': id,
        'fromStatus': fromStatus,
      },
    );
    return r.affectedRows > 0;
  }

  @override
  Future<bool> claimIdempotencyKey({
    required String companyId,
    required String userId,
    required String key,
    required String requestFingerprint,
  }) async {
    final result = await _db.execute(
      Sql.named(
        'INSERT INTO idempotency_keys (company_id, user_id, key, request_fingerprint, status, body, created_at) '
        "VALUES (@companyId, @userId, @key, @fingerprint, 0, '', now()) ON CONFLICT DO NOTHING",
      ),
      parameters: {'companyId': companyId, 'userId': userId, 'key': key, 'fingerprint': requestFingerprint},
    );
    return result.affectedRows == 1;
  }

  @override
  Future<void> completeIdempotencyKey({
    required String companyId,
    required String userId,
    required String key,
    required int status,
    required String body,
  }) async {
    await _db.execute(
      Sql.named(
        'UPDATE idempotency_keys SET status = @status, body = @body '
        'WHERE company_id = @companyId AND user_id = @userId AND key = @key',
      ),
      parameters: {'status': status, 'body': body, 'companyId': companyId, 'userId': userId, 'key': key},
    );
  }

  @override
  Future<void> releaseIdempotencyKey({required String companyId, required String userId, required String key}) async {
    await _db.execute(
      Sql.named('DELETE FROM idempotency_keys WHERE company_id = @companyId AND user_id = @userId AND key = @key'),
      parameters: {'companyId': companyId, 'userId': userId, 'key': key},
    );
  }

  @override
  Future<Group> createGroup({required String id, required String companyId, required String name}) async {
    await _db.execute(
      Sql.named('INSERT INTO groups (id, company_id, name) VALUES (@id, @companyId, @name)'),
      parameters: {'id': id, 'companyId': companyId, 'name': name},
    );
    return Group(id: id, companyId: companyId, name: name);
  }

  @override
  Future<Group?> findGroupById(String id) async {
    final result = await _db.execute(
      Sql.named('SELECT id, company_id, name FROM groups WHERE id = @id'),
      parameters: {'id': id},
    );
    if (result.isEmpty) return null;
    final row = result.first;
    return Group(id: row[0] as String, companyId: row[1] as String, name: row[2] as String);
  }

  @override
  Future<List<Group>> listGroupsForCompany(String companyId) async {
    final result = await _db.execute(
      Sql.named('SELECT id, company_id, name FROM groups WHERE company_id = @companyId ORDER BY name'),
      parameters: {'companyId': companyId},
    );
    return [for (final row in result) Group(id: row[0] as String, companyId: row[1] as String, name: row[2] as String)];
  }

  @override
  Future<Membership> createMembership({
    required String id,
    required String userId,
    required String companyId,
    required String groupId,
    required bool isAdmin,
  }) async {
    await _db.execute(
      Sql.named('''
        INSERT INTO memberships (id, user_id, company_id, group_id, is_admin, active)
        VALUES (@id, @userId, @companyId, @groupId, @isAdmin, true)
      '''),
      parameters: {'id': id, 'userId': userId, 'companyId': companyId, 'groupId': groupId, 'isAdmin': isAdmin},
    );
    return Membership(id: id, userId: userId, companyId: companyId, groupId: groupId, isAdmin: isAdmin, active: true);
  }

  @override
  Future<Membership?> findMembershipById(String id) async {
    final result = await _db.execute(
      Sql.named(
        'SELECT id, user_id, company_id, group_id, is_admin, active, hourly_cost_cents FROM memberships WHERE id = @id',
      ),
      parameters: {'id': id},
    );
    if (result.isEmpty) return null;
    return _toMembership(result.first);
  }

  @override
  Future<Membership?> findMembership({required String userId, required String companyId}) async {
    final result = await _db.execute(
      Sql.named(
        'SELECT id, user_id, company_id, group_id, is_admin, active, hourly_cost_cents FROM memberships '
        'WHERE user_id = @userId AND company_id = @companyId',
      ),
      parameters: {'userId': userId, 'companyId': companyId},
    );
    if (result.isEmpty) return null;
    return _toMembership(result.first);
  }

  @override
  Future<List<Membership>> listMembershipsForCompany(String companyId) async {
    final result = await _db.execute(
      Sql.named(
        'SELECT id, user_id, company_id, group_id, is_admin, active, hourly_cost_cents FROM memberships WHERE company_id = @companyId',
      ),
      parameters: {'companyId': companyId},
    );
    return [for (final row in result) _toMembership(row)];
  }

  @override
  Future<List<Membership>> listMembershipsForUser(String userId) async {
    final result = await _db.execute(
      Sql.named(
        'SELECT id, user_id, company_id, group_id, is_admin, active, hourly_cost_cents FROM memberships WHERE user_id = @userId',
      ),
      parameters: {'userId': userId},
    );
    return [for (final row in result) _toMembership(row)];
  }

  @override
  Future<bool> updateMembership({
    required String id,
    String? groupId,
    bool? active,
    bool? isAdmin,
    int? Function()? hourlyCostCents,
  }) async {
    final existing = await findMembershipById(id);
    if (existing == null) return false;
    final result = await _db.execute(
      Sql.named(
        'UPDATE memberships SET group_id = @groupId, active = @active, is_admin = @isAdmin, '
        'hourly_cost_cents = @rate WHERE id = @id',
      ),
      parameters: {
        'groupId': groupId ?? existing.groupId,
        'active': active ?? existing.active,
        'isAdmin': isAdmin ?? existing.isAdmin,
        'rate': hourlyCostCents != null ? hourlyCostCents() : existing.hourlyCostCents,
        'id': id,
      },
    );
    return result.affectedRows > 0;
  }

  @override
  Future<int> countActiveAdmins(String companyId) async {
    final result = await _db.execute(
      Sql.named(
        'SELECT count(*) FROM memberships WHERE company_id = @companyId AND is_admin = true AND active = true',
      ),
      parameters: {'companyId': companyId},
    );
    return result.first.first as int;
  }

  @override
  Future<void> setGroupPermission({
    required String groupId,
    required PermissionKey permission,
    required bool granted,
  }) async {
    if (granted) {
      await _db.execute(
        Sql.named('''
          INSERT INTO group_permissions (group_id, permission) VALUES (@groupId, @permission)
          ON CONFLICT (group_id, permission) DO NOTHING
        '''),
        parameters: {'groupId': groupId, 'permission': permission},
      );
    } else {
      await _db.execute(
        Sql.named('DELETE FROM group_permissions WHERE group_id = @groupId AND permission = @permission'),
        parameters: {'groupId': groupId, 'permission': permission},
      );
    }
  }

  @override
  Future<List<GroupPermission>> listGroupPermissions(String groupId) async {
    final result = await _db.execute(
      Sql.named('SELECT group_id, permission FROM group_permissions WHERE group_id = @groupId'),
      parameters: {'groupId': groupId},
    );
    return [for (final row in result) GroupPermission(groupId: row[0] as String, permission: row[1] as String)];
  }

  @override
  Future<void> setMembershipOverride({
    required String membershipId,
    required PermissionKey permission,
    required bool allowed,
  }) async {
    await _db.execute(
      Sql.named('''
        INSERT INTO membership_permission_overrides (membership_id, permission, allowed)
        VALUES (@membershipId, @permission, @allowed)
        ON CONFLICT (membership_id, permission) DO UPDATE SET allowed = EXCLUDED.allowed
      '''),
      parameters: {'membershipId': membershipId, 'permission': permission, 'allowed': allowed},
    );
  }

  @override
  Future<void> removeMembershipOverride({required String membershipId, required PermissionKey permission}) async {
    await _db.execute(
      Sql.named(
        'DELETE FROM membership_permission_overrides WHERE membership_id = @membershipId AND permission = @permission',
      ),
      parameters: {'membershipId': membershipId, 'permission': permission},
    );
  }

  @override
  Future<List<MembershipPermissionOverride>> listMembershipOverrides(String membershipId) async {
    final result = await _db.execute(
      Sql.named(
        'SELECT membership_id, permission, allowed FROM membership_permission_overrides WHERE membership_id = @membershipId',
      ),
      parameters: {'membershipId': membershipId},
    );
    return [
      for (final row in result)
        MembershipPermissionOverride(membershipId: row[0] as String, permission: row[1] as String, allowed: row[2] as bool),
    ];
  }

  @override
  Future<void> savePendingLogin({required String tokenHash, required String userId, required DateTime expiresAt}) async {
    await _db.execute(
      Sql.named(
        'INSERT INTO pending_logins (token_hash, user_id, expires_at) VALUES (@tokenHash, @userId, @expiresAt)',
      ),
      parameters: {'tokenHash': tokenHash, 'userId': userId, 'expiresAt': expiresAt},
    );
  }

  @override
  Future<String?> consumePendingLogin(String tokenHash, DateTime now) async {
    final result = await _db.execute(
      Sql.named('SELECT user_id, expires_at FROM pending_logins WHERE token_hash = @tokenHash'),
      parameters: {'tokenHash': tokenHash},
    );
    if (result.isEmpty) return null;
    final row = result.first;
    await _db.execute(
      Sql.named('DELETE FROM pending_logins WHERE token_hash = @tokenHash'),
      parameters: {'tokenHash': tokenHash},
    );
    final expiresAt = row[1] as DateTime;
    if (now.isAfter(expiresAt)) return null;
    return row[0] as String;
  }

  @override
  Future<void> saveInvitation(Invitation invitation) async {
    await _db.execute(
      Sql.named('''
        INSERT INTO invitations (token_hash, company_id, email, group_id, invited_by_user_id, expires_at)
        VALUES (@tokenHash, @companyId, @email, @groupId, @invitedBy, @expiresAt)
      '''),
      parameters: {
        'tokenHash': invitation.tokenHash,
        'companyId': invitation.companyId,
        'email': invitation.email,
        'groupId': invitation.groupId,
        'invitedBy': invitation.invitedByUserId,
        'expiresAt': invitation.expiresAt,
      },
    );
  }

  @override
  Future<Invitation?> consumeInvitation(String tokenHash, DateTime now) async {
    // DELETE ... RETURNING: Lesen und Entwerten in einer Anweisung —
    // zwei gleichzeitige Einlöseversuche können nicht beide gewinnen.
    final result = await _db.execute(
      Sql.named(
        'DELETE FROM invitations WHERE token_hash = @tokenHash '
        'RETURNING token_hash, company_id, email, group_id, invited_by_user_id, expires_at',
      ),
      parameters: {'tokenHash': tokenHash},
    );
    if (result.isEmpty) return null;
    final invitation = _toInvitation(result.first);
    return invitation.isExpired(now) ? null : invitation;
  }

  @override
  Future<List<Invitation>> listInvitationsForCompany(String companyId) async {
    final result = await _db.execute(
      Sql.named(
        'SELECT token_hash, company_id, email, group_id, invited_by_user_id, expires_at FROM invitations '
        'WHERE company_id = @companyId ORDER BY expires_at',
      ),
      parameters: {'companyId': companyId},
    );
    return [for (final row in result) _toInvitation(row)];
  }

  Invitation _toInvitation(ResultRow row) => Invitation(
        tokenHash: row[0] as String,
        companyId: row[1] as String,
        email: row[2] as String,
        groupId: row[3] as String,
        invitedByUserId: row[4] as String,
        expiresAt: row[5] as DateTime,
      );

  @override
  Future<void> deleteSessionsForUser(String userId, {String? exceptTokenHash}) async {
    await _db.execute(
      Sql.named("DELETE FROM company_sessions WHERE user_id = @userId AND token_hash <> coalesce(@except, '')"),
      parameters: {'userId': userId, 'except': exceptTokenHash},
    );
  }

  @override
  Future<void> updatePasswordHash(String userId, String passwordHash) async {
    await _db.execute(
      Sql.named('UPDATE app_users SET password_hash = @hash WHERE id = @id'),
      parameters: {'hash': passwordHash, 'id': userId},
    );
  }

  @override
  Future<void> purgeExpired(DateTime now) async {
    await _db.execute(Sql.named('DELETE FROM company_sessions WHERE expires_at < @now'), parameters: {'now': now});
    await _db.execute(Sql.named('DELETE FROM pending_logins WHERE expires_at < @now'), parameters: {'now': now});
    // Stichtage in Dart berechnen: bei "@now - interval" leitet Postgres
    // den Parametertyp falsch als interval ab (42883).
    await _db.execute(
      Sql.named('DELETE FROM invitations WHERE expires_at < @cutoff'),
      parameters: {'cutoff': now.subtract(const Duration(days: 30))},
    );
    await _db.execute(
      Sql.named('DELETE FROM idempotency_keys WHERE created_at < @cutoff'),
      parameters: {'cutoff': now.subtract(const Duration(days: 7))},
    );
  }

  @override
  Future<void> saveSession(CompanySession session) async {
    await _db.execute(
      Sql.named('''
        INSERT INTO company_sessions (token_hash, membership_id, user_id, company_id, created_at, expires_at)
        VALUES (@tokenHash, @membershipId, @userId, @companyId, @createdAt, @expiresAt)
        ON CONFLICT (token_hash) DO UPDATE SET expires_at = EXCLUDED.expires_at
      '''),
      parameters: {
        'tokenHash': session.tokenHash,
        'membershipId': session.membershipId,
        'userId': session.userId,
        'companyId': session.companyId,
        'createdAt': session.createdAt,
        'expiresAt': session.expiresAt,
      },
    );
  }

  @override
  Future<CompanySession?> findSession(String tokenHash) async {
    final result = await _db.execute(
      Sql.named(
        'SELECT token_hash, membership_id, user_id, company_id, created_at, expires_at FROM company_sessions '
        'WHERE token_hash = @tokenHash',
      ),
      parameters: {'tokenHash': tokenHash},
    );
    if (result.isEmpty) return null;
    final row = result.first;
    return CompanySession(
      tokenHash: row[0] as String,
      membershipId: row[1] as String,
      userId: row[2] as String,
      companyId: row[3] as String,
      createdAt: row[4] as DateTime,
      expiresAt: row[5] as DateTime,
    );
  }

  @override
  Future<void> deleteSession(String tokenHash) async {
    await _db.execute(
      Sql.named('DELETE FROM company_sessions WHERE token_hash = @tokenHash'),
      parameters: {'tokenHash': tokenHash},
    );
  }

  Company _toCompany(ResultRow row) {
    final modulesRaw = row[2] as String;
    return Company(
      id: row[0] as String,
      name: row[1] as String,
      enabledModules: modulesRaw.isEmpty ? const {} : modulesRaw.split(',').toSet(),
    );
  }

  Membership _toMembership(ResultRow row) => Membership(
        id: row[0] as String,
        userId: row[1] as String,
        companyId: row[2] as String,
        groupId: row[3] as String,
        isAdmin: row[4] as bool,
        active: row[5] as bool,
        hourlyCostCents: row[6] as int?,
      );
}
