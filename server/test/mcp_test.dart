import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:test/test.dart';
import 'package:werkkern_client/werkkern_client.dart';
import 'package:werkkern_mcp/werkkern_mcp.dart';

import 'package:werkkernerp_server/src/business/repository_memory.dart';
import 'package:werkkernerp_server/src/repository_memory.dart';
import 'package:werkkernerp_server/src/router.dart';

import 'support/starter_groups.dart';

/// C8: MCP-Tools als dünne Schicht über der REST-API, gegen den echten
/// Router. Regelgleichheit UI/API/MCP: dieselben Endpunkte, dieselbe
/// Rechteprüfung; Finalisieren nur über die Freigabe in der App.
void main() {
  late HttpServer server;
  late Uri base;
  late WerkkernApiClient user;
  late String agentToken;
  late String monteurGroup;

  setUp(() async {
    final router = PhaseBRouter(repository: InMemoryPhaseBRepository(), business: InMemoryBusinessRepository());
    server = await shelf_io.serve(router.handler.call, InternetAddress.loopbackIPv4, 0);
    base = Uri.parse('http://127.0.0.1:${server.port}');
    user = WerkkernApiClient(baseUrl: base);
    await user.register('kay@example.com', 'passwort-12345');
    final companyId = await user.createCompany((await user.login('kay@example.com', 'passwort-12345')).identityToken, 'Elektro Kay');
    await user.selectCompany((await user.login('kay@example.com', 'passwort-12345')).identityToken, companyId);
    await clearGroupPermissions(user);
    final groups = await user.groups();
    final own = groups.firstWhere((g) => g.name == 'Projektleiter');
    monteurGroup = groups.firstWhere((g) => g.name == 'Monteur').id;
    for (final p in ['customers.read', 'customers.write', 'invoices.read', 'invoices.write', 'invoices.finalize']) {
      await user.setGroupPermission(own.id, p, granted: true);
    }
    await user.setModules({'aiAgents'});
    agentToken = (await user.createAgentToken('Test-Agent')).token;
  });
  tearDown(() => server.close(force: true));

  Future<Map<String, Object?>> callTool(WerkkernMcpServer mcp, String name, Map<String, Object?> args, {int id = 1}) async {
    final response = await mcp.handle({
      'jsonrpc': '2.0',
      'id': id,
      'method': 'tools/call',
      'params': {'name': name, 'arguments': args},
    });
    return response!['result'] as Map<String, Object?>;
  }

  Object? payload(Map<String, Object?> toolResult) =>
      jsonDecode(((toolResult['content'] as List).single as Map)['text'] as String);

  test('Initialisierung, Tool-Liste, Arbeit am Entwurf, Finalisieren nur über Freigabe', () async {
    final mcp = WerkkernMcpServer(WerkkernApiClient(baseUrl: base)..token = agentToken);
    final init = await mcp.handle({'jsonrpc': '2.0', 'id': 0, 'method': 'initialize', 'params': {'protocolVersion': '2025-06-18'}});
    expect((init!['result'] as Map)['protocolVersion'], '2025-06-18');
    expect(await mcp.handle({'jsonrpc': '2.0', 'method': 'notifications/initialized'}), isNull);
    final tools = ((await mcp.handle({'jsonrpc': '2.0', 'id': 1, 'method': 'tools/list'}))!['result'] as Map)['tools'] as List;
    expect(tools.map((t) => (t as Map)['name']), containsAll(['create_document_draft', 'finalize_document', 'list_approvals']));

    final customer = payload(await callTool(mcp, 'create_customer', {'name': 'Baustelle Meyer'})) as Map;
    final draft = payload(await callTool(mcp, 'create_document_draft', {
      'customerId': customer['id'],
      'items': [
        {'kind': 'hours', 'description': 'Montage', 'quantity': '2', 'unitPriceCents': 6500, 'vatRatePercent': 19},
      ],
    })) as Map;
    expect((draft['totals'] as Map)['grossCents'], 15470);

    final finalize = payload(await callTool(mcp, 'finalize_document', {'id': draft['id'], 'version': draft['version']})) as Map;
    expect(finalize['status'], 'pending');
    expect((payload(await callTool(mcp, 'get_document', {'id': draft['id']})) as Map)['status'], 'draft');

    // Nutzer bestätigt in der App.
    final pending = await user.approvals(status: 'pending');
    await user.confirmApproval(pending.single.id);
    final finalized = payload(await callTool(mcp, 'get_document', {'id': draft['id']})) as Map;
    expect(finalized['number'], matches(RegExp(r'^R-\d{5}$')));
    final approvals = payload(await callTool(mcp, 'list_approvals', {'status': 'confirmed'})) as Map;
    expect((approvals['approvals'] as List).single['resultStatus'], 200);
  });

  test('Verbotenes wird pro Aufruf abgewiesen und dem Modell als Tool-Fehler gemeldet', () async {
    // Agent eines Monteurs ohne Schreibrecht.
    await user.setGroupPermission(monteurGroup, 'customers.read', granted: true);
    final invitation = await user.createInvitation('monteur@example.com', monteurGroup);
    final monteur = WerkkernApiClient(baseUrl: base);
    final companyId = await monteur.acceptInvitation(invitation, 'passwort-12345');
    await monteur.selectCompany((await monteur.login('monteur@example.com', 'passwort-12345')).identityToken, companyId);
    final monteurAgent = (await monteur.createAgentToken('Handy')).token;
    final mcp = WerkkernMcpServer(WerkkernApiClient(baseUrl: base)..token = monteurAgent);

    final listed = await callTool(mcp, 'list_customers', {});
    expect(listed['isError'], isNull);
    final denied = await callTool(mcp, 'create_customer', {'name': 'Darf nicht'});
    expect(denied['isError'], isTrue);
    expect(((denied['content'] as List).single as Map)['text'], contains('403'));
    expect(await user.customers(query: 'Darf nicht'), isEmpty);

    final unknown = await mcp.handle({'jsonrpc': '2.0', 'id': 9, 'method': 'tools/call', 'params': {'name': 'drop_database'}});
    expect((unknown!['error'] as Map)['code'], -32602);
  });

  /// Volle Rechte und alle Fachmodule für die eigene Gruppe (Projektleiter).
  Future<void> enableAllModules() async {
    final own = (await user.groups()).firstWhere((g) => g.name == 'Projektleiter').id;
    for (final p in [
      'articles.read', 'articles.write', 'invoices.payment', 'projects.read', 'projects.write', 'timeTracking.read',
      'timeTracking.write', 'fleet.read', 'fleet.write', 'accounting.read', 'accounting.write', 'stock.read',
      'stock.write', 'purchaseOrders.read', 'purchaseOrders.write', 'dunning.read', 'dunning.write',
    ]) {
      await user.setGroupPermission(own, p, granted: true);
    }
    await user.setModules({
      'aiAgents', 'orders', 'projects', 'timeTracking', 'fleet', 'buchhaltung', 'lagerbestand', 'bestellwesen',
      'dunning', 'recurringInvoices',
    });
  }

  test('Jedes lesende Modul-Werkzeug erreicht seinen Endpunkt', () async {
    await enableAllModules();
    final mcp = WerkkernMcpServer(WerkkernApiClient(baseUrl: base)..token = agentToken);
    final tools = ((await mcp.handle({'jsonrpc': '2.0', 'id': 1, 'method': 'tools/list'}))!['result'] as Map)['tools'] as List;
    final names = tools.map((t) => (t as Map)['name'] as String).toSet();
    final reads = <String, Map<String, Object?>>{
      'get_dashboard': {},
      'list_projects': {'includeArchived': true},
      'list_time_entries': {'mine': true},
      'list_time_sheets': {},
      'list_suppliers': {},
      'list_purchase_orders': {'status': 'draft'},
      'purchase_order_suggestions': {},
      'list_low_stock': {},
      'list_stock_movements': {},
      'list_vehicles': {},
      'list_vehicle_costs': {'from': '2026-01-01', 'to': '2026-12-31'},
      'list_expenses': {},
      'list_open_items': {},
      'get_euer': {'from': '2026-01-01', 'to': '2026-12-31'},
      'list_overdue_invoices': {},
      'list_recurring_templates': {},
    };
    expect(names, containsAll(reads.keys));
    for (final MapEntry(key: name, value: args) in reads.entries) {
      final result = await callTool(mcp, name, args);
      expect(result['isError'], isNull, reason: '$name: ${((result['content'] as List).single as Map)['text']}');
    }
  });

  test('Bestellung, Wareneingang, Bestand, Zeiten und Belege über MCP — Irreversibles nur per Freigabe', () async {
    await enableAllModules();
    final mcp = WerkkernMcpServer(WerkkernApiClient(baseUrl: base)..token = agentToken);
    Future<Map> tool(String name, Map<String, Object?> args) async {
      final result = await callTool(mcp, name, args);
      expect(result['isError'], isNull, reason: '$name: ${((result['content'] as List).single as Map)['text']}');
      return payload(result) as Map;
    }

    final supplier = await tool('create_supplier', {'name': 'Elektrogroßhandel Nord'});
    final article = await user.request('POST', '/articles', body: {'name': 'NYM-J 3x1,5', 'minimumStock': '50'}) as Map;
    expect(((await tool('list_low_stock', {}))['articles'] as List).single['id'], article['id']);

    final draft = await tool('create_purchase_order_draft', {
      'supplierId': supplier['id'],
      'items': [
        {'articleId': article['id'], 'description': 'NYM-J 3x1,5', 'quantity': '100', 'purchasePriceCents': 89},
      ],
    });
    expect(draft['totalNetCents'], 8900);
    final finalize = await tool('finalize_purchase_order', {'id': draft['id'], 'version': draft['version']});
    expect(finalize['status'], 'pending');
    expect((await tool('get_purchase_order', {'id': draft['id']}))['status'], 'draft');
    await user.confirmApproval(finalize['approvalId'] as String);
    final order = await tool('get_purchase_order', {'id': draft['id']});
    expect(order['number'], startsWith('B-'));

    final position = ((order['items'] as List).single as Map)['id'];
    final receive = await tool('receive_purchase_order', {
      'id': draft['id'],
      'receipts': {position: '100'},
    });
    expect(receive['status'], 'pending');
    await user.confirmApproval(receive['approvalId'] as String);
    final movements = (await tool('list_stock_movements', {'articleId': article['id']}))['movements'] as List;
    expect(movements.single['type'], 'purchaseOrderReceipt');

    final correction = await tool('correct_stock', {'id': article['id'], 'countedQuantity': '98', 'reason': 'Verschnitt'});
    expect(correction['status'], 'pending');
    await user.confirmApproval(correction['approvalId'] as String);
    expect((await user.request('GET', '/articles/${article['id']}') as Map)['stockQuantity'], '98');

    final project = await tool('create_project', {'name': 'Neubau Meyer'});
    final entry = await tool('create_time_entry', {'date': '2026-10-30', 'hours': '3.5', 'projectId': project['id']});
    expect(entry['hours'], '3.5');
    final expense = await tool('create_expense', {
      'date': '2026-10-30',
      'description': 'Bohrer',
      'amountGrossCents': 2380,
      'vatRatePercent': 19,
      'projectId': project['id'],
    });
    expect(expense['amountGrossCents'], 2380);
    expect(((await tool('list_expenses', {'projectId': project['id']}))['expenses'] as List), hasLength(1));
    expect(await user.approvals(status: 'pending'), isEmpty, reason: 'Anlegen braucht keine Freigabe');
  });

  test('Echter stdio-Prozess (bin/werkkern_mcp.dart) spricht MCP gegen den Server', () async {
    final process = await Process.start(
      Platform.resolvedExecutable,
      ['run', 'bin/werkkern_mcp.dart'],
      workingDirectory: '../packages/werkkern_mcp',
      environment: {'WERKKERN_URL': base.toString(), 'WERKKERN_AGENT_TOKEN': agentToken},
    );
    final lines = process.stdout.transform(utf8.decoder).transform(const LineSplitter()).asBroadcastStream();
    Future<Map<String, Object?>> send(Map<String, Object?> message) async {
      process.stdin.writeln(jsonEncode(message));
      return jsonDecode(await lines.first.timeout(const Duration(seconds: 60))) as Map<String, Object?>;
    }

    try {
      final init = await send({'jsonrpc': '2.0', 'id': 1, 'method': 'initialize', 'params': {'protocolVersion': '2025-06-18'}});
      expect(((init['result'] as Map)['serverInfo'] as Map)['name'], 'werkkern-erp');
      process.stdin.writeln(jsonEncode({'jsonrpc': '2.0', 'method': 'notifications/initialized'}));
      final created = await send({
        'jsonrpc': '2.0',
        'id': 2,
        'method': 'tools/call',
        'params': {'name': 'create_customer', 'arguments': {'name': 'Über stdio'}},
      });
      expect((created['result'] as Map)['isError'], isNull);
      expect((await user.customers(query: 'stdio')).single.name, 'Über stdio');
    } finally {
      await process.stdin.close();
      process.kill();
    }
  }, timeout: const Timeout(Duration(minutes: 2)));
}
