import 'package:flutter_test/flutter_test.dart';
import 'package:werkkernerp/data/database/database.dart';
import 'package:werkkernerp/data/database/tables.dart';
import 'package:werkkernerp/domain/models/money.dart';
import 'package:werkkernerp/domain/services/dashboard_service.dart';
import 'package:werkkernerp/domain/services/dunning_service.dart';

/// Dashboard-Kern (Kay-Anfrage 2026-10-17: "Ein Dashboard hätte ich auch
/// gerne als Einstiegspunkt").
void main() {
  const defaultConfig = DunningConfig(
    reminder2AfterDays: 14,
    reminder3AfterDays: 28,
    feeLevel1: Money.fromCents(0),
    feeLevel2: Money.fromCents(0),
    feeLevel3: Money.fromCents(0),
    interestRatePercent: 0,
  );

  Invoice invoiceWith({
    required DateTime issueDate,
    PaymentStatus paymentStatus = PaymentStatus.open,
    DateTime? dueDate,
  }) =>
      Invoice(
        id: 'inv-${issueDate.toIso8601String()}-$paymentStatus',
        companyId: 'company-1',
        customerId: 'customer-1',
        kind: DocumentKind.invoice,
        status: InvoiceStatus.finalized,
        invoiceNumber: 'R-26001',
        numberYear: issueDate.year,
        issueDate: issueDate,
        serviceDate: issueDate,
        paymentTerms: null,
        notes: null,
        customerSnapshotName: null,
        customerSnapshotAddress: null,
        customerSnapshotVatId: null,
        companySnapshotName: null,
        companySnapshotAddress: null,
        companySnapshotTaxNumber: null,
        companySnapshotVatId: null,
        companySnapshotIban: null,
        finalizedAt: issueDate,
        createdAt: issueDate,
        updatedAt: issueDate,
        convertedFromId: null,
        isAdvancePayment: false,
        isFixedPrice: false,
        stockBooked: false,
        dueDate: dueDate,
        paymentStatus: paymentStatus,
        paidAt: null,
      );

  test('Umsatz dieses Monats/Jahres summiert nur Rechnungen mit passendem issueDate', () {
    final now = DateTime(2026, 10, 17);
    final summary = computeDashboardSummary(
      finalizedInvoices: [
        InvoiceWithGross(
          invoice: invoiceWith(issueDate: DateTime(2026, 10, 1)),
          gross: Money.fromCents(10000),
        ),
        InvoiceWithGross(
          invoice: invoiceWith(issueDate: DateTime(2026, 1, 1), paymentStatus: PaymentStatus.paid),
          gross: Money.fromCents(20000),
        ),
        InvoiceWithGross(
          invoice: invoiceWith(issueDate: DateTime(2025, 12, 1), paymentStatus: PaymentStatus.paid),
          gross: Money.fromCents(99999),
        ),
      ],
      now: now,
      dunningConfig: defaultConfig,
    );
    expect(summary.revenueThisMonth, Money.fromCents(10000));
    expect(summary.revenueThisYear, Money.fromCents(30000));
  });

  test('Offene Rechnungen werden gezählt und summiert, bezahlte nicht', () {
    final now = DateTime(2026, 10, 17);
    final summary = computeDashboardSummary(
      finalizedInvoices: [
        InvoiceWithGross(
          invoice: invoiceWith(issueDate: now, paymentStatus: PaymentStatus.open),
          gross: Money.fromCents(5000),
        ),
        InvoiceWithGross(
          invoice: invoiceWith(issueDate: now, paymentStatus: PaymentStatus.open),
          gross: Money.fromCents(3000),
        ),
        InvoiceWithGross(
          invoice: invoiceWith(issueDate: now, paymentStatus: PaymentStatus.paid),
          gross: Money.fromCents(7000),
        ),
      ],
      now: now,
      dunningConfig: defaultConfig,
    );
    expect(summary.openInvoicesCount, 2);
    expect(summary.openInvoicesSum, Money.fromCents(8000));
  });

  test('Überfällige offene Rechnungen (Mahnstufe erreicht) werden separat gezählt', () {
    final now = DateTime(2026, 10, 17);
    final summary = computeDashboardSummary(
      finalizedInvoices: [
        // Ohne Fälligkeitsdatum -> nie überfällig.
        InvoiceWithGross(
          invoice: invoiceWith(issueDate: now, paymentStatus: PaymentStatus.open),
          gross: Money.fromCents(1000),
        ),
        // Weit überfälliges Fälligkeitsdatum.
        InvoiceWithGross(
          invoice: invoiceWith(
            issueDate: now,
            paymentStatus: PaymentStatus.open,
            dueDate: DateTime(2026, 1, 1),
          ),
          gross: Money.fromCents(2000),
        ),
      ],
      now: now,
      dunningConfig: defaultConfig,
    );
    expect(summary.openInvoicesCount, 2);
    expect(summary.overdueInvoicesCount, 1);
  });

  test('Fuhrpark-/Projekt-/Vorlagen-Zahlen werden unverändert durchgereicht', () {
    final nextDue = DateTime(2026, 11, 1);
    final summary = computeDashboardSummary(
      finalizedInvoices: const [],
      now: DateTime(2026, 10, 17),
      dunningConfig: defaultConfig,
      vehiclesDueSoonCount: 2,
      activeProjectsCount: 5,
      activeRecurringTemplatesCount: 3,
      nextRecurringDueDate: nextDue,
    );
    expect(summary.vehiclesDueSoonCount, 2);
    expect(summary.activeProjectsCount, 5);
    expect(summary.activeRecurringTemplatesCount, 3);
    expect(summary.nextRecurringDueDate, nextDue);
    expect(summary.revenueThisMonth, Money.zero());
    expect(summary.openInvoicesCount, 0);
  });
}
