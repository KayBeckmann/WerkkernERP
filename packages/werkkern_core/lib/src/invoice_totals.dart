import 'package:decimal/decimal.dart';

import 'money.dart';

/// Eine einzelne Position für die Summenberechnung — bewusst von der
/// Drift-Zeile entkoppelt, damit der reine Rechenkern ohne Datenbank
/// testbar bleibt.
class InvoiceLineInput {
  const InvoiceLineInput({
    required this.quantity,
    required this.unitPriceCents,
    required this.vatRatePercent,
    this.discountPercent = 0,
  });

  final Decimal quantity;
  final int unitPriceCents;
  final double vatRatePercent;

  /// Rabatt in Prozent auf diese Position (Kay-Nachtrag 2026-10-16).
  /// Wird auf den Netto-Betrag **vor** der Steuerberechnung angewendet
  /// — Steuer wird also auf den bereits rabattierten Betrag berechnet,
  /// nicht auf den vollen Betrag mit nachträglichem Steuerabzug (das
  /// wäre bei unterschiedlichen Rabatt-/Steuersätzen nicht äquivalent).
  final double discountPercent;

  Money get lineGrossBeforeDiscount =>
      Money.fromCents(unitPriceCents).multiplyByQuantity(quantity);

  Money get lineNet => discountPercent == 0
      ? lineGrossBeforeDiscount
      : lineGrossBeforeDiscount - lineGrossBeforeDiscount.applyPercent(discountPercent);
}

/// Summen einer Rechnung, **je Steuersatz aufgeschlüsselt** (F1-
/// Pflichtangabe: "Entgelt aufgeschlüsselt nach Steuersätzen"). Die
/// Steuer wird auf die **Netto-Summe je Satz** berechnet, nicht als
/// Summe der einzelnen Positions-Steuerbeträge — das ist die in
/// Deutschland übliche Konvention und vermeidet Rundungsdrift zwischen
/// beiden Rechenwegen (F2).
class InvoiceTotals {
  const InvoiceTotals({required this.netByRate, required this.taxByRate});

  /// Sortierte Steuersätze (z. B. [0, 7, 19]) für eine stabile
  /// Anzeigereihenfolge.
  final Map<double, Money> netByRate;
  final Map<double, Money> taxByRate;

  List<double> get sortedRates => netByRate.keys.toList()..sort();

  Money get totalNet => netByRate.values.fold(Money.zero(), (a, b) => a + b);
  Money get totalTax => taxByRate.values.fold(Money.zero(), (a, b) => a + b);
  Money get totalGross => totalNet + totalTax;
}

InvoiceTotals calculateInvoiceTotals(List<InvoiceLineInput> lines) {
  final netByRate = <double, Money>{};
  for (final line in lines) {
    final existing = netByRate[line.vatRatePercent] ?? Money.zero();
    netByRate[line.vatRatePercent] = existing + line.lineNet;
  }
  final taxByRate = <double, Money>{
    for (final entry in netByRate.entries) entry.key: entry.value.applyPercent(entry.key),
  };
  return InvoiceTotals(netByRate: netByRate, taxByRate: taxByRate);
}
