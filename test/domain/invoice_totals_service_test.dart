import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:werkkernerp/domain/models/money.dart';
import 'package:werkkernerp/domain/services/invoice_totals_service.dart';

void main() {
  test('A2-Abnahme: drei Positionstypen mit 19/7/0% — Summen je Steuersatz korrekt', () {
    final totals = calculateInvoiceTotals([
      // Artikel: 2 Stk á 130,00 € (19%)
      InvoiceLineInput(
        quantity: Decimal.fromInt(2),
        unitPriceCents: 13000,
        vatRatePercent: 19,
      ),
      // Stunden: 3,25 h á 65,00 € (19%) — dieselbe Satzgruppe, muss addiert werden
      InvoiceLineInput(
        quantity: Decimal.parse('3.25'),
        unitPriceCents: 6500,
        vatRatePercent: 19,
      ),
      // Freitext: 1 Stk á 50,00 € (7%)
      InvoiceLineInput(quantity: Decimal.one, unitPriceCents: 5000, vatRatePercent: 7),
      // 0%-Position
      InvoiceLineInput(quantity: Decimal.one, unitPriceCents: 2000, vatRatePercent: 0),
    ]);

    // Netto je Satz: 19% -> 260,00 + 211,25 = 471,25 €; 7% -> 50,00 €; 0% -> 20,00 €.
    expect(totals.netByRate[19], Money.fromCents(47125));
    expect(totals.netByRate[7], Money.fromCents(5000));
    expect(totals.netByRate[0], Money.fromCents(2000));

    expect(totals.taxByRate[19], Money.fromCents(8954)); // 471,25 * 0,19 = 89,5375 -> 89,54
    expect(totals.taxByRate[7], Money.fromCents(350));
    expect(totals.taxByRate[0], Money.zero());

    expect(totals.totalNet, Money.fromCents(54125));
    expect(totals.totalTax, Money.fromCents(9304));
    expect(totals.totalGross, Money.fromCents(63429));
  });

  test('Leere Rechnung hat Summe null', () {
    final totals = calculateInvoiceTotals([]);
    expect(totals.totalNet, Money.zero());
    expect(totals.totalGross, Money.zero());
    expect(totals.sortedRates, isEmpty);
  });

  test(
    'Kay-Nachtrag 2026-10-16: Rabatt pro Position wirkt auf den Netto-Betrag vor der '
    'Steuerberechnung — 100€ netto, 10% Rabatt, 19% MwSt. -> 90€ netto, 17,10€ Steuer',
    () {
      final totals = calculateInvoiceTotals([
        InvoiceLineInput(
          quantity: Decimal.one,
          unitPriceCents: 10000,
          vatRatePercent: 19,
          discountPercent: 10,
        ),
      ]);
      expect(totals.netByRate[19], Money.fromCents(9000));
      expect(totals.taxByRate[19], Money.fromCents(1710));
      expect(totals.totalGross, Money.fromCents(10710));
    },
  );

  test('Rabatt 0 % (Default) verändert den Betrag nicht', () {
    final line = InvoiceLineInput(quantity: Decimal.one, unitPriceCents: 10000, vatRatePercent: 19);
    expect(line.lineNet, Money.fromCents(10000));
  });

  test('Rabatt wirkt auf mehrere Positionen unabhängig — nur die rabattierte Position sinkt', () {
    final totals = calculateInvoiceTotals([
      InvoiceLineInput(quantity: Decimal.one, unitPriceCents: 10000, vatRatePercent: 19),
      InvoiceLineInput(
        quantity: Decimal.one,
        unitPriceCents: 10000,
        vatRatePercent: 19,
        discountPercent: 50,
      ),
    ]);
    // 100€ ohne Rabatt + 50€ nach 50% Rabatt = 150€ netto in derselben Satzgruppe.
    expect(totals.netByRate[19], Money.fromCents(15000));
  });

  test('sortedRates liefert Sätze aufsteigend für eine stabile Anzeige', () {
    final totals = calculateInvoiceTotals([
      InvoiceLineInput(quantity: Decimal.one, unitPriceCents: 100, vatRatePercent: 19),
      InvoiceLineInput(quantity: Decimal.one, unitPriceCents: 100, vatRatePercent: 0),
      InvoiceLineInput(quantity: Decimal.one, unitPriceCents: 100, vatRatePercent: 7),
    ]);
    expect(totals.sortedRates, [0, 7, 19]);
  });
}
