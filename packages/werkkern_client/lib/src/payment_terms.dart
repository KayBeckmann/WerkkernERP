import 'api_client.dart';

/// A2-Nachtrag (Kay, 15./16.11.2026): Zahlungsbedingung der Firma.
class OnlinePaymentTerm {
  const OnlinePaymentTerm({required this.id, required this.label, required this.netDays, this.isDefault = false});
  factory OnlinePaymentTerm.fromJson(Map<String, Object?> j) => OnlinePaymentTerm(
        id: j['id'] as String,
        label: j['label'] as String,
        netDays: j['netDays'] as int,
        isDefault: j['isDefault'] as bool? ?? false,
      );
  final String id;
  final String label;
  final int netDays;
  final bool isDefault;
}

/// Zahlungsbedingung am Beleg (Schnappschuss).
class OnlineDocumentTerms {
  const OnlineDocumentTerms({this.termId, required this.label, required this.netDays, this.skontoPercent, this.skontoDays});
  factory OnlineDocumentTerms.fromJson(Map<String, Object?> j) => OnlineDocumentTerms(
        termId: j['termId'] as String?,
        label: j['label'] as String,
        netDays: j['netDays'] as int,
        skontoPercent: (j['skontoPercent'] as num?)?.toDouble(),
        skontoDays: j['skontoDays'] as int?,
      );
  final String? termId;
  final String label;
  final int netDays;
  final double? skontoPercent;
  final int? skontoDays;

  Map<String, Object?> toJson() => {
        'termId': termId,
        'label': label,
        'netDays': netDays,
        'skontoPercent': skontoPercent,
        'skontoDays': skontoDays,
      };
}

extension PaymentTermApi on WerkkernApiClient {
  Future<List<OnlinePaymentTerm>> paymentTerms() async {
    final j = await request('GET', '/payment-terms') as Map<String, Object?>;
    return [for (final t in j['paymentTerms'] as List) OnlinePaymentTerm.fromJson(t as Map<String, Object?>)];
  }

  Future<OnlinePaymentTerm> savePaymentTerm({String? id, required String label, required int netDays}) async =>
      OnlinePaymentTerm.fromJson(await request(id == null ? 'POST' : 'PUT', id == null ? '/payment-terms' : '/payment-terms/$id',
          body: {'label': label, 'netDays': netDays}) as Map<String, Object?>);

  Future<void> setDefaultPaymentTerm(String id) => request('PUT', '/payment-terms/$id/default', body: const {});

  Future<void> deletePaymentTerm(String id) => request('DELETE', '/payment-terms/$id');
}
