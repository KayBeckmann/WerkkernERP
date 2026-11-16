import 'package:test/test.dart';
import 'package:werkkern_client/werkkern_client.dart';

import 'support/module_harness.dart';

void main() => runStorageLocationTests(inMemoryRepositories);

/// C5.4-Nachtrag (Kay, 16.11.2026) online — dieselben Regeln wie offline:
/// Summe der Plätze = Gesamtbestand, Entnahme-Vorschlag, Zielplatz beim
/// Wareneingang, Umlagerung, Inventur nach Lagerort.
void runStorageLocationTests(RepositoryFactory create) {
  final h = ModuleHarness(create)..install();
  const permissions = [
    'customers.read', 'customers.write', 'articles.read', 'articles.write', 'invoices.read', 'invoices.write',
    'invoices.finalize', 'stock.read', 'stock.write', 'purchaseOrders.read', 'purchaseOrders.write',
  ];
  const modules = {'bestellwesen', 'lagerbestand', 'orders'};
  Matcher status(int code) => throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', code));

  Future<Map<String, String>> bins(CompanyClient c, String articleId) async => {
        for (final s in ((await c.get('/articles/$articleId/bin-stock'))['stocks'] as List).cast<Map<String, Object?>>())
          s['label'] as String: s['quantity'] as String,
      };

  test('Lagerorte/Plätze, Umlagerung, Entnahme-Vorschlag, Wareneingang, Inventur nach Lagerort', () async {
    final c = await h.company('lager@example.com', permissions: permissions, modules: modules);
    final article = (await c.post('/articles', {'name': 'Abzweigdose'}))['id'] as String;
    await c.post('/articles/$article/stock-correction', {'countedQuantity': '5', 'reason': 'Anfangsbestand'});
    expect(await bins(c, article), {'Platz noch nicht zugeordnet': '5'});

    final lager = (await c.post('/storage-locations', {'name': 'Lager'}))['id'] as String;
    await expectLater(c.post('/storage-locations/$lager/bins', {'row': ' '}), status(400));
    final p2 = (await c.post('/storage-locations/$lager/bins', {'row': '1', 'compartment': '2'}))['id'] as String;
    final p10 = (await c.post('/storage-locations/$lager/bins', {'row': '1', 'compartment': '10'}))['id'] as String;
    final listed = (await c.get('/storage-locations'))['locations'] as List;
    expect(((listed.single as Map)['bins'] as List).map((b) => (b as Map)['label']), ['Reihe 1 / Fach 2', 'Reihe 1 / Fach 10']);

    // Umlagerung: Gesamtbestand bleibt.
    await c.post('/articles/$article/stock-transfer', {'fromBinKey': '', 'toBinKey': p2, 'quantity': '5'});
    expect(await bins(c, article), {'Lager · Reihe 1 / Fach 2': '5'});
    expect((await c.get('/articles/$article'))['stockQuantity'], '5');
    await expectLater(c.delete('/storage-bins/$p2'), status(409));

    // Wareneingang mit Zielplatz bzw. Standardplatz.
    await c.put('/articles/$article/default-bin', {'binId': p10});
    final supplier = (await c.post('/suppliers', {'name': 'Großhandel'}))['id'] as String;
    final draft = await c.post('/purchase-orders', {
      'supplierId': supplier,
      'items': [
        {'articleId': article, 'description': 'Dose', 'quantity': '3'},
        {'articleId': article, 'description': 'Dose groß', 'quantity': '10'},
      ],
    });
    final po = await c.post('/purchase-orders/${draft['id']}/finalize', {'version': draft['version']});
    final items = (po['items'] as List).cast<Map<String, Object?>>();
    final big = items.firstWhere((i) => i['quantity'] == '10')['id'] as String;
    final small = items.firstWhere((i) => i['quantity'] == '3')['id'] as String;
    await c.post('/purchase-orders/${draft['id']}/receive', {
      'receipts': {small: '3', big: '10'},
      'targetBins': {big: p2},
    });
    expect(await bins(c, article), {'Lager · Reihe 1 / Fach 2': '15', 'Lager · Reihe 1 / Fach 10': '3'});

    // Entnahme: Vorschlag = Platz mit größtem Bestand; gewählt wird Fach 10 (nur 3).
    final customer = (await c.post('/customers', {'name': 'Meyer'}))['id'] as String;
    final order = await c.post('/documents', {
      'kind': 'order',
      'customerId': customer,
      'items': [
        {'kind': 'article', 'articleId': article, 'description': 'Dose', 'quantity': '5', 'unitPriceCents': 100, 'vatRatePercent': 19},
      ],
    });
    final checkResult = await c.get('/documents/${order['id']}/stock-check');
    final withdrawal = (checkResult['withdrawals'] as List).single as Map;
    expect(withdrawal['suggestedBinKey'], p2);
    expect(withdrawal['quantity'], '5');
    await expectLater(
      c.post('/documents/${order['id']}/finalize', {'version': order['version'], 'withdrawalBins': {article: 'gibt-es-nicht'}}),
      status(404),
    );
    await c.post('/documents/${order['id']}/finalize', {'version': order['version'], 'withdrawalBins': {article: p10}});
    expect(await bins(c, article), {'Lager · Reihe 1 / Fach 2': '13', 'Lager · Reihe 1 / Fach 10': '0'});
    expect((await c.get('/articles/$article'))['stockQuantity'], '13');

    // Inventur nach Lagerort: Laufreihenfolge, Fund an leerem Platz.
    final empty = (await c.post('/storage-locations/$lager/bins', {'row': '2'}))['id'] as String;
    final count = await c.post('/inventory-counts', {'label': 'Lager 11/2026', 'locationId': lager});
    expect(count['locationId'], lager);
    final countItems = (count['items'] as List).cast<Map<String, Object?>>();
    expect([for (final i in countItems) (i['binLabel'], i['expectedQuantity'])], [
      ('Lager · Reihe 1 / Fach 2', '13'),
      ('Lager · Reihe 1 / Fach 10', '0'),
    ]);
    expect(((count['bins'] as List).map((b) => (b as Map)['id'])), [p2, p10, empty]);
    await c.put('/inventory-counts/${count['id']}/items/${countItems[0]['id']}', {'countedQuantity': '12'});
    final withFound = await c.post('/inventory-counts/${count['id']}/found', {'articleId': article, 'binKey': empty});
    final found = ((withFound['items'] as List).cast<Map<String, Object?>>()).firstWhere((i) => i['binKey'] == empty);
    await c.put('/inventory-counts/${count['id']}/items/${found['id']}', {'countedQuantity': '2'});
    await c.post('/inventory-counts/${count['id']}/complete');
    expect(await bins(c, article), {
      'Lager · Reihe 1 / Fach 2': '12',
      'Lager · Reihe 1 / Fach 10': '0',
      'Lager · Reihe 2': '2',
    });
    expect((await c.get('/articles/$article'))['stockQuantity'], '14');

    final movements = ((await c.get('/stock/movements', query: {'articleId': article}))['movements'] as List).cast<Map>();
    expect(movements.where((m) => m['type'] == 'transfer').map((m) => m['binKey']).toSet(), {'', p2});

    // Leerer Lagerort lässt sich löschen, belegter nicht.
    final van = (await c.post('/storage-locations', {'name': 'Fahrzeug'}))['id'] as String;
    await c.post('/storage-locations/$van/bins', {'shelf': 'Kiste'});
    await c.delete('/storage-locations/$van');
    await expectLater(c.delete('/storage-locations/$lager'), status(409));
    expect(((await c.get('/storage-locations'))['locations'] as List).length, 1);
  });
}
