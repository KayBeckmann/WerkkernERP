import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

import 'support/module_harness.dart';

void main() => runPdfArchiveTests(inMemoryRepositories);

void runPdfArchiveTests(RepositoryFactory create) {
  final h = ModuleHarness(create)..install();
  const perms = [
    'customers.write',
    'invoices.write',
    'invoices.read',
    'purchaseOrders.write',
    'purchaseOrders.read',
    'articles.write',
    'timeTracking.write',
  ];
  const modules = {
    'quotes',
    'orders',
    'bestellwesen',
    'lagerbestand',
    'timeTracking',
  };
  final first = Uint8List.fromList([
    ...ascii.encode('%PDF-1.4\n'),
    0,
    255,
    128,
    10,
  ]);
  final second = Uint8List.fromList([...ascii.encode('%PDF-1.7\n'), 1, 2, 3]);

  Future<http.Response> download(CompanyClient c, String path) => http.get(
    h.base.resolve(path),
    headers: {'authorization': 'Bearer ${c.client.token}'},
  );
  Future<Map<String, Object?>> invoice(CompanyClient c, String kind) async {
    final customer = await c.post('/customers', {'name': 'Test'});
    return c.post('/documents', {
      'kind': kind,
      'customerId': customer['id'],
      'items': [],
    });
  }

  test(
    'PDF creation stores v1 and v2 immediately, preserves exact bytes and hash without sending',
    () async {
      final c = await h.company(
        'archive@example.org',
        permissions: perms,
        modules: modules,
      );
      final doc = await invoice(c, 'invoice');
      final path = '/pdf-archive/document/${doc['id']}/versions';
      expect((await c.get(path))['versions'], isEmpty);
      final v1 = await c.post(path, {'pdfBase64': base64Encode(first)});
      expect(v1['version'], 1);
      expect(v1['sha256'], sha256.convert(first).toString());
      expect(v1['createdAt'], isNotNull);
      final v2 = await c.post(path, {'pdfBase64': base64Encode(second)});
      expect(v2['version'], 2);
      expect((await c.get(path))['versions'], [v1, v2]);
      final bytes = await download(c, '$path/1');
      expect(bytes.statusCode, 200);
      expect(bytes.headers['content-type'], startsWith('application/pdf'));
      expect(bytes.bodyBytes, first);
      expect((await download(c, '$path/2')).bodyBytes, second);
      expect((await download(c, '$path/3')).statusCode, 404);
      expect((await c.get(path))['versions'], [v1, v2]);
      await expectLater(c.delete('/documents/${doc['id']}'), throwsStatus(409));
    },
  );

  test('concurrent creations allocate distinct versions', () async {
    final c = await h.company(
      'parallel@example.org',
      permissions: perms,
      modules: modules,
    );
    final doc = await invoice(c, 'invoice');
    final path = '/pdf-archive/document/${doc['id']}/versions';
    final created = await Future.wait(
      List.generate(6, (_) => c.post(path, {'pdfBase64': base64Encode(first)})),
    );
    expect(created.map((v) => v['version']).toSet(), {1, 2, 3, 4, 5, 6});
    expect((await c.get(path))['versions'], hasLength(6));
  });

  test(
    'source identity, document-kind modules, read/write rights and tenant are enforced',
    () async {
      final a = await h.company(
        'a@example.org',
        permissions: perms,
        modules: modules,
      );
      final b = await h.company(
        'b@example.org',
        permissions: perms,
        modules: modules,
      );
      final quote = await invoice(a, 'quote');
      final path = '/pdf-archive/document/${quote['id']}/versions';
      await expectLater(
        b.post(path, {'pdfBase64': base64Encode(first)}),
        throwsStatus(404),
      );
      await expectLater(b.get(path), throwsStatus(404));
      await a.client.setModules({
        'orders',
        'bestellwesen',
        'lagerbestand',
        'timeTracking',
      });
      await expectLater(
        a.post(path, {'pdfBase64': base64Encode(first)}),
        throwsStatus(403),
      );
      await a.client.setModules(modules);
      await a.client.setGroupPermission(
        a.ownGroup,
        'invoices.write',
        granted: false,
      );
      await expectLater(
        a.post(path, {'pdfBase64': base64Encode(first)}),
        throwsStatus(403),
      );
      await a.client.setGroupPermission(
        a.ownGroup,
        'invoices.write',
        granted: true,
      );
      await a.post(path, {'pdfBase64': base64Encode(first)});
      await a.client.setGroupPermission(
        a.ownGroup,
        'invoices.read',
        granted: false,
      );
      await expectLater(a.get(path), throwsStatus(403));
      expect((await download(a, '$path/1')).statusCode, 403);
      expect((await download(b, '$path/1')).statusCode, 404);
      await expectLater(
        a.post('/pdf-archive/document/unknown/versions', {
          'pdfBase64': base64Encode(first),
        }),
        throwsStatus(404),
      );
      await expectLater(
        a.post('/pdf-archive/document/${quote['id']}/versions', {
          'pdfBase64': 'bad',
        }),
        throwsStatus(400),
      );
    },
  );

  test('tenant archive browses safe metadata across disabled modules with paging and rights', () async {
    final a = await h.company('browse-a@example.org', permissions: [
      ...perms, 'timeTracking.read',
    ], modules: modules);
    final b = await h.company('browse-b@example.org', permissions: perms, modules: modules);
    final quote = await invoice(a, 'quote');
    final invoiceDoc = await invoice(a, 'invoice');
    final bDoc = await invoice(b, 'invoice');
    final quotePath = '/pdf-archive/document/${quote['id']}/versions';
    final invoicePath = '/pdf-archive/document/${invoiceDoc['id']}/versions';
    final bPath = '/pdf-archive/document/${bDoc['id']}/versions';
    await a.post(quotePath, {'pdfBase64': base64Encode(first)});
    await a.post(invoicePath, {'pdfBase64': base64Encode(first)});
    await a.post(invoicePath, {'pdfBase64': base64Encode(second)});
    await b.post(bPath, {'pdfBase64': base64Encode(first)});
    await a.client.setModules({'orders', 'bestellwesen', 'lagerbestand', 'timeTracking'});
    expect((await download(a, '$quotePath/1')).statusCode, 200);
    final all = (await a.get('/pdf-archive/versions'))['versions'] as List;
    expect(all, hasLength(3));
    final dates = [for (final e in all) DateTime.parse((e as Map)['createdAt'] as String)];
    expect(dates, orderedEquals([...dates]..sort((a, b) => b.compareTo(a))));
    expect(all.map((e) => (e as Map)['sourceId']).toSet(), {quote['id'], invoiceDoc['id']});
    expect(all.every((e) => (e as Map).keys.toSet().containsAll(
      {'sourceType', 'sourceId', 'version', 'createdAt', 'sha256', 'sizeBytes'})), isTrue);
    expect(all.every((e) => !(e as Map).containsKey('bytes') && !e.containsKey('companyId')), isTrue);
    expect((await b.get('/pdf-archive/versions'))['versions'], hasLength(1));
    final firstPage = await a.get('/pdf-archive/versions', query: {'limit': '1'});
    expect(firstPage['hasMore'], isTrue);
    expect((firstPage['versions'] as List), hasLength(1));
    final page = await a.get('/pdf-archive/versions', query: {'limit': '2', 'offset': '1'});
    expect(page['versions'], all.skip(1).take(2).toList());
    expect(page['hasMore'], isFalse);
    await a.client.setGroupPermission(a.ownGroup, 'invoices.read', granted: false);
    expect((await a.get('/pdf-archive/versions'))['versions'], isEmpty);
    await expectLater(a.get('/pdf-archive/versions', query: {'limit': '1001'}), throwsStatus(400));
    await expectLater(a.get('/pdf-archive/versions', query: {'offset': '-1'}), throwsStatus(400));
  });

  test(
    'purchase orders archive, sheets reject draft and accept signed-only PDFs',
    () async {
      final c = await h.company(
        'other@example.org',
        permissions: perms,
        modules: modules,
      );
      final supplier = await c.post('/suppliers', {
        'name': 'Synthetic supplier',
      });
      final order = await c.post('/purchase-orders', {
        'supplierId': supplier['id'],
        'items': [],
      });
      final orderPath = '/pdf-archive/purchase-order/${order['id']}/versions';
      expect(
        (await c.post(orderPath, {
          'pdfBase64': base64Encode(first),
        }))['version'],
        1,
      );
      expect((await download(c, '$orderPath/1')).bodyBytes, first);
      await expectLater(
        c.delete('/purchase-orders/${order['id']}'),
        throwsStatus(409),
      );
      final doc = await invoice(c, 'order');
      final sheet = await c.post('/time-sheets', {'documentId': doc['id']});
      final path = '/pdf-archive/time-sheet/${sheet['id']}/versions';
      await expectLater(
        c.post(path, {'pdfBase64': base64Encode(first)}),
        throwsStatus(409),
      );
      expect((await c.get(path))['versions'], isEmpty);
      final entry = await c.post('/time-entries', {
        'date': '2026-10-20',
        'hours': '2',
        'documentId': doc['id'],
      });
      await c.post('/time-sheets/${sheet['id']}/entries', {
        'entryIds': [entry['id']],
      });
      const signature =
          'iVBORw0KGgo='; // PNG signature; signing validates the magic bytes.
      await c.post('/time-sheets/${sheet['id']}/sign', {
        'signaturePng': signature,
      });
      expect(
        (await c.post(path, {'pdfBase64': base64Encode(second)}))['version'],
        1,
      );
      expect((await download(c, '$path/1')).bodyBytes, second);
      await c.client.setGroupPermission(c.ownGroup, 'timeTracking.write', granted: false);
      await c.client.setGroupPermission(c.ownGroup, 'timeTracking.read', granted: true);
      await c.client.setModules({'lagerbestand'});
      expect((await c.get(path))['versions'], hasLength(1));
      expect((await download(c, '$orderPath/1')).bodyBytes, first);
      expect((await download(c, '$path/1')).bodyBytes, second);
      expect((await c.get('/pdf-archive/versions'))['versions'], hasLength(2));
    },
  );
}
