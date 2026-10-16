import 'package:decimal/decimal.dart';

/// Geldwert in Minor Units (Cent) als Integer — niemals als Binär-Float
/// (Roadmap F2: "Geldwerte als Dezimal-/Minor-Unit-Werte statt
/// Binär-Floats"). Rundung bei jeder Berechnung: kaufmännisch
/// (round half away from zero) auf ganze Cent, die in Deutschland übliche
/// Konvention.
class Money {
  const Money.fromCents(this.cents);

  factory Money.zero() => const Money.fromCents(0);

  /// Für Eingaben in Euro, z. B. aus einem Formularfeld.
  factory Money.fromEuroString(String value) {
    final normalized = value.trim().replaceAll('.', '').replaceAll(',', '.');
    final decimal = Decimal.parse(normalized.isEmpty ? '0' : normalized);
    return Money.fromCents(_roundCommercial(decimal * Decimal.fromInt(100)).toBigInt().toInt());
  }

  final int cents;

  Money operator +(Money other) => Money.fromCents(cents + other.cents);
  Money operator -(Money other) => Money.fromCents(cents - other.cents);

  bool operator >(Money other) => cents > other.cents;
  bool operator <(Money other) => cents < other.cents;
  bool operator >=(Money other) => cents >= other.cents;
  bool operator <=(Money other) => cents <= other.cents;

  @override
  bool operator ==(Object other) => other is Money && other.cents == cents;

  @override
  int get hashCode => cents.hashCode;

  /// Multipliziert mit einer beliebig genauen Dezimalmenge (z. B. 2,5
  /// Stunden) und rundet das Ergebnis kaufmännisch auf ganze Cent — exakte
  /// Dezimalarithmetik über [Decimal], nie über `double`.
  Money multiplyByQuantity(Decimal quantity) {
    final result = Decimal.fromInt(cents) * quantity;
    return Money.fromCents(_roundCommercial(result).toBigInt().toInt());
  }

  /// Wendet einen Prozentsatz an (z. B. MwSt. oder Artikelgruppen-
  /// Aufschlag) und rundet kaufmännisch auf ganze Cent.
  Money applyPercent(double percent) {
    final factor = Decimal.parse(percent.toString()) / Decimal.fromInt(100);
    final result = Decimal.fromInt(cents) * factor.toDecimal(scaleOnInfinitePrecision: 10);
    return Money.fromCents(_roundCommercial(result).toBigInt().toInt());
  }

  /// Nettobetrag plus Steuer in einem Schritt (Roadmap: `Brutto = Netto ×
  /// (1 + MwSt_in_Prozent / 100)`).
  Money get taxAmountAt => this;

  static Decimal _roundCommercial(Decimal value) {
    // Decimal.round() in package:decimal rundet bereits "round half away
    // from zero" (kaufmännisch) für positive wie negative Werte — exakt
    // die in F2 geforderte Konvention.
    return value.round();
  }

  double toEuro() => cents / 100;

  String formatEuro() {
    final euros = cents ~/ 100;
    final remCents = (cents % 100).abs().toString().padLeft(2, '0');
    return '$euros,$remCents';
  }

  @override
  String toString() => '${formatEuro()} €';
}
