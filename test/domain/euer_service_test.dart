import 'package:flutter_test/flutter_test.dart';
import 'package:werkkernerp/data/database/database.dart';
import 'package:werkkernerp/data/database/tables.dart';
import 'package:werkkernerp/domain/models/money.dart';
import 'package:werkkernerp/domain/services/dashboard_service.dart';
import 'package:werkkernerp/domain/services/euer_service.dart';

/// C14.3 EÜR-Übersicht (Kay-Priorisierungsentscheidung 2026-10-18).
void main() {
  Invoice invoiceWith({required DateTime issueDate}) => Invoice(
        id: 'inv-${issueDate.toIso8601String()}',
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
        dueDate: null,
        paymentStatus: PaymentStatus.open,
        paidAt: null,
      );

  Expense expenseWith({required DateTime date, required int cents, String? categoryId}) => Expense(
        id: 'exp-${date.toIso8601String()}-$cents-$categoryId',
        companyId: 'company-1',
        date: date,
        description: 'Testbeleg',
        amountGrossCents: cents,
        vatRatePercent: 19,
        categoryId: categoryId,
        supplierReference: null,
        createdAt: date,
        updatedAt: date,
      );

  ExpenseCategory categoryWith({required String id, required String label, String? skr03Account}) =>
      ExpenseCategory(id: id, companyId: 'company-1', label: label, skr03Account: skr03Account, createdAt: DateTime.now());

  test('nur Einnahmen/Ausgaben innerhalb des Zeitraums werden berücksichtigt', () {
    final summary = computeEuerSummary(
      allFinalizedInvoices: [
        InvoiceWithGross(invoice: invoiceWith(issueDate: DateTime(2026, 10, 15)), gross: Money.fromCents(10000)),
        InvoiceWithGross(invoice: invoiceWith(issueDate: DateTime(2026, 9, 1)), gross: Money.fromCents(99999)),
      ],
      allExpenses: [
        expenseWith(date: DateTime(2026, 10, 10), cents: 3000),
        expenseWith(date: DateTime(2026, 11, 1), cents: 88888),
      ],
      categoryById: const {},
      periodStart: DateTime(2026, 10, 1),
      periodEnd: DateTime(2026, 10, 31),
    );

    expect(summary.totalIncome, Money.fromCents(10000));
    expect(summary.totalExpenses, Money.fromCents(3000));
    expect(summary.surplus, Money.fromCents(7000));
  });

  test('Ausgaben werden nach Kategorie gruppiert, größte Kategorie zuerst', () {
    final categoryById = {
      'material': categoryWith(id: 'material', label: 'Material', skr03Account: '4200'),
      'kfz': categoryWith(id: 'kfz', label: 'Fahrzeugkosten'),
    };
    final summary = computeEuerSummary(
      allFinalizedInvoices: const [],
      allExpenses: [
        expenseWith(date: DateTime(2026, 10, 1), cents: 1000, categoryId: 'material'),
        expenseWith(date: DateTime(2026, 10, 2), cents: 2000, categoryId: 'material'),
        expenseWith(date: DateTime(2026, 10, 3), cents: 500, categoryId: 'kfz'),
      ],
      categoryById: categoryById,
      periodStart: DateTime(2026, 10, 1),
      periodEnd: DateTime(2026, 10, 31),
    );

    expect(summary.expensesByCategory.length, 2);
    expect(summary.expensesByCategory.first.categoryLabel, 'Material');
    expect(summary.expensesByCategory.first.total, Money.fromCents(3000));
    expect(summary.expensesByCategory.first.skr03Account, '4200');
    expect(summary.expensesByCategory.last.categoryLabel, 'Fahrzeugkosten');
    expect(summary.totalExpenses, Money.fromCents(3500));
  });

  test('Belege ohne Kategorie werden als "Ohne Kategorie" zusammengefasst', () {
    final summary = computeEuerSummary(
      allFinalizedInvoices: const [],
      allExpenses: [
        expenseWith(date: DateTime(2026, 10, 1), cents: 1000),
        expenseWith(date: DateTime(2026, 10, 2), cents: 500),
      ],
      categoryById: const {},
      periodStart: DateTime(2026, 10, 1),
      periodEnd: DateTime(2026, 10, 31),
    );

    expect(summary.expensesByCategory.single.categoryLabel, 'Ohne Kategorie');
    expect(summary.expensesByCategory.single.total, Money.fromCents(1500));
  });

  test('surplus kann negativ sein, wenn Ausgaben die Einnahmen übersteigen', () {
    final summary = computeEuerSummary(
      allFinalizedInvoices: [
        InvoiceWithGross(invoice: invoiceWith(issueDate: DateTime(2026, 10, 1)), gross: Money.fromCents(1000)),
      ],
      allExpenses: [expenseWith(date: DateTime(2026, 10, 1), cents: 5000)],
      categoryById: const {},
      periodStart: DateTime(2026, 10, 1),
      periodEnd: DateTime(2026, 10, 31),
    );

    expect(summary.surplus, Money.fromCents(-4000));
  });
}
