// ignore_for_file: experimental_member_use
import 'package:decimal/decimal.dart';
import 'package:test/test.dart';
import 'package:werkkern_core/werkkern_core.dart';
import 'package:xml/xml.dart';
import 'package:xml/xpath.dart';

/// A2-Nachtrag (Kay, 15./16.11.2026): Zahlungsbedingungen und Skonto.
void main() {
  const terms14 = DocumentPaymentTerms(label: '14 Tage', netDays: 14, skontoPercent: 2, skontoDays: 7);
  final issue = DateTime(2026, 11, 16);

  test('Vorgaben: Sofort/7/14/30, 14 Tage ist Standard, „Sofort netto“ ohne Abzug', () {
    expect([for (final p in defaultPaymentTermPresets) p.netDays], [0, 7, 14, 30]);
    expect(defaultPaymentTermPresets.where((p) => p.isDefault).single.label, '14 Tage');
    const sofort = DocumentPaymentTerms(label: 'Sofort netto', netDays: 0);
    final s = summarizePaymentTerms(
      terms: sofort,
      issueDate: issue,
      net: Money.fromCents(10000),
      gross: Money.fromCents(11900),
      smallBusinessExempt: false,
    );
    expect(paymentTermsText(sofort, s), 'Zahlbar sofort ohne Abzug.');
    expect(s.dueDate, issue);
  });

  test('Kundenstandard vor Firmenstandard, Skonto-Modus Firma/keins/eigen', () {
    final company = resolvePaymentDefaults(companyDefaultTermId: 'f14', companySkontoPercent: 2, companySkontoDays: 7);
    expect((company.termId, company.skontoPercent, company.skontoDays), ('f14', 2.0, 7));
    final customer = resolvePaymentDefaults(
      customerTermId: 'k30',
      companyDefaultTermId: 'f14',
      customerSkontoMode: 'custom',
      customerSkontoPercent: 3,
      customerSkontoDays: 10,
      companySkontoPercent: 2,
      companySkontoDays: 7,
    );
    expect((customer.termId, customer.skontoPercent, customer.skontoDays), ('k30', 3.0, 10));
    final none = resolvePaymentDefaults(companyDefaultTermId: 'f14', customerSkontoMode: 'none', companySkontoPercent: 2, companySkontoDays: 7);
    expect(none.skontoPercent, isNull);
    expect(resolvePaymentDefaults().termId, isNull);
  });

  test('Kay-Entscheidung: ohne § 19 Skonto auf netto, mit § 19 auf brutto', () {
    final normal = summarizePaymentTerms(
      terms: terms14,
      issueDate: issue,
      net: Money.fromCents(14188),
      gross: Money.fromCents(16644),
      smallBusinessExempt: false,
    );
    expect(normal.skontoBase!.cents, 14188);
    expect(normal.skontoAmount!.cents, 284, reason: '141,88 € × 2 % = 2,8376 → 2,84 €');
    expect(normal.payableWithSkonto!.cents, 16360);
    expect(normal.dueDate, DateTime(2026, 11, 30));
    expect(normal.skontoDate, DateTime(2026, 11, 23));
    expect(
      paymentTermsText(terms14, normal),
      'Zahlbar innerhalb von 14 Tagen bis 30.11.2026 ohne Abzug. Bei Zahlung bis 23.11.2026 2 % Skonto auf '
      'den Nettobetrag (2,84 €), zu zahlen 163,60 €.',
    );

    final exempt = summarizePaymentTerms(
      terms: terms14,
      issueDate: issue,
      net: Money.fromCents(14188),
      gross: Money.fromCents(14188),
      smallBusinessExempt: true,
    );
    expect(exempt.skontoBase!.cents, 14188);
    expect(exempt.payableWithSkonto!.cents, 13904);
    expect(paymentTermsText(terms14, exempt), contains('Skonto auf den Rechnungsbetrag'));
  });

  test('Schlussrechnung: Skonto anteilig auf den offenen Betrag; ohne Skonto keine Angabe', () {
    final s = summarizePaymentTerms(
      terms: terms14,
      issueDate: issue,
      net: Money.fromCents(10000),
      gross: Money.fromCents(11900),
      payable: Money.fromCents(5950),
      smallBusinessExempt: false,
    );
    expect(s.skontoBase!.cents, 5000);
    expect(s.skontoAmount!.cents, 100);
    expect(s.payableWithSkonto!.cents, 5850);
    const plain = DocumentPaymentTerms(label: '30 Tage', netDays: 30);
    final p = summarizePaymentTerms(terms: plain, issueDate: issue, net: Money.fromCents(100), gross: Money.fromCents(119), smallBusinessExempt: false);
    expect(p.skontoAmount, isNull);
    expect(paymentTermsText(plain, p), isNot(contains('Skonto')));
  });

  test('E-Rechnung: XRechnung mit #SKONTO#-Zeile und Fälligkeit, ZUGFeRD nur Text', () {
    EInvoiceData data(EInvoiceProfile profile) => EInvoiceData(
          profile: profile,
          kind: 'invoice',
          number: 'R-26010',
          issueDate: issue,
          serviceDate: issue,
          seller: const EInvoiceParty(
            name: 'Elektro Beckmann',
            address: PostalAddress(street: 'Musterstraße 1', postalCode: '23966', city: 'Wismar'),
            taxNumber: '079/123/45678',
            email: 'info@elektro.example',
            phone: '03841 1',
            iban: 'DE02120300000000202051',
          ),
          buyer: const EInvoiceParty(
            name: 'Stadt Wismar',
            address: PostalAddress(street: 'Am Markt 1', postalCode: '23966', city: 'Wismar'),
            email: 'rechnung@wismar.example',
            leitwegId: '04011000-1234512345-06',
          ),
          terms: terms14,
          lines: [EInvoiceLine(description: 'Montage', quantity: Decimal.one, unitPriceCents: 10000, vatRatePercent: 19)],
        );
    final xr = XmlDocument.parse(buildEInvoiceXml(data(EInvoiceProfile.xrechnung)));
    final text = xr.xpath('//ram:SpecifiedTradePaymentTerms/ram:Description').single.innerText;
    expect(text.split('\n').first, '#SKONTO#TAGE=7#PROZENT=2.00#BASISBETRAG=100.00#');
    expect(text, contains('2 % Skonto auf den Nettobetrag (2,00 €), zu zahlen 117,00 €'));
    expect(xr.xpath('//ram:DueDateDateTime/udt:DateTimeString').single.innerText, '20261130');
    final zf = XmlDocument.parse(buildEInvoiceXml(data(EInvoiceProfile.zugferdEn16931)));
    expect(zf.xpath('//ram:SpecifiedTradePaymentTerms/ram:Description').single.innerText, isNot(contains('#SKONTO#')));
  });
}
