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
        'SELECT id, user_id, company_id, group_id, is_admin, active FROM memberships WHERE id = @id',
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
        'SELECT id, user_id, company_id, group_id, is_admin, active FROM memberships '
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
        'SELECT id, user_id, company_id, group_id, is_admin, active FROM memberships WHERE company_id = @companyId',
      ),
      parameters: {'companyId': companyId},
    );
    return [for (final row in result) _toMembership(row)];
  }

  @override
  Future<List<Membership>> listMembershipsForUser(String userId) async {
    final result = await _db.execute(
      Sql.named(
        'SELECT id, user_id, company_id, group_id, is_admin, active FROM memberships WHERE user_id = @userId',
      ),
      parameters: {'userId': userId},
    );
    return [for (final row in result) _toMembership(row)];
  }

  @override
  Future<bool> updateMembership({required String id, String? groupId, bool? active, bool? isAdmin}) async {
    final existing = await findMembershipById(id);
    if (existing == null) return false;
    final result = await _db.execute(
      Sql.named('UPDATE memberships SET group_id = @groupId, active = @active, is_admin = @isAdmin WHERE id = @id'),
      parameters: {
        'groupId': groupId ?? existing.groupId,
        'active': active ?? existing.active,
        'isAdmin': isAdmin ?? existing.isAdmin,
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
      );
}
