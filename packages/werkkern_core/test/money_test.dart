import 'package:decimal/decimal.dart';
import 'package:test/test.dart';
import 'package:werkkern_core/werkkern_core.dart';

void main() {
  test('Roadmap-Referenzfall: 100 € EK + 30 % Aufschlag = 130 € netto', () {
    final ek = Money.fromCents(10000);
    final aufschlag = ek.applyPercent(30);
    final netto = ek + aufschlag;
    expect(netto, Money.fromCents(13000));
    expect(netto.formatEuro(), '130,00');
  });

  test('MwSt 19% auf 130€ netto ergibt 154,70€ brutto', () {
    final netto = Money.fromCents(13000);
    final steuer = netto.applyPercent(19);
    expect(steuer, Money.fromCents(2470));
    expect((netto + steuer).formatEuro(), '154,70');
  });

  test('0% MwSt ergibt keinen Steuerbetrag', () {
    final netto = Money.fromCents(5000);
    expect(netto.applyPercent(0), Money.zero());
  });

  test('Kaufmännische Rundung: halbe Cent werden von Null weg gerundet', () {
    // 0,005 € * 100 Stück = 0,50 € exakt, aber als Zwischenschritt-Beispiel
    // für Rundung bei ungeraden Centbeträgen: 1 Cent * 2,5 Stk = 2,5 Cent -> 3.
    final unitPrice = Money.fromCents(1);
    final result = unitPrice.multiplyByQuantity(Decimal.parse('2.5'));
    expect(result, Money.fromCents(3));
  });

  test('Einzelpreis * Menge mit Dezimalstunden (F2: keine Binär-Floats)', () {
    final hourlyRate = Money.fromCents(6500); // 65,00 €/h
    final result = hourlyRate.multiplyByQuantity(Decimal.parse('3.25')); // 3,25 h
    expect(result, Money.fromCents(21125)); // 211,25 €
  });

  test('fromEuroString parst deutsche Dezimalschreibweise', () {
    expect(Money.fromEuroString('1.234,56').cents, 123456);
    expect(Money.fromEuroString('0,30').cents, 30);
    expect(Money.fromEuroString('19').cents, 1900);
  });

  test('Negative Beträge behalten ihr Vorzeichen, auch unter 1 €', () {
    expect(const Money.fromCents(-50).formatEuro(), '-0,50');
    expect(const Money.fromCents(-150).formatEuro(), '-1,50');
    expect(const Money.fromCents(-5).toString(), '-0,05 €');
    expect(const Money.fromCents(0).formatEuro(), '0,00');
  });
}
