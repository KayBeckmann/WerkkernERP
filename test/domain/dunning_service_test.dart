import 'package:flutter_test/flutter_test.dart';
import 'package:werkkernerp/data/database/database.dart';
import 'package:werkkernerp/data/database/tables.dart';
import 'package:werkkernerp/domain/models/money.dart';
import 'package:werkkernerp/domain/services/dunning_service.dart';

/// C12 Mahnwesen (Kay-Priorisierungsentscheidung 2026-10-17 + Kay-
/// Feedback 2026-10-17 "Mahngebühren und Mahnschreiben-PDF bitte
/// umsetzen") — datumsbasierte Stufenberechnung mit konfigurierbaren
/// Fristen/Gebühren/Zins statt fester Konstanten (siehe Klassendoc bei
/// `DunningConfig`).
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
        isFixedPrice: false,
        stockBooked: false,
        dueDate: dueDate,
        paymentStatus: paymentStatus,
        paidAt: null,
      );

  test('Ohne Fälligkeitsdatum ist nie eine Mahnstufe erreicht', () {
    final invoice = invoiceWith(dueDate: null);
    expect(dunningLevelFor(invoice, DateTime(2027, 1, 1), defaultConfig), DunningLevel.none);
  });

  test('Vor der Fälligkeit ist keine Mahnstufe erreicht', () {
    final invoice = invoiceWith(dueDate: DateTime(2026, 6, 1));
    expect(dunningLevelFor(invoice, DateTime(2026, 5, 1), defaultConfig), DunningLevel.none);
  });

  test('Ein bereits bezahltes Dokument zeigt nie eine Mahnstufe, egal wie überfällig', () {
    final invoice = invoiceWith(dueDate: DateTime(2026, 1, 1), paymentStatus: PaymentStatus.paid);
    expect(dunningLevelFor(invoice, DateTime(2026, 12, 1), defaultConfig), DunningLevel.none);
  });

  test('Ein Entwurf zeigt nie eine Mahnstufe, auch mit gesetztem Fälligkeitsdatum', () {
    final invoice = invoiceWith(dueDate: DateTime(2026, 1, 1), status: InvoiceStatus.draft);
    expect(dunningLevelFor(invoice, DateTime(2026, 12, 1), defaultConfig), DunningLevel.none);
  });

  test('1-13 Tage überfällig: einfache Überfälligkeit (Default-Fristen)', () {
    final invoice = invoiceWith(dueDate: DateTime(2026, 6, 1));
    expect(dunningLevelFor(invoice, DateTime(2026, 6, 10), defaultConfig), DunningLevel.overdue);
  });

  test('14-27 Tage überfällig: 2. Mahnstufe (Default-Fristen)', () {
    final invoice = invoiceWith(dueDate: DateTime(2026, 6, 1));
    expect(dunningLevelFor(invoice, DateTime(2026, 6, 15), defaultConfig), DunningLevel.reminder2);
  });

  test('ab 28 Tage überfällig: 3. Mahnstufe (Default-Fristen)', () {
    final invoice = invoiceWith(dueDate: DateTime(2026, 6, 1));
    expect(dunningLevelFor(invoice, DateTime(2026, 6, 29), defaultConfig), DunningLevel.reminder3);
  });

  test(
    'Kays eigene, abweichende Fristen werden tatsächlich verwendet statt fester Konstanten',
    () {
      const customConfig = DunningConfig(
        reminder2AfterDays: 5,
        reminder3AfterDays: 10,
        feeLevel1: Money.fromCents(0),
        feeLevel2: Money.fromCents(0),
        feeLevel3: Money.fromCents(0),
        interestRatePercent: 0,
      );
      final invoice = invoiceWith(dueDate: DateTime(2026, 6, 1));
      // Mit den Default-Fristen wäre das noch "einfach überfällig" (<14
      // Tage) — mit den engeren eigenen Fristen bereits die 2. Stufe.
      expect(dunningLevelFor(invoice, DateTime(2026, 6, 7), customConfig), DunningLevel.reminder2);
    },
  );

  test('dunningLevelLabel liefert für jede erreichbare Stufe einen nicht-leeren Text', () {
    for (final level in [DunningLevel.overdue, DunningLevel.reminder2, DunningLevel.reminder3]) {
      expect(dunningLevelLabel(level), isNotEmpty);
    }
    expect(dunningLevelLabel(DunningLevel.none), isEmpty);
  });

  test('dunningLetterTitle nennt das Mahnschreiben explizit "Mahnung" je Stufe', () {
    expect(dunningLetterTitle(DunningLevel.overdue), '1. Mahnung');
    expect(dunningLetterTitle(DunningLevel.reminder2), '2. Mahnung');
    expect(dunningLetterTitle(DunningLevel.reminder3), '3. Mahnung');
  });

  test('DunningConfig.feeFor liefert die Gebühr der jeweiligen Stufe', () {
    const config = DunningConfig(
      reminder2AfterDays: 14,
      reminder3AfterDays: 28,
      feeLevel1: Money.fromCents(500),
      feeLevel2: Money.fromCents(1000),
      feeLevel3: Money.fromCents(1500),
      interestRatePercent: 0,
    );
    expect(config.feeFor(DunningLevel.none), Money.fromCents(0));
    expect(config.feeFor(DunningLevel.overdue), Money.fromCents(500));
    expect(config.feeFor(DunningLevel.reminder2), Money.fromCents(1000));
    expect(config.feeFor(DunningLevel.reminder3), Money.fromCents(1500));
  });

  test('dunningInterestFor ohne Zinssatz oder ohne Überfälligkeit ergibt 0', () {
    expect(
      dunningInterestFor(principal: Money.fromCents(100000), overdueDays: 30, ratePercent: 0),
      Money.fromCents(0),
    );
    expect(
      dunningInterestFor(principal: Money.fromCents(100000), overdueDays: 0, ratePercent: 9),
      Money.fromCents(0),
    );
  });

  test('dunningInterestFor berechnet den einfachen Tageszins (principal × rate% × tage/365)', () {
    // 1.000,00 € × 9,2 % × 365 Tage / 365 = genau ein Jahreszins = 92,00 €.
    final interest =
        dunningInterestFor(principal: Money.fromCents(100000), overdueDays: 365, ratePercent: 9.2);
    expect(interest, Money.fromCents(9200));
  });
}
