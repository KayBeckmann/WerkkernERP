import 'package:test/test.dart';
import 'package:werkkern_client/werkkern_client.dart';

import 'support/module_harness.dart';

void main() => runAgentModuleTests(inMemoryRepositories);

String _daysAgo(int days) {
  final d = DateTime.now().toUtc().subtract(Duration(days: days));
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

/// C8 für die Online-Fachmodule: was eine Nummer vergibt, Bestand bucht,
/// eine Mahnung protokolliert oder einen Entwurf/Beleg löscht, legt über
/// ein Agent-Token nur eine Freigabe-Anfrage an. Ausgeführt wird erst nach
/// Bestätigung in der App; Unterschreiben bleibt dem Kunden vorbehalten.
void runAgentModuleTests(RepositoryFactory create) {
  final h = ModuleHarness(create)..install();
  const permissions = [
    'customers.read',
    'customers.write',
    'articles.read',
    'articles.write',
    'invoices.read',
    'invoices.write',
    'invoices.finalize',
    'invoices.payment',
    'stock.read',
    'stock.write',
    'purchaseOrders.read',
    'purchaseOrders.write',
    'accounting.read',
    'accounting.write',
    'dunning.read',
    'dunning.write',
    'timeTracking.read',
    'timeTracking.write',
  ];
  const modules = {'aiAgents', 'bestellwesen', 'lagerbestand', 'buchhaltung', 'dunning', 'timeTracking'};

  Future<({CompanyClient user, CompanyClient agent})> setup() async {
    final user = await h.company('a@example.com', permissions: permissions, modules: modules);
    final agentClient = WerkkernApiClient(baseUrl: h.base)..token = (await user.client.createAgentToken('Agent')).token;
    return (user: user, agent: CompanyClient(agentClient, user.companyId, user.ownGroup, user.groups));
  }

  Future<String> pendingId(Future<Map<String, Object?>> request) async {
    final response = await request;
    expect(response['status'], 'pending');
    return response['approvalId'] as String;
  }

  test('Bestellung: Finalisieren, Wareneingang und Löschen nur nach Bestätigung', () async {
    final s = await setup();
    final supplier = (await s.agent.post('/suppliers', {'name': 'Nord'}))['id'] as String;
    final cable = (await s.agent.post('/articles', {'name': 'Kabel'}))['id'] as String;
    final draft = await s.agent.post('/purchase-orders', {
      'supplierId': supplier,
      'items': [
        {'articleId': cable, 'description': 'Kabel', 'quantity': '100', 'purchasePriceCents': 120},
      ],
    });

    final finalizeRequest = await s.agent.post('/purchase-orders/${draft['id']}/finalize', {
      'version': draft['version'],
    });
    expect(finalizeRequest['summary'], contains('bei Nord über 120,00 € netto finalisieren'));
    expect((await s.user.get('/purchase-orders/${draft['id']}'))['status'], 'draft', reason: 'nichts ohne Bestätigung');
    await s.user.client.confirmApproval(finalizeRequest['approvalId'] as String);
    final order = await s.user.get('/purchase-orders/${draft['id']}');
    expect(order['number'], startsWith('B-'));

    final item = ((order['items'] as List).single as Map)['id'] as String;
    final receive = await pendingId(
      s.agent.post('/purchase-orders/${draft['id']}/receive', {
        'receipts': {item: '40'},
      }),
    );
    expect((await s.user.get('/articles/$cable'))['stockQuantity'], '0');
    await s.user.client.confirmApproval(receive);
    expect((await s.user.get('/articles/$cable'))['stockQuantity'], '40');

    final second = await s.agent.post('/purchase-orders', {
      'supplierId': supplier,
      'items': [
        {'description': 'Versand', 'quantity': '1', 'purchasePriceCents': 990},
      ],
    });
    final delete = await s.agent.client.request('DELETE', '/purchase-orders/${second['id']}') as Map<String, Object?>;
    expect(delete['status'], 'pending');
    expect((await s.user.get('/purchase-orders/${second['id']}'))['status'], 'draft');
    await expectLater(
      s.agent.client.request('DELETE', '/purchase-orders/${draft['id']}'),
      throwsStatus(409),
      reason: 'finalisierte Bestellung: keine sinnlose Freigabe-Anfrage',
    );
  });

  test('Lager: Bestandskorrektur und Inventur-Abschluss nur nach Bestätigung', () async {
    final s = await setup();
    final cable = (await s.user.post('/articles', {'name': 'Kabel'}))['id'] as String;
    final correction = await pendingId(
      s.agent.post('/articles/$cable/stock-correction', {'countedQuantity': '12', 'reason': 'Zählung Lager'}),
    );
    expect((await s.user.get('/articles/$cable'))['stockQuantity'], '0');
    await s.user.client.confirmApproval(correction);
    expect((await s.user.get('/articles/$cable'))['stockQuantity'], '12');

    final count = await s.agent.post('/inventory-counts', {'label': 'Inventur', 'allArticles': true});
    final item = ((count['items'] as List).single as Map)['id'] as String;
    await s.agent.put('/inventory-counts/${count['id']}/items/$item', {'countedQuantity': '10'});
    final complete = await pendingId(s.agent.post('/inventory-counts/${count['id']}/complete'));
    expect((await s.user.get('/inventory-counts/${count['id']}'))['status'], 'draft');
    await s.user.client.confirmApproval(complete);
    expect((await s.user.get('/inventory-counts/${count['id']}'))['status'], 'completed');
    expect((await s.user.get('/articles/$cable'))['stockQuantity'], '10');
  });

  test('Mahnung und Beleg-Löschen nur nach Bestätigung; Ablehnen ändert nichts', () async {
    final s = await setup();
    final customer = (await s.user.post('/customers', {'name': 'Meyer'}))['id'] as String;
    final draft = await s.user.post('/documents', {
      'customerId': customer,
      'items': [
        {'kind': 'text', 'description': 'Leistung', 'quantity': '1', 'unitPriceCents': 100000, 'vatRatePercent': 0},
      ],
    });
    final invoice = await s.user.post('/documents/${draft['id']}/finalize', {'version': draft['version']});
    await s.user.put('/documents/${invoice['id']}/due-date', {'dueDate': _daysAgo(20)});

    final dunning = await s.agent.post('/documents/${invoice['id']}/dunning-notices');
    expect(dunning['summary'], contains('Meyer'));
    expect((await s.user.get('/documents/${invoice['id']}/dunning-notices'))['notices'], isEmpty);
    await s.user.client.confirmApproval(dunning['approvalId'] as String);
    expect((await s.user.get('/documents/${invoice['id']}/dunning-notices'))['notices'] as List, hasLength(1));

    final expense = await s.agent.post('/expenses', {
      'date': '2026-10-01',
      'description': 'Tankbeleg',
      'amountGrossCents': 5950,
      'vatRatePercent': 19,
    });
    final delete = await s.agent.client.request('DELETE', '/expenses/${expense['id']}') as Map<String, Object?>;
    expect(delete['summary'], contains('Tankbeleg'));
    await s.user.client.request('POST', '/approvals/${delete['approvalId']}/reject');
    expect((await s.user.get('/expenses'))['expenses'] as List, hasLength(1), reason: 'abgelehnt: Beleg bleibt');
  });

  test('Stundenzettel: Agent unterschreibt nie; Entwurf löschen nur nach Bestätigung', () async {
    final s = await setup();
    final customer = (await s.user.post('/customers', {'name': 'Meyer'}))['id'] as String;
    final draft = await s.user.post('/documents', {'customerId': customer, 'items': const []});
    final entry = await s.agent.post('/time-entries', {'date': '2026-10-20', 'hours': '2', 'documentId': draft['id']});
    final sheet = await s.agent.post('/time-sheets', {
      'documentId': draft['id'],
      'date': '2026-10-20',
      'entryIds': [entry['id']],
    });

    await expectLater(
      s.agent.post('/time-sheets/${sheet['id']}/sign', {'signaturePng': 'iVBORw0KGgo=', 'signerName': 'KI'}),
      throwsStatus(403),
    );
    final delete = await s.agent.client.request('DELETE', '/time-sheets/${sheet['id']}') as Map<String, Object?>;
    expect(delete['status'], 'pending');
    expect((await s.user.get('/time-sheets/${sheet['id']}'))['status'], 'draft');
    await s.user.client.confirmApproval(delete['approvalId'] as String);
    await expectLater(s.user.get('/time-sheets/${sheet['id']}'), throwsStatus(404));
  });
}
