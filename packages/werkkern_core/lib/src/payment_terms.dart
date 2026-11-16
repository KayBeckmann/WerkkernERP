/// A2-Nachtrag (Kay, 15./16.11.2026): Zahlungsbedingungen und optionales
/// Skonto — gemeinsamer Rechenkern für App, PDF, E-Rechnung und Server.
library;

import 'package:decimal/decimal.dart';

import 'money.dart';

/// Vorgaben je neuer Firma: „Sofort netto“ heißt sofort fällig **ohne
/// Abzug**, nicht „Nettopreis plus Umsatzsteuer“.
const defaultPaymentTermPresets = <({String label, int netDays, bool isDefault})>[
  (label: 'Sofort netto', netDays: 0, isDefault: false),
  (label: '7 Tage', netDays: 7, isDefault: false),
  (label: '14 Tage', netDays: 14, isDefault: true),
  (label: '30 Tage', netDays: 30, isDefault: false),
];

/// Dokumentarten, die Zahlungsbedingung/Skonto vorbelegt bekommen.
bool documentKindUsesPaymentTerms(String kind) => kind == 'invoice' || kind == 'order';

/// Am Beleg festgehaltene Bedingung (Schnappschuss, unabhängig von
/// späteren Stammdatenänderungen).
class DocumentPaymentTerms {
  const DocumentPaymentTerms({required this.label, required this.netDays, this.skontoPercent, this.skontoDays});

  final String label;
  final int netDays;

  /// Beide gesetzt = Skonto gilt; sonst kein Skonto.
  final double? skontoPercent;
  final int? skontoDays;

  bool get hasSkonto => skontoPercent != null && skontoPercent! > 0 && skontoDays != null && skontoDays! >= 0;
}

/// Kundenstandard vor Firmenstandard (Roadmap A2-Nachtrag); `null`, wenn
/// keine Bedingung bekannt ist. [customerSkontoMode]: `company` (Vorgabe
/// der Firma), `none` (kein Skonto), `custom` (eigene Werte am Kunden).
({String? termId, double? skontoPercent, int? skontoDays}) resolvePaymentDefaults({
  String? customerTermId,
  String? companyDefaultTermId,
  String customerSkontoMode = 'company',
  double? customerSkontoPercent,
  int? customerSkontoDays,
  double? companySkontoPercent,
  int? companySkontoDays,
}) {
  final termId = customerTermId ?? companyDefaultTermId;
  return switch (customerSkontoMode) {
    'none' => (termId: termId, skontoPercent: null, skontoDays: null),
    'custom' => (termId: termId, skontoPercent: customerSkontoPercent, skontoDays: customerSkontoDays),
    _ => (termId: termId, skontoPercent: companySkontoPercent, skontoDays: companySkontoDays),
  };
}

DateTime _addDays(DateTime date, int days) => DateTime(date.year, date.month, date.day + days);

/// Fälligkeit = Belegdatum + Zahlungsziel.
DateTime paymentDueDate(DateTime issueDate, DocumentPaymentTerms terms) => _addDays(issueDate, terms.netDays);

/// Ende der Skontofrist, `null` ohne Skonto.
DateTime? skontoDueDate(DateTime issueDate, DocumentPaymentTerms terms) =>
    terms.hasSkonto ? _addDays(issueDate, terms.skontoDays!) : null;

/// Skonto-Grundlage (Kay-Entscheidung 2026-11-16): ohne § 19 die
/// **Nettosumme**, mit § 19 die **Bruttosumme** (dort identisch mit netto).
/// Bei Schlussrechnungen mit Abschlägen anteilig auf den noch offenen
/// Betrag: Grundlage × Restbetrag ÷ Bruttosumme (Arbeitsentscheidung).
Money skontoBase({
  required Money net,
  required Money gross,
  required bool smallBusinessExempt,
  Money? payable,
}) {
  final base = smallBusinessExempt ? gross : net;
  if (payable == null || payable.cents == gross.cents || gross.cents == 0) return base;
  final ratio = Decimal.fromInt(payable.cents) / Decimal.fromInt(gross.cents);
  return Money.fromCents(
    (Decimal.fromInt(base.cents) * ratio.toDecimal(scaleOnInfinitePrecision: 10)).round().toBigInt().toInt(),
  );
}

/// Skontobetrag = Grundlage × Satz, kaufmännisch auf den Cent.
Money skontoAmount(Money base, double percent) => base.applyPercent(percent);

/// Zusammenfassung für PDF, Editor und E-Rechnung.
class PaymentTermsSummary {
  const PaymentTermsSummary({
    required this.dueDate,
    required this.payable,
    this.skontoDate,
    this.skontoBase,
    this.skontoAmount,
    this.skontoPercent,
    required this.smallBusinessExempt,
  });
  final DateTime dueDate;
  final Money payable;
  final DateTime? skontoDate;
  final Money? skontoBase;
  final Money? skontoAmount;
  final double? skontoPercent;
  final bool smallBusinessExempt;

  Money? get payableWithSkonto => skontoAmount == null ? null : payable - skontoAmount!;
}

PaymentTermsSummary summarizePaymentTerms({
  required DocumentPaymentTerms terms,
  required DateTime issueDate,
  required Money net,
  required Money gross,
  Money? payable,
  required bool smallBusinessExempt,
}) {
  final toPay = payable ?? gross;
  final base = terms.hasSkonto
      ? skontoBase(net: net, gross: gross, smallBusinessExempt: smallBusinessExempt, payable: toPay)
      : null;
  return PaymentTermsSummary(
    dueDate: paymentDueDate(issueDate, terms),
    payable: toPay,
    skontoDate: skontoDueDate(issueDate, terms),
    skontoBase: base,
    skontoAmount: base == null ? null : skontoAmount(base, terms.skontoPercent!),
    skontoPercent: terms.hasSkonto ? terms.skontoPercent : null,
    smallBusinessExempt: smallBusinessExempt,
  );
}

String _date(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

String _percent(double p) => p == p.roundToDouble() ? p.toStringAsFixed(0) : p.toString().replaceAll('.', ',');

/// Text für Beleg und E-Rechnung, z. B. „Zahlbar innerhalb von 14 Tagen
/// bis 30.11.2026 ohne Abzug. Bei Zahlung bis 23.11.2026 2 % Skonto auf
/// den Nettobetrag (2,44 €), zu zahlen 142,56 €.“
String paymentTermsText(DocumentPaymentTerms terms, PaymentTermsSummary s) {
  final main = terms.netDays == 0
      ? 'Zahlbar sofort ohne Abzug.'
      : 'Zahlbar innerhalb von ${terms.netDays} Tagen bis ${_date(s.dueDate)} ohne Abzug.';
  if (s.skontoAmount == null) return main;
  final basis = s.smallBusinessExempt ? 'den Rechnungsbetrag' : 'den Nettobetrag';
  return '$main Bei Zahlung bis ${_date(s.skontoDate!)} ${_percent(s.skontoPercent!)} % Skonto auf $basis '
      '(${s.skontoAmount}), zu zahlen ${s.payableWithSkonto}.';
}

/// XRechnung-Skonto-Zeile (BT-20, Format der KoSIT):
/// `#SKONTO#TAGE=7#PROZENT=2.00#BASISBETRAG=121.88#` + Zeilenumbruch.
String xrechnungSkontoLine(PaymentTermsSummary s, int skontoDays) {
  final cents = s.skontoBase!.cents;
  final base = '${cents ~/ 100}.${(cents % 100).toString().padLeft(2, '0')}';
  return '#SKONTO#TAGE=$skontoDays#PROZENT=${s.skontoPercent!.toStringAsFixed(2)}#BASISBETRAG=$base#\n';
}
