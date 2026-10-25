import 'package:test/test.dart';

import 'support/module_harness.dart';

void main() => runDunningTests(inMemoryRepositories);

String _daysAgo(int days) {
  final d = DateTime.now().toUtc().subtract(Duration(days: days));
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

/// C12 online: Stufen, Gebühren, Zins, Protokoll — Kern wie offline.
void runDunningTests(RepositoryFactory create) {
  final h = ModuleHarness(create)..install();
  const permissions = [
    'customers.read', 'customers.write', 'invoices.read', 'invoices.write', 'invoices.finalize', 'invoices.payment',
    'dunning.read', 'dunning.write',
  ];
  const modules = {'dunning', 'orders'};

  Future<Map<String, Object?>> invoiceDue(CompanyClient c, String customerId, int daysAgo, {String kind = 'invoice'}) async {
    final draft = await c.post('/documents', {
      'kind': kind,
      'customerId': customerId,
      'items': [
        {'kind': 'text', 'description': 'Leistung', 'quantity': '1', 'unitPriceCents': 100000, 'vatRatePercent': 0},
      ],
    });
    final finalized = await c.post('/documents/${draft['id']}/finalize', {'version': draft['version']});
    if (kind == 'invoice') await c.put('/documents/${finalized['id']}/due-date', {'dueDate': _daysAgo(daysAgo)});
    return finalized;
  }

  test('Stufen nach Fristen, Gebühr je Stufe, Zins 365-Tage-Basis; bezahlt/nicht fällig fallen raus', () async {
    final c = await h.company('a@example.com', permissions: permissions, modules: modules);
    final settings = await c.put('/dunning/settings', {
      'reminder2AfterDays': 10,
      'reminder3AfterDays': 20,
      'feeLevel1Cents': 0,
      'feeLevel2Cents': 500,
      'feeLevel3Cents': 1000,
      'interestRatePercent': 9.125,
      'introText': 'Sicher ein Versehen.',
    });
    expect(settings['reminder3AfterDays'], 20);
    final customer = (await c.post('/customers', {'name': 'Meyer'}))['id'] as String;
    final level1 = await invoiceDue(c, customer, 3);
    final level2 = await invoiceDue(c, customer, 12);
    final level3 = await invoiceDue(c, customer, 73);
    final paid = await invoiceDue(c, customer, 50);
    await c.post('/documents/${paid['id']}/payment', {'paid': true});
    await invoiceDue(c, customer, -5); // noch nicht fällig
    await invoiceDue(c, customer, 0, kind: 'order');

    final overdue = ((await c.get('/dunning/overdue'))['overdue'] as List).cast<Map<String, Object?>>();
    expect(overdue.map((o) => o['documentId']), [level3['id'], level2['id'], level1['id']]);
    expect(overdue.map((o) => o['level']), [3, 2, 1]);
    expect(overdue[1]['feeCents'], 500);
    // 1000 € × 9,125 % × 73/365 = 18,25 €
    expect(overdue[0]['interestCents'], 1825);
    expect(overdue[0]['totalDueCents'], 100000 + 1000 + 1825);

    final notice = await c.post('/documents/${level2['id']}/dunning-notices');
    expect(notice['title'], '2. Mahnung');
    expect(notice['introText'], 'Sicher ein Versehen.');
    expect(notice['totalDueCents'], 100500 + (notice['interestCents'] as int));
    final again = ((await c.get('/dunning/overdue'))['overdue'] as List).cast<Map<String, Object?>>();
    expect((again.firstWhere((o) => o['documentId'] == level2['id'])['lastNotice'] as Map)['level'], 2);
    expect(((await c.get('/documents/${level2['id']}/dunning-notices'))['notices'] as List), hasLength(1));
    await expectLater(c.post('/documents/${paid['id']}/dunning-notices'), throwsStatus(409));
  });

  test('Einstellungen validiert, Rechte, Modul, Firmentrennung', () async {
    final a = await h.company('a@example.com', permissions: permissions, modules: modules);
    final b = await h.company('b@example.com', permissions: permissions, modules: modules);
    await expectLater(a.put('/dunning/settings', {'reminder2AfterDays': 30, 'reminder3AfterDays': 10}), throwsStatus(400));
    await expectLater(a.put('/dunning/settings', {'feeLevel1Cents': -1}), throwsStatus(400));
    await expectLater(a.put('/dunning/settings', {'geheim': 1}), throwsStatus(400));
    expect((await a.get('/dunning/settings'))['reminder2AfterDays'], 14, reason: 'Vorgabe wie offline');

    final customer = (await a.post('/customers', {'name': 'Meyer'}))['id'] as String;
    final invoice = await invoiceDue(a, customer, 30);
    await expectLater(b.post('/documents/${invoice['id']}/dunning-notices'), throwsStatus(404));
    expect((await b.get('/dunning/overdue'))['overdue'], isEmpty);

    final reader = await h.company('r@example.com', permissions: ['dunning.read'], modules: modules);
    await expectLater(reader.put('/dunning/settings', {'reminder2AfterDays': 1}), throwsStatus(403));
    await a.client.setModules({'orders'});
    await expectLater(a.get('/dunning/overdue'), throwsStatus(403));
  });
}
