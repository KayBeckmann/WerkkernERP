/// Mahnwesen online (C12): Mahnstufe, Gebühr und Verzugszins rechnet der
/// gemeinsame Kern (`werkkern_core`); hier nur das Protokoll erstellter
/// Mahnungen — online ist nachvollziehbar, wer wann welche Stufe gemahnt
/// hat (offline wird nichts gespeichert).
library;

class DunningNotice {
  const DunningNotice({
    required this.id,
    required this.companyId,
    required this.documentId,
    required this.level,
    required this.invoiceGrossCents,
    required this.feeCents,
    required this.interestCents,
    required this.overdueDays,
    required this.createdByUserId,
    required this.createdAt,
    this.sentAt,
  });
  final String id;
  final String companyId;
  final String documentId;

  /// 1–3 (= 1./2./3. Mahnung).
  final int level;
  final int invoiceGrossCents;
  final int feeCents;
  final int interestCents;
  final int overdueDays;
  final String createdByUserId;
  final DateTime createdAt;

  /// Per Mail versendet (Mailversand über den Server).
  final DateTime? sentAt;

  int get totalDueCents => invoiceGrossCents + feeCents + interestCents;

  Map<String, Object?> toJson() => {
        'id': id,
        'documentId': documentId,
        'level': level,
        'invoiceGrossCents': invoiceGrossCents,
        'feeCents': feeCents,
        'interestCents': interestCents,
        'totalDueCents': totalDueCents,
        'overdueDays': overdueDays,
        'createdAt': createdAt.toIso8601String(),
        'sentAt': sentAt?.toIso8601String(),
      };
}

abstract interface class DunningStore {
  Future<List<DunningNotice>> listDunningNotices(String companyId, {String? documentId});
  Future<DunningNotice?> findDunningNotice(String companyId, String id);
  Future<void> createDunningNotice(DunningNotice notice);
  Future<bool> markDunningNoticeSent(String companyId, String id, DateTime sentAt);
}
