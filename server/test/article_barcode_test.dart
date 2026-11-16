import 'package:test/test.dart';
import 'package:werkkern_client/werkkern_client.dart';

import 'support/module_harness.dart';

void main() => runArticleBarcodeTests(inMemoryRepositories);

/// A1-Nachtrag (Kay, 16.11.2026): Barcode je Artikel, je Firma eindeutig,
/// exakte Suche nur in der eigenen Firma.
void runArticleBarcodeTests(RepositoryFactory create) {
  final h = ModuleHarness(create)..install();
  const permissions = ['articles.read', 'articles.write'];
  Matcher status(int code) => throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', code));

  test('Barcode: führende Null, eindeutig je Firma, Suche exakt, ältere Clients löschen nichts', () async {
    final a = await h.company('bc1@example.com', permissions: permissions);
    final b = await h.company('bc2@example.com', permissions: permissions);
    final fi = await a.post('/articles', {'name': 'FI-Schalter', 'barcode': ' 0401 2345 ', 'active': true});
    expect(fi['barcode'], '04012345');
    await expectLater(a.post('/articles', {'name': 'Doppelt', 'barcode': '04012345'}), status(409));
    // Andere Firma darf denselben Code haben und sieht den fremden Artikel nicht.
    await b.post('/articles', {'name': 'Fremd', 'barcode': '04012345'});
    expect((await a.client.articleByBarcode('04012345'))!.name, 'FI-Schalter');
    expect((await b.client.articleByBarcode('04012345'))!.name, 'Fremd');
    expect(await a.client.articleByBarcode('0401234'), isNull, reason: 'nur exakt');

    final legacy = await a.put('/articles/${fi['id']}', {'name': 'FI-Schalter 40A', 'active': true});
    expect(legacy['barcode'], '04012345', reason: 'nicht genannt = unverändert');
    final ls = await a.post('/articles', {'name': 'LS-Schalter', 'active': true});
    await expectLater(a.put('/articles/${ls['id']}', {'name': 'LS', 'barcode': '04012345'}), status(409));
    final removed = await a.put('/articles/${fi['id']}', {'name': 'FI', 'barcode': '', 'active': true});
    expect(removed['barcode'], isNull);
    await a.put('/articles/${ls['id']}', {'name': 'LS', 'barcode': '04012345', 'active': true});
    expect((await a.client.articleByBarcode('04012345'))!.name, 'LS');
  });
}
