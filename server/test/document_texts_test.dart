import 'dart:io';

import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:test/test.dart';
import 'package:werkkern_client/werkkern_client.dart';

import 'package:werkkernerp_server/src/business/repository.dart';
import 'package:werkkernerp_server/src/business/repository_memory.dart';
import 'package:werkkernerp_server/src/repository.dart';
import 'package:werkkernerp_server/src/repository_memory.dart';
import 'package:werkkernerp_server/src/router.dart';

void main() => runDocumentTextTests(() async => (InMemoryPhaseBRepository(), InMemoryBusinessRepository()));

void runDocumentTextTests(Future<(PhaseBRepository, BusinessRepository)> Function() create) {
  late HttpServer server;
  late WerkkernApiClient c;
  late String customerId;

  setUp(() async {
    final (repository, business) = await create();
    server = await shelf_io.serve(PhaseBRouter(repository: repository, business: business).handler.call, InternetAddress.loopbackIPv4, 0);
    c = WerkkernApiClient(baseUrl: Uri.parse('http://127.0.0.1:${server.port}'));
    await c.register('chef@example.com', 'passwort-12345');
    final companyId = await c.createCompany((await c.login('chef@example.com', 'passwort-12345')).identityToken, 'Firma');
    await c.selectCompany((await c.login('chef@example.com', 'passwort-12345')).identityToken, companyId);
    final own = (await c.groups()).firstWhere((g) => g.name == 'Projektleiter').id;
    for (final p in ['customers.read', 'customers.write', 'invoices.read', 'invoices.write', 'invoices.finalize']) {
      await c.setGroupPermission(own, p, granted: true);
    }
    customerId = (await c.createCustomer(const OnlineCustomer(id: '', name: 'Meyer'))).id;
  });
  tearDown(() => server.close(force: true));

  Map<String, Object?> item(num vat) =>
      {'kind': 'text', 'description': 'X', 'quantity': '1', 'unitPriceCents': 10000, 'vatRatePercent': vat};

  test('Dokumenttexte je Art und Fußzeile werden beim Finalisieren eingefroren', () async {
    await c.request('PUT', '/company/profile', body: {
      'footerText': 'Bankverbindung …',
      'documentTexts': {
        'invoice': {'intro': 'Vielen Dank für Ihren Auftrag.', 'closing': 'Zahlbar in 14 Tagen.'},
        'quote': {'intro': 'Gültig 30 Tage.'},
        'unbekannt': {'intro': 'wird ignoriert'},
      },
    });
    final profile = await c.request('GET', '/company/profile') as Map;
    expect((profile['documentTexts'] as Map).keys, unorderedEquals(['invoice', 'quote']));

    final draft = await c.request('POST', '/documents', body: {'customerId': customerId, 'items': [item(19)]}) as Map;
    expect(draft['textSnapshot'], isNull, reason: 'Entwurf hat noch keinen Schnappschuss');
    final invoice = await c.request('POST', '/documents/${draft['id']}/finalize', body: {'version': 1}) as Map;
    final snapshot = invoice['textSnapshot'] as Map;
    expect(snapshot['intro'], 'Vielen Dank für Ihren Auftrag.');
    expect(snapshot['closing'], 'Zahlbar in 14 Tagen.');
    expect(snapshot['footer'], 'Bankverbindung …');
    expect(snapshot['smallBusinessExempt'], isFalse);

    await c.request('PUT', '/company/profile', body: {'footerText': 'Neu', 'documentTexts': <String, Object?>{}});
    final reloaded = await c.request('GET', '/documents/${invoice['id']}') as Map;
    expect((reloaded['textSnapshot'] as Map)['footer'], 'Bankverbindung …');
  });

  test('§ 19 UStG: Server erzwingt 0 % USt beim Speichern und Finalisieren, Schnappschuss im Dokument', () async {
    final oldDraft = await c.request('POST', '/documents', body: {'customerId': customerId, 'items': [item(19)]}) as Map;
    await c.request('PUT', '/company/profile', body: {'smallBusinessExempt': true});

    await expectLater(c.request('POST', '/documents', body: {'customerId': customerId, 'items': [item(19)]}),
        throwsA(isA<ApiException>().having((e) => e.message, 'm', contains('§ 19'))));
    await expectLater(c.request('POST', '/documents/${oldDraft['id']}/finalize', body: {'version': 1}),
        throwsA(isA<ApiException>().having((e) => e.isConflict, '409', isTrue)));

    final ok = await c.request('POST', '/documents', body: {'customerId': customerId, 'items': [item(0)]}) as Map;
    final invoice = await c.request('POST', '/documents/${ok['id']}/finalize', body: {'version': 1}) as Map;
    expect((invoice['textSnapshot'] as Map)['smallBusinessExempt'], isTrue);
    expect((invoice['totals'] as Map)['taxCents'], 0);

    // Später wieder umgeschaltet: das finalisierte Dokument behält den Hinweis.
    await c.request('PUT', '/company/profile', body: {'smallBusinessExempt': false});
    final reloaded = await c.request('GET', '/documents/${invoice['id']}') as Map;
    expect((reloaded['textSnapshot'] as Map)['smallBusinessExempt'], isTrue);
  });
}
