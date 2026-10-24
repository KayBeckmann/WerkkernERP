import 'dart:io';

import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:test/test.dart';
import 'package:werkkern_client/werkkern_client.dart';

import 'package:werkkernerp_server/src/business/repository.dart';
import 'package:werkkernerp_server/src/business/repository_memory.dart';
import 'package:werkkernerp_server/src/repository.dart';
import 'package:werkkernerp_server/src/repository_memory.dart';
import 'package:werkkernerp_server/src/router.dart';

void main() => runProjectTests(() async => (InMemoryPhaseBRepository(), InMemoryBusinessRepository()));

/// C1/C2/C3.3 online — gleiche Regeln wie offline.
void runProjectTests(Future<(PhaseBRepository, BusinessRepository)> Function() create) {
  late HttpServer server;
  late Uri base;
  final yy = (DateTime.now().toUtc().year % 100).toString().padLeft(2, '0');

  setUp(() async {
    final (repository, business) = await create();
    server = await shelf_io.serve(PhaseBRouter(repository: repository, business: business).handler.call, InternetAddress.loopbackIPv4, 0);
    base = Uri.parse('http://127.0.0.1:${server.port}');
  });
  tearDown(() => server.close(force: true));

  Future<({WerkkernApiClient client, String companyId, String ownGroup})> company(String email, {List<String>? permissions}) async {
    final client = WerkkernApiClient(baseUrl: base);
    await client.register(email, 'passwort-12345');
    final companyId = await client.createCompany((await client.login(email, 'passwort-12345')).identityToken, 'Firma $email');
    await client.selectCompany((await client.login(email, 'passwort-12345')).identityToken, companyId);
    final own = (await client.groups()).firstWhere((g) => g.name == 'Projektleiter').id;
    for (final p in permissions ??
        [
          'customers.read', 'customers.write', 'invoices.read', 'invoices.write', 'invoices.finalize',
          'projects.read', 'projects.write', 'timeTracking.read', 'timeTracking.write',
        ]) {
      await client.setGroupPermission(own, p, granted: true);
    }
    await client.setModules({'projects', 'orders', 'quotes', 'timeTracking'});
    return (client: client, companyId: companyId, ownGroup: own);
  }

  Future<Map<String, Object?>> post(WerkkernApiClient c, String path, Map<String, Object?> body) async =>
      await c.request('POST', path, body: body) as Map<String, Object?>;

  test('Projektnummer PP je Jahr; Rechnung zum Projekt R-JJPPxxx, gemeinsamer Zähler mit projektfreien', () async {
    final a = await company('a@example.com');
    final customer = await a.client.createCustomer(const OnlineCustomer(id: '', name: 'Meyer'));
    final p1 = await post(a.client, '/projects', {'name': 'Neubau Meyer', 'customerId': customer.id});
    final p2 = await post(a.client, '/projects', {'name': 'Wartung'});
    expect(p1['displayNumber'], '$yy/01');
    expect(p2['displayNumber'], '$yy/02');

    Future<String?> finalizeNew({String? projectId}) async {
      final draft = await post(a.client, '/documents', {
        'customerId': customer.id,
        'projectId': ?projectId,
        'items': [
          {'kind': 'text', 'description': 'X', 'quantity': '1', 'unitPriceCents': 10000, 'vatRatePercent': 19},
        ],
      });
      return (await post(a.client, '/documents/${draft['id']}/finalize', {'version': 1}))['number'] as String?;
    }

    expect(await finalizeNew(projectId: p2['id'] as String), 'R-${yy}02001');
    expect(await finalizeNew(), 'R-${yy}002', reason: 'Zähler je Art/Jahr, wie offline');
  });

  test('Projektdetail: Dokumente, geplant/gebucht, Stundenkosten, Ergebnis; Zeit erbt Projekt vom Auftrag', () async {
    final a = await company('a@example.com');
    final customer = await a.client.createCustomer(const OnlineCustomer(id: '', name: 'Meyer'));
    final project = await post(a.client, '/projects', {'name': 'Neubau'});
    final members = await a.client.members();
    await a.client.updateMember(members.single.id, hourlyCostCents: () => 4000);
    await a.client.selectCompany((await a.client.login('a@example.com', 'passwort-12345')).identityToken, a.companyId);

    final order = await post(a.client, '/documents', {
      'kind': 'order',
      'customerId': customer.id,
      'projectId': project['id'],
      'items': [
        {'kind': 'hours', 'description': 'Montage', 'quantity': '10', 'unitPriceCents': 6500, 'vatRatePercent': 19},
      ],
    });
    final entry = await post(a.client, '/time-entries', {'date': '2026-10-24', 'hours': '2.5', 'documentId': order['id']});
    expect(entry['projectId'], project['id'], reason: 'vom Auftrag übernommen');
    await post(a.client, '/time-entries', {'date': '2026-10-24', 'hours': '1', 'projectId': project['id']});

    final finalOrder = await post(a.client, '/documents/${order['id']}/finalize', {'version': 1});
    final invoice = await post(a.client, '/documents/${finalOrder['id']}/convert', {'kind': 'invoice'});
    expect(invoice['projectId'], project['id'], reason: 'Umwandlung übernimmt Projekt');
    await post(a.client, '/documents/${invoice['id']}/finalize', {'version': 1});

    final detail = await a.client.request('GET', '/projects/${project['id']}') as Map;
    expect((detail['documents'] as List), hasLength(2));
    final result = detail['result'] as Map;
    expect(result['invoiceGrossCents'], 77350); // 10 x 65 € + 19 %
    expect(result['plannedHours'], '10');
    expect(result['bookedHours'], '3.5');
    expect(result['hoursCostCents'], 14000); // 3,5 h x 40 €
    expect(result['resultCents'], 77350 - 14000);
  });

  test('Mandantentrennung, Löschschutz, Archiv und Rechte', () async {
    final a = await company('a@example.com');
    final b = await company('b@example.com');
    final projectB = await post(b.client, '/projects', {'name': 'Geheim'});
    final customerA = await a.client.createCustomer(const OnlineCustomer(id: '', name: 'K'));

    await expectLater(a.client.request('GET', '/projects/${projectB['id']}'), throwsA(isA<ApiException>().having((e) => e.statusCode, 's', 404)));
    await expectLater(
      post(a.client, '/documents', {'customerId': customerA.id, 'projectId': projectB['id']}),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 's', 404)),
    );
    await expectLater(
      post(a.client, '/time-entries', {'date': '2026-10-24', 'hours': '1', 'projectId': projectB['id']}),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 's', 404)),
    );

    final projectA = await post(a.client, '/projects', {'name': 'Eigen'});
    final draft = await post(a.client, '/documents', {'customerId': customerA.id});
    final assigned = await a.client.request('PUT', '/documents/${draft['id']}/project', body: {'version': 1, 'projectId': projectA['id']}) as Map;
    expect(assigned['projectId'], projectA['id']);
    await expectLater(a.client.request('DELETE', '/projects/${projectA['id']}'), throwsA(isA<ApiException>().having((e) => e.isConflict, '409', isTrue)));

    await a.client.request('PUT', '/projects/${projectA['id']}', body: {'status': 'archived'});
    expect(((await a.client.request('GET', '/projects') as Map)['projects'] as List), isEmpty);
    expect(((await a.client.request('GET', '/projects', query: {'includeArchived': 'true'}) as Map)['projects'] as List), hasLength(1));

    // Leser ohne Rechnungs-/Zeitrechte sieht das Projekt, aber keine Summen.
    final readerGroup = await a.client.createGroup('Nur Projekte');
    await a.client.setGroupPermission(readerGroup.id, 'projects.read', granted: true);
    final invitation = await a.client.createInvitation('leser@example.com', readerGroup.id);
    final reader = WerkkernApiClient(baseUrl: base);
    await reader.acceptInvitation(invitation, 'passwort-12345');
    await reader.selectCompany((await reader.login('leser@example.com', 'passwort-12345')).identityToken, a.companyId);
    final seen = await reader.request('GET', '/projects/${projectA['id']}') as Map;
    expect((seen['result'] as Map)['invoiceGrossCents'], isNull);
    expect((seen['result'] as Map)['hoursCostCents'], isNull);
    expect(seen['documents'], isEmpty);
    await expectLater(post(reader, '/projects', {'name': 'x'}), throwsA(isA<ApiException>().having((e) => e.isForbidden, '403', isTrue)));

    await a.client.setModules({'orders'});
    await expectLater(a.client.request('GET', '/projects'), throwsA(isA<ApiException>().having((e) => e.isForbidden, '403', isTrue)));
  });
}
