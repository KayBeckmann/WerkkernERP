import 'package:test/test.dart';
import 'package:werkkern_core/werkkern_core.dart';

void main() {
  test('Enddatum ab Finalisierung, über Monatsgrenze, ohne Uhrzeit', () {
    expect(quoteValidUntil(DateTime(2026, 11, 16, 23, 59), 14), DateTime(2026, 11, 30));
    expect(quoteValidUntil(DateTime(2026, 12, 20), 14), DateTime(2027, 1, 3));
    expect(quoteValidityDaysBetween(DateTime(2026, 11, 16, 15), DateTime(2026, 12, 16)), 30);
  });

  test('Text: finalisiert mit Datum, Entwurf mit Dauer, ohne Frist keiner', () {
    expect(quoteValidityText(days: 14, validUntil: DateTime(2026, 11, 30)), 'Dieses Angebot ist gültig bis 30.11.2026.');
    expect(quoteValidityText(days: 14), 'Dieses Angebot ist 14 Tage ab Ausstellung gültig.');
    expect(quoteValidityText(days: 1), 'Dieses Angebot ist 1 Tag ab Ausstellung gültig.');
    expect(quoteValidityText(), isNull);
    expect(isValidQuoteValidityDays(-1), isFalse);
    expect(isValidQuoteValidityDays(null), isTrue);
  });
}
