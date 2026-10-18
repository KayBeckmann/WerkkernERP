import 'package:flutter_test/flutter_test.dart';
import 'package:werkkernerp/domain/services/bank_csv_import_service.dart';

/// C14.4 Bankabgleich per CSV (Kay-Priorisierungsentscheidung
/// 2026-10-18: CSV statt MT940, mit konfigurierbarer Spaltenzuordnung).
void main() {
  const germanMapping = BankCsvMapping(
    delimiter: ';',
    hasHeaderRow: true,
    dateColumn: 'Buchungstag',
    amountColumn: 'Betrag',
    purposeColumn: 'Verwendungszweck',
    counterpartyColumn: 'Auftraggeber',
    dateFormat: 'dd.MM.yyyy',
    decimalSeparator: ',',
  );

  test('parst eine typische deutsche Bank-CSV mit Kopfzeile vollständig', () {
    const csvText = 'Buchungstag;Betrag;Verwendungszweck;Auftraggeber\n'
        '15.10.2026;1.234,56;Rechnung R-26001;Testkunde GmbH\n'
        '16.10.2026;-59,50;Materialkauf;Elektrogrosshandel';

    final result = parseBankCsv(csvText, germanMapping);

    expect(result.errors, isEmpty);
    expect(result.transactions, hasLength(2));
    expect(result.transactions[0].date, DateTime(2026, 10, 15));
    expect(result.transactions[0].amountCents, 123456);
    expect(result.transactions[0].purpose, 'Rechnung R-26001');
    expect(result.transactions[0].counterparty, 'Testkunde GmbH');
    expect(result.transactions[1].amountCents, -5950);
  });

  test('Spaltenindex statt Kopfzeile funktioniert ebenfalls', () {
    const mapping = BankCsvMapping(
      delimiter: ',',
      hasHeaderRow: false,
      dateColumn: '0',
      amountColumn: '1',
      dateFormat: 'yyyy-MM-dd',
      decimalSeparator: '.',
    );
    const csvText = '2026-10-15,1234.56\n2026-10-16,-59.50';

    final result = parseBankCsv(csvText, mapping);

    expect(result.errors, isEmpty);
    expect(result.transactions, hasLength(2));
    expect(result.transactions[0].amountCents, 123456);
    expect(result.transactions[1].amountCents, -5950);
  });

  test('eine fehlerhafte Zeile bricht den Import nicht ab — andere Zeilen werden trotzdem übernommen', () {
    const csvText = 'Buchungstag;Betrag;Verwendungszweck;Auftraggeber\n'
        'kein-datum;1.234,56;Rechnung;Testkunde\n'
        '16.10.2026;-59,50;Material;Grosshandel';

    final result = parseBankCsv(csvText, germanMapping);

    expect(result.transactions, hasLength(1));
    expect(result.transactions.single.amountCents, -5950);
    expect(result.errors, hasLength(1));
    expect(result.errors.single.rowNumber, 1);
  });

  test('fehlender Betrag erzeugt einen Fehler statt eines falschen Werts', () {
    const csvText = 'Buchungstag;Betrag;Verwendungszweck;Auftraggeber\n'
        '15.10.2026;;Rechnung;Testkunde';

    final result = parseBankCsv(csvText, germanMapping);

    expect(result.transactions, isEmpty);
    expect(result.errors.single.message, contains('Betrag'));
  });

  test('zwei Zeilen mit identischen Werten erzeugen denselben importHash — Grundlage der Duplikat-Erkennung', () {
    const csvText = 'Buchungstag;Betrag;Verwendungszweck;Auftraggeber\n'
        '15.10.2026;100,00;Test;Kunde\n'
        '15.10.2026;100,00;Test;Kunde';

    final result = parseBankCsv(csvText, germanMapping);

    expect(result.transactions[0].importHash, result.transactions[1].importHash);
  });

  test('BankCsvMapping.isComplete prüft Datum- und Betragsspalte', () {
    expect(germanMapping.isComplete, isTrue);
    const incomplete = BankCsvMapping(
      delimiter: ';',
      hasHeaderRow: true,
      dateColumn: '',
      amountColumn: 'Betrag',
      dateFormat: 'dd.MM.yyyy',
      decimalSeparator: ',',
    );
    expect(incomplete.isComplete, isFalse);
  });
}
