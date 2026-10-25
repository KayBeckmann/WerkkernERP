import 'package:test/test.dart';

import 'support/module_harness.dart';

void main() => runPurchasingTests(inMemoryRepositories);

/// C5.2 online — gleiche Regeln wie offline.
void runPurchasingTests(RepositoryFactory create) {
  final h = ModuleHarness(create)..install();
  const permissions = [
    'customers.read', 'customers.write', 'articles.read', 'articles.write', 'invoices.read', 'invoices.write',
    'invoices.finalize', 'stock.read', 'stock.write', 'purchaseOrders.read', 'purchaseOrders.write',
    'accounting.read', 'accounting.write', 'projects.read', 'projects.write',
  ];
  const modules = {'bestellwesen', 'lagerbestand', 'buchhaltung', 'orders', 'projects'};
  final yy = (DateTime.now().toUtc().year % 100).toString().padLeft(2, '0');

  Future<({CompanyClient c, String nord, String sued, String cable, String socket})> setup(String email) async {
    final c = await h.company(email, permissions: permissions, modules: modules);
    final nord = (await c.post('/suppliers', {'name': 'Nord', 'minimumOrderQuantity': '100'}))['id'] as String;
    final sued = (await c.post('/suppliers', {'name': 'Süd'}))['id'] as String;
    final cable = (await c.post('/articles', {'name': 'Kabel', 'minimumStock': '50', 'defaultSupplierId': nord}))['id'] as String;
    final socket = (await c.post('/articles', {'name': 'Steckdose', 'minimumStock': '10'}))['id'] as String;
    await c.put('/articles/$cable/prices/$nord', {'purchasePriceCents': 120});
    await c.put('/articles/$cable/prices/$sued', {'purchasePriceCents': 100});
    await c.put('/articles/$socket/prices/$sued', {'purchasePriceCents': 250});
    return (c: c, nord: nord, sued: sued, cable: cable, socket: socket);
  }

  test('Entwurf → Finalisieren B-JJ001 → Teil- und Restlieferung bucht Bestand, Beleg und Status', () async {
    final s = await setup('a@example.com');
    final c = s.c;
    final project = await c.post('/projects', {'name': 'Neubau'});
    final category = await c.post('/expense-categories', {'label': 'Material', 'skr03Account': '3400'});
    final draft = await c.post('/purchase-orders', {
      'supplierId': s.nord,
      'projectId': project['id'],
      'expenseCategoryId': category['id'],
      'items': [
        {'articleId': s.cable, 'description': 'Kabel', 'quantity': '100', 'purchasePriceCents': 120},
        {'description': 'Versandpauschale', 'quantity': '1', 'purchasePriceCents': 990},
      ],
    });
    expect(draft['totalNetCents'], 12990);
    expect(draft['number'], isNull);
    await expectLater(c.post('/purchase-orders/${draft['id']}/receive', {'receipts': {'x': '1'}}), throwsStatus(409));

    final order = await c.post('/purchase-orders/${draft['id']}/finalize', {'version': draft['version']});
    expect(order['number'], 'B-${yy}001');
    expect((order['supplierSnapshot'] as Map)['name'], 'Nord');
    await expectLater(c.put('/purchase-orders/${draft['id']}', {'version': order['version'], 'items': []}), throwsStatus(409));
    final items = (order['items'] as List).cast<Map<String, Object?>>();
    final cableItem = items.firstWhere((i) => i['articleId'] == s.cable)['id'] as String;
    final shipping = items.firstWhere((i) => i['articleId'] == null)['id'] as String;

    final partial = await c.post('/purchase-orders/${draft['id']}/receive', {'receipts': {cableItem: '40'}});
    expect(partial['status'], 'partiallyReceived');
    expect((await c.get('/articles/${s.cable}'))['stockQuantity'], '40');
    await expectLater(c.post('/purchase-orders/${draft['id']}/receive', {'receipts': {cableItem: '61'}}), throwsStatus(409));
    expect((await c.get('/articles/${s.cable}'))['stockQuantity'], '40', reason: 'Überlieferung bucht nichts');

    final full = await c.post('/purchase-orders/${draft['id']}/receive', {'receipts': {cableItem: '60', shipping: '1'}});
    expect(full['status'], 'fullyReceived');
    expect((await c.get('/articles/${s.cable}'))['stockQuantity'], '100');

    final expenses = ((await c.get('/expenses'))['expenses'] as List).cast<Map<String, Object?>>();
    expect(expenses.map((e) => e['amountGrossCents']), unorderedEquals([4800, 7200 + 990]));
    expect(expenses.every((e) => e['projectId'] == project['id'] && e['categoryId'] == category['id'] && e['vatRatePercent'] == 0), isTrue);
    final movements = (await c.get('/stock/movements', query: {'articleId': s.cable}))['movements'] as List;
    expect(movements.map((m) => (m as Map)['type']).toSet(), {'purchaseOrderReceipt'});
    expect((movements.first as Map)['referenceLabel'], 'B-${yy}001');

    await expectLater(c.delete('/suppliers/${s.nord}'), throwsStatus(409), reason: 'Lieferant mit Bestellung bleibt');
    await expectLater(c.delete('/purchase-orders/${draft['id']}'), throwsStatus(409));
  });

  test('Aus Auftrag: ein Lieferant für alles bzw. günstigster je Artikel; ohne Preis nicht zuordenbar', () async {
    final s = await setup('a@example.com');
    final c = s.c;
    final customer = (await c.post('/customers', {'name': 'Meyer'}))['id'] as String;
    final noPrice = (await c.post('/articles', {'name': 'Sonderteil'}))['id'] as String;
    Map<String, Object?> item(String articleId, String q) =>
        {'kind': 'article', 'articleId': articleId, 'description': 'x', 'quantity': q, 'unitPriceCents': 500, 'vatRatePercent': 19};
    final draft = await c.post('/documents', {
      'kind': 'order',
      'customerId': customer,
      'items': [item(s.cable, '30'), item(s.cable, '20'), item(s.socket, '4'), item(noPrice, '1')],
    });
    await expectLater(c.post('/documents/${draft['id']}/purchase-orders', {'mode': 'cheapest'}), throwsStatus(409));
    final order = await c.post('/documents/${draft['id']}/finalize', {'version': draft['version']});

    final one = await c.post('/documents/${order['id']}/purchase-orders', {'mode': 'oneSupplier', 'supplierId': s.nord});
    expect(one['purchaseOrderIds'] as List, hasLength(1));
    expect((one['unassignable'] as List).map((u) => (u as Map)['articleName']), unorderedEquals(['Steckdose', 'Sonderteil']));
    final nordOrder = await c.get('/purchase-orders/${(one['purchaseOrderIds'] as List).single}');
    expect((nordOrder['items'] as List).single, containsPair('quantity', '50'));
    expect(nordOrder['sourceOrderId'], order['id']);

    final cheapest = await c.post('/documents/${order['id']}/purchase-orders', {'mode': 'cheapest'});
    final ids = (cheapest['purchaseOrderIds'] as List).cast<String>();
    expect(ids, hasLength(1), reason: 'Kabel und Steckdose sind beide bei Süd am günstigsten');
    final sued = await c.get('/purchase-orders/${ids.single}');
    expect(sued['supplierId'], s.sued);
    expect((sued['items'] as List).map((i) => (i as Map)['purchasePriceCents']), unorderedEquals([100, 250]));
    expect(((await c.get('/purchase-orders', query: {'sourceOrderId': order['id'] as String}))['purchaseOrders'] as List), hasLength(2));
  });

  test('Bestellvorschläge aus Unterbestand: Standardlieferant vor günstigstem, Mindestbestellmenge nur Hinweis', () async {
    final s = await setup('a@example.com');
    final c = s.c;
    final result = await c.get('/purchase-orders/suggestions');
    final suggestions = (result['suggestions'] as List).cast<Map<String, Object?>>();
    final nord = suggestions.firstWhere((x) => x['supplierId'] == s.nord);
    expect((nord['items'] as List).single, containsPair('quantity', '50'), reason: 'Kabel beim Standardlieferanten Nord, nicht beim günstigeren Süd');
    expect(nord['meetsMinimumOrderQuantity'], isFalse, reason: '50 < Mindestbestellmenge 100');
    final sued = suggestions.firstWhere((x) => x['supplierId'] == s.sued);
    expect((sued['items'] as List).single, containsPair('quantity', '10'));

    final created = await c.post('/purchase-orders/from-suggestion', {'supplierId': s.nord});
    expect(created['status'], 'draft');
    expect((created['items'] as List).single, containsPair('purchasePriceCents', 120));
    await expectLater(c.post('/purchase-orders/from-suggestion', {'supplierId': 'unbekannt'}), throwsStatus(404));
  });

  test('Firmentrennung, Rechte, Validierung', () async {
    final a = await setup('a@example.com');
    final b = await setup('b@example.com');
    final draft = await a.c.post('/purchase-orders', {'supplierId': a.nord, 'items': [{'description': 'x', 'quantity': '1'}]});
    await expectLater(b.c.get('/purchase-orders/${draft['id']}'), throwsStatus(404));
    await expectLater(b.c.post('/purchase-orders', {'supplierId': a.nord}), throwsStatus(404));
    await expectLater(b.c.post('/purchase-orders', {'supplierId': b.nord, 'items': [{'articleId': a.cable, 'description': 'x', 'quantity': '1'}]}), throwsStatus(404));
    await expectLater(a.c.post('/purchase-orders', {'supplierId': a.nord, 'items': [{'description': 'x', 'quantity': '0'}]}), throwsStatus(400));
    await expectLater(a.c.post('/purchase-orders/${draft['id']}/finalize', {'version': 99}), throwsStatus(409));
    final empty = await a.c.post('/purchase-orders', {'supplierId': a.nord});
    await expectLater(a.c.post('/purchase-orders/${empty['id']}/finalize', {'version': empty['version']}), throwsStatus(409));
    await a.c.delete('/purchase-orders/${empty['id']}');

    final reader = await h.company('r@example.com', permissions: ['purchaseOrders.read'], modules: modules);
    await expectLater(reader.post('/purchase-orders', {'supplierId': 'x'}), throwsStatus(403));
    await a.c.client.setModules({'lagerbestand'});
    await expectLater(a.c.get('/purchase-orders'), throwsStatus(403));
  });
}
