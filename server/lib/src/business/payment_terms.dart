/// A2-Nachtrag (Kay, 15./16.11.2026): Zahlungsbedingungen je Firma online
/// (wie offline `PaymentTerms`). Genau eine ist Firmenstandard.
library;

class PaymentTerm {
  const PaymentTerm({
    required this.id,
    required this.companyId,
    required this.label,
    required this.netDays,
    this.isDefault = false,
    this.sortOrder = 0,
  });
  final String id;
  final String companyId;
  final String label;
  final int netDays;
  final bool isDefault;
  final int sortOrder;

  PaymentTerm copyWith({String? label, int? netDays, bool? isDefault}) => PaymentTerm(
        id: id,
        companyId: companyId,
        label: label ?? this.label,
        netDays: netDays ?? this.netDays,
        isDefault: isDefault ?? this.isDefault,
        sortOrder: sortOrder,
      );

  Map<String, Object?> toJson() => {'id': id, 'label': label, 'netDays': netDays, 'isDefault': isDefault};
}

abstract interface class PaymentTermStore {
  Future<List<PaymentTerm>> listPaymentTerms(String companyId);
  Future<void> savePaymentTerm(PaymentTerm term);

  /// Setzt [id] als einzigen Standard der Firma.
  Future<void> setDefaultPaymentTerm(String companyId, String id);

  /// Kunden verlieren die Zuordnung; Belege behalten ihren Schnappschuss.
  Future<bool> deletePaymentTerm(String companyId, String id);
}
