import 'package:flutter_test/flutter_test.dart';
import 'package:werkkernerp/domain/services/time_sheet_billing_recipient.dart';

void main() {
  test('signed sheet uses accounting email before contact and general address', () {
    expect(timeSheetBillingRecipient(
      invoiceEmail: 'buchhaltung@example.invalid',
      contactEmail: 'kontakt@example.invalid',
      customerEmail: 'allgemein@example.invalid',
    ), 'buchhaltung@example.invalid');
  });

  test('signed sheet falls back to contact, then general address', () {
    expect(timeSheetBillingRecipient(
      contactEmail: 'kontakt@example.invalid',
      customerEmail: 'allgemein@example.invalid',
    ), 'kontakt@example.invalid');
    expect(timeSheetBillingRecipient(customerEmail: 'allgemein@example.invalid'),
        'allgemein@example.invalid');
    expect(timeSheetBillingRecipient(), isNull);
  });
}
