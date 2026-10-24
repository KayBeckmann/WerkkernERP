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
    server = await shelf_io.serve(router.handler.call, 'localhost', 0);
    base = Uri.parse('http://localhost:${server.port}');
    user = WerkkernApiClient(baseUrl: base);
    await user.register('kay@example.com', 'passwort-12345');
    final companyId = await user.createCompany((await user.login('kay@example.com', 'passwort-12345')).identityToken, 'Elektro Kay');
    await user.selectCompany((await user.login('kay@example.com', 'passwort-12345')).identityToken, companyId);
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
