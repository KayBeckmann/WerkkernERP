import 'package:csv/csv.dart';
import 'package:intl/intl.dart';

import '../../data/database/database.dart';
import '../models/money.dart';

/// C14.4 Bankabgleich per CSV (Kay-Priorisierungsentscheidung
/// 2026-10-18: CSV statt MT940). Reine, datenbankfreie Parsing-Logik —
/// gleiches Trennungsprinzip wie überall in diesem Verzeichnis. Jede
/// Bank hat ein eigenes CSV-Spaltenschema, deshalb eine konfigurierbare
/// Spaltenzuordnung ([BankCsvMapping]) statt eines bankspezifischen
/// Parsers.
class BankCsvMapping {
  const BankCsvMapping({
    required this.delimiter,
    required this.hasHeaderRow,
    required this.dateColumn,
    required this.amountColumn,
    this.purposeColumn,
    this.counterpartyColumn,
    required this.dateFormat,
    required this.decimalSeparator,
  });

  factory BankCsvMapping.fromCompany(Company company) => BankCsvMapping(
        delimiter: company.bankCsvDelimiter,
        hasHeaderRow: company.bankCsvHasHeaderRow,
        dateColumn: company.bankCsvDateColumn ?? '',
        amountColumn: company.bankCsvAmountColumn ?? '',
        purposeColumn: company.bankCsvPurposeColumn,
        counterpartyColumn: company.bankCsvCounterpartyColumn,
        dateFormat: company.bankCsvDateFormat,
        decimalSeparator: company.bankCsvDecimalSeparator,
      );

  /// Spaltentrennzeichen (meist `;` bei deutschen Bank-Exporten).
  final String delimiter;

  /// `true`: Spalten werden über die Kopfzeile per Name referenziert.
  /// `false`: Spalten werden über einen nullbasierten Index referenziert.
  final bool hasHeaderRow;

  /// Spaltenname (bei [hasHeaderRow]) oder -index (als Text) für Datum
  /// bzw. Betrag.
  final String dateColumn;
  final String amountColumn;
  final String? purposeColumn;
  final String? counterpartyColumn;

  /// `intl`-Musterformat, z. B. `dd.MM.yyyy`.
  final String dateFormat;

  /// `,` oder `.` als Dezimaltrenner im Betragsfeld.
  final String decimalSeparator;

  bool get isComplete => dateColumn.isNotEmpty && amountColumn.isNotEmpty;
}

class ParsedBankTransaction {
  const ParsedBankTransaction({
    required this.date,
    required this.amountCents,
    this.purpose,
    this.counterparty,
    required this.importHash,
  });
  final DateTime date;
  final int amountCents;
  final String? purpose;
  final String? counterparty;
  final String importHash;
}

class BankCsvParseError {
  const BankCsvParseError({required this.rowNumber, required this.message});

  /// 1-basiert, bezogen auf die Datenzeilen (ohne Kopfzeile) — so, wie
  /// Kay die Zeile in seinem Tabellenprogramm wiederfinden würde.
  final int rowNumber;
  final String message;
}

class BankCsvParseResult {
  const BankCsvParseResult({required this.transactions, required this.errors});
  final List<ParsedBankTransaction> transactions;
  final List<BankCsvParseError> errors;
}

/// Berechnet einen stabilen Hash aus den fachlich relevanten Feldern —
/// Grundlage der Duplikat-Erkennung beim erneuten Import derselben
/// Export-Datei (siehe Doc-Kommentar bei `BankTransactions` in
/// tables.dart). Bewusst kein kryptographischer Hash nötig, nur
/// Eindeutigkeit innerhalb einer Firma.
String computeBankTransactionHash({
  required DateTime date,
  required int amountCents,
  String? purpose,
  String? counterparty,
}) =>
    '${date.toIso8601String()}|$amountCents|${purpose ?? ''}|${counterparty ?? ''}';

Money _parseAmount(String raw, String decimalSeparator) {
  var normalized = raw.trim().replaceAll(RegExp(r'[^0-9,.\-]'), '');
  if (decimalSeparator == '.') {
    // US-/englische Konvention (Punkt=Dezimal, Komma=Tausender) auf
    // `Money.fromEuroString()`s deutsche Konvention ummünzen, statt die
    // Rundungslogik dort zu duplizieren.
    normalized = normalized
        .replaceAll('.', '\u0000')
        .replaceAll(',', '.')
        .replaceAll('\u0000', ',');
  }
  return Money.fromEuroString(normalized);
}

/// Parst den vollständigen CSV-Text gemäß [mapping]. Einzelne fehler-
/// hafte Zeilen brechen den Import nicht ab (A3-Prinzip: ein Fehler
/// darf nicht stillschweigend alles verschlucken) — sie landen in
/// [BankCsvParseResult.errors], alle übrigen Zeilen werden trotzdem
/// übernommen.
BankCsvParseResult parseBankCsv(String csvText, BankCsvMapping mapping) {
  final csv = Csv(fieldDelimiter: mapping.delimiter, autoDetect: false);
  final transactions = <ParsedBankTransaction>[];
  final errors = <BankCsvParseError>[];

  if (mapping.hasHeaderRow) {
    final rows = csv.decodeWithHeaders(csvText);
    for (var i = 0; i < rows.length; i++) {
      final result = _parseRow(
        rawDate: rows[i][mapping.dateColumn]?.toString(),
        rawAmount: rows[i][mapping.amountColumn]?.toString(),
        rawPurpose: mapping.purposeColumn == null ? null : rows[i][mapping.purposeColumn!]?.toString(),
        rawCounterparty: mapping.counterpartyColumn == null
            ? null
            : rows[i][mapping.counterpartyColumn!]?.toString(),
        mapping: mapping,
      );
      result.fold(transactions.add, (message) => errors.add(BankCsvParseError(rowNumber: i + 1, message: message)));
    }
  } else {
    final rows = csv.decode(csvText);
    final dateIndex = int.tryParse(mapping.dateColumn);
    final amountIndex = int.tryParse(mapping.amountColumn);
    final purposeIndex = mapping.purposeColumn == null ? null : int.tryParse(mapping.purposeColumn!);
    final counterpartyIndex =
        mapping.counterpartyColumn == null ? null : int.tryParse(mapping.counterpartyColumn!);
    for (var i = 0; i < rows.length; i++) {
      if (dateIndex == null || amountIndex == null) {
        errors.add(const BankCsvParseError(rowNumber: 0, message: 'Spaltenindizes sind ungültig.'));
        break;
      }
      final row = rows[i];
      final result = _parseRow(
        rawDate: dateIndex < row.length ? row[dateIndex]?.toString() : null,
        rawAmount: amountIndex < row.length ? row[amountIndex]?.toString() : null,
        rawPurpose: purposeIndex != null && purposeIndex < row.length ? row[purposeIndex]?.toString() : null,
        rawCounterparty: counterpartyIndex != null && counterpartyIndex < row.length
            ? row[counterpartyIndex]?.toString()
            : null,
        mapping: mapping,
      );
      result.fold(transactions.add, (message) => errors.add(BankCsvParseError(rowNumber: i + 1, message: message)));
    }
  }

  return BankCsvParseResult(transactions: transactions, errors: errors);
}

/// Gibt entweder eine erfolgreich geparste Transaktion ODER eine
/// Fehlermeldung zurück — modelliert hier bewusst ohne eigenen
/// Ergebnistyp (`Either`/Sealed Class gibt es in diesem Projekt bisher
/// nicht), stattdessen ein einfacher `fold`-Callback-Helfer.
_RowResult _parseRow({
  required String? rawDate,
  required String? rawAmount,
  required String? rawPurpose,
  required String? rawCounterparty,
  required BankCsvMapping mapping,
}) {
  if (rawDate == null || rawDate.trim().isEmpty) {
    return const _RowResult.error('Kein Datum in der konfigurierten Spalte gefunden.');
  }
  if (rawAmount == null || rawAmount.trim().isEmpty) {
    return const _RowResult.error('Kein Betrag in der konfigurierten Spalte gefunden.');
  }
  DateTime date;
  try {
    date = DateFormat(mapping.dateFormat).parseStrict(rawDate.trim());
  } catch (_) {
    return _RowResult.error('Datum "$rawDate" passt nicht zum Format "${mapping.dateFormat}".');
  }
  Money amount;
  try {
    amount = _parseAmount(rawAmount, mapping.decimalSeparator);
  } catch (_) {
    return _RowResult.error('Betrag "$rawAmount" konnte nicht gelesen werden.');
  }
  final purpose = rawPurpose?.trim().isEmpty ?? true ? null : rawPurpose!.trim();
  final counterparty = rawCounterparty?.trim().isEmpty ?? true ? null : rawCounterparty!.trim();
  return _RowResult.ok(
    ParsedBankTransaction(
      date: date,
      amountCents: amount.cents,
      purpose: purpose,
      counterparty: counterparty,
      importHash: computeBankTransactionHash(
        date: date,
        amountCents: amount.cents,
        purpose: purpose,
        counterparty: counterparty,
      ),
    ),
  );
}

class _RowResult {
  const _RowResult.ok(ParsedBankTransaction transaction)
      : _transaction = transaction,
        _error = null;
  const _RowResult.error(String message)
      : _transaction = null,
        _error = message;

  final ParsedBankTransaction? _transaction;
  final String? _error;

  T fold<T>(T Function(ParsedBankTransaction) onOk, T Function(String) onError) =>
      _transaction != null ? onOk(_transaction) : onError(_error!);
}
