// ignore_for_file: experimental_member_use
import 'package:decimal/decimal.dart';
import 'package:test/test.dart';
import 'package:werkkern_core/werkkern_core.dart';
import 'package:xml/xml.dart';
import 'package:xml/xpath.dart';

/// C15.2 E-Rechnung: CII-XML für ZUGFeRD EN 16931 und XRechnung.
const _seller = EInvoiceParty(
  name: 'Elektro Beckmann',
  address: PostalAddress(street: 'Musterstraße 1', postalCode: '23966', city: 'Wismar'),
  vatId: 'DE123456789',
  taxNumber: '079/123/45678',
  email: 'info@elektro.example',
  phone: '03841 1',
  iban: 'DE02 1203 0000 0000 2020 51',
  bic: 'BYLADEM1001',
);

const _buyer = EInvoiceParty(
  name: 'Stadt Wismar',
  address: PostalAddress(street: 'Am Markt 1', postalCode: '23966', city: 'Wismar'),
  email: 'rechnung@wismar.example',
  leitwegId: '04011000-1234512345-06',
  contactName: 'Erika Muster',
);

EInvoiceData sample({
  EInvoiceProfile profile = EInvoiceProfile.zugferdEn16931,
  String kind = 'invoice',
  bool exempt = false,
  List<EInvoiceLine>? lines,
  List<EInvoicePriorPayment> prior = const [],
  String? referenced,
  EInvoiceParty seller = _seller,
  EInvoiceParty buyer = _buyer,
  DateTime? dueDate,
}) =>
    EInvoiceData(
      profile: profile,
      kind: kind,
      number: kind == 'creditNote' ? 'G-26001' : 'R-26007',
      issueDate: DateTime(2026, 11, 16),
      serviceDate: DateTime(2026, 11, 10),
      dueDate: dueDate ?? DateTime(2026, 11, 30),
      paymentTerms: 'Zahlbar innerhalb 14 Tagen netto.',
      seller: seller,
      buyer: buyer,
      smallBusinessExempt: exempt,
      priorPayments: prior,
      referencedInvoiceNumber: referenced,
      referencedInvoiceDate: referenced == null ? null : DateTime(2026, 10, 1),
      lines: lines ??
          [
            EInvoiceLine(
              description: 'Beratung',
              quantity: Decimal.one,
              unit: 'h',
              unitPriceCents: 10000,
              vatRatePercent: exempt ? 0 : 19,
              discountPercent: 10,
            ),
            EInvoiceLine(
              description: 'Kabel NYM-J 3x1,5',
              quantity: Decimal.parse('12.5'),
              unit: 'm',
              unitPriceCents: 255,
              vatRatePercent: exempt ? 0 : 19,
              groupLabel: 'Material',
            ),
            EInvoiceLine(
              description: 'Fachbuch',
              quantity: Decimal.fromInt(2),
              unit: 'Stk',
              unitPriceCents: 1000,
              vatRatePercent: exempt ? 0 : 7,
            ),
          ],
    );

XmlDocument parse(EInvoiceData d) => XmlDocument.parse(buildEInvoiceXml(d));

String text(XmlDocument doc, String xpath) => doc.xpath(xpath).single.innerText;

void main() {
  group('Pflichtfelder', () {
    test('vollständige Rechnung hat keine Probleme, Entwurf und leere Parteien schon', () {
      expect(eInvoiceProblems(sample()), isEmpty);
      expect(eInvoiceProblems(sample(profile: EInvoiceProfile.xrechnung)), isEmpty);
      final draft = EInvoiceData(
        profile: EInvoiceProfile.xrechnung,
        kind: 'invoice',
        number: null,
        issueDate: DateTime(2026, 1, 1),
        serviceDate: DateTime(2026, 1, 1),
        seller: const EInvoiceParty(name: 'X'),
        buyer: const EInvoiceParty(name: ''),
        lines: const [],
      );
      final problems = eInvoiceProblems(draft);
      expect(problems, contains('Dokument ist noch nicht finalisiert (keine Nummer).'));
      expect(problems, contains('Keine Positionen.'));
      expect(problems, contains('Verkäufer: PLZ fehlt.'));
      expect(problems, contains('Verkäufer: USt-IdNr. oder Steuernummer fehlt.'));
      expect(problems, contains('Verkäufer: E-Mail fehlt.'));
      expect(problems, contains('Kunde: Name fehlt.'));
      expect(problems, contains('Kunde: Leitweg-ID / Käuferreferenz fehlt (XRechnung).'));
      expect(problems, contains('Verkäufer: IBAN fehlt (XRechnung verlangt eine Zahlungsangabe).'));
      expect(() => buildEInvoiceXml(draft), throwsStateError);
      expect(buildEInvoiceXml(draft, allowProblems: true), contains('<ram:ID>ENTWURF</ram:ID>'));
    });

    test('ZUGFeRD verlangt keine Leitweg-ID und keine Verkäufer-Telefonnummer', () {
      final d = sample(
        seller: const EInvoiceParty(
          name: 'Elektro Beckmann',
          address: PostalAddress(street: 'Musterstraße 1', postalCode: '23966', city: 'Wismar'),
          taxNumber: '079/123/45678',
        ),
        buyer: const EInvoiceParty(
          name: 'Privatkunde',
          address: PostalAddress(street: 'Weg 2', postalCode: '23966', city: 'Wismar'),
        ),
      );
      expect(eInvoiceProblems(d), isEmpty);
      expect(eInvoiceProblems(sample(profile: EInvoiceProfile.xrechnung, buyer: d.buyer, seller: d.seller)), isNotEmpty);
    });

    test('§ 19 mit Steuersatz > 0 und Gutschrift ohne Bezug werden gemeldet', () {
      expect(
        eInvoiceProblems(sample(exempt: true, lines: [
          EInvoiceLine(description: 'x', quantity: Decimal.one, unitPriceCents: 100, vatRatePercent: 19),
        ])),
        contains('Position 1: § 19 UStG aktiv, aber Steuersatz 19 %.'),
      );
      expect(eInvoiceProblems(sample(kind: 'creditNote')), contains('Gutschrift: Bezug zur korrigierten Rechnung fehlt.'));
      expect(eInvoiceProblems(sample(kind: 'creditNote', referenced: 'R-26001')), isEmpty);
      expect(eInvoiceProblems(sample(kind: 'quote')), contains('Nur Rechnungen und Gutschriften sind E-Rechnungen.'));
    });
  });

  group('CII-Struktur', () {
    test('Kopf, Profilkennung, Parteien, Steuern und Summen (ZUGFeRD EN 16931)', () {
      final d = sample();
      final doc = parse(d);
      expect(doc.rootElement.name.qualified, 'rsm:CrossIndustryInvoice');
      expect(
        text(doc, '//ram:GuidelineSpecifiedDocumentContextParameter/ram:ID'),
        'urn:cen.eu:en16931:2017',
      );
      expect(doc.xpath('//ram:BusinessProcessSpecifiedDocumentContextParameter'), isEmpty, reason: 'nur XRechnung');
      expect(text(doc, '//rsm:ExchangedDocument/ram:ID'), 'R-26007');
      expect(text(doc, '//rsm:ExchangedDocument/ram:TypeCode'), '380');
      expect(text(doc, '//rsm:ExchangedDocument/ram:IssueDateTime/udt:DateTimeString'), '20261116');
      expect(text(doc, '//ram:ApplicableHeaderTradeDelivery//udt:DateTimeString'), '20261110');
      expect(text(doc, '//ram:BuyerReference'), '04011000-1234512345-06');

      final seller = doc.xpath('//ram:SellerTradeParty').single;
      expect(seller.xpath('ram:Name').single.innerText, 'Elektro Beckmann');
      expect(seller.xpath('ram:PostalTradeAddress/ram:PostcodeCode').single.innerText, '23966');
      expect(seller.xpath('ram:PostalTradeAddress/ram:LineOne').single.innerText, 'Musterstraße 1');
      expect(seller.xpath('ram:PostalTradeAddress/ram:CountryID').single.innerText, 'DE');
      expect(seller.xpath('ram:URIUniversalCommunication/ram:URIID').single.getAttribute('schemeID'), 'EM');
      expect(seller.xpath('ram:DefinedTradeContact/ram:PersonName').single.innerText, 'Elektro Beckmann');
      expect(
        [for (final e in seller.xpath('ram:SpecifiedTaxRegistration/ram:ID')) (e.getAttribute('schemeID'), e.innerText)],
        [('FC', '079/123/45678'), ('VA', 'DE123456789')],
      );
      final buyer = doc.xpath('//ram:BuyerTradeParty').single;
      expect(buyer.xpath('ram:DefinedTradeContact/ram:PersonName').single.innerText, 'Erika Muster');
      expect(buyer.xpath('ram:SpecifiedTaxRegistration'), isEmpty);

      expect(text(doc, '//ram:SpecifiedTradeSettlementPaymentMeans/ram:TypeCode'), '58');
      expect(text(doc, '//ram:PayeePartyCreditorFinancialAccount/ram:IBANID'), 'DE02120300000000202051');
      expect(text(doc, '//ram:PayeeSpecifiedCreditorFinancialInstitution/ram:BICID'), 'BYLADEM1001');
      expect(text(doc, '//ram:SpecifiedTradePaymentTerms/ram:DueDateDateTime/udt:DateTimeString'), '20261130');

      // Summen = Rechenkern: Beratung 100 − 10 % = 90; Kabel 12,5 × 2,55 = 31,88 (19 %); Buch 20 (7 %).
      final totals = d.totals;
      expect(totals.netByRate[19]!.cents, 12188);
      expect(totals.taxByRate[19]!.cents, 2316);
      expect(totals.netByRate[7]!.cents, 2000);
      expect(totals.taxByRate[7]!.cents, 140);
      final taxes = doc.xpath('//ram:ApplicableHeaderTradeSettlement/ram:ApplicableTradeTax');
      expect(taxes, hasLength(2));
      expect(taxes.first.xpath('ram:RateApplicablePercent').single.innerText, '7');
      expect(taxes.first.xpath('ram:BasisAmount').single.innerText, '20.00');
      expect(taxes.first.xpath('ram:CalculatedAmount').single.innerText, '1.40');
      expect(taxes.first.xpath('ram:CategoryCode').single.innerText, 'S');
      expect(taxes.last.xpath('ram:BasisAmount').single.innerText, '121.88');
      expect(taxes.last.xpath('ram:CalculatedAmount').single.innerText, '23.16');
      final sums = doc.xpath('//ram:SpecifiedTradeSettlementHeaderMonetarySummation').single;
      expect(sums.xpath('ram:LineTotalAmount').single.innerText, '141.88');
      expect(sums.xpath('ram:TaxBasisTotalAmount').single.innerText, '141.88');
      expect(sums.xpath('ram:TaxTotalAmount').single.innerText, '24.56');
      expect(sums.xpath('ram:TaxTotalAmount').single.getAttribute('currencyID'), 'EUR');
      expect(sums.xpath('ram:GrandTotalAmount').single.innerText, '166.44');
      expect(sums.xpath('ram:DuePayableAmount').single.innerText, '166.44');
      expect(sums.xpath('ram:TotalPrepaidAmount'), isEmpty);
      // Summe der Positionsbeträge entspricht BT-106 (BR-CO-10).
      final lineTotals = doc.xpath('//ram:SpecifiedTradeSettlementLineMonetarySummation/ram:LineTotalAmount');
      expect(lineTotals.map((e) => e.innerText), ['90.00', '31.88', '20.00']);
    });

    test('Positionen: Einheitencodes, Rabatt als Nachlass, Netto-Einzelpreis, Gruppe als Notiz', () {
      final doc = parse(sample());
      final lines = doc.xpath('//ram:IncludedSupplyChainTradeLineItem').toList();
      expect(lines, hasLength(3));
      final first = lines[0];
      expect(first.xpath('ram:AssociatedDocumentLineDocument/ram:LineID').single.innerText, '1');
      expect(first.xpath('ram:SpecifiedTradeProduct/ram:Name').single.innerText, 'Beratung');
      expect(first.xpath('.//ram:BilledQuantity').single.getAttribute('unitCode'), 'HUR');
      expect(first.xpath('.//ram:GrossPriceProductTradePrice/ram:ChargeAmount').single.innerText, '100.00');
      expect(first.xpath('.//ram:AppliedTradeAllowanceCharge/ram:ActualAmount').single.innerText, '10');
      expect(first.xpath('.//ram:AppliedTradeAllowanceCharge/ram:ChargeIndicator/udt:Indicator').single.innerText, 'false');
      expect(first.xpath('.//ram:NetPriceProductTradePrice/ram:ChargeAmount').single.innerText, '90');
      expect(first.xpath('.//ram:ApplicableTradeTax/ram:CategoryCode').single.innerText, 'S');
      final second = lines[1];
      expect(second.xpath('.//ram:BilledQuantity').single.innerText, '12.5');
      expect(second.xpath('.//ram:BilledQuantity').single.getAttribute('unitCode'), 'MTR');
      expect(second.xpath('ram:AssociatedDocumentLineDocument/ram:IncludedNote/ram:Content').single.innerText, 'Gruppe: Material');
      expect(second.xpath('.//ram:GrossPriceProductTradePrice'), isEmpty, reason: 'ohne Rabatt nur Nettopreis');
      expect(second.xpath('.//ram:NetPriceProductTradePrice/ram:ChargeAmount').single.innerText, '2.55');
      expect(lines[2].xpath('.//ram:BilledQuantity').single.getAttribute('unitCode'), 'C62');
      expect(unitCodeFor('m²'), 'MTK');
      expect(unitCodeFor('pauschal'), 'LS');
      expect(unitCodeFor('Unbekannt'), 'C62');
    });

    test('XRechnung: Geschäftsprozess, Spezifikationskennung, Kontakt des Verkäufers', () {
      final doc = parse(sample(profile: EInvoiceProfile.xrechnung));
      expect(
        text(doc, '//ram:BusinessProcessSpecifiedDocumentContextParameter/ram:ID'),
        'urn:fdc:peppol.eu:2017:poacc:billing:01:1.0',
      );
      expect(
        text(doc, '//ram:GuidelineSpecifiedDocumentContextParameter/ram:ID'),
        'urn:cen.eu:en16931:2017#compliant#urn:xeinkauf.de:kosit:xrechnung_3.0',
      );
      final contact = doc.xpath('//ram:SellerTradeParty/ram:DefinedTradeContact').single;
      expect(contact.xpath('ram:TelephoneUniversalCommunication/ram:CompleteNumber').single.innerText, '03841 1');
      expect(contact.xpath('ram:EmailURIUniversalCommunication/ram:URIID').single.innerText, 'info@elektro.example');
    });

    test('§ 19 UStG: Kategorie E, 0 %, Befreiungsgrund und Hinweis', () {
      final doc = parse(sample(exempt: true));
      final tax = doc.xpath('//ram:ApplicableHeaderTradeSettlement/ram:ApplicableTradeTax').single;
      expect(tax.xpath('ram:CategoryCode').single.innerText, 'E');
      expect(tax.xpath('ram:RateApplicablePercent').single.innerText, '0');
      expect(tax.xpath('ram:CalculatedAmount').single.innerText, '0.00');
      expect(tax.xpath('ram:ExemptionReason').single.innerText, smallBusinessExemptionReason);
      // Reihenfolge nach CII-Schema: CalculatedAmount, TypeCode, ExemptionReason, BasisAmount, CategoryCode, Rate.
      expect(
        [for (final e in tax.childElements) e.name.local],
        ['CalculatedAmount', 'TypeCode', 'ExemptionReason', 'BasisAmount', 'CategoryCode', 'RateApplicablePercent'],
      );
      expect(
        doc.xpath('//rsm:ExchangedDocument/ram:IncludedNote/ram:Content').map((e) => e.innerText),
        contains('Gemäß § 19 Abs. 1 UStG wird keine Umsatzsteuer berechnet.'),
      );
      for (final line in doc.xpath('//ram:IncludedSupplyChainTradeLineItem')) {
        expect(line.xpath('.//ram:ApplicableTradeTax/ram:CategoryCode').single.innerText, 'E');
      }
      expect(text(doc, '//ram:GrandTotalAmount'), '141.88');
    });

    test('0 % ohne § 19 ist Kategorie Z', () {
      final doc = parse(sample(lines: [
        EInvoiceLine(description: 'Steuerfrei', quantity: Decimal.one, unitPriceCents: 500, vatRatePercent: 0),
      ]));
      expect(text(doc, '//ram:ApplicableHeaderTradeSettlement/ram:ApplicableTradeTax/ram:CategoryCode'), 'Z');
      expect(doc.xpath('//ram:ExemptionReason'), isEmpty);
    });

    test('Gutschrift: Typ 381 mit Bezug auf die korrigierte Rechnung', () {
      final doc = parse(sample(kind: 'creditNote', referenced: 'R-26001'));
      expect(text(doc, '//rsm:ExchangedDocument/ram:TypeCode'), '381');
      expect(text(doc, '//rsm:ExchangedDocument/ram:ID'), 'G-26001');
      final ref = doc.xpath('//ram:InvoiceReferencedDocument').single;
      expect(ref.xpath('ram:IssuerAssignedID').single.innerText, 'R-26001');
      expect(ref.xpath('ram:FormattedIssueDateTime/qdt:DateTimeString').single.innerText, '20261001');
      // Bezug steht nach der Summenaufstellung (Schema-Reihenfolge).
      final settlement = doc.xpath('//ram:ApplicableHeaderTradeSettlement').single;
      final names = [for (final e in settlement.childElements) e.name.local];
      expect(names.indexOf('InvoiceReferencedDocument'), greaterThan(names.indexOf('SpecifiedTradeSettlementHeaderMonetarySummation')));
    });

    test('Schlussrechnung: Abschläge als Vorauszahlung und Bezüge, Restbetrag', () {
      final doc = parse(sample(prior: const [
        EInvoicePriorPayment(invoiceNumber: 'R-26003', grossCents: 5000),
        EInvoicePriorPayment(invoiceNumber: 'R-26005', grossCents: 10000),
      ]));
      expect(text(doc, '//ram:TotalPrepaidAmount'), '150.00');
      expect(text(doc, '//ram:DuePayableAmount'), '16.44');
      expect(text(doc, '//ram:GrandTotalAmount'), '166.44');
      expect(
        doc.xpath('//ram:InvoiceReferencedDocument/ram:IssuerAssignedID').map((e) => e.innerText),
        ['R-26003', 'R-26005'],
      );
    });

    test('Sonderzeichen werden maskiert, Dateiname ist sicher', () {
      final doc = parse(sample(lines: [
        EInvoiceLine(description: 'Schalter <3 & "Dose"', quantity: Decimal.one, unitPriceCents: 100, vatRatePercent: 19),
      ]));
      expect(text(doc, '//ram:SpecifiedTradeProduct/ram:Name'), 'Schalter <3 & "Dose"');
      expect(eInvoiceXmlFileName('R-26/001'), 'R-26_001.xml');
      expect(eInvoiceXmlFileName(null), 'Entwurf.xml');
      expect(facturXAttachmentName, 'factur-x.xml');
    });

    test('Profile aus dem Kundenformat', () {
      expect(EInvoiceProfile.forFormat(EInvoiceFormat.zugferd), EInvoiceProfile.zugferdEn16931);
      expect(EInvoiceProfile.forFormat(EInvoiceFormat.xrechnung), EInvoiceProfile.xrechnung);
    });
  });
}
