import 'dart:convert';

import 'package:test/test.dart';
import 'package:werkkern_client/werkkern_client.dart';

import 'support/module_harness.dart';

void main() => runEInvoiceSnapshotTests(inMemoryRepositories);

/// C15.1 E-Rechnung (Kay 2026-11-15): strukturierte Stammdaten am Kunden
/// und im Firmenprofil, Parteien-Schnappschuss beim Finalisieren.
void runEInvoiceSnapshotTests(RepositoryFactory create) {
  final h = ModuleHarness(create)..install();
  const permissions = ['customers.read', 'customers.write', 'invoices.read', 'invoices.write', 'invoices.finalize'];
  Matcher status(int code) => throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', code));

  test('Kunde: Anschrift strukturiert, Leitweg-ID, Format; ältere Clients löschen nichts', () async {
    final c = await h.company('e1@example.com', permissions: permissions, modules: {'eInvoice', 'quotes'});
    final created = await c.post('/customers', {
      'name': 'Stadt Wismar',
      'address': 'Am Markt 1, 23966 Wismar',
      'street': 'Am Markt 1',
      'postalCode': '23966',
      'city': 'Wismar',
      'countryCode': 'de',
      'leitwegId': '04011000-1234512345-06',
      'eInvoiceFormat': 'xrechnung',
    });
    expect(created['countryCode'], 'DE', reason: 'Ländercode wird groß geschrieben');
    expect(created['eInvoiceFormat'], 'xrechnung');
    expect(created['leitwegId'], '04011000-1234512345-06');

    final legacy = await c.put('/customers/${created['id']}', {'name': 'Stadt Wismar', 'email': 'post@example.org'});
    expect(legacy['street'], 'Am Markt 1', reason: 'nicht genannt = unverändert');
    expect(legacy['eInvoiceFormat'], 'xrechnung');

    final unknownFormat = await c.put('/customers/${created['id']}', {'name': 'Stadt Wismar', 'eInvoiceFormat': 'unsinn'});
    expect(unknownFormat['eInvoiceFormat'], 'zugferd', reason: 'unbekannt fällt auf die Vorgabe zurück');
  });

  test('Firmenprofil: Straße/PLZ/Ort/Land/BIC, alte Clients behalten sie', () async {
    final c = await h.company('e2@example.com', permissions: permissions);
    final saved = await c.put('/company/profile', {
      'address': 'Musterstraße 1, 23966 Wismar',
      'iban': 'DE02120300000000202051',
      'street': 'Musterstraße 1',
      'postalCode': '23966',
      'city': 'Wismar',
      'countryCode': 'de',
      'bic': 'BYLADEM1001',
    });
    expect(saved['bic'], 'BYLADEM1001');
    expect(saved['countryCode'], 'DE');
    final legacy = await c.put('/company/profile', {'address': 'Musterstraße 2, 23966 Wismar'});
    expect(legacy['street'], 'Musterstraße 1');
    expect(legacy['bic'], 'BYLADEM1001');
    expect((await c.get('/company/profile'))['postalCode'], '23966');
  });

  test('Finalisieren friert Verkäufer/Käufer als eInvoiceSnapshot ein — nur Rechnung/Gutschrift', () async {
    final c = await h.company('e3@example.com', permissions: permissions, modules: {'quotes'});
    await c.put('/company/profile', {
      'address': 'Musterstraße 1, 23966 Wismar',
      'taxNumber': '079/123/45678',
      'iban': 'DE02120300000000202051',
      'bic': 'BYLADEM1001',
      'email': 'info@elektro.example',
      'phone': '03841 1',
    });
    final customer = await c.post('/customers', {
      'name': 'Musterwerk',
      'address': 'Werkstraße 5\n23970 Wismar',
      'email': 'info@musterwerk.example',
      'invoiceEmail': 'rechnung@musterwerk.example',
      'contacts': [
        {'name': 'Erika', 'role': 'Buchhaltung', 'email': 'erika@musterwerk.example'},
      ],
    });
    final erika = ((customer['contacts'] as List).single as Map)['id'] as String;
    final draft = await c.post('/documents', {
      'kind': 'invoice',
      'customerId': customer['id'],
      'contactId': erika,
      'items': [
        {'kind': 'text', 'description': 'Montage', 'quantity': '1', 'unitPriceCents': 10000, 'vatRatePercent': 19},
      ],
    });
    expect(draft['eInvoiceSnapshot'], isNull, reason: 'Entwurf hat keinen Schnappschuss');
    final finalized = await c.post('/documents/${draft['id']}/finalize', {'version': draft['version']});
    final snapshot = finalized['eInvoiceSnapshot'] as Map<String, Object?>;
    final seller = snapshot['seller'] as Map<String, Object?>;
    final buyer = snapshot['buyer'] as Map<String, Object?>;
    expect((seller['address'] as Map)['postalCode'], '23966', reason: 'Freitext zerlegt');
    expect((seller['address'] as Map)['street'], 'Musterstraße 1');
    expect(seller['bic'], 'BYLADEM1001');
    expect(seller['taxNumber'], '079/123/45678');
    expect((buyer['address'] as Map)['city'], 'Wismar');
    expect((buyer['address'] as Map)['postalCode'], '23970');
    expect(buyer['email'], 'rechnung@musterwerk.example');
    expect(buyer['contactName'], 'Erika');
    expect(snapshot['format'], 'zugferd');

    // Spätere Profiländerung ändert den Schnappschuss nicht.
    await c.put('/company/profile', {'address': 'Neue Straße 9, 10115 Berlin', 'bic': 'ANDERS'});
    final reread = await c.get('/documents/${draft['id']}');
    expect(((reread['eInvoiceSnapshot'] as Map)['seller'] as Map)['bic'], 'BYLADEM1001');

    // Angebot: keine E-Rechnung.
    final quote = await c.post('/documents', {
      'kind': 'quote',
      'customerId': customer['id'],
      'items': [
        {'kind': 'text', 'description': 'Angebot', 'quantity': '1', 'unitPriceCents': 100, 'vatRatePercent': 19},
      ],
    });
    final finalizedQuote = await c.post('/documents/${quote['id']}/finalize', {'version': quote['version']});
    expect(finalizedQuote['eInvoiceSnapshot'], isNull);
    await expectLater(c.get('/documents/unbekannt'), status(404));
  });

  test('E-Rechnung: Prüfung und XML-Abruf nur mit Modul, nur finalisiert, vollständige Daten', () async {
    final c = await h.company('e4@example.com', permissions: permissions, modules: {'eInvoice'});
    await c.put('/company/profile', {
      'address': 'Musterstraße 1, 23966 Wismar',
      'taxNumber': '079/123/45678',
      'iban': 'DE02120300000000202051',
      'email': 'info@elektro.example',
      'phone': '03841 1',
    });
    final customer = await c.post('/customers', {
      'name': 'Stadt Wismar',
      'address': 'Am Markt 1, 23966 Wismar',
      'email': 'rechnung@wismar.example',
      'leitwegId': '04011000-1234512345-06',
      'eInvoiceFormat': 'xrechnung',
    });
    final draft = await c.post('/documents', {
      'kind': 'invoice',
      'customerId': customer['id'],
      'paymentTerms': '14 Tage netto',
      'items': [
        {'kind': 'text', 'description': 'Montage', 'quantity': '2', 'unit': 'h', 'unitPriceCents': 6500, 'vatRatePercent': 19},
      ],
    });
    final draftStatus = await c.get('/documents/${draft['id']}/einvoice');
    expect(draftStatus['format'], 'xrechnung');
    expect(draftStatus['problems'], contains('Dokument ist noch nicht finalisiert (keine Nummer).'));
    await expectLater(c.client.eInvoiceXml(draft['id'] as String), status(409));

    final finalized = await c.post('/documents/${draft['id']}/finalize', {'version': draft['version']});
    final ready = await c.get('/documents/${draft['id']}/einvoice');
    expect(ready['problems'], isEmpty);
    expect(ready['fileName'], '${finalized['number']}.xml');
    final xml = utf8.decode(await c.client.eInvoiceXml(draft['id'] as String));
    expect(xml, contains('urn:xeinkauf.de:kosit:xrechnung_3.0'));
    expect(xml, contains('<ram:BuyerReference>04011000-1234512345-06</ram:BuyerReference>'));
    expect(xml, contains('<ram:GrandTotalAmount>154.70</ram:GrandTotalAmount>'));
    expect(xml, contains('<ram:BilledQuantity unitCode="HUR">2</ram:BilledQuantity>'));

    // Ohne Modul: 409; fremdes/fehlendes Dokument: 404.
    final other = await h.company('e5@example.com', permissions: permissions);
    await expectLater(other.get('/documents/${draft['id']}/einvoice'), status(404));
    final quote = await other.post('/customers', {'name': 'X'});
    final inv = await other.post('/documents', {'kind': 'invoice', 'customerId': quote['id'], 'items': []});
    await expectLater(other.get('/documents/${inv['id']}/einvoice'), status(409));
  });
}
