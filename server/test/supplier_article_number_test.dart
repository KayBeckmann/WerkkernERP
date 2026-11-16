import 'package:test/test.dart';

import 'support/module_harness.dart';

void main() => runSupplierArticleNumberTests(inMemoryRepositories);

/// C5.2-Nachtrag (Kay, 16.11.2026): Lieferantenartikelnummer je Artikel ×
/// Lieferant — Bestellung an AZ zeigt nur die AZ-Nummer, an Sonepar nur
/// die Sonepar-Nummer, finalisiert bleibt sie eingefroren, Kundenbelege
/// enthalten sie nie.
void runSupplierArticleNumberTests(RepositoryFactory create) {
  final h = ModuleHarness(create)..install();
  const permissions = [
    'customers.read', 'customers.write', 'articles.read', 'articles.write', 'invoices.read', 'invoices.write',
    'stock.read', 'stock.write', 'purchaseOrders.read', 'purchaseOrders.write',
  ];
  const modules = {'bestellwesen', 'lagerbestand', 'orders'};

  test('Nummer je Zuordnung, Schnappschuss beim Finalisieren, nicht auf Kundenbelegen', () async {
    final c = await h.company('lan@example.com', permissions: permissions, modules: modules);
    final az = (await c.post('/suppliers', {'name': 'AZ'}))['id'] as String;
    final sonepar = (await c.post('/suppliers', {'name': 'Sonepar'}))['id'] as String;
    final ls = (await c.post('/articles', {'name': 'LS B16/1'}))['id'] as String;
    await c.put('/articles/$ls/prices/$az', {'purchasePriceCents': 250, 'supplierArticleNumber': ' 0060903A '});
    await c.put('/articles/$ls/prices/$sonepar', {'purchasePriceCents': 260, 'supplierArticleNumber': 'SP-77'});
    // Ältere Clients ohne Feld lassen die Nummer stehen.
    await c.put('/articles/$ls/prices/$az', {'purchasePriceCents': 240});
    final prices = {
      for (final p in ((await c.get('/articles/$ls/prices'))['prices'] as List).cast<Map>()) p['supplierName']: p,
    };
    expect((prices['AZ']!['supplierArticleNumber'], prices['AZ']!['purchasePriceCents']), ('0060903A', 240));
    expect(prices['Sonepar']!['supplierArticleNumber'], 'SP-77');

    Future<Map<String, Object?>> draft(String supplierId) => c.post('/purchase-orders', {
          'supplierId': supplierId,
          'items': [
            {'articleId': ls, 'description': 'LS B16/1', 'quantity': '10'},
            {'description': 'Versand', 'quantity': '1'},
          ],
        });
    List<Object?> numbers(Map<String, Object?> order) =>
        [for (final i in (order['items'] as List).cast<Map>()) i['supplierArticleNumber']];

    final azDraft = await draft(az);
    final soneparDraft = await draft(sonepar);
    expect(numbers(azDraft), ['0060903A', null]);
    expect(numbers(soneparDraft), ['SP-77', null]);

    final finalized = await c.post('/purchase-orders/${azDraft['id']}/finalize', {'version': azDraft['version']});
    expect(numbers(finalized), ['0060903A', null]);
    await c.put('/articles/$ls/prices/$az', {'purchasePriceCents': 240, 'supplierArticleNumber': 'NEU'});
    expect(numbers(await c.get('/purchase-orders/${azDraft['id']}')), ['0060903A', null], reason: 'Schnappschuss');
    // Wareneingang verliert den Schnappschuss nicht.
    final item = ((finalized['items'] as List).first as Map)['id'] as String;
    final received = await c.post('/purchase-orders/${azDraft['id']}/receive', {'receipts': {item: '10'}});
    expect(numbers(received), ['0060903A', null]);
    // Leer entfernt die Nummer.
    await c.put('/articles/$ls/prices/$sonepar', {'purchasePriceCents': 260, 'supplierArticleNumber': ''});
    expect(numbers(await c.get('/purchase-orders/${soneparDraft['id']}')), [null, null]);

    // Kundenbeleg: keine Lieferantennummer.
    final customer = (await c.post('/customers', {'name': 'Meyer'}))['id'] as String;
    final order = await c.post('/documents', {
      'kind': 'order',
      'customerId': customer,
      'items': [
        {'kind': 'article', 'articleId': ls, 'description': 'LS B16/1', 'quantity': '1', 'unitPriceCents': 500, 'vatRatePercent': 19},
      ],
    });
    expect(order.toString(), isNot(contains('0060903A')));
    expect(order.toString(), isNot(contains('NEU')));
  });
}
