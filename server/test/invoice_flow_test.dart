import 'dart:io';

import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:test/test.dart';
import 'package:werkkern_client/werkkern_client.dart';

import 'package:werkkernerp_server/src/business/repository.dart';
import 'package:werkkernerp_server/src/business/repository_memory.dart';
import 'package:werkkernerp_server/src/repository.dart';
import 'package:werkkernerp_server/src/repository_memory.dart';
import 'package:werkkernerp_server/src/router.dart';

import 'support/starter_groups.dart';

void main() => runInvoiceFlowTests(() async => (InMemoryPhaseBRepository(), InMemoryBusinessRepository()));

/// C3.2 Zeit/Material + Festpreis, C13 Abschläge, Gutschriften — online
/// nach denselben Regeln wie offline.
void runInvoiceFlowTests(Future<(PhaseBRepository, BusinessRepository)> Function() create) {
  late HttpServer server;
  late WerkkernApiClient c;
  late String customerId;
  final yy = (DateTime.now().toUtc().year % 100).toString().padLeft(2, '0');

  setUp(() async {
    final (repository, business) = await create();
    server = await shelf_io.serve(PhaseBRouter(repository: repository, business: business).handler.call, InternetAddress.loopbackIPv4, 0);
    c = WerkkernApiClient(baseUrl: Uri.parse('http://127.0.0.1:${server.port}'));
    await c.register('chef@example.com', 'passwort-12345');
    final companyId = await c.createCompany((await c.login('chef@example.com', 'passwort-12345')).identityToken, 'Firma');
    await c.selectCompany((await c.login('chef@example.com', 'passwort-12345')).identityToken, companyId);
    await clearGroupPermissions(c);
    final own = (await c.groups()).firstWhere((g) => g.name == 'Projektleiter').id;
    for (final p in ['customers.read', 'customers.write', 'invoices.read', 'invoices.write', 'invoices.finalize', 'timeTracking.read', 'timeTracking.write']) {
      await c.setGroupPermission(own, p, granted: true);
    }
    await c.setModules({'orders', 'timeTracking', 'advancePaymentInvoices', 'creditNotes'});
    customerId = (await c.createCustomer(const OnlineCustomer(id: '', name: 'Meyer'))).id;
  });
  tearDown(() => server.close(force: true));

  Future<Map<String, Object?>> post(String path, Map<String, Object?> body) async =>
      await c.request('POST', path, body: body) as Map<String, Object?>;
  Future<Map<String, Object?>> put(String path, Map<String, Object?> body) async =>
      await c.request('PUT', path, body: body) as Map<String, Object?>;

  const orderItems = [
    {'kind': 'article', 'description': 'Kabel', 'quantity': '1', 'unitPriceCents': 10000, 'vatRatePercent': 19},
    {'kind': 'hours', 'description': 'Montage', 'quantity': '10', 'unitPriceCents': 6500, 'vatRatePercent': 19, 'unit': 'h'},
  ];

  Future<Map<String, Object?>> finalizedOrder({bool fixedPrice = false}) async {
    final order = await post('/documents', {'kind': 'order', 'customerId': customerId, 'items': orderItems});
    var version = order['version'] as int;
    if (fixedPrice) {
      version = (await put('/documents/${order['id']}', {'version': version, 'items': orderItems, 'isFixedPrice': true}))['version'] as int;
    }
    return post('/documents/${order['id']}/finalize', {'version': version});
  }

  test('Ohne Festpreis: Rechnung übernimmt die gebuchten Ist-Stunden statt der geplanten', () async {
    final order = await finalizedOrder();
    await post('/time-entries', {'date': '2026-10-24', 'hours': '2', 'documentId': order['id']});
    await post('/time-entries', {'date': '2026-10-25', 'hours': '1.5', 'documentId': order['id']});
    final invoice = await post('/documents/${order['id']}/convert', {'kind': 'invoice'});
    final items = (invoice['items'] as List).cast<Map>();
    expect(items.map((i) => i['description']), ['Kabel', 'Geleistete Stunden (Ist-Zeit)']);
    expect(items.last['quantity'], '3.5');
    expect(items.last['unitPriceCents'], 6500);
    expect(items.last['unit'], 'h');
  });

  test('Mit Festpreis: geplante Stunden bleiben, Kennzeichen wandert mit', () async {
    final order = await finalizedOrder(fixedPrice: true);
    expect(order['isFixedPrice'], isTrue);
    await post('/time-entries', {'date': '2026-10-24', 'hours': '2', 'documentId': order['id']});
    final invoice = await post('/documents/${order['id']}/convert', {'kind': 'invoice'});
    expect((invoice['items'] as List).cast<Map>().last['quantity'], '10');
  });

  test('Abschläge: einzeln mit Nummer in der Schlussrechnung, Restbetrag', () async {
    final order = await finalizedOrder(fixedPrice: true);
    Future<Map<String, Object?>> advance(int cents) async {
      final draft = await post('/documents/${order['id']}/convert', {'kind': 'invoice'});
      final updated = await put('/documents/${draft['id']}', {
        'version': draft['version'],
        'isAdvancePayment': true,
        'items': [
          {'kind': 'text', 'description': 'Abschlag', 'quantity': '1', 'unitPriceCents': cents, 'vatRatePercent': 19},
        ],
      });
      expect(updated['isAdvancePayment'], isTrue);
      return post('/documents/${draft['id']}/finalize', {'version': updated['version']});
    }

    final a1 = await advance(20000);
    final a2 = await advance(10000);
    final finalDraft = await post('/documents/${order['id']}/convert', {'kind': 'invoice'});
    final finalInvoice = await post('/documents/${finalDraft['id']}/finalize', {'version': finalDraft['version']});
    final advances = (finalInvoice['advancePayments'] as List).cast<Map>();
    expect(advances.map((a) => a['number']), [a1['number'], a2['number']]);
    expect(advances.map((a) => a['grossCents']), [23800, 11900]);
    expect((finalInvoice['totals'] as Map)['grossCents'], 89250); // (100 + 650) × 1,19
    expect(finalInvoice['remainingCents'], 89250 - 23800 - 11900);
    expect(a1['advancePayments'], isEmpty, reason: 'ein Abschlag zieht keine anderen ab');
  });

  test('Gutschrift: nur aus finalisierter Rechnung, Modul nötig, eigener Kreis G, an der Rechnung gelistet', () async {
    final draft = await post('/documents', {'customerId': customerId, 'items': orderItems});
    await expectLater(post('/documents/${draft['id']}/credit-note', {}), throwsA(isA<ApiException>().having((e) => e.isConflict, '409', isTrue)));
    final invoice = await post('/documents/${draft['id']}/finalize', {'version': 1});

    await c.setModules({'orders'});
    await expectLater(post('/documents/${invoice['id']}/credit-note', {}), throwsA(isA<ApiException>().having((e) => e.isForbidden, '403', isTrue)));
    await c.setModules({'orders', 'creditNotes'});

    final credit = await post('/documents/${invoice['id']}/credit-note', {});
    expect(credit['kind'], 'creditNote');
    expect(credit['convertedFromNumber'], invoice['number']);
    expect((credit['items'] as List), hasLength(2));
    // Teil-Gutschrift: auf eine Position kürzen.
    final shortened = await put('/documents/${credit['id']}', {
      'version': credit['version'],
      'items': [orderItems.first],
    });
    final finalCredit = await post('/documents/${credit['id']}/finalize', {'version': shortened['version']});
    expect(finalCredit['number'], 'G-${yy}001');
    final reloaded = await c.request('GET', '/documents/${invoice['id']}') as Map;
    expect((reloaded['creditNotes'] as List).single['grossCents'], 11900);
  });

  test('Kennzeichen nur, wo sie fachlich passen', () async {
    final order = await post('/documents', {'kind': 'order', 'customerId': customerId});
    await expectLater(put('/documents/${order['id']}', {'version': 1, 'isAdvancePayment': true}), throwsA(isA<ApiException>()));
    final invoice = await post('/documents', {'customerId': customerId});
    await expectLater(put('/documents/${invoice['id']}', {'version': 1, 'isFixedPrice': true}), throwsA(isA<ApiException>()));
    await c.setModules({'orders'});
    await expectLater(put('/documents/${invoice['id']}', {'version': 1, 'isAdvancePayment': true}),
        throwsA(isA<ApiException>().having((e) => e.isForbidden, '403', isTrue)));
  });
}
