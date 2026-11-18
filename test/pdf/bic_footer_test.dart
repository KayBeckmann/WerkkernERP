import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:werkkern_client/werkkern_client.dart';
import 'package:werkkernerp/data/database/tables.dart';
import 'package:werkkernerp/pdf/invoice_pdf_builder.dart';
import 'package:werkkernerp/pdf/online_document_pdf.dart';
import 'package:werkkernerp/pdf/purchase_order_pdf_builder.dart';

import '../ui/online/online_test_server.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  PdfDocumentData data({String? bic}) => PdfDocumentData(
    kind: DocumentKind.invoice,
    issueDate: DateTime(2026), serviceDate: DateTime(2026),
    companySnapshotBic: bic, lines: const [],
  );

  test('BIC token uses configured value and removes missing BIC-only line', () {
    expect(interpolateFooter('Bank: {{bic}}', data(bic: 'GENODEF1XXX')), 'Bank: GENODEF1XXX');
    expect(interpolateFooter('Adresse\nBIC: {{bic}}', data()), 'Adresse');
  });

  test('online preview uses settings BIC but finalized PDF uses frozen BIC', () {
    OnlineDocument document(String status, {String? bic}) => OnlineDocument.fromJson({
      'id': 'd', 'customerId': 'c', 'kind': 'invoice', 'status': status,
      'issueDate': '2026-11-17', 'serviceDate': '2026-11-17', 'version': 1,
      'companySnapshot': {'name': 'Firma', 'bic': bic},
      'textSnapshot': {'footerColumns': {'center': 'BIC: {{bic}}'}},
    });
    const live = OnlineCompanyProfile(bic: 'NEWBIC', footerColumns: {'center': 'BIC: {{bic}}'});
    final preview = onlineDocumentPdfData(document('draft'), liveCompany: live);
    final finalized = onlineDocumentPdfData(document('finalized', bic: 'OLDBIC'), liveCompany: live);
    expect(interpolateFooter(preview.footerColumns!['center']!, preview), 'BIC: NEWBIC');
    expect(interpolateFooter(finalized.footerColumns!['center']!, finalized), 'BIC: OLDBIC');
  });

  test('online settings readback and finalization freeze BIC from profile', () async {
    final server = OnlineTestServer();
    final token = await server.seedCompany(
      email: 'bic@example.com', companyName: 'Firma',
      permissions: ['customers.read', 'customers.write', 'invoices.read', 'invoices.write', 'invoices.finalize'],
    );
    await server.put('/company/profile', {'bic': 'OLDBIC', 'footerColumns': {'center': 'BIC: {{bic}}'}}, token);
    final profile = await server.get('/company/profile', token);
    expect(profile['bic'], 'OLDBIC');
    final customer = await server.post('/customers', {'name': 'Kunde'}, token);
    final draft = await server.post('/documents', {'customerId': customer['id'], 'items': [
      {'kind': 'text', 'description': 'Leistung', 'quantity': '1', 'unitPriceCents': 100, 'vatRatePercent': 19},
    ]}, token);
    final finalized = await server.post('/documents/${draft['id']}/finalize', {'version': draft['version']}, token);
    await server.put('/company/profile', {'bic': 'NEWBIC'}, token);
    final document = OnlineDocument.fromJson(finalized);
    final pdfData = onlineDocumentPdfData(document, liveCompany: const OnlineCompanyProfile(bic: 'NEWBIC'));
    expect(interpolateFooter(pdfData.footerColumns!['center']!, pdfData), 'BIC: OLDBIC');
  });

  test('supplier order resolves BIC in PDF footer', () async {
    final bytes = await buildPurchaseOrderPdfFromData(PurchaseOrderPdfData(
      number: 'PO-BIC', issueDate: DateTime(2026), supplierName: 'Supplier',
      companyName: 'Firma', companyBic: 'GENODEF1XXX',
      footerColumns: const {'center': 'BIC: {{bic}}'}, items: const [],
    ));
    final dir = await Directory.systemTemp.createTemp('bic-footer-');
    try {
      final path = '${dir.path}/order.pdf';
      await File(path).writeAsBytes(bytes);
      final extracted = await Process.run('pdftotext', ['-layout', path, '-']);
      expect(extracted.exitCode, 0);
      expect(extracted.stdout, contains('BIC: GENODEF1XXX'));
    } finally {
      await dir.delete(recursive: true);
    }
  });

  test('long configured supplier footer renders BIC and final line', () async {
    final template = '${List.generate(10, (i) => 'Zeile $i').join('\n')}\nBIC: {{bic}}';
    final bytes = await buildPurchaseOrderPdfFromData(PurchaseOrderPdfData(
      number: 'PO-LONG', issueDate: DateTime(2026), supplierName: 'Supplier',
      companyName: 'Firma', companyBic: 'GENODEF1XXX',
      footerColumns: {'center': template}, items: const [],
    ));
    final dir = await Directory.systemTemp.createTemp('bic-long-');
    try {
      final path = '${dir.path}/order.pdf';
      await File(path).writeAsBytes(bytes);
      final extracted = await Process.run('pdftotext', ['-layout', path, '-']);
      expect(extracted.exitCode, 0);
      expect(extracted.stdout, contains('Zeile 0'));
      expect(extracted.stdout, contains('BIC: GENODEF1XXX'));
    } finally {
      await dir.delete(recursive: true);
    }
  });

  test('long configured footer keeps BIC token and other lines', () {
    final template = '${List.generate(14, (i) => 'Zeile $i').join('\n')}\nBIC: {{bic}}';
    final value = interpolateFooter(template, data(bic: 'GENODEF1XXX'));
    expect(value.split('\n').length, 15);
    expect(value, endsWith('BIC: GENODEF1XXX'));
  });
}
