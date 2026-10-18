import '../../data/database/database.dart';
import '../models/money.dart';

/// C14.5 DATEV-Export (Kay-Priorisierungsentscheidung 2026-10-18,
/// letzter Baustein der vollen Buchhaltung, Kontenrahmen SKR03).
///
/// Exportiert bewusst **nur Belege/Ausgaben**, nicht Rechnungen/
/// Einnahmen — eine Rechnung korrekt zu verbuchen bräuchte
/// Personenkonten (Debitoren) und eine Kontierungslogik, die über das
/// hinausgeht, was diese App ohne echte Rechts-/Fachprüfung behaupten
/// sollte (gleiche Zurückhaltung wie bei den SKR03-Kontonummern in
/// C14.2 — siehe dortigen Doc-Kommentar). Das **BU-Schlüssel**-Feld
/// bleibt deshalb ebenfalls immer leer: welcher Steuerschlüssel richtig
/// ist, hängt von aktuellem Steuerrecht ab, das sich ändern kann — eine
/// hier fest hinterlegte Zahl wäre eine Behauptung, die diese App nicht
/// verantworten kann. Ein leeres BU-Feld ist beim DATEV-Import gültig
/// und wird von Kays Steuerberater ergänzt.
///
/// Format: DATEV EXTF Buchungsstapel, Formatversion 13 (125 Spalten je
/// Buchungszeile), semikolon-getrennt, CRLF-Zeilenenden. Quelle: DATEV-
/// Entwicklerportal-Spezifikation (Header 31 Felder, Buchungssatz 125
/// Felder) — recherchiert und gegen eine veröffentlichte, gepflegte
/// Open-Source-Implementierung (github.com/ledermann/datev)
/// gegengeprüft, **keine eigene Spekulation über das Format**. Die
/// Datei selbst behauptet trotzdem keine Garantie auf fehlerfreien
/// DATEV-Import — das bleibt Kays/seinem Steuerberater vorbehalten zu
/// prüfen.
class DatevExportConfig {
  const DatevExportConfig({
    required this.beraterNummer,
    required this.mandantNummer,
    required this.bankGegenkonto,
    required this.sachkontenlaenge,
    required this.companyName,
  });

  factory DatevExportConfig.fromCompany(Company company) => DatevExportConfig(
        beraterNummer: company.datevBeraterNummer ?? '',
        mandantNummer: company.datevMandantNummer ?? '',
        bankGegenkonto: company.datevBankGegenkonto ?? '',
        sachkontenlaenge: company.datevSachkontenlaenge,
        companyName: company.name,
      );

  final String beraterNummer;
  final String mandantNummer;
  final String bankGegenkonto;
  final int sachkontenlaenge;
  final String companyName;

  bool get isComplete =>
      beraterNummer.isNotEmpty && mandantNummer.isNotEmpty && bankGegenkonto.isNotEmpty;
}

/// Ergebnis eines Exportversuchs — Belege ohne zugewiesenes SKR03-Konto
/// können nicht korrekt verbucht werden und werden **nicht** exportiert
/// (lieber fehlend als falsch), landen stattdessen in [skippedExpenses]
/// (A3-Prinzip: ein Fehler/eine Lücke darf nicht stillschweigend
/// übergangen werden).
class DatevExportResult {
  const DatevExportResult({required this.csvContent, required this.exportedCount, required this.skippedExpenses});
  final String csvContent;
  final int exportedCount;
  final List<Expense> skippedExpenses;
}

const List<String> _bookingColumnHeaders = [
  'Umsatz (ohne Soll/Haben-Kz)',
  'Soll/Haben-Kennzeichen',
  'WKZ Umsatz',
  'Kurs',
  'Basisumsatz',
  'WKZ Basisumsatz',
  'Konto',
  'Gegenkonto (ohne BU-Schlüssel)',
  'BU-Schlüssel',
  'Belegdatum',
  'Belegfeld 1',
  'Belegfeld 2',
  'Skonto',
  'Buchungstext',
];

/// Nur die ersten 14 (inhaltlich genutzten) Spalten tragen einen Namen
/// — die Spalten 15–125 bleiben nach DATEV-Spezifikation ungenutzt für
/// diesen einfachen Belege-Export, müssen aber als leere Felder
/// vorhanden sein, damit die Datei exakt 125 Spalten je Zeile hat.
const int _totalBookingColumns = 125;

String _escapeField(String value) {
  final needsQuoting = value.contains(';') || value.contains('"') || value.contains('\n');
  if (!needsQuoting) return value;
  return '"${value.replaceAll('"', '""')}"';
}

String _formatAmount(Money money) {
  // DATEV erwartet den Betrag OHNE Vorzeichen (Vorzeichen kommt über
  // Soll/Haben-Kennzeichen) und mit Komma als Dezimaltrenner.
  final cents = money.cents.abs();
  final euros = cents ~/ 100;
  final remCents = (cents % 100).toString().padLeft(2, '0');
  return '$euros,$remCents';
}

String _truncate(String value, int maxLength) => value.length <= maxLength ? value : value.substring(0, maxLength);

/// Baut den vollständigen DATEV-EXTF-Buchungsstapel für die
/// übergebenen Belege. `periodStart`/`periodEnd` bestimmen sowohl den
/// im Header angegebenen Zeitraum als auch das Wirtschaftsjahr-Beginn-
/// Feld (vereinfachend: Jahresanfang von `periodStart`).
DatevExportResult buildDatevBuchungsstapel({
  required List<Expense> expenses,
  required Map<String, ExpenseCategory> categoryById,
  required DatevExportConfig config,
  required DateTime periodStart,
  required DateTime periodEnd,
  required DateTime generatedAt,
}) {
  final included = <Expense>[];
  final skipped = <Expense>[];
  for (final expense in expenses) {
    final account = expense.categoryId == null ? null : categoryById[expense.categoryId]?.skr03Account;
    if (account == null || account.isEmpty) {
      skipped.add(expense);
    } else {
      included.add(expense);
    }
  }

  // WJ-Beginn/Datum vom/Datum bis im Header sind yyyyMMdd (nicht
  // ddMMyyyy!) — nur das Belegdatum JE BUCHUNG ist TTMM ohne Jahr
  // (direkt unten in der Zeilen-Schleife), beides nach der
  // recherchierten DATEV-Spezifikation (siehe Klassendoc).
  String yyyymmdd(DateTime d) =>
      '${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';
  String yyyymmddhhmmssfff(DateTime d) =>
      '${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}'
      '${d.hour.toString().padLeft(2, '0')}${d.minute.toString().padLeft(2, '0')}'
      '${d.second.toString().padLeft(2, '0')}000';

  final fiscalYearStart = DateTime(periodStart.year, 1, 1);
  final headerFields = <String>[
    'EXTF', // 1 Kennzeichen
    '700', // 2 Versionsnummer
    '21', // 3 Datenkategorie (21 = Buchungsstapel)
    'Buchungsstapel', // 4 Formatname
    '13', // 5 Formatversion
    yyyymmddhhmmssfff(generatedAt), // 6 Erzeugt am
    '', // 7 Importiert
    'WK', // 8 Herkunft-Kennzeichen (eigene Wahl, nicht offiziell bei DATEV registriert)
    'WerkkernERP', // 9 Exportiert von
    '', // 10 Importiert von
    config.beraterNummer, // 11 Berater
    config.mandantNummer, // 12 Mandant
    yyyymmdd(fiscalYearStart), // 13 WJ-Beginn
    config.sachkontenlaenge.toString(), // 14 Sachkontenlänge
    yyyymmdd(periodStart), // 15 Datum vom
    yyyymmdd(periodEnd), // 16 Datum bis
    'Belege ${config.companyName}', // 17 Bezeichnung
    '', // 18 Diktatkürzel
    '1', // 19 Buchungstyp (1 = Finanzbuchführung)
    '', // 20 Rechnungslegungszweck
    '', // 21 Festschreibung
    'EUR', // 22 WKZ
    '', // 23 reserviert
    '', // 24 Derivatskennzeichen
    '', // 25 reserviert 2
    '', // 26 reserviert 3
    '03', // 27 SKR (SKR03, Kay-Entscheidung 2026-10-18)
    '', // 28 Branchenlösung-Id
    '', // 29 reserviert 4
    '', // 30 reserviert 5
    '', // 31 Anwendungsinformation
  ];

  final lines = <String>[
    headerFields.map(_escapeField).join(';'),
    [
      ..._bookingColumnHeaders,
      for (var i = _bookingColumnHeaders.length; i < _totalBookingColumns; i++) '',
    ].map(_escapeField).join(';'),
  ];

  for (final expense in included) {
    final account = categoryById[expense.categoryId]!.skr03Account!;
    final row = <String>[
      _formatAmount(Money.fromCents(expense.amountGrossCents)), // 1 Umsatz
      'S', // 2 Soll/Haben — Ausgabe wird auf das Aufwandskonto im Soll gebucht
      'EUR', // 3 WKZ Umsatz
      '', // 4 Kurs
      '', // 5 Basisumsatz
      '', // 6 WKZ Basisumsatz
      account, // 7 Konto (SKR03-Aufwandskonto der Kategorie)
      config.bankGegenkonto, // 8 Gegenkonto
      '', // 9 BU-Schlüssel — bewusst leer, siehe Klassendoc
      '${expense.date.day.toString().padLeft(2, '0')}${expense.date.month.toString().padLeft(2, '0')}', // 10 Belegdatum (TTMM)
      expense.supplierReference ?? '', // 11 Belegfeld 1
      '', // 12 Belegfeld 2
      '', // 13 Skonto
      _truncate(expense.description, 60), // 14 Buchungstext
    ];
    final padded = [...row, for (var i = row.length; i < _totalBookingColumns; i++) ''];
    lines.add(padded.map(_escapeField).join(';'));
  }

  return DatevExportResult(
    csvContent: '${lines.join('\r\n')}\r\n',
    exportedCount: included.length,
    skippedExpenses: skipped,
  );
}
