import 'package:flutter_test/flutter_test.dart';
import 'package:werkkernerp/data/database/database.dart';
import 'package:werkkernerp/data/database/tables.dart';
import 'package:werkkernerp/domain/services/dunning_service.dart';

/// C12 Mahnwesen (Kay-Priorisierungsentscheidung 2026-10-17) — reine,
/// datumsbasierte Stufenberechnung ohne Mahngebühr/Verzugszins (siehe
/// Klassendoc in `dunning_service.dart`).
void main() {
  Invoice invoiceWith({
    DateTime? dueDate,
    PaymentStatus paymentStatus = PaymentStatus.open,
    InvoiceStatus status = InvoiceStatus.finalized,
  }) =>
      Invoice(
        id: 'inv-1',
        companyId: 'company-1',
        customerId: 'customer-1',
        kind: DocumentKind.invoice,
        status: status,
        invoiceNumber: status == InvoiceStatus.finalized ? 'R-26001' : null,
        numberYear: status == InvoiceStatus.finalized ? 2026 : null,
        issueDate: DateTime(2026, 1, 1),
        serviceDate: DateTime(2026, 1, 1),
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
        finalizedAt: status == InvoiceStatus.finalized ? DateTime(2026, 1, 1) : null,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
        convertedFromId: null,
        isAdvancePayment: false,
        dueDate: dueDate,
        paymentStatus: paymentStatus,
        paidAt: null,
      );

  test('Ohne Fälligkeitsdatum ist nie eine Mahnstufe erreicht', () {
    final invoice = invoiceWith(dueDate: null);
    expect(dunningLevelFor(invoice, DateTime(2027, 1, 1)), DunningLevel.none);
  });

  test('Vor der Fälligkeit ist keine Mahnstufe erreicht', () {
    final invoice = invoiceWith(dueDate: DateTime(2026, 6, 1));
    expect(dunningLevelFor(invoice, DateTime(2026, 5, 1)), DunningLevel.none);
  });

  test('Ein bereits bezahltes Dokument zeigt nie eine Mahnstufe, egal wie überfällig', () {
    final invoice = invoiceWith(dueDate: DateTime(2026, 1, 1), paymentStatus: PaymentStatus.paid);
    expect(dunningLevelFor(invoice, DateTime(2026, 12, 1)), DunningLevel.none);
  });

  test('Ein Entwurf zeigt nie eine Mahnstufe, auch mit gesetztem Fälligkeitsdatum', () {
    final invoice = invoiceWith(dueDate: DateTime(2026, 1, 1), status: InvoiceStatus.draft);
    expect(dunningLevelFor(invoice, DateTime(2026, 12, 1)), DunningLevel.none);
  });

  test('1-13 Tage überfällig: einfache Überfälligkeit', () {
    final invoice = invoiceWith(dueDate: DateTime(2026, 6, 1));
    expect(dunningLevelFor(invoice, DateTime(2026, 6, 10)), DunningLevel.overdue);
  });

  test('14-27 Tage überfällig: 2. Mahnstufe', () {
    final invoice = invoiceWith(dueDate: DateTime(2026, 6, 1));
    expect(dunningLevelFor(invoice, DateTime(2026, 6, 15)), DunningLevel.reminder2);
  });

  test('ab 28 Tage überfällig: 3. Mahnstufe', () {
    final invoice = invoiceWith(dueDate: DateTime(2026, 6, 1));
    expect(dunningLevelFor(invoice, DateTime(2026, 6, 29)), DunningLevel.reminder3);
  });

  test('dunningLevelLabel liefert für jede erreichbare Stufe einen nicht-leeren Text', () {
    for (final level in [DunningLevel.overdue, DunningLevel.reminder2, DunningLevel.reminder3]) {
      expect(dunningLevelLabel(level), isNotEmpty);
    }
    expect(dunningLevelLabel(DunningLevel.none), isEmpty);
  });
}
