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
    this.hourlyCostCents,
  });
  final String id;
  final String userId;
  final String companyId;
  final String groupId;
  final bool isAdmin;
  final bool active;

  /// C3 online: eigener Stundenkostensatz dieses Mitglieds in dieser
  /// Firma (Kay-Vorgabe 2026-10-20: "echte Benutzerkonten mit je
  /// eigenem/abweichendem Stundensatz"). `null` = nicht gepflegt, die
  /// Buchung trägt dann keine Kosten bei (nicht geraten).
  final int? hourlyCostCents;
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
    this.isAgent = false,
  });

  /// C8: Zugriff über ein Agent-Token (LLM/MCP) statt einer
  /// App-Sitzung — gleiche Fachrechte wie der Nutzer, aber nie
  /// Admin-Funktionen und irreversible Aktionen nur nach Freigabe.
  final bool isAgent;
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

/// Firmen-Stammdaten für Dokumente (F1-Pflichtangaben: Anschrift,
/// Steuernummer/USt-IdNr.) — wie `Companies` in der Offline-App. Werden
/// beim Finalisieren in das Dokument eingefroren.
class CompanyProfile {
  const CompanyProfile({
    required this.companyId,
    this.address,
    this.taxNumber,
    this.vatId,
    this.iban,
    this.email,
    this.phone,
    this.footerText,
    this.documentTexts = const {},
    this.smallBusinessExempt = false,
  });
  final String companyId;
  final String? address;
  final String? taxNumber;
  final String? vatId;
  final String? iban;
  final String? email;
  final String? phone;

  /// PDF-Fußzeile (alle Dokumentarten).
  final String? footerText;

  /// Einleitungs-/Schlusstext je Dokumentart (`invoice`, `quote`, ...),
  /// wie offline "pro Dokument abweichend".
  final Map<String, ({String? intro, String? closing})> documentTexts;

  /// Kleinunternehmerregelung § 19 UStG: Server erzwingt 0 % USt, PDF
  /// zeigt den festen Hinweis. Arbeitsvorgabe, keine Rechtsprüfung.
  final bool smallBusinessExempt;

  Map<String, Object?> toJson() => {
        'address': address,
        'taxNumber': taxNumber,
        'vatId': vatId,
        'iban': iban,
        'email': email,
        'phone': phone,
        'footerText': footerText,
        'documentTexts': {
          for (final e in documentTexts.entries) e.key: {'intro': e.value.intro, 'closing': e.value.closing},
        },
        'smallBusinessExempt': smallBusinessExempt,
      };
}

/// Audit-Eintrag (ADR-0001 B0.3 "Audit-/Betriebskonzept"): **wer** hat
/// **was** an **welchem** Objekt getan — bewusst ohne Inhalte
/// (Datenminimierung; Inhalte stehen im Objekt selbst bzw. sind nach
/// Finalisierung ohnehin unveränderlich).
class AuditEntry {
  const AuditEntry({
    required this.companyId,
    required this.userId,
    required this.action,
    required this.entityType,
    this.entityId,
    required this.at,
  });
  final String companyId;
  final String? userId;
  final String action;
  final String entityType;
  final String? entityId;
  final DateTime at;
}

/// Gespeicherte Antwort zu einem `Idempotency-Key` (B2).
/// [requestFingerprint] verhindert, dass derselbe Schlüssel für einen
/// anderen Aufruf wiederverwendet wird (dann 422 statt falscher Antwort).
class StoredResponse {
  const StoredResponse({required this.requestFingerprint, required this.status, required this.body});
  final String requestFingerprint;
  final int status;
  final String body;
}

/// C8: persönliches Token für einen LLM-Agenten (MCP/API). Gebunden an
/// genau eine Mitgliedschaft; der Agent hat dadurch exakt die aktuell
/// wirksamen Rechte des Nutzers in dieser Firma — Entzug wirkt sofort.
class AgentToken {
  const AgentToken({
    required this.id,
    required this.tokenHash,
    required this.membershipId,
    required this.userId,
    required this.companyId,
    required this.label,
    required this.createdAt,
    this.lastUsedAt,
  });
  final String id;
  final String tokenHash;
  final String membershipId;
  final String userId;
  final String companyId;
  final String label;
  final DateTime createdAt;
  final DateTime? lastUsedAt;
}

/// C8: vom Agenten angefragte irreversible Aktion, die erst nach
/// Bestätigung durch den Nutzer in der App ausgeführt wird.
class PendingApproval {
  const PendingApproval({
    required this.id,
    required this.companyId,
    required this.userId,
    required this.agentTokenId,
    required this.method,
    required this.path,
    required this.body,
    required this.summary,
    required this.status,
    required this.createdAt,
    this.decidedAt,
    this.resultStatus,
    this.resultBody,
  });
  final String id;
  final String companyId;
  final String userId;
  final String agentTokenId;
  final String method;
  final String path;
  final String body;

  /// Menschlich lesbare Beschreibung für den Bestätigungsdialog.
  final String summary;

  /// `pending` | `confirmed` | `rejected`
  final String status;
  final DateTime createdAt;
  final DateTime? decidedAt;
  final int? resultStatus;
  final String? resultBody;
}
