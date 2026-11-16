import 'package:test/test.dart';
import 'package:werkkern_client/werkkern_client.dart';

import 'support/module_harness.dart';

void main() => runPdfLayoutSnapshotTests(inMemoryRepositories);

void runPdfLayoutSnapshotTests(RepositoryFactory create) {
  final h = ModuleHarness(create)..install();
  const permissions = ['customers.read', 'customers.write', 'invoices.read', 'invoices.write', 'invoices.finalize'];

  test('company layout is validated and old profile updates preserve it', () async {
    final c = await h.company('layout-profile@example.com', permissions: permissions);
    expect((await c.get('/company/profile'))['pdfLayout'], 'classic');
    expect((await c.put('/company/profile', {'pdfLayout': 'nordLetterhead'}))['pdfLayout'], 'nordLetterhead');
    expect((await c.put('/company/profile', {'address': 'Example Street'}))['pdfLayout'], 'nordLetterhead');
    await expectLater(c.put('/company/profile', {'pdfLayout': 'other'}),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 400)));
    expect((await c.get('/company/profile'))['pdfLayout'], 'nordLetterhead');
  });

  test('finalized document captures layout; drafts track profile; legacy defaults classic', () async {
    final c = await h.company('layout-doc@example.com', permissions: permissions);
    final customer = (await c.post('/customers', {'name': 'Example Customer'}))['id'];
    Future<Map<String, Object?>> draft() => c.post('/documents', {
      'kind': 'invoice', 'customerId': customer,
      'items': [
        {'kind': 'text', 'description': 'Work', 'quantity': '1', 'unitPriceCents': 10000, 'vatRatePercent': 0},
      ],
    });
    final old = await draft();
    final oldFinal = await c.post('/documents/${old['id']}/finalize', {'version': old['version']});
    expect(oldFinal['pdfLayoutSnapshot'], 'classic');
    final pending = await draft();
    expect(pending['pdfLayoutSnapshot'], isNull);
    await c.put('/company/profile', {'pdfLayout': 'nordLetterhead'});
    final issued = await c.post('/documents/${pending['id']}/finalize', {'version': pending['version']});
    expect(issued['pdfLayoutSnapshot'], 'nordLetterhead');
    await c.put('/company/profile', {'pdfLayout': 'classic'});
    expect((await c.get('/documents/${pending['id']}'))['pdfLayoutSnapshot'], 'nordLetterhead');
    expect((await c.get('/documents/${old['id']}'))['pdfLayoutSnapshot'], 'classic');
  });
}
