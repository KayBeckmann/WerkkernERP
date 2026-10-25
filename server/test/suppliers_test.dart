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

    await a.delete('/article-groups/${group['id']}');
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
    await expectLater(b.delete('/article-groups/${groupA['id']}'), throwsStatus(404));
    await expectLater(b.put('/suppliers/${supplierA['id']}', {'name': 'gekapert'}), throwsStatus(404));
    expect((await a.get('/suppliers/${supplierA['id']}'))['name'], 'Nord');
  });

  test('Rechte: Lesen ohne Schreiben; Validierung', () async {
    final a = await h.company('a@example.com', permissions: ['articles.read']);
    await expectLater(a.post('/suppliers', {'name': 'Nord'}), throwsStatus(403));
    expect((await a.get('/article-groups'))['articleGroups'], isEmpty);
    final w = await h.company('w@example.com', permissions: ['articles.write']);
    await expectLater(w.post('/suppliers', {}), throwsStatus(400));
    await expectLater(w.post('/article-groups', {'name': 'X', 'markupPercent': -1}), throwsStatus(400));
    await expectLater(w.post('/suppliers', {'name': 'X', 'minimumOrderQuantity': 'viel'}), throwsStatus(400));
    await expectLater(w.get('/suppliers'), throwsStatus(403));
  });
}
