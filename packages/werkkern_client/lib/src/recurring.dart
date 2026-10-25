import 'api_client.dart';
import 'fleet.dart' show onlineDate;
import 'models.dart';

/// Wiederkehrende Rechnungen online (C11) — der Server erzeugt fällige
/// Entwürfe täglich selbst.
class OnlineRecurringTemplate {
  const OnlineRecurringTemplate({
    required this.id,
    required this.customerId,
    this.customerName,
    required this.label,
    required this.interval,
    required this.nextDueDate,
    this.paymentTerms,
    this.notes,
    this.active = true,
    this.items = const [],
    this.grossCents = 0,
  });
  factory OnlineRecurringTemplate.fromJson(Map<String, Object?> j) => OnlineRecurringTemplate(
        id: j['id'] as String,
        customerId: j['customerId'] as String,
        customerName: j['customerName'] as String?,
        label: j['label'] as String,
        interval: j['interval'] as String,
        nextDueDate: DateTime.parse(j['nextDueDate'] as String),
        paymentTerms: j['paymentTerms'] as String?,
        notes: j['notes'] as String?,
        active: j['active'] as bool,
        items: [for (final i in (j['items'] as List? ?? const [])) OnlineDocumentItem.fromJson(i as Map<String, Object?>)],
        grossCents: j['grossCents'] as int? ?? 0,
      );
  final String id;
  final String customerId;
  final String? customerName;
  final String label;

  /// `monthly`, `quarterly`, `yearly`.
  final String interval;
  final DateTime nextDueDate;
  final String? paymentTerms;
  final String? notes;
  final bool active;
  final List<OnlineDocumentItem> items;
  final int grossCents;
}

Map<String, Object?> _map(Object? value) => value as Map<String, Object?>;

extension RecurringApi on WerkkernApiClient {
  Future<List<OnlineRecurringTemplate>> recurringTemplates({bool includeInactive = false}) async {
    final j = _map(await request('GET', '/recurring-templates', query: {if (includeInactive) 'includeInactive': 'true'}));
    return [for (final t in j['templates'] as List) OnlineRecurringTemplate.fromJson(t as Map<String, Object?>)];
  }

  Future<OnlineRecurringTemplate> recurringTemplate(String id) async =>
      OnlineRecurringTemplate.fromJson(_map(await request('GET', '/recurring-templates/$id')));

  Future<OnlineRecurringTemplate> saveRecurringTemplate({
    String? id,
    required String customerId,
    required String label,
    required String interval,
    required DateTime nextDueDate,
    String? paymentTerms,
    String? notes,
    bool active = true,
    required List<OnlineDocumentItem> items,
  }) async {
    final body = {
      'customerId': customerId,
      'label': label,
      'interval': interval,
      'nextDueDate': onlineDate(nextDueDate),
      'paymentTerms': paymentTerms,
      'notes': notes,
      'active': active,
      'items': [for (final i in items) i.toJson()],
    };
    return OnlineRecurringTemplate.fromJson(_map(id == null
        ? await request('POST', '/recurring-templates', body: body)
        : await request('PUT', '/recurring-templates/$id', body: body)));
  }

  Future<void> deleteRecurringTemplate(String id) => request('DELETE', '/recurring-templates/$id');

  /// Fällige Entwürfe der Firma sofort erzeugen; liefert die Anzahl.
  Future<int> generateRecurringNow() async => _map(await request('POST', '/recurring-templates/generate'))['created'] as int;
}
