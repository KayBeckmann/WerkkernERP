import 'models.dart';
import 'repository.dart';

class InMemoryPhaseBRepository implements PhaseBRepository {
  final List<AppUser> _users = [];
  final List<Company> _companies = [];
  final List<Group> _groups = [];
  final List<Membership> _memberships = [];
  final List<GroupPermission> _groupPermissions = [];
  final List<MembershipPermissionOverride> _overrides = [];
  final List<({String tokenHash, String userId, DateTime expiresAt})> _pendingLogins = [];
  final List<CompanySession> _sessions = [];
  final List<Invitation> _invitations = [];
  final Map<String, CompanyProfile> _profiles = {};
  final List<AuditEntry> _audit = [];
  final Map<String, StoredResponse> _idempotent = {};

  @override
  Future<StoredResponse?> findIdempotentResponse({
    required String companyId,
    required String userId,
    required String key,
  }) async =>
      _idempotent['$companyId|$userId|$key'];

  @override
  Future<bool> claimIdempotencyKey({
    required String companyId,
    required String userId,
    required String key,
    required String requestFingerprint,
  }) async {
    final id = '$companyId|$userId|$key';
    if (_idempotent.containsKey(id)) return false;
    _idempotent[id] = StoredResponse(requestFingerprint: requestFingerprint, status: 0, body: '');
    return true;
  }

  @override
  Future<void> completeIdempotencyKey({
    required String companyId,
    required String userId,
    required String key,
    required int status,
    required String body,
  }) async {
    final id = '$companyId|$userId|$key';
    final claimed = _idempotent[id];
    if (claimed == null) return;
    _idempotent[id] = StoredResponse(requestFingerprint: claimed.requestFingerprint, status: status, body: body);
  }

  @override
  Future<void> releaseIdempotencyKey({required String companyId, required String userId, required String key}) async =>
      _idempotent.remove('$companyId|$userId|$key');

  @override
  Future<CompanyProfile> getCompanyProfile(String companyId) async =>
      _profiles[companyId] ?? CompanyProfile(companyId: companyId);

  @override
  Future<void> saveCompanyProfile(CompanyProfile profile) async => _profiles[profile.companyId] = profile;

  @override
  Future<void> recordAudit(AuditEntry entry) async => _audit.add(entry);

  @override
  Future<List<AuditEntry>> listAudit(String companyId, {int limit = 100}) async =>
      _audit.reversed.where((e) => e.companyId == companyId).take(limit).toList();

  @override
  Future<AppUser> createUser({required String id, required String email, required String passwordHash}) async {
    final user = AppUser(id: id, email: email, passwordHash: passwordHash);
    _users.add(user);
    return user;
  }

  @override
  Future<AppUser?> findUserByEmail(String email) async => _users.where((u) => u.email == email).firstOrNull;

  @override
  Future<AppUser?> findUserById(String id) async => _users.where((u) => u.id == id).firstOrNull;

  @override
  Future<Company> createCompany({required String id, required String name}) async {
    final company = Company(id: id, name: name, enabledModules: const {});
    _companies.add(company);
    return company;
  }

  @override
  Future<Company?> findCompanyById(String id) async => _companies.where((c) => c.id == id).firstOrNull;

  @override
  Future<void> setCompanyModules({required String companyId, required Set<String> enabledModules}) async {
    final index = _companies.indexWhere((c) => c.id == companyId);
    if (index == -1) return;
    final existing = _companies[index];
    _companies[index] = Company(id: existing.id, name: existing.name, enabledModules: enabledModules);
  }

  @override
  Future<Group> createGroup({required String id, required String companyId, required String name}) async {
    final group = Group(id: id, companyId: companyId, name: name);
    _groups.add(group);
    return group;
  }

  @override
  Future<Group?> findGroupById(String id) async => _groups.where((g) => g.id == id).firstOrNull;

  @override
  Future<List<Group>> listGroupsForCompany(String companyId) async =>
      _groups.where((g) => g.companyId == companyId).toList();

  @override
  Future<Membership> createMembership({
    required String id,
    required String userId,
    required String companyId,
    required String groupId,
    required bool isAdmin,
  }) async {
    final membership = Membership(
      id: id,
      userId: userId,
      companyId: companyId,
      groupId: groupId,
      isAdmin: isAdmin,
      active: true,
    );
    _memberships.add(membership);
    return membership;
  }

  @override
  Future<Membership?> findMembershipById(String id) async => _memberships.where((m) => m.id == id).firstOrNull;

  @override
  Future<Membership?> findMembership({required String userId, required String companyId}) async =>
      _memberships.where((m) => m.userId == userId && m.companyId == companyId).firstOrNull;

  @override
  Future<List<Membership>> listMembershipsForCompany(String companyId) async =>
      _memberships.where((m) => m.companyId == companyId).toList();

  @override
  Future<List<Membership>> listMembershipsForUser(String userId) async =>
      _memberships.where((m) => m.userId == userId).toList();

  @override
  Future<bool> updateMembership({required String id, String? groupId, bool? active, bool? isAdmin}) async {
    final index = _memberships.indexWhere((m) => m.id == id);
    if (index == -1) return false;
    final existing = _memberships[index];
    _memberships[index] = Membership(
      id: existing.id,
      userId: existing.userId,
      companyId: existing.companyId,
      groupId: groupId ?? existing.groupId,
      isAdmin: isAdmin ?? existing.isAdmin,
      active: active ?? existing.active,
    );
    return true;
  }

  @override
  Future<int> countActiveAdmins(String companyId) async =>
      _memberships.where((m) => m.companyId == companyId && m.isAdmin && m.active).length;

  @override
  Future<void> setGroupPermission({
    required String groupId,
    required PermissionKey permission,
    required bool granted,
  }) async {
    _groupPermissions.removeWhere((gp) => gp.groupId == groupId && gp.permission == permission);
    if (granted) {
      _groupPermissions.add(GroupPermission(groupId: groupId, permission: permission));
    }
  }

  @override
  Future<List<GroupPermission>> listGroupPermissions(String groupId) async =>
      _groupPermissions.where((gp) => gp.groupId == groupId).toList();

  @override
  Future<void> setMembershipOverride({
    required String membershipId,
    required PermissionKey permission,
    required bool allowed,
  }) async {
    _overrides.removeWhere((o) => o.membershipId == membershipId && o.permission == permission);
    _overrides.add(MembershipPermissionOverride(membershipId: membershipId, permission: permission, allowed: allowed));
  }

  @override
  Future<void> removeMembershipOverride({required String membershipId, required PermissionKey permission}) async {
    _overrides.removeWhere((o) => o.membershipId == membershipId && o.permission == permission);
  }

  @override
  Future<List<MembershipPermissionOverride>> listMembershipOverrides(String membershipId) async =>
      _overrides.where((o) => o.membershipId == membershipId).toList();

  @override
  Future<void> savePendingLogin({required String tokenHash, required String userId, required DateTime expiresAt}) async {
    _pendingLogins.add((tokenHash: tokenHash, userId: userId, expiresAt: expiresAt));
  }

  @override
  Future<String?> consumePendingLogin(String tokenHash, DateTime now) async {
    final index = _pendingLogins.indexWhere((p) => p.tokenHash == tokenHash);
    if (index == -1) return null;
    final pending = _pendingLogins.removeAt(index);
    if (now.isAfter(pending.expiresAt)) return null;
    return pending.userId;
  }

  @override
  Future<void> saveInvitation(Invitation invitation) async => _invitations.add(invitation);

  @override
  Future<Invitation?> consumeInvitation(String tokenHash, DateTime now) async {
    final index = _invitations.indexWhere((i) => i.tokenHash == tokenHash);
    if (index == -1) return null;
    final invitation = _invitations.removeAt(index);
    return invitation.isExpired(now) ? null : invitation;
  }

  @override
  Future<List<Invitation>> listInvitationsForCompany(String companyId) async =>
      _invitations.where((i) => i.companyId == companyId).toList();

  @override
  Future<void> saveSession(CompanySession session) async {
    _sessions.removeWhere((s) => s.tokenHash == session.tokenHash);
    _sessions.add(session);
  }

  @override
  Future<CompanySession?> findSession(String tokenHash) async =>
      _sessions.where((s) => s.tokenHash == tokenHash).firstOrNull;

  @override
  Future<void> deleteSession(String tokenHash) async {
    _sessions.removeWhere((s) => s.tokenHash == tokenHash);
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
