/// Firma aus Sicht des Plattformbetreibers (Superadmin-Panel).
class PlatformCompanyInfo {
  const PlatformCompanyInfo({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.activeMembers,
    required this.adminEmails,
    this.plan,
    this.paidUntil,
    this.note,
    this.overdue = false,
    this.suspended = false,
    this.suspendedAt,
    this.suspendReason,
  });

  factory PlatformCompanyInfo.fromJson(Map<String, Object?> j) => PlatformCompanyInfo(
        id: j['id'] as String,
        name: j['name'] as String,
        createdAt: DateTime.parse(j['createdAt'] as String),
        activeMembers: j['activeMembers'] as int,
        adminEmails: (j['adminEmails'] as List).cast<String>(),
        plan: j['plan'] as String?,
        paidUntil: j['paidUntil'] == null ? null : DateTime.parse(j['paidUntil'] as String),
        note: j['note'] as String?,
        overdue: j['overdue'] as bool? ?? false,
        suspended: j['suspended'] as bool? ?? false,
        suspendedAt: j['suspendedAt'] == null ? null : DateTime.parse(j['suspendedAt'] as String),
        suspendReason: j['suspendReason'] as String?,
      );

  final String id;
  final String name;
  final DateTime createdAt;
  final int activeMembers;
  final List<String> adminEmails;
  final String? plan;

  /// Kalendertag, bis einschließlich dem bezahlt ist.
  final DateTime? paidUntil;
  final String? note;
  final bool overdue;
  final bool suspended;
  final DateTime? suspendedAt;
  final String? suspendReason;
}
