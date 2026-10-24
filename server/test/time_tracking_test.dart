import 'dart:io';

import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:test/test.dart';
import 'package:werkkern_client/werkkern_client.dart';

import 'package:werkkernerp_server/src/business/repository.dart';
import 'package:werkkernerp_server/src/business/repository_memory.dart';
import 'package:werkkernerp_server/src/repository.dart';
import 'package:werkkernerp_server/src/repository_memory.dart';
import 'package:werkkernerp_server/src/router.dart';

void main() => runTimeTrackingTests(() async => (InMemoryPhaseBRepository(), InMemoryBusinessRepository()));

/// C3 online: echte Nutzer buchen eigene Zeiten; Stundensatz je
/// Mitgliedschaft wird beim Buchen eingefroren.
void runTimeTrackingTests(Future<(PhaseBRepository, BusinessRepository)> Function() create) {
  late HttpServer server;
  late Uri base;
  late WerkkernApiClient chef;
  late String companyId;
  late String orderId;
  late String monteurGroup;

  setUp(() async {
    final (repository, business) = await create();
    server = await shelf_io.serve(PhaseBRouter(repository: repository, business: business).handler.call, InternetAddress.loopbackIPv4, 0);
    base = Uri.parse('http://127.0.0.1:${server.port}');
    chef = WerkkernApiClient(baseUrl: base);
    await chef.register('chef@example.com', 'passwort-12345');
    companyId = await chef.createCompany((await chef.login('chef@example.com', 'passwort-12345')).identityToken, 'Firma');
    await chef.selectCompany((await chef.login('chef@example.com', 'passwort-12345')).identityToken, companyId);
    final groups = await chef.groups();
    final own = groups.firstWhere((g) => g.name == 'Projektleiter').id;
    monteurGroup = groups.firstWhere((g) => g.name == 'Monteur').id;
    for (final p in ['customers.read', 'customers.write', 'invoices.read', 'invoices.write', 'invoices.finalize', 'timeTracking.read', 'timeTracking.write']) {
      await chef.setGroupPermission(own, p, granted: true);
    }
    for (final p in ['invoices.read', 'timeTracking.write']) {
      await chef.setGroupPermission(monteurGroup, p, granted: true);
    }
    await chef.setModules({'orders', 'timeTracking'});
    final customer = await chef.createCustomer(const OnlineCustomer(id: '', name: 'Meyer'));
    orderId = (await chef.createDocument(customerId: customer.id, kind: 'order')).id;
  });
  tearDown(() => server.close(force: true));

  Future<WerkkernApiClient> monteur(String email) async {
    final invitation = await chef.createInvitation(email, monteurGroup);
    final client = WerkkernApiClient(baseUrl: base);
    await client.acceptInvitation(invitation, 'passwort-12345');
    await client.selectCompany((await client.login(email, 'passwort-12345')).identityToken, companyId);
    return client;
  }

  Future<Map<String, Object?>> book(WerkkernApiClient c, {String hours = '2.5', String? documentId}) async =>
      await c.request('POST', '/time-entries', body: {
        'date': '2026-10-24',
        'hours': hours,
        'documentId': documentId ?? orderId,
        'note': 'Unterverteilung',
      }) as Map<String, Object?>;

  test('Monteur bucht eigene Zeiten mit eingefrorenem Stundensatz; sieht nur eigene, Chef sieht alle', () async {
    final m1 = await monteur('m1@example.com');
    final m2 = await monteur('m2@example.com');
    final member = (await chef.members()).firstWhere((m) => m.email == 'm1@example.com');
    await chef.request('PATCH', '/memberships/${member.id}', body: {'hourlyCostCents': 3800});

    final first = await book(m1);
    expect(first['hourlyCostCents'], 3800);
    expect(first['userEmail'], 'm1@example.com');
    await chef.request('PATCH', '/memberships/${member.id}', body: {'hourlyCostCents': 4200});
    expect((await book(m1, hours: '1'))['hourlyCostCents'], 4200, reason: 'neue Buchung, neuer Satz');
    await book(m2, hours: '3');

    final own = await m1.request('GET', '/time-entries') as Map;
    expect(own['scope'], 'mine');
    expect((own['entries'] as List), hasLength(2));
    expect(own['totalHours'], '3.5');
    expect((own['entries'] as List).first['hourlyCostCents'], isNotNull);

    final all = await chef.request('GET', '/time-entries') as Map;
    expect(all['scope'], 'company');
    expect(all['totalHours'], '6.5');
    final order = await chef.document(orderId);
    expect(order.rawJson['bookedHours'], '6.5');
  });

  test('Nur eigene Buchungen ändern/löschen; ohne Leserecht sind fremde unsichtbar (404)', () async {
    final m1 = await monteur('m1@example.com');
    final m2 = await monteur('m2@example.com');
    final entry = await book(m1);
    final id = entry['id'];

    await expectLater(m2.request('PUT', '/time-entries/$id', body: {'date': '2026-10-24', 'hours': '9', 'documentId': orderId}),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 404)));
    await expectLater(chef.request('DELETE', '/time-entries/$id'),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 403)));

    final updated = await m1.request('PUT', '/time-entries/$id', body: {'date': '2026-10-23', 'hours': '3,25', 'documentId': orderId}) as Map;
    expect(updated['hours'], '3.25');
    await m1.request('DELETE', '/time-entries/$id');
    expect(((await m1.request('GET', '/time-entries') as Map)['entries'] as List), isEmpty);
  });

  test('Validierung, Modul und Rechte', () async {
    final m1 = await monteur('m1@example.com');
    for (final bad in [
      {'date': '24.10.2026', 'hours': '2', 'documentId': orderId},
      {'date': '2026-10-24', 'hours': '0', 'documentId': orderId},
      {'date': '2026-10-24', 'hours': '25', 'documentId': orderId},
      {'date': '2026-10-24', 'hours': 'viel', 'documentId': orderId},
      {'date': '2026-10-24', 'hours': '2'},
    ]) {
      await expectLater(m1.request('POST', '/time-entries', body: bad), throwsA(isA<ApiException>()), reason: '$bad');
    }
    final customer = (await chef.customers()).single;
    final quote = await chef.request('POST', '/documents', body: {'customerId': customer.id}) as Map; // Rechnung ok
    expect((await book(m1, documentId: quote['id'] as String))['documentId'], quote['id']);

    // Entwurf mit gebuchten Zeiten ist nicht löschbar.
    await expectLater(chef.deleteDocument(quote['id'] as String),
        throwsA(isA<ApiException>().having((e) => e.isConflict, 'conflict', isTrue)));

    await chef.setModules({'orders'});
    await expectLater(book(m1), throwsA(isA<ApiException>().having((e) => e.isForbidden, '403', isTrue)));
    await chef.setModules({'orders', 'timeTracking'});

    final reader = await monteur('nur-lesen@example.com');
    await chef.setGroupPermission(monteurGroup, 'timeTracking.write', granted: false);
    await expectLater(reader.request('GET', '/time-entries'), throwsA(isA<ApiException>().having((e) => e.isForbidden, '403', isTrue)));
  });
}
