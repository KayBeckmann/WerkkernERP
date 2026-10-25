import 'api_client.dart';

/// Mahnwesen online (C12).
class OnlineOverdueInvoice {
  const OnlineOverdueInvoice({
    required this.documentId,
    this.number,
    this.customerName,
    required this.dueDate,
    required this.level,
    required this.levelLabel,
    required this.overdueDays,
    required this.invoiceGrossCents,
    required this.feeCents,
    required this.interestCents,
    required this.totalDueCents,
    this.lastNoticeLevel,
    this.lastNoticeAt,
  });
  factory OnlineOverdueInvoice.fromJson(Map<String, Object?> j) {
    final last = j['lastNotice'] as Map<String, Object?>?;
    return OnlineOverdueInvoice(
      documentId: j['documentId'] as String,
      number: j['number'] as String?,
      customerName: j['customerName'] as String?,
      dueDate: DateTime.parse(j['dueDate'] as String),
      level: j['level'] as int,
      levelLabel: j['levelLabel'] as String,
      overdueDays: j['overdueDays'] as int,
      invoiceGrossCents: j['invoiceGrossCents'] as int,
      feeCents: j['feeCents'] as int,
      interestCents: j['interestCents'] as int,
      totalDueCents: j['totalDueCents'] as int,
      lastNoticeLevel: last?['level'] as int?,
      lastNoticeAt: last == null ? null : DateTime.parse(last['createdAt'] as String),
    );
  }
  final String documentId;
  final String? number;
  final String? customerName;
  final DateTime dueDate;

  /// 1–3.
  final int level;
  final String levelLabel;
  final int overdueDays;
  final int invoiceGrossCents;
  final int feeCents;
  final int interestCents;
  final int totalDueCents;
  final int? lastNoticeLevel;
  final DateTime? lastNoticeAt;
}

class OnlineDunningNotice {
  const OnlineDunningNotice({
    required this.id,
    required this.level,
    required this.invoiceGrossCents,
    required this.feeCents,
    required this.interestCents,
    required this.overdueDays,
    required this.createdAt,
    this.sentAt,
    this.interestRatePercent = 0,
    this.introText,
    this.closingText,
  });
  factory OnlineDunningNotice.fromJson(Map<String, Object?> j) => OnlineDunningNotice(
        id: j['id'] as String,
        level: j['level'] as int,
        invoiceGrossCents: j['invoiceGrossCents'] as int,
        feeCents: j['feeCents'] as int,
        interestCents: j['interestCents'] as int,
        overdueDays: j['overdueDays'] as int,
        createdAt: DateTime.parse(j['createdAt'] as String),
        sentAt: j['sentAt'] == null ? null : DateTime.parse(j['sentAt'] as String),
        interestRatePercent: (j['interestRatePercent'] as num? ?? 0).toDouble(),
        introText: j['introText'] as String?,
        closingText: j['closingText'] as String?,
      );
  final String id;
  final int level;
  final int invoiceGrossCents;
  final int feeCents;
  final int interestCents;
  final int overdueDays;
  final DateTime createdAt;
  final DateTime? sentAt;
  final double interestRatePercent;
  final String? introText;
  final String? closingText;
}

Map<String, Object?> _map(Object? value) => value as Map<String, Object?>;

extension DunningApi on WerkkernApiClient {
  Future<List<OnlineOverdueInvoice>> overdueInvoices() async {
    final j = _map(await request('GET', '/dunning/overdue'));
    return [for (final o in j['overdue'] as List) OnlineOverdueInvoice.fromJson(o as Map<String, Object?>)];
  }

  Future<Map<String, Object?>> dunningSettings() async => _map(await request('GET', '/dunning/settings'));

  Future<void> saveDunningSettings(Map<String, Object?> settings) => request('PUT', '/dunning/settings', body: settings);

  Future<OnlineDunningNotice> createDunningNotice(String documentId) async =>
      OnlineDunningNotice.fromJson(_map(await request('POST', '/documents/$documentId/dunning-notices')));

  Future<List<OnlineDunningNotice>> dunningNotices(String documentId) async {
    final j = _map(await request('GET', '/documents/$documentId/dunning-notices'));
    return [for (final n in j['notices'] as List) OnlineDunningNotice.fromJson(n as Map<String, Object?>)];
  }
}
