import 'package:test/test.dart';

import 'support/module_harness.dart';

void main() => runStockTests(inMemoryRepositories);

/// C5.1/C5.3 online — dieselben Regeln wie offline.
void runStockTests(RepositoryFactory create) {
  final h = ModuleHarness(create)..install();
  const permissions = [
    'customers.read', 'customers.write', 'articles.read', 'articles.write',
    'invoices.read', 'invoices.write', 'invoices.finalize', 'stock.read', 'stock.write',
  ];
  const modules = {'lagerbestand', 'orders', 'quotes', 'deliveryNotes', 'creditNotes'};

  Future<({CompanyClient c, String customerId, String cable, String socket})> setup(String email) async {
    final c = await h.company(email, permissions: permissions, modules: modules);
    final customer = await c.post('/customers', {'name': 'Meyer'});
    final cable = await c.post('/articles', {'name': 'Kabel', 'unit': 'm', 'minimumStock': '50'});
    final socket = await c.post('/articles', {'name': 'Steckdose'});
    return (c: c, customerId: customer['id'] as String, cable: cable['id'] as String, socket: socket['id'] as String);
  }

  Map<String, Object?> item(String articleId, String quantity) =>
      {'kind': 'article', 'articleId': articleId, 'description': 'x', 'quantity': quantity, 'unitPriceCents': 100, 'vatRatePercent': 19};

  Future<String> stockOf(CompanyClient c, String articleId) async => (await c.get('/articles/$articleId'))['stockQuantity'] as String;

  Future<Map<String, Object?>> finalized(CompanyClient c, String customerId, String kind, List<Map<String, Object?>> items) async {
    final draft = await c.post('/documents', {'kind': kind, 'customerId': customerId, 'items': items});
    return c.post('/documents/${draft['id']}/finalize', {'version': draft['version']});
  }

  test('Genau eine Buchung pro Kette; Gutschrift bucht zurück; Angebot bucht nie', () async {
    final s = await setup('a@example.com');
    final c = s.c;
    await c.post('/articles/${s.cable}/stock-correction', {'countedQuantity': '100', 'reason': 'Anfangsbestand'});
    expect(await stockOf(c, s.cable), '100');

    final quote = await finalized(c, s.customerId, 'quote', [item(s.cable, '5')]);
    expect(await stockOf(c, s.cable), '100', reason: 'Angebot bucht nicht');

    final order = await c.post('/documents/${quote['id']}/convert', {'kind': 'order'});
    final finalOrder = await c.post('/documents/${order['id']}/finalize', {'version': order['version']});
    expect(finalOrder['stockBooked'], isTrue);
    expect(await stockOf(c, s.cable), '95');

    final invoice = await c.post('/documents/${order['id']}/convert', {'kind': 'invoice'});
    final finalInvoice = await c.post('/documents/${invoice['id']}/finalize', {'version': invoice['version']});
    expect(finalInvoice['stockBooked'], isFalse);
    expect(await stockOf(c, s.cable), '95', reason: 'Rechnung aus gebuchtem Auftrag bucht nicht doppelt');

    final credit = await c.post('/documents/${invoice['id']}/credit-note');
    await c.put('/documents/${credit['id']}', {'version': credit['version'], 'items': [item(s.cable, '2.5')]});
    final reloaded = await c.get('/documents/${credit['id']}');
    await c.post('/documents/${credit['id']}/finalize', {'version': reloaded['version']});
    expect(await stockOf(c, s.cable), '97.5', reason: 'Gutschrift bucht nur ihre eigene Menge zurück');

    final movements = (await c.get('/stock/movements', query: {'articleId': s.cable}))['movements'] as List;
    expect(movements.map((m) => (m as Map)['type']), ['creditNoteReturn', 'documentBooking', 'inventoryCorrection']);
    expect((movements[1] as Map)['referenceLabel'], finalOrder['number']);
    expect((movements[1] as Map)['quantityDelta'], '-5');

    // Direkte Rechnung bucht selbst; Stunden/Freitext ohne Artikel zählen nicht.
    await finalized(c, s.customerId, 'invoice', [
      item(s.socket, '3'),
      {'kind': 'hours', 'description': 'Montage', 'quantity': '2', 'unitPriceCents': 6500, 'vatRatePercent': 19},
    ]);
    expect(await stockOf(c, s.socket), '-3', reason: 'Bestand darf negativ werden (nur Warnung)');
  });

  test('Bearbeiteter, bereits gebuchter Auftrag bucht die Mengendifferenz nach', () async {
    final s = await setup('a@example.com');
    final c = s.c;
    final order = await finalized(c, s.customerId, 'order', [item(s.cable, '3'), item(s.cable, '2')]);
    expect(await stockOf(c, s.cable), '-5', reason: 'zwei Positionen desselben Artikels summiert');

    final edited = await c.put('/documents/${order['id']}', {'version': order['version'], 'items': [item(s.cable, '8'), item(s.socket, '1')]});
    expect(await stockOf(c, s.cable), '-8');
    expect(await stockOf(c, s.socket), '-1');
    await c.put('/documents/${order['id']}', {'version': edited['version'], 'items': [item(s.socket, '1')]});
    expect(await stockOf(c, s.cable), '0');
    final notes = ((await c.get('/stock/movements', query: {'articleId': s.cable}))['movements'] as List)
        .map((m) => (m as Map)['note'])
        .toList();
    expect(notes, ['Korrektur nach Bearbeitung', 'Korrektur nach Bearbeitung', null]);
  });

  test('Ohne Lagermodul keine Buchung; Bestandswarnung vor dem Finalisieren', () async {
    final s = await setup('a@example.com');
    final c = s.c;
    final draft = await c.post('/documents', {'kind': 'invoice', 'customerId': s.customerId, 'items': [item(s.cable, '7')]});
    final checkResult = await c.get('/documents/${draft['id']}/stock-check');
    expect(checkResult['booksStock'], isTrue);
    expect((checkResult['warnings'] as List).single, containsPair('requested', '7'));

    await c.client.setModules({'orders'});
    await c.post('/documents/${draft['id']}/finalize', {'version': draft['version']});
    expect(await stockOf(c, s.cable), '0');
    await expectLater(c.get('/stock/movements'), throwsStatus(403));
  });

  test('Inventurlauf: volle Aufnahme, Zählung, Abschluss bucht Abweichungen, danach gesperrt', () async {
    final s = await setup('a@example.com');
    final c = s.c;
    await c.post('/articles/${s.cable}/stock-correction', {'countedQuantity': '40', 'reason': 'Start'});
    expect(((await c.get('/stock/low'))['articles'] as List).single, containsPair('shortfall', '10'));

    final count = await c.post('/inventory-counts', {'label': 'Inventur 2026', 'allArticles': true});
    final items = (count['items'] as List).cast<Map<String, Object?>>();
    expect(items, hasLength(2));
    final cableItem = items.firstWhere((i) => i['articleId'] == s.cable);
    expect(cableItem['expectedQuantity'], '40');
    final socketItem = items.firstWhere((i) => i['articleId'] == s.socket);
    await c.put('/inventory-counts/${count['id']}/items/${cableItem['id']}', {'countedQuantity': '38,5'});
    await c.put('/inventory-counts/${count['id']}/items/${socketItem['id']}', {'countedQuantity': '0'});

    final done = await c.post('/inventory-counts/${count['id']}/complete');
    expect(done['status'], 'completed');
    expect(await stockOf(c, s.cable), '38.5');
    expect(((await c.get('/stock/movements', query: {'articleId': s.socket}))['movements'] as List), isEmpty,
        reason: 'keine Abweichung → keine Bewegung');
    await expectLater(c.post('/inventory-counts/${count['id']}/complete'), throwsStatus(409));
    await expectLater(c.put('/inventory-counts/${count['id']}/items/${cableItem['id']}', {'countedQuantity': '1'}), throwsStatus(409));
    await expectLater(c.post('/articles/${s.cable}/stock-correction', {'countedQuantity': '1'}), throwsStatus(400));

    // Artikelpflege ändert den Bestand nie.
    await c.put('/articles/${s.cable}', {'name': 'Kabel', 'minimumStock': '10'});
    expect(await stockOf(c, s.cable), '38.5');
    expect((await c.get('/stock/low'))['articles'], isEmpty);
  });

  test('Firmentrennung und Rechte', () async {
    final a = await setup('a@example.com');
    final b = await setup('b@example.com');
    await expectLater(b.c.post('/articles/${a.cable}/stock-correction', {'countedQuantity': '1', 'reason': 'x'}), throwsStatus(404));
    final count = await a.c.post('/inventory-counts', {'label': 'A'});
    await expectLater(b.c.get('/inventory-counts/${count['id']}'), throwsStatus(404));
    await expectLater(b.c.post('/inventory-counts/${count['id']}/articles', {'articleIds': [b.cable]}), throwsStatus(404));
    await expectLater(a.c.post('/inventory-counts/${count['id']}/articles', {'articleIds': [b.cable]}), throwsStatus(404));
    expect((await b.c.get('/stock/movements'))['movements'], isEmpty);

    final reader = await h.company('r@example.com', permissions: ['stock.read'], modules: modules);
    await expectLater(reader.post('/inventory-counts', {'label': 'X'}), throwsStatus(403));
  });
}
