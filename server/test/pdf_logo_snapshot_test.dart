import 'dart:convert';
import 'dart:typed_data';

import 'package:image/image.dart' as image;
import 'package:test/test.dart';
import 'package:werkkern_client/werkkern_client.dart';

import 'support/module_harness.dart';

// Synthetic 1x1 PNG; no customer or brand asset.
final syntheticPng = base64Encode(base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGP4z8DwHwAFAAH/iZk9HQAAAABJRU5ErkJggg==',
));

void main() => runPdfLogoTests(inMemoryRepositories);

void runPdfLogoTests(RepositoryFactory create) {
  final h = ModuleHarness(create)..install();
  const permissions = ['customers.read', 'customers.write', 'invoices.read', 'invoices.write', 'invoices.finalize'];

  test('profile logo upload, replacement, removal and legacy updates are tenant scoped', () async {
    final a = await h.company('logo-a@example.test', permissions: permissions);
    final b = await h.company('logo-b@example.test', permissions: permissions);
    expect((await a.get('/company/profile'))['pdfLogoBase64'], isNull);
    expect((await a.put('/company/profile', {'pdfLogoBase64': syntheticPng}))['pdfLogoBase64'], syntheticPng);
    expect((await b.get('/company/profile'))['pdfLogoBase64'], isNull);
    expect((await a.put('/company/profile', {'address': 'Example Street'}))['pdfLogoBase64'], syntheticPng);
    final jpeg = base64Encode(image.encodeJpg(image.Image(width: 2, height: 2)));
    expect((await a.put('/company/profile', {'pdfLogoBase64': jpeg}))['pdfLogoBase64'], jpeg);
    expect((await a.put('/company/profile', {'pdfLogoBase64': null}))['pdfLogoBase64'], isNull);
  });

  test('rejects invalid encoding, spoofed image, oversized bytes and excessive dimensions', () async {
    final c = await h.company('logo-validation@example.test', permissions: permissions);
    for (final payload in [
      'not base64!',
      base64Encode(utf8.encode('<svg onload="alert(1)"/>')),
      base64Encode(base64Decode(syntheticPng).sublist(0, 40)),
      base64Encode([...base64Decode(syntheticPng), ...utf8.encode('<script>')]),
      base64Encode(Uint8List(1024 * 1024 + 1)),
      base64Encode(Uint8List.fromList(base64Decode(syntheticPng))..setRange(16, 20, [0, 0, 32, 0])),
    ]) {
      await expectLater(c.put('/company/profile', {'pdfLogoBase64': payload}),
          throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 400)));
    }
    expect((await c.get('/company/profile'))['pdfLogoBase64'], isNull);
  });

  test('finalized logo bytes remain after profile removal; old documents have no logo', () async {
    final c = await h.company('logo-final@example.test', permissions: permissions);
    final customer = (await c.post('/customers', {'name': 'Synthetic Customer'}))['id'];
    Future<Map<String, Object?>> draft() => c.post('/documents', {
      'kind': 'invoice', 'customerId': customer,
      'items': [{'kind': 'text', 'description': 'Work', 'quantity': '1', 'unitPriceCents': 100, 'vatRatePercent': 0}],
    });
    final old = await draft();
    final oldFinal = await c.post('/documents/${old['id']}/finalize', {'version': old['version']});
    expect(oldFinal['pdfLogoSnapshot'], isNull);
    await c.put('/company/profile', {'pdfLogoBase64': syntheticPng});
    final pending = await draft();
    expect(pending['pdfLogoSnapshot'], isNull);
    final issued = await c.post('/documents/${pending['id']}/finalize', {'version': pending['version']});
    expect(issued['pdfLogoSnapshot'], syntheticPng);
    await c.put('/company/profile', {'pdfLogoBase64': null});
    expect((await c.get('/documents/${pending['id']}'))['pdfLogoSnapshot'], syntheticPng);
    expect((await c.get('/documents/${old['id']}'))['pdfLogoSnapshot'], isNull);
  });
}
