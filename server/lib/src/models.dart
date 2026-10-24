/// B1 Mitgliedschaften/Gruppen/Backend-Isolation — Datenmodelle.
/// Siehe Roadmap-Abschnitt B1 und [[Decisions/ADR-0001-phase-b-architektur]].
library;

/// Globale Nutzeridentität — **nicht** firmengebunden (anders als die
/// Offline-App, die companyId-isolierte Stammdaten je Firma hält).
/// Ein Nutzer kann über [Membership] zu mehreren Firmen gehören
/// (viele-zu-viele, Roadmap B1 Punkt 1).
class AppUser {
  const AppUser({required this.id, required this.email, required this.passwordHash});
  final String id;
  final String email;
  final String passwordHash;
}

/// [enabledModules] sind freie Modul-Schlüssel (z. B. "projects",
/// "timeTracking") — bewusst eine offene Menge statt vorab fixierter
/// Spalten, damit dieselben Modul-Schlüssel wie in der Offline-App
/// (`Companies.*Enabled`) wiederverwendbar bleiben, ohne die Tabelle
/// bei jedem neuen Modul erneut zu migrieren. Eine deaktivierte
/// Firmenfunktion bleibt vorrangig gegenüber jeder Mitgliedschafts-/
/// Berechtigungsentscheidung (Roadmap B1 Punkt 2) — siehe
/// [PermissionResolver.hasPermission].
class Company {
  const Company({required this.id, required this.name, required this.enabledModules});
  final String id;
  final String name;
  final Set<String> enabledModules;
}

/// Startvorlagen laut Roadmap: "Projektleiter", "Monteur",
/// "Buchhaltung" — frei umbenennbar/ergänzbar wie `StaffRoles` in der
/// Offline-App. **Keine** vorbelegten Berechtigungen (siehe
/// [GroupPermission]) — "konkrete Startrechte sind nicht entschieden
/// und müssen vor Rollout fachlich festgelegt werden" (Roadmap B1).
class Group {
  const Group({required this.id, required this.companyId, required this.name});
  final String id;
  final String companyId;
  final String name;
}

/// Ein granuliertes Recht, z. B. `"projects.read"`. Bewusst ein
/// einfacher String-Schlüssel statt eines festen Enums — das konkrete
/// Rechte-Set ist Teil der noch offenen fachlichen Festlegung, nicht
/// dieser B1-Grundlage.
typedef PermissionKey = String;

/// Gewährt [permission] standardmäßig jedem Mitglied von [groupId] —
/// durch eine [MembershipPermissionOverride] je Mitgliedschaft
/// übersteuerbar (Roadmap B1 Punkt 2: "Individuelles Erlauben/Sperren
/// je Berechtigung überschreibt die Gruppe").
class GroupPermission {
  const GroupPermission({required this.groupId, required this.permission});
  final String groupId;
  final PermissionKey permission;
}

/// Genau eine Mitgliedschaft pro (userId, companyId) — "Pro Firma
/// gehört ein Nutzer genau einer Gruppe an" (Roadmap B1 Punkt 1).
/// [isAdmin] ist **keine** Berechtigung (siehe [PermissionKey]),
/// sondern eine eigene strukturelle Eigenschaft — "Nur Firmenadmin...
/// verwaltet Gruppen, Zuordnung und Ausnahmen – nicht delegierbar über
/// eine normale Einzelberechtigung" (Roadmap B1 Punkt 2). Der erste
/// Admin einer neuen Firma wird bei Firmenanlage automatisch gesetzt
/// (siehe `CompanyRepository.createCompanyWithFirstAdmin`) — ein
/// Recovery-Weg für den Fall seines Ausfalls ist laut Roadmap bewusst
/// noch offen.
class Membership {
  const Membership({
    required this.id,
    required this.userId,
    required this.companyId,
    required this.groupId,
    required this.isAdmin,
    required this.active,
  });
  final String id;
  final String userId;
  final String companyId;
  final String groupId;
  final bool isAdmin;
  final bool active;
}

class MembershipPermissionOverride {
  const MembershipPermissionOverride({
    required this.membershipId,
    required this.permission,
    required this.allowed,
  });
  final String membershipId;
  final PermissionKey permission;

  /// `true` = explizit gewährt, `false` = explizit gesperrt — beides
  /// übersteuert die Gruppenvorgabe.
  final bool allowed;
}

class CompanySession {
  const CompanySession({
    required this.tokenHash,
    required this.membershipId,
    required this.userId,
    required this.companyId,
    required this.createdAt,
    required this.expiresAt,
  });
  final String tokenHash;
  final String membershipId;
  final String userId;
  final String companyId;
  final DateTime createdAt;
  final DateTime expiresAt;

  bool isExpired(DateTime now) => now.isAfter(expiresAt);
}

/// Einladung eines (noch nicht oder bereits registrierten) Nutzers in
/// eine Firma — schließt die in B1 zurückgestellte Onboarding-Lücke
/// ("`POST /memberships` setzt eine bereits registrierte E-Mail
/// voraus"). Einmal verwendbar, nur als Hash gespeichert (gleiches
/// Prinzip wie Sitzungen, siehe `Tokens`). Gruppe wird schon beim
/// Einladen festgelegt — "pro Firma genau eine Gruppe" (B1 Punkt 1)
/// gilt damit ab der ersten Sekunde der Mitgliedschaft.
class Invitation {
  const Invitation({
    required this.tokenHash,
    required this.companyId,
    required this.email,
    required this.groupId,
    required this.invitedByUserId,
    required this.expiresAt,
  });
  final String tokenHash;
  final String companyId;
  final String email;
  final String groupId;
  final String invitedByUserId;
  final DateTime expiresAt;

  bool isExpired(DateTime now) => now.isAfter(expiresAt);
}
