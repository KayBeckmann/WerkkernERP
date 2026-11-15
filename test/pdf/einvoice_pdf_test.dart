import 'dart:convert';
import 'dart:io';

import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:werkkern_core/werkkern_core.dart';
import 'package:werkkernerp/data/database/tables.dart' show DocumentKind;
import 'package:werkkernerp/pdf/invoice_pdf_builder.dart';

/// C15.3 ZUGFeRD-Hybrid-PDF: finalisierte Rechnung mit vollständigen
/// E-Rechnungsdaten bekommt eine eingebettete `factur-x.xml` samt PDF/A-3-
/// Metadaten; Entwurf und unvollständige Daten bleiben reines PDF.
/// Nachweis über poppler (`pdfdetach`) und `qpdf --check`, wenn vorhanden.
const _seller = EInvoiceParty(
  name: 'Elektro Beckmann',
  address: PostalAddress(street: 'Musterstraße 1', postalCode: '23966', city: 'Wismar'),
  taxNumber: '079/123/45678',
  email: 'info@elektro.example',
  phone: '03841 1',
  iban: 'DE02120300000000202051',
);
const _buyer = EInvoiceParty(
  name: 'Musterwerk GmbH',
  address: PostalAddress(street: 'Werkstraße 5', postalCode: '23970', city: 'Wismar'),
);

PdfDocumentData data({bool complete = true, DocumentKind kind = DocumentKind.invoice}) {
  final lines = [
    EInvoiceLine(description: 'Montage', quantity: Decimal.fromInt(2), unit: 'h', unitPriceCents: 6500, vatRatePercent: 19),
  ];
  return PdfDocumentData(
    kind: kind,
    invoiceNumber: 'R-26009',
    issueDate: DateTime(2026, 11, 16),
    serviceDate: DateTime(2026, 11, 10),
    companySnapshotName: 'Elektro Beckmann',
    companySnapshotAddress: 'Musterstraße 1, 23966 Wismar',
    customerSnapshotName: 'Musterwerk GmbH',
    customerSnapshotAddress: 'Werkstraße 5, 23970 Wismar',
    lines: const [PdfLine(description: 'Montage', quantity: '2', unit: 'h', unitPriceCents: 6500, vatRatePercent: 19)],
    eInvoice: EInvoiceData(
      profile: EInvoiceProfile.zugferdEn16931,
      kind: kind.name,
      number: 'R-26009',
      issueDate: DateTime(2026, 11, 16),
      serviceDate: DateTime(2026, 11, 10),
      dueDate: DateTime(2026, 11, 30),
      seller: _seller,
      buyer: complete ? _buyer : const EInvoiceParty(name: 'Musterwerk GmbH'),
      lines: lines,
    ),
  );
}

Future<bool> _has(String tool) async => (await Process.run('which', [tool])).exitCode == 0;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  setUp(() async => dir = await Directory.systemTemp.createTemp('werkkern-zugferd-'));
  tearDown(() => dir.delete(recursive: true));

  test('finalisierte Rechnung: factur-x.xml eingebettet, PDF/A-3-Metadaten, Anhang extrahierbar', () async {
    final bytes = await renderDocumentPdf(data(), isPreview: false);
    final text = latin1.decode(bytes, allowInvalid: true);
    expect(text, contains('/EmbeddedFiles'));
    expect(text, contains('factur-x.xml'));
    expect(text, contains('/AFRelationship'));
    expect(text, contains('urn:factur-x:pdfa:CrossIndustryDocument:invoice:1p0#'));
    expect(text, contains('<fx:ConformanceLevel>EN 16931</fx:ConformanceLevel>'));
    expect(text, contains('<pdfaid:part>3</pdfaid:part>'));
    expect(text, contains('/OutputIntent'));
    expect(pdfEmbedsEInvoice(data(), isPreview: false), isTrue);

    if (!await _has('pdfdetach')) return;
    final file = File('${dir.path}/rechnung.pdf')..writeAsBytesSync(bytes);
    final list = await Process.run('pdfdetach', ['-list', file.path]);
    expect(list.stdout.toString(), contains('factur-x.xml'));
    await Process.run('pdfdetach', ['-saveall', '-o', dir.path, file.path]);
    final xml = File('${dir.path}/factur-x.xml').readAsStringSync();
    expect(xml, contains('<rsm:CrossIndustryInvoice'));
    expect(xml, contains('<ram:ID>R-26009</ram:ID>'));
    expect(xml, contains('<ram:GrandTotalAmount>154.70</ram:GrandTotalAmount>'));
    if (await _has('qpdf')) {
      // Bekannte Eigenheit des pdf-Pakets: `PdfaAttachedFiles` legt neben
      // /EmbeddedFiles einen leeren /Dests-Namensbaum an, den qpdf als
      // Warnung (Exit 3) meldet. Alles andere muss sauber sein.
      final check = await Process.run('qpdf', ['--check', file.path]);
      final output = check.stdout.toString() + check.stderr.toString();
      expect(check.exitCode, anyOf(0, 3), reason: output);
      final warnings = output.split('\n').where((l) => l.startsWith('WARNING'));
      expect(warnings.where((l) => !l.contains('name/number tree node')), isEmpty, reason: output);
    }
  });

  test('Entwurf und unvollständige Daten: kein Anhang, keine PDF/A-Kennzeichnung', () async {
    final preview = latin1.decode(await renderDocumentPdf(data(), isPreview: true), allowInvalid: true);
    expect(preview, isNot(contains('/EmbeddedFiles')));
    expect(preview, isNot(contains('pdfaid')));
    final incomplete = data(complete: false);
    expect(eInvoiceProblems(incomplete.eInvoice!), contains('Kunde: Straße fehlt.'));
    expect(pdfEmbedsEInvoice(incomplete, isPreview: false), isFalse);
    final plain = latin1.decode(await renderDocumentPdf(incomplete, isPreview: false), allowInvalid: true);
    expect(plain, isNot(contains('/EmbeddedFiles')));
    expect(plain, contains('%PDF-'));
  });
}
