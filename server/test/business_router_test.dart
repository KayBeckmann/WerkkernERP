import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:test/test.dart';

import 'package:werkkernerp_server/src/business/repository.dart';
import 'package:werkkernerp_server/src/business/repository_memory.dart';
import 'package:werkkernerp_server/src/repository.dart';
import 'package:werkkernerp_server/src/repository_memory.dart';
import 'package:werkkernerp_server/src/router.dart';

void main() => runBusinessTests(() async => (InMemoryPhaseBRepository(), InMemoryBusinessRepository()));

/// B1 Punkt 3 — Fach-Endpunkte. Läuft gegen In-Memory und (siehe
/// `business_postgres_test.dart`) gegen echtes Postgres.
void runBusinessTests(Future<(PhaseBRepository, BusinessRepository)> Function() createRepositories) {
  late HttpServer server;
  late Uri baseUrl;

  setUp(() async {
    final (repository, business) = await createRepositories();
    server = await shelf_io.serve(PhaseBRouter(repository: repository, business: business).handler.call, InternetAddress.loopbackIPv4, 0);
    baseUrl = Uri.parse('http://127.0.0.1:${server.port}');
  });

  tearDown(() => server.close(force: true));

  final year = DateTime.now().toUtc().year % 100;

  Future<Map<String, Object?>> post(String path, Map<String, String> headers, Object body, {int expect = 200}) async {
    final r = await http.post(baseUrl.resolve(path), headers: headers, body: jsonEncode(body));
    expectStatus(r, expect);
    return r.body.isEmpty ? {} : jsonDecode(r.body) as Map<String, Object?>;
  }

  Future<String> identity(String email) async {
    final r = await http.post(baseUrl.resolve('/auth/login'), body: jsonEncode({'email': email, 'password': 'passwort-12345'}));
    return (jsonDecode(r.body) as Map<String, Object?>)['identityToken'] as String;
  }

  Future<String> select(String email, String companyId) async {
    final body = await post('/auth/select-company', {}, {'identityToken': await identity(email), 'companyId': companyId});
    return body['token'] as String;
  }

  /// Firma mit Admin, dessen eigene Gruppe die angegebenen Rechte hat
  /// (Startgruppen haben bewusst keine vorbelegten Rechte).
  Future<({Map<String, String> auth, String companyId, String groupId})> company(
    String email,
    String name, {
    List<String> permissions = const [
      'customers.read',
      'customers.write',
      'articles.read',
      'articles.write',
      'invoices.read',
      'invoices.write',
      'invoices.finalize',
      'invoices.payment',
    ],
    List<String> modules = const [],
  }) async {
    await post('/auth/register', {}, {'email': email, 'password': 'passwort-12345'}, expect: 201);
    final created = await post('/companies', {}, {'identityToken': await identity(email), 'name': name}, expect: 201);
    final companyId = created['companyId'] as String;
    final auth = {'authorization': 'Bearer ${await select(email, companyId)}'};
    final me = jsonDecode((await http.get(baseUrl.resolve('/me'), headers: auth)).body) as Map<String, Object?>;
    final groupId = me['groupId'] as String;
    for (final p in permissions) {
      final r = await http.put(baseUrl.resolve('/groups/$groupId/permissions/$p'), headers: auth, body: jsonEncode({'granted': true}));
      expectStatus(r, 200);
    }
    if (modules.isNotEmpty) {
      final r = await http.put(baseUrl.resolve('/company/modules'), headers: auth, body: jsonEncode({'modules': modules}));
      expectStatus(r, 200);
    }
    return (auth: auth, companyId: companyId, groupId: groupId);
  }

  /// Weiteres Mitglied in einer eigenen, neuen Gruppe mit genau [permissions].
  Future<Map<String, String>> member(
    ({Map<String, String> auth, String companyId, String groupId}) c,
    String email,
    List<String> permissions,
  ) async {
    final group = await post('/groups', c.auth, {'name': 'Gruppe $email'}, expect: 201);
    for (final p in permissions) {
      await http.put(baseUrl.resolve('/groups/${group['id']}/permissions/$p'), headers: c.auth, body: jsonEncode({'granted': true}));
    }
    await post('/auth/register', {}, {'email': email, 'password': 'passwort-12345'}, expect: 201);
    await post('/memberships', c.auth, {'email': email, 'groupId': group['id']}, expect: 201);
    return {'authorization': 'Bearer ${await select(email, c.companyId)}'};
  }

  Map<String, Object?> invoiceBody(String customerId, {String kind = 'invoice'}) => {
        'kind': kind,
        'customerId': customerId,
        'issueDate': '2026-10-24',
        'items': <Map<String, Object?>>[
          {'kind': 'article', 'description': 'Kabel', 'quantity': '2', 'unitPriceCents': 13000, 'vatRatePercent': 19, 'groupLabel': 'Material'},
          {'kind': 'hours', 'description': 'Montage', 'quantity': '1,5', 'unitPriceCents': 6000, 'vatRatePercent': 7, 'groupLabel': 'Arbeit'},
          {'kind': 'text', 'description': 'Pauschale', 'quantity': 1, 'unitPriceCents': 5000, 'vatRatePercent': 0},
        ],
      };

  test('Kunden: anlegen, ändern, suchen; Suche findet nie Kunden einer anderen Firma', () async {
    final a = await company('a@example.com', 'Firma A');
    final b = await company('b@example.com', 'Firma B');
    final mueller = await post('/customers', a.auth, {'name': 'Müller GmbH', 'vatId': 'DE123'}, expect: 201);
    await post('/customers', a.auth, {'name': 'Schmidt'}, expect: 201);
    await post('/customers', b.auth, {'name': 'Müller GmbH'}, expect: 201);

    final updated = await http.put(baseUrl.resolve('/customers/${mueller['id']}'), headers: a.auth, body: jsonEncode({'name': 'Müller & Söhne GmbH'}));
    expectStatus(updated, 200);

    final search = jsonDecode((await http.get(baseUrl.resolve('/customers?q=müller'), headers: a.auth)).body) as Map<String, Object?>;
    final names = (search['customers'] as List).map((c) => (c as Map)['name']).toList();
    expect(names, ['Müller & Söhne GmbH'], reason: 'nur Firma A, nur Treffer');

    final wildcard = jsonDecode((await http.get(baseUrl.resolve('/customers?q=%25'), headers: a.auth)).body) as Map<String, Object?>;
    expect(wildcard['customers'], isEmpty, reason: '% ist kein Platzhalter');
  });

  test('Cross-Tenant: fremde Kunden-/Artikel-/Dokument-IDs liefern 404 bzw. werden abgewiesen', () async {
    final a = await company('a@example.com', 'Firma A');
    final b = await company('b@example.com', 'Firma B');
    final customerA = await post('/customers', a.auth, {'name': 'Kunde A'}, expect: 201);
    final articleA = await post('/articles', a.auth, {'name': 'Artikel A', 'salePriceCents': 100}, expect: 201);
    final docA = await post('/documents', a.auth, invoiceBody(customerA['id'] as String), expect: 201);
    final customerB = await post('/customers', b.auth, {'name': 'Kunde B'}, expect: 201);

    for (final path in ['/customers/${customerA['id']}', '/articles/${articleA['id']}', '/documents/${docA['id']}']) {
      expectStatus(await http.get(baseUrl.resolve(path), headers: b.auth), 404);
    }
    expectStatus(await http.put(baseUrl.resolve('/customers/${customerA['id']}'), headers: b.auth, body: jsonEncode({'name': 'gekapert'})), 404);
    expectStatus(await http.delete(baseUrl.resolve('/customers/${customerA['id']}'), headers: b.auth), 404);
    expectStatus(await http.put(baseUrl.resolve('/documents/${docA['id']}'), headers: b.auth, body: jsonEncode({'version': 1})), 404);
    expectStatus(await http.post(baseUrl.resolve('/documents/${docA['id']}/finalize'), headers: b.auth, body: jsonEncode({'version': 1})), 404);
    expectStatus(await http.delete(baseUrl.resolve('/documents/${docA['id']}'), headers: b.auth), 404);

    // Dokument in B mit A's Kunde anlegen -> Kunde "nicht gefunden".
    await post('/documents', b.auth, invoiceBody(customerA['id'] as String), expect: 404);
    // Position in B mit A's Artikel -> abgewiesen.
    final foreignArticle = invoiceBody(customerB['id'] as String);
    (foreignArticle['items'] as List).add({
      'kind': 'article', 'articleId': articleA['id'], 'description': 'x', 'quantity': 1, 'unitPriceCents': 1, 'vatRatePercent': 19,
    });
    await post('/documents', b.auth, foreignArticle, expect: 400);

    final listB = jsonDecode((await http.get(baseUrl.resolve('/documents?q=Kunde'), headers: b.auth)).body) as Map<String, Object?>;
    expect(listB['documents'], isEmpty);

    // A's Daten sind unverändert.
    final stillA = jsonDecode((await http.get(baseUrl.resolve('/customers/${customerA['id']}'), headers: a.auth)).body) as Map;
    expect(stillA['name'], 'Kunde A');
  });

  test('Rechte: ohne Recht 403, Leserecht erlaubt kein Schreiben, Entwurf ohne Finalisierungsrecht', () async {
    final a = await company('a@example.com', 'Firma A');
    final customer = await post('/customers', a.auth, {'name': 'Kunde'}, expect: 201);
    final nobody = await member(a, 'nobody@example.com', []);
    final reader = await member(a, 'reader@example.com', ['customers.read', 'invoices.read']);
    final monteur = await member(a, 'monteur@example.com', ['customers.read', 'invoices.read', 'invoices.write']);

    expectStatus(await http.get(baseUrl.resolve('/customers'), headers: nobody), 403);
    expectStatus(await http.get(baseUrl.resolve('/customers'), headers: reader), 200);
    expectStatus(await http.post(baseUrl.resolve('/customers'), headers: reader, body: jsonEncode({'name': 'x'})), 403);
    await post('/documents', reader, invoiceBody(customer['id'] as String), expect: 403);

    final draft = await post('/documents', monteur, invoiceBody(customer['id'] as String), expect: 201);
    await post('/documents/${draft['id']}/finalize', monteur, {'version': draft['version']}, expect: 403);
    await post('/documents/${draft['id']}/finalize', a.auth, {'version': draft['version']}, expect: 200);
  });

  test('A2-Referenzfall: drei Positionstypen, zwei Gruppen, 19/7/0 % — Summen auf den Cent', () async {
    final a = await company('a@example.com', 'Firma A');
    final customer = await post('/customers', a.auth, {'name': 'Kunde'}, expect: 201);
    final doc = await post('/documents', a.auth, invoiceBody(customer['id'] as String), expect: 201);
    final totals = doc['totals'] as Map<String, Object?>;
    // 2 × 130,00 @19 % = 260,00 (Steuer 49,40); 1,5 × 60,00 @7 % = 90,00
    // (Steuer 6,30); 50,00 @0 %. Netto 400,00, Steuer 55,70, Brutto 455,70.
    expect(totals['netCents'], 40000);
    expect(totals['taxCents'], 5570);
    expect(totals['grossCents'], 45570);
    expect((totals['byRate'] as List).map((r) => (r as Map)['vatRatePercent']), [0, 7, 19]);
    expect(doc['status'], 'draft');
    expect(doc['number'], isNull, reason: 'Entwürfe tragen keine Nummer (F3)');
    final items = doc['items'] as List;
    expect(items.map((i) => (i as Map)['groupLabel']), ['Material', 'Arbeit', null]);
    expect((items[1] as Map)['quantity'], '1.5');
  });

  test('Entwurf: Update mit veralteter Version 409 (kein stilles Überschreiben), sonst Version + 1', () async {
    final a = await company('a@example.com', 'Firma A');
    final customer = await post('/customers', a.auth, {'name': 'Kunde'}, expect: 201);
    final doc = await post('/documents', a.auth, invoiceBody(customer['id'] as String), expect: 201);

    final ok = await http.put(baseUrl.resolve('/documents/${doc['id']}'), headers: a.auth, body: jsonEncode({
      'version': 1,
      'notes': 'Gerät A',
      'items': [{'kind': 'text', 'description': 'Neu', 'quantity': 1, 'unitPriceCents': 1000, 'vatRatePercent': 19}],
    }));
    expectStatus(ok, 200);
    final updated = jsonDecode(ok.body) as Map<String, Object?>;
    expect(updated['version'], 2);
    expect((updated['totals'] as Map)['grossCents'], 1190);

    final stale = await http.put(baseUrl.resolve('/documents/${doc['id']}'), headers: a.auth, body: jsonEncode({'version': 1, 'notes': 'Gerät B'}));
    expectStatus(stale, 409);
    final current = jsonDecode((await http.get(baseUrl.resolve('/documents/${doc['id']}'), headers: a.auth)).body) as Map;
    expect(current['notes'], 'Gerät A');
  });

  test('Finalisierung: Nummernkreis je Firma/Art/Jahr, Schnappschuss eingefroren, danach unveränderlich', () async {
    final a = await company('a@example.com', 'Firma A', modules: ['quotes']);
    final b = await company('b@example.com', 'Firma B');
    final customer = await post('/customers', a.auth, {'name': 'Kunde Alt', 'address': 'Weg 1'}, expect: 201);
    final customerB = await post('/customers', b.auth, {'name': 'Kunde B'}, expect: 201);

    Future<Map<String, Object?>> finalizeNew(Map<String, String> auth, String customerId, {String kind = 'invoice'}) async {
      final draft = await post('/documents', auth, invoiceBody(customerId, kind: kind), expect: 201);
      return post('/documents/${draft['id']}/finalize', auth, {'version': draft['version']});
    }

    final first = await finalizeNew(a.auth, customer['id'] as String);
    final second = await finalizeNew(a.auth, customer['id'] as String);
    final quote = await finalizeNew(a.auth, customer['id'] as String, kind: 'quote');
    final firstB = await finalizeNew(b.auth, customerB['id'] as String);
    expect(first['number'], 'R-${year}001');
    expect(second['number'], 'R-${year}002');
    expect(quote['number'], 'An-${year}001', reason: 'eigener Kreis je Dokumentart');
    expect(firstB['number'], 'R-${year}001', reason: 'gleicher Zählerwert nur in getrennter Firma');
    expect((first['customerSnapshot'] as Map)['name'], 'Kunde Alt');
    expect((first['companySnapshot'] as Map)['name'], 'Firma A');

    // Stammdatenänderung danach verändert das finalisierte Dokument nicht.
    await http.put(baseUrl.resolve('/customers/${customer['id']}'), headers: a.auth, body: jsonEncode({'name': 'Kunde Neu'}));
    final reloaded = jsonDecode((await http.get(baseUrl.resolve('/documents/${first['id']}'), headers: a.auth)).body) as Map;
    expect((reloaded['customerSnapshot'] as Map)['name'], 'Kunde Alt');

    final v = first['version'];
    expectStatus(await http.put(baseUrl.resolve('/documents/${first['id']}'), headers: a.auth, body: jsonEncode({'version': v})), 409);
    expectStatus(await http.delete(baseUrl.resolve('/documents/${first['id']}'), headers: a.auth), 409);
    expectStatus(await http.post(baseUrl.resolve('/documents/${first['id']}/finalize'), headers: a.auth, body: jsonEncode({'version': v})), 409);

    // Kunde mit Dokumenten ist nicht löschbar.
    expectStatus(await http.delete(baseUrl.resolve('/customers/${customer['id']}'), headers: a.auth), 409);
  });

  test('Nebenläufigkeit: doppeltes Finalisieren vergibt genau eine Nummer; parallele Dokumente lückenlos', () async {
    final a = await company('a@example.com', 'Firma A');
    final customer = await post('/customers', a.auth, {'name': 'Kunde'}, expect: 201);
    final draft = await post('/documents', a.auth, invoiceBody(customer['id'] as String), expect: 201);

    final responses = await Future.wait([
      for (var i = 0; i < 2; i++)
        http.post(baseUrl.resolve('/documents/${draft['id']}/finalize'), headers: a.auth, body: jsonEncode({'version': 1})),
    ]);
    expect(responses.map((r) => r.statusCode).toList()..sort(), [200, 409]);

    final drafts = [
      for (var i = 0; i < 5; i++) await post('/documents', a.auth, invoiceBody(customer['id'] as String), expect: 201),
    ];
    final finalized = await Future.wait([
      for (final d in drafts)
        http.post(baseUrl.resolve('/documents/${d['id']}/finalize'), headers: a.auth, body: jsonEncode({'version': 1})),
    ]);
    final numbers = finalized.map((r) {
      expectStatus(r, 200);
      return (jsonDecode(r.body) as Map)['number'] as String;
    }).toSet();
    expect(numbers, {for (var n = 2; n <= 6; n++) 'R-$year${n.toString().padLeft(3, '0')}'});
  });

  test('Deaktiviertes Modul: Angebote weder anlegbar noch lesbar noch in der Liste — Daten bleiben erhalten', () async {
    final a = await company('a@example.com', 'Firma A', modules: ['quotes']);
    final customer = await post('/customers', a.auth, {'name': 'Kunde'}, expect: 201);
    final quote = await post('/documents', a.auth, invoiceBody(customer['id'] as String, kind: 'quote'), expect: 201);
    await post('/documents', a.auth, invoiceBody(customer['id'] as String), expect: 201);

    await http.put(baseUrl.resolve('/company/modules'), headers: a.auth, body: jsonEncode({'modules': <String>[]}));
    expectStatus(await http.get(baseUrl.resolve('/documents/${quote['id']}'), headers: a.auth), 403);
    await post('/documents', a.auth, invoiceBody(customer['id'] as String, kind: 'quote'), expect: 403);
    final list = jsonDecode((await http.get(baseUrl.resolve('/documents'), headers: a.auth)).body) as Map;
    expect((list['documents'] as List).map((d) => (d as Map)['kind']), ['invoice']);

    await http.put(baseUrl.resolve('/company/modules'), headers: a.auth, body: jsonEncode({'modules': ['quotes']}));
    expectStatus(await http.get(baseUrl.resolve('/documents/${quote['id']}'), headers: a.auth), 200);
  });

  test('Validierung: leere Positionen nicht finalisierbar, ungültige Werte 400', () async {
    final a = await company('a@example.com', 'Firma A');
    final customer = await post('/customers', a.auth, {'name': 'Kunde'}, expect: 201);
    final empty = await post('/documents', a.auth, {'customerId': customer['id']}, expect: 201);
    await post('/documents/${empty['id']}/finalize', a.auth, {'version': 1}, expect: 400);
    await post('/documents', a.auth, {'customerId': customer['id'], 'kind': 'rechnung'}, expect: 400);
    await post('/documents', a.auth, {
      'customerId': customer['id'],
      'items': [{'kind': 'text', 'description': 'x', 'quantity': 'viel', 'unitPriceCents': 1, 'vatRatePercent': 19}],
    }, expect: 400);
    await post('/documents', a.auth, {
      'customerId': customer['id'],
      'items': [{'kind': 'text', 'description': 'x', 'quantity': 1, 'unitPriceCents': 1.5, 'vatRatePercent': 19}],
    }, expect: 400);
    await post('/documents', a.auth, {'customerId': customer['id'], 'issueDate': '24.10.2026'}, expect: 400);
    await post('/customers', a.auth, {'name': '   '}, expect: 400);
  });

  test('Artikel: deaktivierte erscheinen nur mit includeInactive', () async {
    final a = await company('a@example.com', 'Firma A');
    final article = await post('/articles', a.auth, {'name': 'NYM-J 3x1,5', 'unit': 'm', 'salePriceCents': 89}, expect: 201);
    await http.put(baseUrl.resolve('/articles/${article['id']}'), headers: a.auth, body: jsonEncode({'name': 'NYM-J 3x1,5', 'active': false}));
    final active = jsonDecode((await http.get(baseUrl.resolve('/articles'), headers: a.auth)).body) as Map;
    expect(active['articles'], isEmpty);
    final all = jsonDecode((await http.get(baseUrl.resolve('/articles?includeInactive=true'), headers: a.auth)).body) as Map;
    expect((all['articles'] as List).single['active'], isFalse);
  });

  test('Firmen-Stammdaten werden beim Finalisieren eingefroren; Audit protokolliert jede Schreibaktion', () async {
    final a = await company('a@example.com', 'Firma A');
    final profile = await http.put(baseUrl.resolve('/company/profile'), headers: a.auth, body: jsonEncode({
      'address': 'Werkstraße 1, 12345 Stadt',
      'taxNumber': '12/345/67890',
      'iban': 'DE00 0000',
    }));
    expectStatus(profile, 200);
    final customer = await post('/customers', a.auth, {'name': 'Kunde'}, expect: 201);
    final draft = await post('/documents', a.auth, invoiceBody(customer['id'] as String), expect: 201);
    final finalized = await post('/documents/${draft['id']}/finalize', a.auth, {'version': 1});
    final snapshot = finalized['companySnapshot'] as Map;
    expect(snapshot['address'], 'Werkstraße 1, 12345 Stadt');
    expect(snapshot['taxNumber'], '12/345/67890');

    await http.put(baseUrl.resolve('/company/profile'), headers: a.auth, body: jsonEncode({'address': 'Neue Straße 9'}));
    final reloaded = jsonDecode((await http.get(baseUrl.resolve('/documents/${draft['id']}'), headers: a.auth)).body) as Map;
    expect((reloaded['companySnapshot'] as Map)['address'], 'Werkstraße 1, 12345 Stadt');

    final audit = jsonDecode((await http.get(baseUrl.resolve('/audit'), headers: a.auth)).body) as Map;
    final actions = (audit['entries'] as List).map((e) => (e as Map)['action']).toList();
    expect(actions.first, 'company.profile', reason: 'neueste zuerst');
    expect(actions, containsAll(['document.finalize', 'document.create', 'customer.create', 'company.create']));
    expect((audit['entries'] as List).first['userEmail'], 'a@example.com');
  });

  test('Stammdaten und Audit: nur Admin ändert/liest, Audit zeigt nie Einträge anderer Firmen', () async {
    final a = await company('a@example.com', 'Firma A');
    final b = await company('b@example.com', 'Firma B');
    await post('/customers', b.auth, {'name': 'Geheimkunde B'}, expect: 201);
    final monteur = await member(a, 'monteur@example.com', ['customers.read']);

    expectStatus(await http.get(baseUrl.resolve('/company/profile'), headers: monteur), 200);
    expectStatus(await http.put(baseUrl.resolve('/company/profile'), headers: monteur, body: jsonEncode({'address': 'x'})), 403);
    expectStatus(await http.get(baseUrl.resolve('/audit'), headers: monteur), 403);

    final auditA = jsonDecode((await http.get(baseUrl.resolve('/audit?limit=1000'), headers: a.auth)).body) as Map;
    final emails = (auditA['entries'] as List).map((e) => (e as Map)['userEmail']).toSet();
    expect(emails.contains('b@example.com'), isFalse);
  });

  test('Umwandlung Angebot → Auftrag → Lieferschein/Rechnung: Entwurf mit Positionen, Herkunft, Regeln wie offline', () async {
    final a = await company('a@example.com', 'Firma A', modules: ['quotes', 'orders', 'deliveryNotes']);
    final b = await company('b@example.com', 'Firma B', modules: ['quotes', 'orders']);
    final customer = await post('/customers', a.auth, {'name': 'Kunde'}, expect: 201);
    final quoteDraft = await post('/documents', a.auth, invoiceBody(customer['id'] as String, kind: 'quote'), expect: 201);

    await post('/documents/${quoteDraft['id']}/convert', a.auth, {'kind': 'order'}, expect: 409); // Entwurf
    final quote = await post('/documents/${quoteDraft['id']}/finalize', a.auth, {'version': 1});
    await post('/documents/${quote['id']}/convert', b.auth, {'kind': 'order'}, expect: 404); // fremde Firma
    await post('/documents/${quote['id']}/convert', a.auth, {'kind': 'proforma'}, expect: 403); // Modul aus

    final order = await post('/documents/${quote['id']}/convert', a.auth, {'kind': 'order'}, expect: 201);
    expect(order['status'], 'draft');
    expect(order['convertedFromId'], quote['id']);
    expect((order['items'] as List), hasLength(3));
    expect((order['totals'] as Map)['grossCents'], 45570);
    final reloadedQuote = jsonDecode((await http.get(baseUrl.resolve('/documents/${quote['id']}'), headers: a.auth)).body) as Map;
    expect((reloadedQuote['convertedTo'] as List).single['id'], order['id']);

    final finalOrder = await post('/documents/${order['id']}/finalize', a.auth, {'version': 1});
    final deliveryNote = await post('/documents/${finalOrder['id']}/convert', a.auth, {'kind': 'deliveryNote'}, expect: 201);
    expect((deliveryNote['items'] as List).map((i) => (i as Map)['kind']), isNot(contains('hours')),
        reason: 'Lieferschein enthält nie Stunden');
    final invoice = await post('/documents/${finalOrder['id']}/convert', a.auth, {'kind': 'invoice'}, expect: 201);
    final finalInvoice = await post('/documents/${invoice['id']}/finalize', a.auth, {'version': 1});
    await post('/documents/${finalInvoice['id']}/convert', a.auth, {'kind': 'order'}, expect: 409,
        ); // Rechnung ist nie Quelle
  });

  test('Zahlungsstatus und Fälligkeit: nur finalisierte Rechnungen, eigenes Recht, Protokoll', () async {
    final a = await company('a@example.com', 'Firma A', modules: ['quotes']);
    final customer = await post('/customers', a.auth, {'name': 'Kunde'}, expect: 201);
    final draft = await post('/documents', a.auth, invoiceBody(customer['id'] as String), expect: 201);
    await post('/documents/${draft['id']}/payment', a.auth, {'paid': true}, expect: 409); // Entwurf
    final invoice = await post('/documents/${draft['id']}/finalize', a.auth, {'version': 1});
    expect(invoice['paymentStatus'], 'open');

    final paid = await post('/documents/${invoice['id']}/payment', a.auth, {'paid': true});
    expect(paid['paymentStatus'], 'paid');
    expect(paid['paidAt'], isNotNull);
    expect(paid['number'], invoice['number'], reason: 'Inhalt/Nummer bleiben unverändert');
    final open = await post('/documents/${invoice['id']}/payment', a.auth, {'paid': false});
    expect(open['paidAt'], isNull);

    final due = await http.put(baseUrl.resolve('/documents/${invoice['id']}/due-date'), headers: a.auth, body: jsonEncode({'dueDate': '2026-11-07'}));
    expectStatus(due, 200);
    expect((jsonDecode(due.body) as Map)['dueDate'], '2026-11-07');
    final cleared = await http.put(baseUrl.resolve('/documents/${invoice['id']}/due-date'), headers: a.auth, body: jsonEncode({'dueDate': null}));
    expect((jsonDecode(cleared.body) as Map)['dueDate'], isNull);

    final quoteDraft = await post('/documents', a.auth, invoiceBody(customer['id'] as String, kind: 'quote'), expect: 201);
    final quote = await post('/documents/${quoteDraft['id']}/finalize', a.auth, {'version': 1});
    await post('/documents/${quote['id']}/payment', a.auth, {'paid': true}, expect: 409);

    final monteur = await member(a, 'monteur@example.com', ['invoices.read', 'invoices.write']);
    await post('/documents/${invoice['id']}/payment', monteur, {'paid': true}, expect: 403);

    final audit = jsonDecode((await http.get(baseUrl.resolve('/audit'), headers: a.auth)).body) as Map;
    expect((audit['entries'] as List).map((e) => (e as Map)['action']), containsAll(['document.paid', 'document.unpaid', 'document.dueDate']));
  });
}

void expectStatus(http.Response response, int status) =>
    expect(response.statusCode, status, reason: '${response.request?.method} ${response.request?.url}: ${response.body}');
