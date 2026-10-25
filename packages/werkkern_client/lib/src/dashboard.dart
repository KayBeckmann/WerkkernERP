import 'api_client.dart';

/// Dashboard-Kachel (Werte je nach Art: count, amountCents, value).
class OnlineDashboardTile {
  const OnlineDashboardTile({required this.key, required this.title, this.count, this.amountCents, this.value, this.detail});
  factory OnlineDashboardTile.fromJson(Map<String, Object?> j) => OnlineDashboardTile(
        key: j['key'] as String,
        title: j['title'] as String,
        count: j['count'] as int?,
        amountCents: j['amountCents'] as int?,
        value: j['value'] as String?,
        detail: j['detail'] as String?,
      );
  final String key;
  final String title;
  final int? count;
  final int? amountCents;
  final String? value;
  final String? detail;
}

typedef OnlineDashboard = ({List<OnlineDashboardTile> tiles, List<String> available, List<String> hidden});

extension DashboardApi on WerkkernApiClient {
  Future<OnlineDashboard> dashboard() async {
    final j = await request('GET', '/dashboard') as Map<String, Object?>;
    return (
      tiles: [for (final t in j['tiles'] as List) OnlineDashboardTile.fromJson(t as Map<String, Object?>)],
      available: (j['available'] as List).cast<String>(),
      hidden: (j['hidden'] as List).cast<String>(),
    );
  }

  Future<void> setDashboardHidden(List<String> hidden) => request('PUT', '/dashboard/preferences', body: {'hidden': hidden});
}
