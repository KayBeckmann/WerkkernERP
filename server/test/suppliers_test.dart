import 'package:test/test.dart';

import 'support/module_harness.dart';

void main() => runSupplierTests(inMemoryRepositories);

/// A1 online: Lieferanten, Artikelgruppen, Mehrlieferanten-Kalkulation.
void runSupplierTests(RepositoryFactory create) {
  final h = ModuleHarness(create)..install();

  test('Referenzfall: 100 € EK beim Standardlieferanten + 30 % Gruppe = 130 € netto; manueller Preis vorrangig', () async {
    final a = await h.company('a@example.com', permissions: ['articles.read', 'articles.write']);
    final s1 = await a.post('/suppliers', {'name': 'Großhandel Nord', 'minimumOrderQuantity': '2,5'});
    expect(s1['minimumOrderQuantity'], '2.5');
    final s2 = await a.post('/suppliers', {'name': 'Elektro Süd'});
    final group = await a.post('/article-groups', {'name': 'Kabel', 'markupPercent': 30});
    final article = await a.post('/articles', {
      'name': 'NYM 3x1,5',
      'unit': 'm',
      'articleGroupId': group['id'],
      'defaultSupplierId': s1['id'],
    });
    expect(article['effectiveSalePriceCents'], isNull, reason: 'ohne EK kein Preis (nicht 0 €)');

    await a.put('/articles/${article['id']}/prices/${s1['id']}', {'purchasePriceCents': 10000});
    await a.put('/articles/${article['id']}/prices/${s2['id']}', {'purchasePriceCents': 8000});
    var loaded = await a.get('/articles/${article['id']}');
    expect(loaded['calculatedSalePriceCents'], 13000);
    expect(loaded['effectiveSalePriceCents'], 13000, reason: 'Standardlieferant entscheidet, nicht der günstigere');
    expect(loaded['articleGroupName'], 'Kabel');
    final prices = (await a.get('/articles/${article['id']}/prices'))['prices'] as List;
    expect(prices.map((p) => (p as Map)['supplierName']), unorderedEquals(['Großhandel Nord', 'Elektro Süd']));

    // EK-Änderung ersetzt den Preis (ein Preis je Paar).
    await a.put('/articles/${article['id']}/prices/${s1['id']}', {'purchasePriceCents': 20000});
    expect((await a.get('/articles/${article['id']}/prices'))['prices'] as List, hasLength(2));
    expect((await a.get('/articles/${article['id']}'))['effectiveSalePriceCents'], 26000);

    // Manueller Preis überschreibt die Kalkulation.
    await a.put('/articles/${article['id']}', {
      'name': 'NYM 3x1,5',
      'unit': 'm',
      'salePriceCents': 15000,
      'articleGroupId': group['id'],
      'defaultSupplierId': s1['id'],
    });
    loaded = await a.get('/articles/${article['id']}');
    expect(loaded['effectiveSalePriceCents'], 15000);
    expect(loaded['calculatedSalePriceCents'], 26000);

    // Liste liefert dieselben Preisfelder.
    final list = (await a.get('/articles'))['articles'] as List;
    expect((list.single as Map)['effectiveSalePriceCents'], 15000);
  });

  test('Ohne Gruppe 0 % Aufschlag; Löschen von Gruppe/Lieferant löst nur den Verweis', () async {
    final a = await h.company('a@example.com', permissions: ['articles.read', 'articles.write']);
    final supplier = await a.post('/suppliers', {'name': 'Nord'});
    final group = await a.post('/article-groups', {'name': 'Leuchten', 'markupPercent': 12.5});
    final article = await a.post('/articles', {'name': 'Spot', 'defaultSupplierId': supplier['id'], 'articleGroupId': group['id']});
    await a.put('/articles/${article['id']}/prices/${supplier['id']}', {'purchasePriceCents': 1001});
    expect((await a.get('/articles/${article['id']}'))['effectiveSalePriceCents'], 1126, reason: '10,01 € × 1,125 = 11,26 €');

    expect((await a.get('/article-groups/${group['id']}/impact'))['articleCount'], 1);
    await a.delete('/article-groups/${group['id']}', query: {'mode': 'ungroup', 'expectedCount': '1'});
    var loaded = await a.get('/articles/${article['id']}');
    expect(loaded['articleGroupId'], isNull);
    expect(loaded['effectiveSalePriceCents'], 1001);

    await a.delete('/suppliers/${supplier['id']}');
    loaded = await a.get('/articles/${article['id']}');
    expect(loaded['defaultSupplierId'], isNull);
    expect(loaded['effectiveSalePriceCents'], isNull);
    expect((await a.get('/articles/${article['id']}/prices'))['prices'], isEmpty);
  });

  test('Firmentrennung: gleichnamige Stammdaten, fremde IDs wie nicht existent', () async {
    final a = await h.company('a@example.com', permissions: ['articles.read', 'articles.write']);
    final b = await h.company('b@example.com', permissions: ['articles.read', 'articles.write']);
    final supplierA = await a.post('/suppliers', {'name': 'Nord'});
    final groupA = await a.post('/article-groups', {'name': 'Kabel', 'markupPercent': 30});
    await b.post('/suppliers', {'name': 'Nord'});
    final articleB = await b.post('/articles', {'name': 'Kabel'});

    expect((await b.get('/suppliers'))['suppliers'] as List, hasLength(1));
    await expectLater(b.get('/suppliers/${supplierA['id']}'), throwsStatus(404));
    await expectLater(b.post('/articles', {'name': 'X', 'articleGroupId': groupA['id']}), throwsStatus(404));
    await expectLater(b.post('/articles', {'name': 'X', 'defaultSupplierId': supplierA['id']}), throwsStatus(404));
    await expectLater(
      b.put('/articles/${articleB['id']}/prices/${supplierA['id']}', {'purchasePriceCents': 1}),
      throwsStatus(404),
    );
    await expectLater(b.delete('/article-groups/${groupA['id']}', query: {'mode': 'ungroup', 'expectedCount': '0'}), throwsStatus(404));
    await expectLater(b.put('/suppliers/${supplierA['id']}', {'name': 'gekapert'}), throwsStatus(404));
    expect((await a.get('/suppliers/${supplierA['id']}'))['name'], 'Nord');
  });

  test('Löschen verlangt Entscheidung und aktuelle Anzahl; leere Gruppe erlaubt', () async {
    final a = await h.company('choice@example.com', permissions: ['articles.read', 'articles.write']);
    final g = await a.post('/article-groups', {'name': 'Gruppe', 'markupPercent': 0});
    final id = g['id'];
    await expectLater(a.delete('/article-groups/$id'), throwsStatus(400));
    final article = await a.post('/articles', {'name': 'Neu', 'articleGroupId': id});
    await expectLater(a.delete('/article-groups/$id', query: {'mode': 'deleteArticles', 'expectedCount': '0'}), throwsStatus(409));
    expect((await a.get('/articles/${article['id']}'))['articleGroupId'], id);
    await a.delete('/article-groups/$id', query: {'mode': 'deleteArticles', 'expectedCount': '1'});
    await expectLater(a.get('/articles/${article['id']}'), throwsStatus(404));
    final empty = await a.post('/article-groups', {'name': 'Leer', 'markupPercent': 0});
    await a.delete('/article-groups/${empty['id']}', query: {'mode': 'ungroup', 'expectedCount': '0'});
  });

  test('Ungroup erhält Artikel-ID, Verkaufspreis und Lieferantenpreis', () async {
    final a = await h.company('preserve@example.com', permissions: ['articles.read', 'articles.write']);
    final g = await a.post('/article-groups', {'name': 'Alt', 'markupPercent': 10});
    final s = await a.post('/suppliers', {'name': 'Lieferant'});
    final article = await a.post('/articles', {'name': 'Teil', 'articleGroupId': g['id'],
      'salePriceCents': 1234, 'defaultSupplierId': s['id']});
    await a.put('/articles/${article['id']}/prices/${s['id']}', {'purchasePriceCents': 456});
    await a.delete('/article-groups/${g['id']}', query: {'mode': 'ungroup', 'expectedCount': '1'});
    final kept = await a.get('/articles/${article['id']}');
    expect(kept['articleGroupId'], isNull);
    expect(kept['id'], article['id']);
    expect(kept['salePriceCents'], 1234);
    expect(kept['defaultSupplierId'], s['id']);
    expect((await a.get('/articles/${article['id']}/prices'))['prices'], hasLength(1));
  });

  test('Artikel löschen bewahrt ausgestellte Dokumentposition als Snapshot', () async {
    final a = await h.company('snapshot@example.com', permissions: [
      'articles.read', 'articles.write', 'customers.read', 'customers.write', 'invoices.read', 'invoices.write', 'invoices.finalize',
    ], modules: {'quotes'});
    final g = await a.post('/article-groups', {'name': 'Material', 'markupPercent': 0});
    final item = await a.post('/articles', {'name': 'Dose', 'articleGroupId': g['id']});
    final customer = await a.post('/customers', {'name': 'Muster'});
    final draft = await a.post('/documents', {'kind': 'quote', 'customerId': customer['id'], 'items': [
      {'kind': 'article', 'articleId': item['id'], 'description': 'Dose im Angebot',
        'quantity': '2', 'unitPriceCents': 500, 'vatRatePercent': 19},
    ]});
    final doc = await a.post('/documents/${draft['id']}/finalize', {'version': draft['version']});
    await a.delete('/article-groups/${g['id']}', query: {'mode': 'deleteArticles', 'expectedCount': '1'});
    final kept = await a.get('/documents/${doc['id']}');
    final position = (kept['items'] as List).single as Map;
    expect(position['description'], 'Dose im Angebot');
    expect(position['unitPriceCents'], 500);
    expect(position['articleId'], isNull);
  });

  test('Lagerhistorie verhindert atomar das Löschen aller Gruppenartikel', () async {
    final a = await h.company('stock-guard@example.com', permissions: [
      'articles.read', 'articles.write', 'stock.read', 'stock.write',
    ], modules: {'lagerbestand'});
    final g = await a.post('/article-groups', {'name': 'Bestand', 'markupPercent': 0});
    final one = await a.post('/articles', {'name': 'Mit Historie', 'articleGroupId': g['id']});
    final two = await a.post('/articles', {'name': 'Ohne Historie', 'articleGroupId': g['id']});
    await a.post('/articles/${one['id']}/stock-correction', {'countedQuantity': '3', 'reason': 'Anfangsbestand'});
    await expectLater(a.delete('/article-groups/${g['id']}',
        query: {'mode': 'deleteArticles', 'expectedCount': '2'}), throwsStatus(409));
    expect((await a.get('/article-groups/${g['id']}/impact'))['articleCount'], 2);
    expect((await a.get('/articles/${two['id']}'))['articleGroupId'], g['id']);
    await a.delete('/article-groups/${g['id']}', query: {'mode': 'ungroup', 'expectedCount': '2'});
    expect((await a.get('/articles/${one['id']}'))['articleGroupId'], isNull);
  });

  test('Rechte: Lesen ohne Schreiben; Validierung', () async {
    final a = await h.company('a@example.com', permissions: ['articles.read']);
    await expectLater(a.post('/suppliers', {'name': 'Nord'}), throwsStatus(403));
    expect((await a.get('/article-groups'))['articleGroups'], isEmpty);
    await expectLater(a.get('/article-groups/missing/impact'), throwsStatus(404));
    await expectLater(a.delete('/article-groups/missing', query: {'mode': 'deleteArticles', 'expectedCount': '0'}), throwsStatus(403));
    final w = await h.company('w@example.com', permissions: ['articles.write']);
    await expectLater(w.post('/suppliers', {}), throwsStatus(400));
    await expectLater(w.post('/article-groups', {'name': 'X', 'markupPercent': -1}), throwsStatus(400));
    await expectLater(w.post('/suppliers', {'name': 'X', 'minimumOrderQuantity': 'viel'}), throwsStatus(400));
    await expectLater(w.get('/suppliers'), throwsStatus(403));
  });
}
