import 'package:werkkern_core/werkkern_core.dart' show revenueSignForKind;

import '../../data/database/database.dart';
import '../models/money.dart';
import 'dashboard_service.dart' show InvoiceWithGross;

/// C14.3 EÜR-Übersicht (Kay-Priorisierungsentscheidung 2026-10-18,
/// dritter Baustein der vollen Buchhaltung). Reine, datenbankfreie
/// Aggregationslogik — gleiches Trennungsprinzip wie
/// `dashboard_service.dart`/`open_items_service.dart`.
///
/// **Ausdrücklich KEINE steuerliche Einnahmen-Überschuss-Rechnung nach
/// § 4 Abs. 3 EStG** — nur eine interne Übersicht aus den in dieser App
/// erfassten Einnahmen (finalisierte Rechnungen) und Ausgaben (Belege).
/// Es fehlen z. B. Abschreibungen (AfA), private Kfz-Nutzung,
/// Rückstellungen und alles, was nicht über diese App läuft. Keine
/// Rechtsprüfung, keine Zusage, dass das für eine Steuererklärung
/// ausreicht — analog zu allen anderen "Arbeitsvorgabe statt
/// Steuerberatung"-Stellen dieser App (F1/F2/C12/C13).
class EuerCategoryTotal {
  const EuerCategoryTotal({
    required this.categoryLabel,
    required this.skr03Account,
    required this.total,
  });
  final String categoryLabel;
  final String? skr03Account;
  final Money total;
}

class EuerSummary {
  const EuerSummary({
    required this.periodStart,
    required this.periodEnd,
    required this.totalIncome,
    required this.totalExpenses,
    required this.expensesByCategory,
    required this.surplus,
  });
  final DateTime periodStart;
  final DateTime periodEnd;
  final Money totalIncome;
  final Money totalExpenses;

  /// Größte Ausgabenkategorie zuerst.
  final List<EuerCategoryTotal> expensesByCategory;

  /// Einnahmen minus Ausgaben — "Überschuss" im Sinn dieser (nicht
  /// steuerlichen) Übersicht.
  final Money surplus;
}

/// Vergleicht nach **Kalendertag**: Start- und Endtag zählen ganztägig
/// mit, egal welche Uhrzeit in [date] steckt. Ein reiner Zeitpunktvergleich
/// würde am letzten Tag des Zeitraums alles nach 00:00 Uhr ausschließen
/// (z. B. eine am 31.10. um 14 Uhr finalisierte Rechnung im Oktober).
bool isWithinDatePeriod(DateTime date, DateTime start, DateTime end) {
  final day = DateTime(date.year, date.month, date.day);
  return !day.isBefore(DateTime(start.year, start.month, start.day)) &&
      !day.isAfter(DateTime(end.year, end.month, end.day));
}

bool _withinPeriod(DateTime date, DateTime start, DateTime end) => isWithinDatePeriod(date, start, end);

/// Filtert UND aggregiert in einem Schritt — bewusst die vollen Listen
/// übergeben (nicht vorgefiltert), damit die UI den Zeitraum wechseln
/// kann, ohne erneut aus der Datenbank laden zu müssen.
///
/// [allVehicleCostEntries] ist optional (leere Liste, wenn C6 Fuhrpark
/// nicht aktiviert ist) — Kay-Entscheidung 2026-10-19: "Fuhrpark wird
/// auf Gemeinkosten gerechnet, nicht auf die Projekte." Die Kosten
/// fließen deshalb als eigene Gemeinkosten-Kategorie "Fuhrpark
/// (Gemeinkosten)" in die Ausgaben ein, **ohne** Verteilungsschlüssel
/// auf Projekte — [VehicleCostEntry.projectId] bleibt dafür bewusst
/// unberücksichtigt (reine Markierung, siehe Doc-Kommentar bei
/// [Vehicles] in tables.dart).
EuerSummary computeEuerSummary({
  required List<InvoiceWithGross> allFinalizedInvoices,
  required List<Expense> allExpenses,
  required Map<String, ExpenseCategory> categoryById,
  required DateTime periodStart,
  required DateTime periodEnd,
  List<VehicleCostEntry> allVehicleCostEntries = const [],
}) {
  // Nur Rechnungen sind Einnahmen, Gutschriften mindern sie (siehe
  // `revenueSignForKind`) — Angebote/Aufträge/Lieferscheine/Proforma nie.
  var totalIncome = Money.zero();
  for (final entry in allFinalizedInvoices) {
    final sign = revenueSignForKind(entry.invoice.kind.name);
    if (sign != 0 && _withinPeriod(entry.invoice.issueDate, periodStart, periodEnd)) {
      totalIncome += Money.fromCents(entry.gross.cents * sign);
    }
  }

  final byCategory = <String, Money>{};
  for (final expense in allExpenses) {
    if (!_withinPeriod(expense.date, periodStart, periodEnd)) continue;
    final key = expense.categoryId ?? '';
    byCategory[key] = (byCategory[key] ?? Money.zero()) + Money.fromCents(expense.amountGrossCents);
  }

  // Fuhrparkkosten als eigene Gemeinkosten-Kategorie, nicht als Beleg
  // erfasst — eigener Sentinel-Schlüssel, der nie mit einer echten
  // Expense-Kategorie-UUID kollidiert.
  const fleetCategoryKey = '__fleet_overhead__';
  for (final cost in allVehicleCostEntries) {
    if (!_withinPeriod(cost.date, periodStart, periodEnd)) continue;
    byCategory[fleetCategoryKey] = (byCategory[fleetCategoryKey] ?? Money.zero()) + Money.fromCents(cost.amountCents);
  }

  final categoryTotals = [
    for (final entry in byCategory.entries)
      EuerCategoryTotal(
        categoryLabel: entry.key == fleetCategoryKey
            ? 'Fuhrpark (Gemeinkosten)'
            : categoryById[entry.key]?.label ?? 'Ohne Kategorie',
        skr03Account: entry.key == fleetCategoryKey ? null : categoryById[entry.key]?.skr03Account,
        total: entry.value,
      ),
  ]..sort((a, b) => b.total.cents.compareTo(a.total.cents));

  final totalExpenses = categoryTotals.fold(Money.zero(), (sum, c) => sum + c.total);

  return EuerSummary(
    periodStart: periodStart,
    periodEnd: periodEnd,
    totalIncome: totalIncome,
    totalExpenses: totalExpenses,
    expensesByCategory: categoryTotals,
    surplus: totalIncome - totalExpenses,
  );
}
