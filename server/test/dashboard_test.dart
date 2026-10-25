import 'package:test/test.dart';
import 'package:werkkernerp_server/src/permission_catalog.dart';

import 'support/module_harness.dart';

void main() => runDashboardTests(inMemoryRepositories);

/// Dashboard nach Rechten + Modulen, Ausblenden je Nutzer.
void runDashboardTests(RepositoryFactory create) {
  final h = ModuleHarness(create)..install();
  const modules = {'timeTracking', 'orders', 'dunning', 'lagerbestand', 'projects'};

  Future<List<String>> keys(CompanyClient c) async =>
      [for (final t in (await c.get('/dashboard'))['tiles'] as List) (t as Map)['key'] as String];

  test('Buchhaltung sieht Finanzen, Monteur (Standardrechte) nur seine Arbeit', () async {
    final chef = await h.company('chef@example.com', permissions: [...starterGroupPermissions['Buchhaltung']!], modules: modules);
    for (final p in starterGroupPermissions['Monteur']!) {
      await chef.client.setGroupPermission(chef.groups['Monteur']!, p, granted: true);
    }
    final customer = (await chef.post('/customers', {'name': 'Meyer'}))['id'] as String;
    final draft = await chef.post('/documents', {
      'kind': 'invoice',
      'customerId': customer,
      'items': [{'kind': 'text', 'description': 'x', 'quantity': '1', 'unitPriceCents': 10000, 'vatRatePercent': 19}],
    });
    final invoice = await chef.post('/documents/${draft['id']}/finalize', {'version': draft['version']});
    await chef.put('/documents/${invoice['id']}/due-date', {'dueDate': '2020-01-01'});

    final chefTiles = ((await chef.get('/dashboard'))['tiles'] as List).cast<Map<String, Object?>>();
    expect(chefTiles.map((t) => t['key']), containsAll(['openInvoices', 'revenue', 'overdue']));
    final open = chefTiles.firstWhere((t) => t['key'] == 'openInvoices');
    expect(open['count'], 1);
    expect(open['amountCents'], 11900);
    expect(open['detail'], '1 überfällig');
    expect(chefTiles.firstWhere((t) => t['key'] == 'overdue')['count'], 1);

    final monteurClient = await h.member(chef, 'monteur@example.com');
    final monteur = CompanyClient(monteurClient, chef.companyId, '', const {});
    final order = await monteur.post('/documents', {'kind': 'order', 'customerId': customer, 'items': []});
    await monteur.post('/time-entries', {'date': _today(), 'hours': '2.5', 'documentId': order['id']});
    final monteurTiles = ((await monteur.get('/dashboard'))['tiles'] as List).cast<Map<String, Object?>>();
    final monteurKeys = monteurTiles.map((t) => t['key']).toList();
    expect(monteurKeys, containsAll(['drafts', 'myHours', 'timeSheets', 'lowStock', 'projects']));
    expect(monteurKeys, isNot(contains('openInvoices')));
    expect(monteurKeys, isNot(contains('revenue')));
    expect(monteurKeys, isNot(contains('overdue')));
    expect(monteurTiles.firstWhere((t) => t['key'] == 'drafts')['count'], 1, reason: 'nur eigene Entwürfe');
    expect(monteurTiles.firstWhere((t) => t['key'] == 'myHours')['value'], '2.5');
  });

  test('Ausblenden gilt je Nutzer; Modul aus entfernt die Kachel', () async {
    final c = await h.company('a@example.com', permissions: ['invoices.read', 'invoices.write', 'timeTracking.write'], modules: modules);
    expect(await keys(c), containsAll(['drafts', 'myHours']));
    await c.put('/dashboard/preferences', {'hidden': ['myHours']});
    expect(await keys(c), isNot(contains('myHours')));
    final all = await c.get('/dashboard');
    expect(all['available'], contains('myHours'), reason: 'zum Wiedereinblenden bekannt');
    await expectLater(c.put('/dashboard/preferences', {'hidden': ['geheim']}), throwsStatus(400));
    await c.client.setModules({'orders'});
    expect(await keys(c), ['drafts']);
  });
}

String _today() {
  final d = DateTime.now().toUtc();
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
