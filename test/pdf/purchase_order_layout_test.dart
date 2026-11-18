import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:decimal/decimal.dart';
import 'package:werkkernerp/pdf/purchase_order_pdf_builder.dart';

const syntheticPng =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGP4z8DwHwAFAAH/iZk9HQAAAABJRU5ErkJggg==';

Future<String> pdfXml(Uint8List bytes) async {
  final directory = await Directory.systemTemp.createTemp(
    'purchase-order-layout-',
  );
  try {
    final file = File('${directory.path}/order.pdf');
    await file.writeAsBytes(bytes);
    final result = await Process.run('pdftohtml', [
      '-xml',
      '-stdout',
      file.path,
    ]);
    expect(result.exitCode, 0, reason: '${result.stderr}');
    return result.stdout as String;
  } finally {
    await directory.delete(recursive: true);
  }
}

PurchaseOrderPdfData orderData() => PurchaseOrderPdfData(
  number: 'SYN-PO-1',
  issueDate: DateTime(2026, 1, 2),
  supplierName: 'Synthetic Supplier',
  supplierAddress: 'Supplier Lane 7',
  ourCustomerNumber: 'CUST-7',
  companyName: 'Synthetic Company',
  companyAddress: 'Company Lane 1',
  items: const [],
);

int coordinate(String line, String attribute) =>
    int.parse(RegExp('$attribute="([0-9]+)"').firstMatch(line)!.group(1)!);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('configured supplier-order introduction and closing appear in PDF', () async {
    final data = PurchaseOrderPdfData(
      number: 'SYN-PO-1',
      issueDate: DateTime(2026, 1, 2),
      supplierName: 'Synthetic Supplier',
      companyName: 'Synthetic Company',
      introText: 'Bitte bestätigen Sie die Lieferung.',
      closingText: 'Wir freuen uns auf Ihre Rückmeldung.',
      items: const [],
    );
    final xml = await pdfXml(await buildPurchaseOrderPdfFromData(data));
    expect(xml, contains('Bitte bestätigen Sie die Lieferung.'));
    expect(xml, contains('Wir freuen uns auf Ihre Rückmeldung.'));
  });

  test(
    'rendered purchase order puts supplier left and company upper right',
    () async {
      final xml = await pdfXml(
        await buildPurchaseOrderPdfFromData(orderData()),
      );
      final lines = xml.split('\n');
      String line(String marker) => lines.firstWhere(
        (entry) =>
            entry.contains(marker) &&
            entry.contains('<text ') &&
            coordinate(entry, 'top') < 500,
      );
      final company = line('Synthetic Company');
      final supplier = line('Synthetic Supplier');
      expect(
        coordinate(company, 'left'),
        greaterThan(coordinate(supplier, 'left') + 150),
      );
      expect(coordinate(company, 'top'), lessThan(coordinate(supplier, 'top')));
      expect(xml, contains('CUST-7'));
    },
  );

  test('rendered logo is above and right-aligned with company', () async {
    final data = PurchaseOrderPdfData(
      number: 'SYN-PO-1',
      issueDate: DateTime(2026, 1, 2),
      supplierName: 'Synthetic Supplier',
      companyName: 'Synthetic Company',
      pdfLogoBase64: syntheticPng,
      items: const [],
    );
    final xml = await pdfXml(await buildPurchaseOrderPdfFromData(data));
    final lines = xml.split('\n');
    final image = lines.firstWhere((entry) => entry.contains('<image '));
    final company = lines.firstWhere(
      (entry) =>
          entry.contains('Synthetic Company') &&
          entry.contains('<text ') &&
          coordinate(entry, 'top') < 500,
    );
    final imageRight = coordinate(image, 'left') + coordinate(image, 'width');
    final companyRight =
        coordinate(company, 'left') + coordinate(company, 'width');
    expect((imageRight - companyRight).abs(), lessThan(20));
    expect(
      coordinate(company, 'top'),
      greaterThan(coordinate(image, 'top') + coordinate(image, 'height')),
    );
  });

  test(
    'configured three-column footer renders on every page below order items',
    () async {
      final data = PurchaseOrderPdfData(
        number: 'SYN-PO-1',
        issueDate: DateTime(2026, 1, 2),
        supplierName: 'Synthetic Supplier',
        companyName: 'Synthetic Company',
        companyIban: 'DE00 0000',
        footerColumns: const {
          'left': 'LEFT {{companyName}}',
          'center': 'CENTER {{iban}}',
          'right': 'RIGHT contact',
        },
        items: [
          for (var i = 0; i < 90; i++)
            (
              description: 'Synthetic item $i',
              quantity: Decimal.one,
              purchasePriceCents: 100,
              supplierArticleNumber: i == 0 ? 'SUP-1' : null,
            ),
        ],
        ourCustomerNumber: 'CUST-7',
      );
      final xml = await pdfXml(await buildPurchaseOrderPdfFromData(data));
      final pages = xml.split('<page ').skip(1).toList();
      expect(pages.length, greaterThan(1));
      for (final page in pages) {
        String row(String marker) =>
            page.split('\n').firstWhere((line) => line.contains(marker));
        final left = row('LEFT');
        final center = row('CENTER');
        final right = row('RIGHT');
        expect(coordinate(left, 'left'), lessThan(coordinate(center, 'left')));
        expect(coordinate(center, 'left'), lessThan(coordinate(right, 'left')));
        expect(coordinate(left, 'top'), greaterThan(900));
        final itemBottom = page
            .split('\n')
            .where(
              (line) =>
                  line.contains('Synthetic item ') && line.contains('<text '),
            )
            .map(
              (line) => coordinate(line, 'top') + coordinate(line, 'height'),
            );
        if (itemBottom.isNotEmpty) {
          expect(
            itemBottom.reduce((a, b) => a > b ? a : b),
            lessThan(coordinate(left, 'top')),
          );
        }
        expect(
          page
              .split('\n')
              .any(
                (line) =>
                    line.contains('Synthetic Company') &&
                    line.contains('<text ') &&
                    coordinate(line, 'top') < 500,
              ),
          isTrue,
          reason: 'Company letterhead must repeat on continuation pages',
        );
        expect(page, contains('Seite '));
        expect(page, isNot(contains('{{taxNumber}}')));
      }
      expect(xml, contains('SUP-1'));
      expect(xml, contains('CUST-7'));
    },
  );
}
