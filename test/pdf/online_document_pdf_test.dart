import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:werkkern_client/werkkern_client.dart';
import 'package:werkkernerp/data/database/tables.dart';
import 'package:werkkernerp/pdf/online_document_pdf.dart';

import '../ui/online/online_test_server.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Finalisiertes Dokument aus dem ECHTEN Server-Router (In-Memory) —
  /// prüft die komplette Kette Server-JSON -> Client-Modell -> PDF-Daten.
  Future<OnlineDocument> finalizedFromServer() async {
    final server = OnlineTestServer();
    final token = await server.seedCompany(
      email: 'kay@example.com',
      companyName: 'Elektro Beckmann',
      permissions: ['customers.read', 'customers.write', 'invoices.read', 'invoices.write', 'invoices.finalize'],
    );
    await server.put('/company/profile', {'address': 'Musterstraße 1, 23966 Wismar', 'taxNumber': '123/456/78901'}, token);
    final customer = await server.post('/customers', {'name': 'Max Mustermann', 'address': 'Kundenweg 2'}, token);
    final draft = await server.post('/documents', {
      'customerId': customer['id'],
      'items': [
        {'kind': 'hours', 'description': 'Zählerschrank setzen', 'quantity': '3', 'unitPriceCents': 6500, 'vatRatePercent': 19, 'groupLabel': 'Arbeit'},
      ],
    }, token);
    final finalized = await server.post('/documents/${draft['id']}/finalize', {'version': draft['version']}, token);
    return OnlineDocument.fromJson(jsonDecode(jsonEncode(finalized)) as Map<String, Object?>);
  }

  test('Finalisiertes Online-Dokument: PDF-Daten nur aus den eingefrorenen Schnappschüssen', () async {
    final document = await finalizedFromServer();
    final data = onlineDocumentPdfData(
      document,
      // Absichtlich abweichende Live-Daten — dürfen NICHT verwendet werden.
      liveCompany: const OnlineCompanyProfile(name: 'Umbenannt', address: 'Neue Straße'),
      liveCustomer: const OnlineCustomer(id: 'x', name: 'Anderer Kunde'),
    );
    expect(data.kind, DocumentKind.invoice);
    expect(data.invoiceNumber, document.number);
    expect(data.companySnapshotName, 'Elektro Beckmann');
    expect(data.companySnapshotAddress, 'Musterstraße 1, 23966 Wismar');
    expect(data.companySnapshotTaxNumber, '123/456/78901');
    expect(data.customerSnapshotName, 'Max Mustermann');
    expect(data.customerSnapshotAddress, 'Kundenweg 2');
    expect(data.lines.single.groupLabel, 'Arbeit');

    final bytes = await buildOnlineDocumentPdf(document);
    expect(utf8.decode(bytes.sublist(0, 5), allowMalformed: true), '%PDF-');
    final dumpDir = Platform.environment['PDF_DUMP_DIR'];
    if (dumpDir != null) File('$dumpDir/online-final.pdf').writeAsBytesSync(bytes);
  });

  test('Entwurf: Vorschau mit Live-Stammdaten (kein Schnappschuss vorhanden)', () async {
    final document = OnlineDocument.fromJson({
      'id': 'd1',
      'customerId': 'c1',
      'kind': 'quote',
      'status': 'draft',
      'issueDate': '2026-10-24',
      'serviceDate': '2026-10-24',
      'version': 1,
      'customerName': 'Name aus Liste',
      'items': [
        {'kind': 'text', 'description': 'Pauschale', 'quantity': '1', 'unitPriceCents': 5000, 'vatRatePercent': 19},
      ],
    });
    final data = onlineDocumentPdfData(
      document,
      liveCompany: const OnlineCompanyProfile(name: 'Elektro Beckmann', iban: 'DE00'),
      liveCustomer: const OnlineCustomer(id: 'c1', name: 'Max Mustermann', vatId: 'DE123'),
    );
    expect(data.kind, DocumentKind.quote);
    expect(data.invoiceNumber, isNull);
    expect(data.companySnapshotIban, 'DE00');
    expect(data.customerSnapshotVatId, 'DE123');

    final bytes = await buildOnlineDocumentPdf(document, liveCompany: const OnlineCompanyProfile(name: 'Elektro Beckmann'));
    expect(utf8.decode(bytes.sublist(0, 5), allowMalformed: true), '%PDF-');
    final dumpDir = Platform.environment['PDF_DUMP_DIR'];
    if (dumpDir != null) File('$dumpDir/online-draft.pdf').writeAsBytesSync(bytes);
  });
}
