import 'package:flutter_test/flutter_test.dart';
import 'package:werkkernerp/data/database/database.dart';
import 'package:werkkernerp/data/database/tables.dart';
import 'package:werkkernerp/domain/models/money.dart';
import 'package:werkkernerp/domain/services/open_items_service.dart';

/// C14.1 Offene-Posten-Übersicht (Kay-Priorisierungsentscheidung
/// 2026-10-18).
void main() {
  Invoice invoiceWith({required String customerId, required String id}) => Invoice(
        id: id,
        companyId: 'company-1',
        customerId: customerId,
        kind: DocumentKind.invoice,
        status: InvoiceStatus.finalized,
        invoiceNumber: 'R-26001',
        numberYear: 2026,
        issueDate: DateTime(2026, 10, 1),
        serviceDate: DateTime(2026, 10, 1),
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
        finalizedAt: DateTime(2026, 10, 1),
        createdAt: DateTime(2026, 10, 1),
        updatedAt: DateTime(2026, 10, 1),
        convertedFromId: null,
        isAdvancePayment: false,
        dueDate: null,
        paymentStatus: PaymentStatus.open,
        paidAt: null,
      );

  test('groupOpenItemsByCustomer fasst mehrere Rechnungen desselben Kunden zusammen', () {
    final items = [
      OpenItem(
        invoice: invoiceWith(customerId: 'kunde-a', id: 'inv-1'),
        gross: Money.fromCents(10000),
        customerName: 'Kunde A',
      ),
      OpenItem(
        invoice: invoiceWith(customerId: 'kunde-a', id: 'inv-2'),
        gross: Money.fromCents(5000),
        customerName: 'Kunde A',
      ),
      OpenItem(
        invoice: invoiceWith(customerId: 'kunde-b', id: 'inv-3'),
        gross: Money.fromCents(2000),
        customerName: 'Kunde B',
      ),
    ];

    final grouped = groupOpenItemsByCustomer(items);

    expect(grouped.length, 2);
    final kundeA = grouped.firstWhere((g) => g.customerId == 'kunde-a');
    expect(kundeA.items.length, 2);
    expect(kundeA.total, Money.fromCents(15000));
    final kundeB = grouped.firstWhere((g) => g.customerId == 'kunde-b');
    expect(kundeB.total, Money.fromCents(2000));
  });

  test('groupOpenItemsByCustomer sortiert nach größter offener Summe zuerst', () {
    final items = [
      OpenItem(
        invoice: invoiceWith(customerId: 'kunde-klein', id: 'inv-1'),
        gross: Money.fromCents(1000),
        customerName: 'Kunde Klein',
      ),
      OpenItem(
        invoice: invoiceWith(customerId: 'kunde-gross', id: 'inv-2'),
        gross: Money.fromCents(99999),
        customerName: 'Kunde Groß',
      ),
    ];

    final grouped = groupOpenItemsByCustomer(items);

    expect(grouped.first.customerId, 'kunde-gross');
    expect(grouped.last.customerId, 'kunde-klein');
  });

  test('totalOpenAmount summiert über alle übergebenen Posten', () {
    final items = [
      OpenItem(
        invoice: invoiceWith(customerId: 'kunde-a', id: 'inv-1'),
        gross: Money.fromCents(100),
        customerName: 'Kunde A',
      ),
      OpenItem(
        invoice: invoiceWith(customerId: 'kunde-b', id: 'inv-2'),
        gross: Money.fromCents(200),
        customerName: 'Kunde B',
      ),
    ];
    expect(totalOpenAmount(items), Money.fromCents(300));
  });

  test('Leere Liste ergibt leere Gruppierung und Summe 0', () {
    expect(groupOpenItemsByCustomer([]), isEmpty);
    expect(totalOpenAmount([]), Money.zero());
  });
}
