/// C15.2 E-Rechnung — Erzeugung des EN-16931-XML in der Syntax
/// UN/CEFACT Cross Industry Invoice (CII, D16B) für zwei Profile:
/// ZUGFeRD 2.x „EN 16931“ (Hybrid-PDF, Datei `factur-x.xml`) und
/// XRechnung 3.0 (reines XML). Reines Dart ohne Abhängigkeiten, damit
/// Offline-App und Server identische Dateien erzeugen.
///
/// Beträge kommen ausschließlich aus [calculateInvoiceTotals] — derselbe
/// Rechenkern wie PDF und Server (F2: nie neu gerechnet). Arbeitsvorgabe,
/// keine Rechtsprüfung (F1): syntaktisch gültig nach den amtlichen
/// Prüfregeln, die fachliche Abnahme bleibt beim Steuerberater.
library;

import 'package:decimal/decimal.dart';

import 'einvoice_party.dart';
import 'invoice_totals.dart';
import 'money.dart';

/// Zielprofil der Datei.
enum EInvoiceProfile {
  /// ZUGFeRD 2.x, Profil EN 16931 (= Factur-X EN 16931).
  zugferdEn16931,

  /// XRechnung 3.0, CII-Syntax.
  xrechnung;

  /// BT-24 Spezifikationskennung.
  String get guidelineId => switch (this) {
        EInvoiceProfile.zugferdEn16931 => 'urn:cen.eu:en16931:2017',
        EInvoiceProfile.xrechnung => 'urn:cen.eu:en16931:2017#compliant#urn:xeinkauf.de:kosit:xrechnung_3.0',
      };

  static EInvoiceProfile forFormat(EInvoiceFormat format) => switch (format) {
        EInvoiceFormat.zugferd => EInvoiceProfile.zugferdEn16931,
        EInvoiceFormat.xrechnung => EInvoiceProfile.xrechnung,
      };
}

/// Eine Position (BG-25). [quantity] als Dezimalzahl, [unit] Freitext
/// („Stk“, „h“), wird über [unitCodeFor] auf UN/ECE Rec 20 abgebildet.
class EInvoiceLine {
  const EInvoiceLine({
    required this.description,
    required this.quantity,
    this.unit,
    required this.unitPriceCents,
    required this.vatRatePercent,
    this.discountPercent = 0,
    this.groupLabel,
    this.articleNumber,
  });

  final String description;
  final Decimal quantity;
  final String? unit;
  final int unitPriceCents;
  final double vatRatePercent;
  final double discountPercent;
  final String? groupLabel;

  /// Artikelnummer des Verkäufers (BT-155), optional.
  final String? articleNumber;

  InvoiceLineInput get totalsInput => InvoiceLineInput(
        quantity: quantity,
        unitPriceCents: unitPriceCents,
        vatRatePercent: vatRatePercent,
        discountPercent: discountPercent,
      );
}

/// Bereits gestellte Abschlagsrechnung (BG-3 + BT-113).
class EInvoicePriorPayment {
  const EInvoicePriorPayment({required this.invoiceNumber, required this.grossCents, this.issueDate});
  final String invoiceNumber;
  final int grossCents;
  final DateTime? issueDate;
}

/// Alle Angaben einer E-Rechnung — neutral gegenüber Drift/Server.
class EInvoiceData {
  const EInvoiceData({
    required this.profile,
    required this.kind,
    required this.number,
    required this.issueDate,
    required this.serviceDate,
    this.dueDate,
    this.paymentTerms,
    this.notes,
    required this.seller,
    required this.buyer,
    required this.lines,
    this.smallBusinessExempt = false,
    this.isAdvancePayment = false,
    this.priorPayments = const [],
    this.referencedInvoiceNumber,
    this.referencedInvoiceDate,
    this.currency = 'EUR',
  });

  final EInvoiceProfile profile;

  /// `invoice` oder `creditNote`.
  final String kind;

  /// Rechnungsnummer (BT-1), `null` bei Entwürfen (dann [eInvoiceProblems]).
  final String? number;
  final DateTime issueDate;
  final DateTime serviceDate;
  final DateTime? dueDate;
  final String? paymentTerms;
  final String? notes;
  final EInvoiceParty seller;
  final EInvoiceParty buyer;
  final List<EInvoiceLine> lines;

  /// Kleinunternehmerregelung § 19 UStG: Kategorie `E` mit Befreiungsgrund.
  final bool smallBusinessExempt;

  /// Abschlagsrechnung (Hinweis in BT-22).
  final bool isAdvancePayment;

  /// Schlussrechnung: bereits gezahlte Abschläge (BT-113) mit Bezug (BG-3).
  final List<EInvoicePriorPayment> priorPayments;

  /// Gutschrift: korrigierte Rechnung (BT-25).
  final String? referencedInvoiceNumber;
  final DateTime? referencedInvoiceDate;
  final String currency;

  InvoiceTotals get totals => calculateInvoiceTotals([for (final l in lines) l.totalsInput]);

  bool get isCreditNote => kind == 'creditNote';
}

/// Einheiten nach UN/ECE Recommendation 20 — unbekannte Einheiten werden
/// `C62` („Stück“), damit die Datei gültig bleibt.
String unitCodeFor(String? unit) {
  final u = (unit ?? '').trim().toLowerCase().replaceAll('.', '');
  return switch (u) {
    '' || 'stk' || 'stück' || 'stueck' || 'st' || 'pc' || 'pcs' || 'piece' => 'C62',
    'h' || 'std' || 'stunde' || 'stunden' || 'hour' => 'HUR',
    'min' || 'minute' || 'minuten' => 'MIN',
    'tag' || 'tage' || 'day' || 'days' => 'DAY',
    'm' || 'meter' || 'lfm' => 'MTR',
    'm2' || 'm²' || 'qm' => 'MTK',
    'm3' || 'm³' => 'MTQ',
    'cm' => 'CMT',
    'mm' => 'MMT',
    'km' => 'KMT',
    'kg' => 'KGM',
    'g' => 'GRM',
    't' => 'TNE',
    'l' || 'liter' => 'LTR',
    'ml' => 'MLT',
    'kwh' => 'KWH',
    'psch' || 'pausch' || 'pauschal' || 'pauschale' || 'ls' => 'LS',
    'set' || 'satz' => 'SET',
    'pack' || 'paket' || 'pck' => 'XPK',
    'rolle' || 'rol' => 'RO',
    'paar' || 'pr' => 'PR',
    'karton' || 'kt' => 'CT',
    'monat' || 'monate' || 'mon' => 'MON',
    'woche' || 'wochen' => 'WEE',
    'jahr' || 'jahre' => 'ANN',
    _ => 'C62',
  };
}

/// Steuerkategorie je Position (BT-151): `S` normal, `Z` 0 % ohne
/// Befreiung, `E` befreit (§ 19 UStG).
String taxCategoryFor({required double ratePercent, required bool smallBusinessExempt}) {
  if (smallBusinessExempt) return 'E';
  return ratePercent == 0 ? 'Z' : 'S';
}

const smallBusinessExemptionReason = 'Kleinunternehmer gemäß § 19 UStG';

/// Dateiname der XML-Datei (XRechnung-Export); im ZUGFeRD-PDF heißt die
/// eingebettete Datei immer `factur-x.xml`.
String eInvoiceXmlFileName(String? number) {
  final base = (number ?? 'Entwurf').replaceAll(RegExp(r'[^A-Za-z0-9_.-]'), '_');
  return '$base.xml';
}

const facturXAttachmentName = 'factur-x.xml';

// ---------------------------------------------------------------------------
// Pflichtfeldprüfung
// ---------------------------------------------------------------------------

/// Fehlende Pflichtangaben als deutsche Hinweise — leer = die Datei
/// erfüllt die Pflichtfelder von EN 16931 bzw. XRechnung, soweit die
/// App sie kennt. Die amtlichen Prüfregeln (C15.5) bleiben maßgeblich.
List<String> eInvoiceProblems(EInvoiceData d) {
  final problems = <String>[];
  final xr = d.profile == EInvoiceProfile.xrechnung;
  if (!isEInvoiceDocumentKind(d.kind)) problems.add('Nur Rechnungen und Gutschriften sind E-Rechnungen.');
  if (d.number == null || d.number!.trim().isEmpty) problems.add('Dokument ist noch nicht finalisiert (keine Nummer).');
  if (d.lines.isEmpty) problems.add('Keine Positionen.');
  for (final (i, line) in d.lines.indexed) {
    if (line.description.trim().isEmpty) problems.add('Position ${i + 1}: Beschreibung fehlt.');
    if (line.quantity <= Decimal.zero) problems.add('Position ${i + 1}: Menge muss größer 0 sein.');
    if (d.smallBusinessExempt && line.vatRatePercent != 0) {
      problems.add('Position ${i + 1}: § 19 UStG aktiv, aber Steuersatz ${line.vatRatePercent.toStringAsFixed(0)} %.');
    }
  }
  problems.addAll(_partyProblems(d.seller, 'Verkäufer', requireContact: xr));
  if (_blank(d.seller.vatId) && _blank(d.seller.taxNumber)) {
    problems.add('Verkäufer: USt-IdNr. oder Steuernummer fehlt.');
  }
  problems.addAll(_partyProblems(d.buyer, 'Kunde', requireContact: false));
  if (xr) {
    if (_blank(d.buyer.leitwegId)) problems.add('Kunde: Leitweg-ID / Käuferreferenz fehlt (XRechnung).');
    if (_blank(d.buyer.email)) problems.add('Kunde: E-Mail fehlt (XRechnung braucht eine elektronische Adresse).');
    if (_blank(d.seller.iban)) problems.add('Verkäufer: IBAN fehlt (XRechnung verlangt eine Zahlungsangabe).');
    if (d.dueDate == null && _blank(d.paymentTerms) && !d.isCreditNote) {
      problems.add('Fälligkeitsdatum oder Zahlungsbedingungen fehlen (XRechnung).');
    }
  }
  if (d.isCreditNote && _blank(d.referencedInvoiceNumber)) {
    problems.add('Gutschrift: Bezug zur korrigierten Rechnung fehlt.');
  }
  return problems;
}

List<String> _partyProblems(EInvoiceParty p, String label, {required bool requireContact}) => [
      if (_blank(p.name)) '$label: Name fehlt.',
      if (_blank(p.address.street)) '$label: Straße fehlt.',
      if (_blank(p.address.postalCode)) '$label: PLZ fehlt.',
      if (_blank(p.address.city)) '$label: Ort fehlt.',
      if (p.address.countryCode.length != 2) '$label: Ländercode (2 Buchstaben) fehlt.',
      if (requireContact && _blank(p.email)) '$label: E-Mail fehlt.',
      if (requireContact && _blank(p.phone)) '$label: Telefon fehlt.',
    ];

bool _blank(String? s) => s == null || s.trim().isEmpty;

// ---------------------------------------------------------------------------
// XML-Erzeugung
// ---------------------------------------------------------------------------

/// Erzeugt das CII-XML. Wirft [StateError], wenn Pflichtangaben fehlen
/// (vorher [eInvoiceProblems] anzeigen); mit [allowProblems] entsteht
/// die Datei trotzdem (nur für Vorschau/Prüfwerkzeuge).
String buildEInvoiceXml(EInvoiceData d, {bool allowProblems = false}) {
  final problems = eInvoiceProblems(d);
  if (problems.isNotEmpty && !allowProblems) {
    throw StateError('E-Rechnung unvollständig: ${problems.join(' ')}');
  }
  final totals = d.totals;
  final b = _Xml();
  final xr = d.profile == EInvoiceProfile.xrechnung;

  b.line('<?xml version="1.0" encoding="UTF-8"?>');
  b.open('rsm:CrossIndustryInvoice', {
    'xmlns:rsm': 'urn:un:unece:uncefact:data:standard:CrossIndustryInvoice:100',
    'xmlns:ram': 'urn:un:unece:uncefact:data:standard:ReusableAggregateBusinessInformationEntity:100',
    'xmlns:udt': 'urn:un:unece:uncefact:data:standard:UnqualifiedDataType:100',
    'xmlns:qdt': 'urn:un:unece:uncefact:data:standard:QualifiedDataType:100',
  });

  // ---- Kontext (BG-2)
  b.open('rsm:ExchangedDocumentContext');
  if (xr) {
    b.open('ram:BusinessProcessSpecifiedDocumentContextParameter');
    b.leaf('ram:ID', 'urn:fdc:peppol.eu:2017:poacc:billing:01:1.0');
    b.close('ram:BusinessProcessSpecifiedDocumentContextParameter');
  }
  b.open('ram:GuidelineSpecifiedDocumentContextParameter');
  b.leaf('ram:ID', d.profile.guidelineId);
  b.close('ram:GuidelineSpecifiedDocumentContextParameter');
  b.close('rsm:ExchangedDocumentContext');

  // ---- Dokument (BG-1)
  b.open('rsm:ExchangedDocument');
  b.leaf('ram:ID', d.number ?? 'ENTWURF');
  b.leaf('ram:TypeCode', d.isCreditNote ? '381' : '380');
  b.open('ram:IssueDateTime');
  b.leaf('udt:DateTimeString', _date(d.issueDate), {'format': '102'});
  b.close('ram:IssueDateTime');
  final notes = <String>[
    if (d.isAdvancePayment) 'Abschlagsrechnung',
    if (d.smallBusinessExempt) 'Gemäß § 19 Abs. 1 UStG wird keine Umsatzsteuer berechnet.',
    if (!_blank(d.notes)) d.notes!.trim(),
  ];
  for (final note in notes) {
    b.open('ram:IncludedNote');
    b.leaf('ram:Content', note);
    b.close('ram:IncludedNote');
  }
  b.close('rsm:ExchangedDocument');

  // ---- Transaktion
  b.open('rsm:SupplyChainTradeTransaction');
  for (final (index, line) in d.lines.indexed) {
    _writeLine(b, d, index + 1, line);
  }

  // Vereinbarung (BG-4 Verkäufer, BG-7 Käufer, BT-10)
  b.open('ram:ApplicableHeaderTradeAgreement');
  if (!_blank(d.buyer.leitwegId)) b.leaf('ram:BuyerReference', d.buyer.leitwegId!.trim());
  _writeParty(b, 'ram:SellerTradeParty', d.seller, isSeller: true);
  _writeParty(b, 'ram:BuyerTradeParty', d.buyer, isSeller: false);
  b.close('ram:ApplicableHeaderTradeAgreement');

  // Lieferung (BT-72 Leistungsdatum)
  b.open('ram:ApplicableHeaderTradeDelivery');
  b.open('ram:ActualDeliverySupplyChainEvent');
  b.open('ram:OccurrenceDateTime');
  b.leaf('udt:DateTimeString', _date(d.serviceDate), {'format': '102'});
  b.close('ram:OccurrenceDateTime');
  b.close('ram:ActualDeliverySupplyChainEvent');
  b.close('ram:ApplicableHeaderTradeDelivery');

  // Abrechnung (BG-16 Zahlung, BG-23 Steuern, BG-22 Summen, BG-3 Bezüge)
  b.open('ram:ApplicableHeaderTradeSettlement');
  b.leaf('ram:InvoiceCurrencyCode', d.currency);
  if (!_blank(d.seller.iban)) {
    b.open('ram:SpecifiedTradeSettlementPaymentMeans');
    b.leaf('ram:TypeCode', '58');
    b.open('ram:PayeePartyCreditorFinancialAccount');
    b.leaf('ram:IBANID', d.seller.iban!.replaceAll(' ', ''));
    b.close('ram:PayeePartyCreditorFinancialAccount');
    if (!_blank(d.seller.bic)) {
      b.open('ram:PayeeSpecifiedCreditorFinancialInstitution');
      b.leaf('ram:BICID', d.seller.bic!.trim());
      b.close('ram:PayeeSpecifiedCreditorFinancialInstitution');
    }
    b.close('ram:SpecifiedTradeSettlementPaymentMeans');
  }
  for (final rate in totals.sortedRates) {
    final category = taxCategoryFor(ratePercent: rate, smallBusinessExempt: d.smallBusinessExempt);
    b.open('ram:ApplicableTradeTax');
    b.leaf('ram:CalculatedAmount', _amount(totals.taxByRate[rate]!));
    b.leaf('ram:TypeCode', 'VAT');
    if (category == 'E') b.leaf('ram:ExemptionReason', smallBusinessExemptionReason);
    b.leaf('ram:BasisAmount', _amount(totals.netByRate[rate]!));
    b.leaf('ram:CategoryCode', category);
    b.leaf('ram:RateApplicablePercent', _percent(rate));
    b.close('ram:ApplicableTradeTax');
  }
  if (!_blank(d.paymentTerms) || d.dueDate != null) {
    b.open('ram:SpecifiedTradePaymentTerms');
    if (!_blank(d.paymentTerms)) b.leaf('ram:Description', d.paymentTerms!.trim());
    if (d.dueDate != null) {
      b.open('ram:DueDateDateTime');
      b.leaf('udt:DateTimeString', _date(d.dueDate!), {'format': '102'});
      b.close('ram:DueDateDateTime');
    }
    b.close('ram:SpecifiedTradePaymentTerms');
  }
  final prepaid = d.priorPayments.fold<int>(0, (sum, p) => sum + p.grossCents);
  final grand = totals.totalGross.cents;
  b.open('ram:SpecifiedTradeSettlementHeaderMonetarySummation');
  b.leaf('ram:LineTotalAmount', _amount(totals.totalNet));
  b.leaf('ram:TaxBasisTotalAmount', _amount(totals.totalNet));
  b.leaf('ram:TaxTotalAmount', _amount(totals.totalTax), {'currencyID': d.currency});
  b.leaf('ram:GrandTotalAmount', _amount(totals.totalGross));
  if (prepaid != 0) b.leaf('ram:TotalPrepaidAmount', _cents(prepaid));
  b.leaf('ram:DuePayableAmount', _cents(grand - prepaid));
  b.close('ram:SpecifiedTradeSettlementHeaderMonetarySummation');
  if (!_blank(d.referencedInvoiceNumber)) {
    _writeReference(b, d.referencedInvoiceNumber!, d.referencedInvoiceDate);
  }
  for (final p in d.priorPayments) {
    _writeReference(b, p.invoiceNumber, p.issueDate);
  }
  b.close('ram:ApplicableHeaderTradeSettlement');
  b.close('rsm:SupplyChainTradeTransaction');
  b.close('rsm:CrossIndustryInvoice');
  return b.toString();
}

void _writeReference(_Xml b, String number, DateTime? date) {
  b.open('ram:InvoiceReferencedDocument');
  b.leaf('ram:IssuerAssignedID', number);
  if (date != null) {
    b.open('ram:FormattedIssueDateTime');
    b.leaf('qdt:DateTimeString', _date(date), {'format': '102'});
    b.close('ram:FormattedIssueDateTime');
  }
  b.close('ram:InvoiceReferencedDocument');
}

void _writeLine(_Xml b, EInvoiceData d, int number, EInvoiceLine line) {
  final input = line.totalsInput;
  final grossUnit = Money.fromCents(line.unitPriceCents);
  // Netto-Einzelpreis (BT-146) mit 4 Nachkommastellen, Rabatt je Einheit (BT-147).
  final unitDiscount = line.discountPercent == 0
      ? Decimal.zero
      : (Decimal.fromInt(line.unitPriceCents) * Decimal.parse(line.discountPercent.toString()) /
              Decimal.fromInt(10000))
          .toDecimal(scaleOnInfinitePrecision: 6);
  final netUnit = (Decimal.fromInt(line.unitPriceCents) / Decimal.fromInt(100)).toDecimal() - unitDiscount;

  b.open('ram:IncludedSupplyChainTradeLineItem');
  b.open('ram:AssociatedDocumentLineDocument');
  b.leaf('ram:LineID', '$number');
  if (!_blank(line.groupLabel)) {
    b.open('ram:IncludedNote');
    b.leaf('ram:Content', 'Gruppe: ${line.groupLabel!.trim()}');
    b.close('ram:IncludedNote');
  }
  b.close('ram:AssociatedDocumentLineDocument');
  b.open('ram:SpecifiedTradeProduct');
  if (!_blank(line.articleNumber)) b.leaf('ram:SellerAssignedID', line.articleNumber!.trim());
  b.leaf('ram:Name', line.description.trim().isEmpty ? 'Position $number' : line.description.trim());
  b.close('ram:SpecifiedTradeProduct');
  b.open('ram:SpecifiedLineTradeAgreement');
  if (line.discountPercent != 0) {
    b.open('ram:GrossPriceProductTradePrice');
    b.leaf('ram:ChargeAmount', _amount(grossUnit));
    b.open('ram:AppliedTradeAllowanceCharge');
    b.open('ram:ChargeIndicator');
    b.leaf('udt:Indicator', 'false');
    b.close('ram:ChargeIndicator');
    b.leaf('ram:ActualAmount', _decimal(unitDiscount, 4));
    b.leaf('ram:Reason', 'Rabatt ${_percent(line.discountPercent)} %');
    b.close('ram:AppliedTradeAllowanceCharge');
    b.close('ram:GrossPriceProductTradePrice');
  }
  b.open('ram:NetPriceProductTradePrice');
  b.leaf('ram:ChargeAmount', _decimal(netUnit, 4));
  b.close('ram:NetPriceProductTradePrice');
  b.close('ram:SpecifiedLineTradeAgreement');
  b.open('ram:SpecifiedLineTradeDelivery');
  b.leaf('ram:BilledQuantity', _decimal(line.quantity, 4), {'unitCode': unitCodeFor(line.unit)});
  b.close('ram:SpecifiedLineTradeDelivery');
  b.open('ram:SpecifiedLineTradeSettlement');
  b.open('ram:ApplicableTradeTax');
  b.leaf('ram:TypeCode', 'VAT');
  b.leaf('ram:CategoryCode', taxCategoryFor(ratePercent: line.vatRatePercent, smallBusinessExempt: d.smallBusinessExempt));
  b.leaf('ram:RateApplicablePercent', _percent(line.vatRatePercent));
  b.close('ram:ApplicableTradeTax');
  b.open('ram:SpecifiedTradeSettlementLineMonetarySummation');
  b.leaf('ram:LineTotalAmount', _amount(input.lineNet));
  b.close('ram:SpecifiedTradeSettlementLineMonetarySummation');
  b.close('ram:SpecifiedLineTradeSettlement');
  b.close('ram:IncludedSupplyChainTradeLineItem');
}

void _writeParty(_Xml b, String element, EInvoiceParty p, {required bool isSeller}) {
  b.open(element);
  b.leaf('ram:Name', p.name.trim());
  if (isSeller || !_blank(p.contactName)) {
    b.open('ram:DefinedTradeContact');
    b.leaf('ram:PersonName', _blank(p.contactName) ? p.name.trim() : p.contactName!.trim());
    if (!_blank(p.phone)) {
      b.open('ram:TelephoneUniversalCommunication');
      b.leaf('ram:CompleteNumber', p.phone!.trim());
      b.close('ram:TelephoneUniversalCommunication');
    }
    if (!_blank(p.email)) {
      b.open('ram:EmailURIUniversalCommunication');
      b.leaf('ram:URIID', p.email!.trim());
      b.close('ram:EmailURIUniversalCommunication');
    }
    b.close('ram:DefinedTradeContact');
  }
  b.open('ram:PostalTradeAddress');
  if (!_blank(p.address.postalCode)) b.leaf('ram:PostcodeCode', p.address.postalCode!.trim());
  if (!_blank(p.address.street)) b.leaf('ram:LineOne', p.address.street!.trim());
  if (!_blank(p.address.city)) b.leaf('ram:CityName', p.address.city!.trim());
  b.leaf('ram:CountryID', p.address.countryCode.toUpperCase());
  b.close('ram:PostalTradeAddress');
  if (!_blank(p.email)) {
    b.open('ram:URIUniversalCommunication');
    b.leaf('ram:URIID', p.email!.trim(), {'schemeID': 'EM'});
    b.close('ram:URIUniversalCommunication');
  }
  if (isSeller && !_blank(p.taxNumber)) {
    b.open('ram:SpecifiedTaxRegistration');
    b.leaf('ram:ID', p.taxNumber!.trim(), {'schemeID': 'FC'});
    b.close('ram:SpecifiedTaxRegistration');
  }
  if (!_blank(p.vatId)) {
    b.open('ram:SpecifiedTaxRegistration');
    b.leaf('ram:ID', p.vatId!.replaceAll(' ', ''), {'schemeID': 'VA'});
    b.close('ram:SpecifiedTaxRegistration');
  }
  b.close(element);
}

String _date(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';

/// Betrag mit Punkt und zwei Nachkommastellen (BR-DEC), Vorzeichen bleibt.
String _cents(int cents) {
  final sign = cents < 0 ? '-' : '';
  final abs = cents.abs();
  return '$sign${abs ~/ 100}.${(abs % 100).toString().padLeft(2, '0')}';
}

String _amount(Money m) => _cents(m.cents);

String _decimal(Decimal value, int maxScale) {
  var s = value.toStringAsFixed(maxScale);
  if (s.contains('.')) {
    s = s.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
  }
  return s.isEmpty ? '0' : s;
}

String _percent(double p) => p == p.roundToDouble() ? p.toStringAsFixed(0) : p.toString();

/// Minimaler XML-Schreiber mit korrektem Escaping und Einrückung.
class _Xml {
  final _buf = StringBuffer();
  var _depth = 0;

  void line(String raw) => _buf.writeln(raw);

  void open(String name, [Map<String, String> attributes = const {}]) {
    _buf.writeln('${'  ' * _depth}<$name${_attrs(attributes)}>');
    _depth++;
  }

  void close(String name) {
    _depth--;
    _buf.writeln('${'  ' * _depth}</$name>');
  }

  void leaf(String name, String text, [Map<String, String> attributes = const {}]) {
    _buf.writeln('${'  ' * _depth}<$name${_attrs(attributes)}>${_escape(text)}</$name>');
  }

  String _attrs(Map<String, String> attributes) =>
      [for (final e in attributes.entries) ' ${e.key}="${_escape(e.value)}"'].join();

  static String _escape(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');

  @override
  String toString() => _buf.toString();
}
