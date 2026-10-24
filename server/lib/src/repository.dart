import 'models.dart';

/// Repository-Schnittstelle (gleiches Muster wie LibreECAD/ADR-0001)
/// — `InMemoryPhaseBRepository` für `dart test`, `PostgresPhaseBRepository`
/// für den echten Betrieb.
abstract class PhaseBRepository {
  // ---- Nutzer (global, firmenübergreifend) -----------------------------
  Future<AppUser> createUser({required String id, required String email, required String passwordHash});
  Future<AppUser?> findUserByEmail(String email);
  Future<AppUser?> findUserById(String id);

  // ---- Firmen -----------------------------------------------------------
  Future<Company> createCompany({required String id, required String name});
  Future<Company?> findCompanyById(String id);
  Future<void> setCompanyModules({required String companyId, required Set<String> enabledModules});

  Future<CompanyProfile> getCompanyProfile(String companyId);
  Future<void> saveCompanyProfile(CompanyProfile profile);

  // ---- Audit -----------------------------------------------------------
  Future<void> recordAudit(AuditEntry entry);

  /// Neueste zuerst.
  Future<List<AuditEntry>> listAudit(String companyId, {int limit = 100});

  // ---- Agent-Token und Freigaben (C8) ---------------------------------
  Future<void> createAgentToken(AgentToken token);
  Future<AgentToken?> findAgentTokenByHash(String tokenHash);
  Future<List<AgentToken>> listAgentTokens({required String companyId, required String userId});
  Future<bool> revokeAgentToken({required String companyId, required String userId, required String id});
  Future<void> touchAgentToken(String id, DateTime at);

  Future<void> createApproval(PendingApproval approval);
  Future<PendingApproval?> findApproval({required String companyId, required String userId, required String id});
  Future<List<PendingApproval>> listApprovals({required String companyId, required String userId, String? status});

  /// Setzt den Status nur, wenn die Freigabe noch [fromStatus] hat —
  /// atomarer Übergang, eine Freigabe kann nie zweimal ausgeführt
  /// werden. `false` = schon entschieden/in Ausführung.
  Future<bool> decideApproval({
    required String id,
    required String status,
    required DateTime at,
    int? resultStatus,
    String? resultBody,
    String fromStatus = 'pending',
  });

  // ---- Idempotenz (B2) -------------------------------------------------
  Future<StoredResponse?> findIdempotentResponse({
    required String companyId,
    required String userId,
    required String key,
  });

  /// Reserviert den Schlüssel **vor** der Ausführung (Antwort noch
  /// leer, status 0). `false` = bereits reserviert/erledigt — zwei
  /// gleichzeitig eintreffende Doppelsendungen führen so nie beide aus.
  Future<bool> claimIdempotencyKey({
    required String companyId,
    required String userId,
    required String key,
    required String requestFingerprint,
  });

  Future<void> completeIdempotencyKey({
    required String companyId,
    required String userId,
    required String key,
    required int status,
    required String body,
  });

  /// Gibt eine Reservierung frei (Serverfehler — erneuter Versuch muss
  /// möglich bleiben).
  Future<void> releaseIdempotencyKey({required String companyId, required String userId, required String key});

  // ---- Gruppen ------------------------------------------------------------
  Future<Group> createGroup({required String id, required String companyId, required String name});
  Future<Group?> findGroupById(String id);
  Future<List<Group>> listGroupsForCompany(String companyId);

  // ---- Mitgliedschaften ---------------------------------------------------
  Future<Membership> createMembership({
    required String id,
    required String userId,
    required String companyId,
    required String groupId,
    required bool isAdmin,
  });
  Future<Membership?> findMembershipById(String id);

  /// Höchstens eine Mitgliedschaft pro (userId, companyId) — siehe
  /// Klassendoc bei [Membership].
  Future<Membership?> findMembership({required String userId, required String companyId});
  Future<List<Membership>> listMembershipsForCompany(String companyId);
  Future<List<Membership>> listMembershipsForUser(String userId);

  /// [hourlyCostCents]: `null` = unverändert, `() => null` = löschen.
  Future<bool> updateMembership({
    required String id,
    String? groupId,
    bool? active,
    bool? isAdmin,
    int? Function()? hourlyCostCents,
  });

  /// Wie viele **aktive** Admin-Mitgliedschaften diese Firma hat — für
  /// den "letzten Admin nicht aussperren"-Schutz (gleiches Prinzip wie
  /// LibreECADs company-users-service).
  Future<int> countActiveAdmins(String companyId);

  // ---- Gruppenrechte --------------------------------------------------------
  Future<void> setGroupPermission({
    required String groupId,
    required PermissionKey permission,
    required bool granted,
  });
  Future<List<GroupPermission>> listGroupPermissions(String groupId);

  // ---- Mitgliedschafts-Ausnahmen ---------------------------------------------
  Future<void> setMembershipOverride({
    required String membershipId,
    required PermissionKey permission,
    required bool allowed,
  });
  Future<void> removeMembershipOverride({required String membershipId, required PermissionKey permission});
  Future<List<MembershipPermissionOverride>> listMembershipOverrides(String membershipId);

  // ---- Identitäts-/Firmensitzungen ---------------------------------------------
  /// Kurzlebiges Zwischen-Token nach Login, bevor der Firmenkontext
  /// gewählt ist (siehe `docs/phase-b-server.md`).
  Future<void> savePendingLogin({required String tokenHash, required String userId, required DateTime expiresAt});
  Future<String?> consumePendingLogin(String tokenHash, DateTime now);

  // ---- Einladungen -----------------------------------------------------------
  Future<void> saveInvitation(Invitation invitation);

  /// Liefert die Einladung und entfernt sie im selben Schritt — eine
  /// Einladung ist genau einmal einlösbar, auch wenn sie abgelaufen ist
  /// (abgelaufene werden dabei mit aufgeräumt, Rückgabe dann `null`).
  Future<Invitation?> consumeInvitation(String tokenHash, DateTime now);

  /// Offene (noch nicht eingelöste) Einladungen einer Firma, inklusive
  /// abgelaufener — die UI zeigt den Ablauf an, statt sie zu verstecken.
  Future<List<Invitation>> listInvitationsForCompany(String companyId);

  Future<void> saveSession(CompanySession session);

  /// Beendet alle Sitzungen eines Nutzers außer [exceptTokenHash] (z. B.
  /// nach Passwortänderung).
  Future<void> deleteSessionsForUser(String userId, {String? exceptTokenHash});

  Future<void> updatePasswordHash(String userId, String passwordHash);

  /// Räumt Abgelaufenes auf: Sitzungen, Login-Zwischentoken, seit 30
  /// Tagen abgelaufene Einladungen, Idempotenz-Einträge älter als 7 Tage.
  Future<void> purgeExpired(DateTime now);
  Future<CompanySession?> findSession(String tokenHash);
  Future<void> deleteSession(String tokenHash);
}
