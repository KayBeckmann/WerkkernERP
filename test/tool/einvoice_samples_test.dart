import 'dart:io';

import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:werkkern_core/werkkern_core.dart';
import 'package:werkkernerp/data/database/tables.dart' show DocumentKind;
import 'package:werkkernerp/pdf/invoice_pdf_builder.dart';

/// C15.5 — schreibt Beispiel-E-Rechnungen für `tool/validate-einvoice.sh`
/// (amtliche Prüfung mit KoSIT-Validator und Mustang). Läuft nur mit
/// `EINVOICE_SAMPLES_DIR`, sonst übersprungen — `flutter test` bleibt
/// ohne Netz und ohne Java.
const _seller = EInvoiceParty(
  name: 'Elektro Beckmann',
  address: PostalAddress(street: 'Musterstraße 1', postalCode: '23966', city: 'Wismar'),
  vatId: 'DE123456789',
  taxNumber: '079/123/45678',
  email: 'info@elektro.example',
  phone: '03841 123456',
  iban: 'DE02120300000000202051',
  bic: 'BYLADEM1001',
);

const _buyer = EInvoiceParty(
  name: 'Stadt Wismar',
  address: PostalAddress(street: 'Am Markt 1', postalCode: '23966', city: 'Wismar'),
  email: 'rechnung@wismar.example',
  leitwegId: '04011000-1234512345-06',
  contactName: 'Erika Muster',
);

List<EInvoiceLine> _lines({bool exempt = false}) => [
      EInvoiceLine(
        description: 'Montage Unterverteilung',
        quantity: Decimal.fromInt(3),
        unit: 'h',
        unitPriceCents: 6500,
        vatRatePercent: exempt ? 0 : 19,
        discountPercent: 10,
      ),
      EInvoiceLine(
        description: 'NYM-J 3x1,5',
        quantity: Decimal.parse('12.5'),
        unit: 'm',
        unitPriceCents: 255,
        vatRatePercent: exempt ? 0 : 19,
        groupLabel: 'Material',
      ),
      EInvoiceLine(
        description: 'Fachbuch VDE 0100',
        quantity: Decimal.one,
        unit: 'Stk',
        unitPriceCents: 4990,
        vatRatePercent: exempt ? 0 : 7,
      ),
    ];

EInvoiceData _sample(
  EInvoiceProfile profile, {
  String kind = 'invoice',
  String number = 'R-26001',
  bool exempt = false,
  List<EInvoicePriorPayment> prior = const [],
  String? referenced,
}) =>
    EInvoiceData(
      profile: profile,
      kind: kind,
      number: number,
      issueDate: DateTime(2026, 11, 16),
      serviceDate: DateTime(2026, 11, 12),
      dueDate: DateTime(2026, 11, 30),
      paymentTerms: 'Zahlbar innerhalb 14 Tagen ohne Abzug.',
      seller: _seller,
      buyer: _buyer,
      smallBusinessExempt: exempt,
      priorPayments: prior,
      referencedInvoiceNumber: referenced,
      referencedInvoiceDate: referenced == null ? null : DateTime(2026, 11, 1),
      lines: _lines(exempt: exempt),
    );

Map<String, EInvoiceData> _samples(EInvoiceProfile p) => {
      'rechnung': _sample(p),
      'kleinunternehmer': _sample(p, number: 'R-26002', exempt: true),
      'gutschrift': _sample(p, kind: 'creditNote', number: 'G-26001', referenced: 'R-26001'),
      'schlussrechnung': _sample(p, number: 'R-26004', prior: const [
        EInvoicePriorPayment(invoiceNumber: 'R-26003', grossCents: 10000),
      ]),
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final target = Platform.environment['EINVOICE_SAMPLES_DIR'];

  test('Beispiel-E-Rechnungen schreiben', () async {
    final dir = Directory(target!)..createSync(recursive: true);
    for (final e in _samples(EInvoiceProfile.xrechnung).entries) {
      expect(eInvoiceProblems(e.value), isEmpty, reason: e.key);
      File('${dir.path}/xrechnung-${e.key}.xml').writeAsStringSync(buildEInvoiceXml(e.value));
    }
    for (final e in _samples(EInvoiceProfile.zugferdEn16931).entries) {
      File('${dir.path}/zugferd-${e.key}.xml').writeAsStringSync(buildEInvoiceXml(e.value));
      final data = e.value;
      final bytes = await renderDocumentPdf(
        PdfDocumentData(
          kind: data.isCreditNote ? DocumentKind.creditNote : DocumentKind.invoice,
          invoiceNumber: data.number,
          issueDate: data.issueDate,
          serviceDate: data.serviceDate,
          companySnapshotName: data.seller.name,
          companySnapshotAddress: data.seller.address.display,
          companySnapshotTaxNumber: data.seller.taxNumber,
          companySnapshotVatId: data.seller.vatId,
          companySnapshotIban: data.seller.iban,
          customerSnapshotName: data.buyer.name,
          customerSnapshotAddress: data.buyer.address.display,
          paymentTerms: data.paymentTerms,
          isSmallBusinessExempt: data.smallBusinessExempt,
          lines: [
            for (final l in data.lines)
              PdfLine(
                description: l.description,
                quantity: l.quantity.toString(),
                unit: l.unit,
                unitPriceCents: l.unitPriceCents,
                vatRatePercent: l.vatRatePercent,
                discountPercent: l.discountPercent,
                groupLabel: l.groupLabel,
              ),
          ],
          eInvoice: data,
        ),
        isPreview: false,
      );
      File('${dir.path}/zugferd-${e.key}.pdf').writeAsBytesSync(bytes);
    }
  }, skip: target == null ? 'EINVOICE_SAMPLES_DIR nicht gesetzt' : null);
}
