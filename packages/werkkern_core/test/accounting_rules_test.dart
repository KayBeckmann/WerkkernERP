import 'package:test/test.dart';
import 'package:werkkern_core/werkkern_core.dart';

void main() {
  test('isInvoiceClosedByCredit: Storno oder volle Gutschrift schließt, Teilgutschrift nicht', () {
    expect(isInvoiceClosedByCredit(cancelled: true, invoiceGrossCents: 11900, creditedGrossCents: 0), isTrue);
    expect(isInvoiceClosedByCredit(cancelled: false, invoiceGrossCents: 11900, creditedGrossCents: 11900), isTrue);
    expect(isInvoiceClosedByCredit(cancelled: false, invoiceGrossCents: 11900, creditedGrossCents: 12000), isTrue);
    expect(isInvoiceClosedByCredit(cancelled: false, invoiceGrossCents: 11900, creditedGrossCents: 11899), isFalse);
    expect(isInvoiceClosedByCredit(cancelled: false, invoiceGrossCents: 0, creditedGrossCents: 0), isFalse);
  });
}
