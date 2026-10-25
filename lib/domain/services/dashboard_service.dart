import 'package:werkkern_core/werkkern_core.dart' show hasPaymentStatusKind, revenueSignForKind;

import '../../data/database/database.dart';
import '../../data/database/tables.dart';
import '../models/money.dart';
import 'dunning_service.dart';

/// Eine finalisierte Rechnung mit ihrem bereits berechneten Bruttobetrag
/// — das Dashboard selbst lädt keine Positionen, das bleibt Aufgabe des
/// Aufrufers (gleiche Trennung wie bei `invoice_totals_service.dart`:
/// reine Rechenlogik hier testbar ohne Datenbank, Datenbeschaffung in
/// der UI-Schicht/`DashboardScreen`).
class InvoiceWithGross {
  const InvoiceWithGross({required this.invoice, required this.gross});
  final Invoice invoice;
  final Money gross;
}

/// Dashboard-Kennzahlen (Kay-Anfrage 2026-10-17: "Ein Dashboard hätte
/// ich auch gerne als Einstiegspunkt, wenn man eine Firma ausgewählt
/// hat").
class DashboardSummary {
  const DashboardSummary({
    required this.openInvoicesCount,
    required this.openInvoicesSum,
    required this.overdueInvoicesCount,
    required this.revenueThisMonth,
    required this.revenueThisYear,
    this.vehiclesDueSoonCount = 0,
    this.activeProjectsCount = 0,
    this.activeRecurringTemplatesCount = 0,
    this.nextRecurringDueDate,
  });

  final int openInvoicesCount;
  final Money openInvoicesSum;
  final int overdueInvoicesCount;
  final Money revenueThisMonth;
  final Money revenueThisYear;
  final int vehiclesDueSoonCount;
  final int activeProjectsCount;
  final int activeRecurringTemplatesCount;
  final DateTime? nextRecurringDueDate;
}

/// Verdichtet bereits geladene Rechnungsdaten zu den Dashboard-
/// Kennzahlen. **Keine Buchhaltungs-/GoBD-Kennzahl**: "Rechnungssumme"
/// ist die Summe finalisierter Bruttobeträge im Zeitraum nach
/// Rechnungsdatum (`issueDate`), nicht automatisch der steuerlich/
/// handelsrechtlich korrekte Umsatz — Abschlags- und zugehörige
/// Schlussrechnung können sich z. B. inhaltlich überschneiden (siehe
/// Roadmap C13). Das bleibt wie die Projekt-Ergebnisrechnung ein
/// eigenes, noch zu klärendes Entscheidungstor — dieses Dashboard
/// behauptet keine Lösung dafür, nur eine schnelle Übersicht.
///
/// "Offen"/"überfällig" zählt nur Rechnungen mit `kind == invoice`
/// (Angebote/Aufträge/Lieferscheine/Proforma haben fachlich keinen
/// Zahlungsstatus, siehe `PaymentStatus`-Doc-Kommentar).
DashboardSummary computeDashboardSummary({
  required List<InvoiceWithGross> finalizedInvoices,
  required DateTime now,
  required DunningConfig dunningConfig,
  int vehiclesDueSoonCount = 0,
  int activeProjectsCount = 0,
  int activeRecurringTemplatesCount = 0,
  DateTime? nextRecurringDueDate,
}) {
  var openCount = 0;
  var openSum = Money.zero();
  var overdueCount = 0;
  var revenueMonth = Money.zero();
  var revenueYear = Money.zero();

  for (final entry in finalizedInvoices) {
    final invoice = entry.invoice;
    final signed = Money.fromCents(entry.gross.cents * revenueSignForKind(invoice.kind.name));
    if (invoice.issueDate.year == now.year) {
      revenueYear += signed;
      if (invoice.issueDate.month == now.month) {
        revenueMonth += signed;
      }
    }
    if (hasPaymentStatusKind(invoice.kind.name) && invoice.paymentStatus == PaymentStatus.open) {
      openCount++;
      openSum += entry.gross;
      if (dunningLevelFor(invoice, now, dunningConfig) != DunningLevel.none) {
        overdueCount++;
      }
    }
  }

  return DashboardSummary(
    openInvoicesCount: openCount,
    openInvoicesSum: openSum,
    overdueInvoicesCount: overdueCount,
    revenueThisMonth: revenueMonth,
    revenueThisYear: revenueYear,
    vehiclesDueSoonCount: vehiclesDueSoonCount,
    activeProjectsCount: activeProjectsCount,
    activeRecurringTemplatesCount: activeRecurringTemplatesCount,
    nextRecurringDueDate: nextRecurringDueDate,
  );
}
