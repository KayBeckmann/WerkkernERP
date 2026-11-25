import 'dart:io';

import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:test/test.dart';
import 'package:werkkern_client/werkkern_client.dart';

import 'package:werkkernerp_server/src/business/models.dart';
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
  late (PhaseBRepository, BusinessRepository) repositories;
  late WerkkernApiClient c;
  late String customerId;
  late String companyId;
  final yy = (DateTime.now().toUtc().year % 100).toString().padLeft(2, '0');

  setUp(() async {
    repositories = await create();
    final (repository, business) = repositories;
    server = await shelf_io.serve(PhaseBRouter(repository: repository, business: business).handler.call, InternetAddress.loopbackIPv4, 0);
    c = WerkkernApiClient(baseUrl: Uri.parse('http://127.0.0.1:${server.port}'));
    await c.register('chef@example.com', 'passwort-12345');
    companyId = await c.createCompany((await c.login('chef@example.com', 'passwort-12345')).identityToken, 'Firma');
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

  test('Materialabschlag wie offline: Artikel und gewählte Freitexte, nie Stunden; zählt als Abschlag', () async {
    final order = await post('/documents', {
      'kind': 'order',
      'customerId': customerId,
      'items': [
        ...orderItems,
        {'kind': 'text', 'description': 'Kleinmaterial', 'quantity': '1', 'unitPriceCents': 2000, 'vatRatePercent': 19},
        {'kind': 'text', 'description': 'Anfahrt', 'quantity': '1', 'unitPriceCents': 3000, 'vatRatePercent': 19},
      ],
    });
    Matcher status(int code) => throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', code));
    await expectLater(post('/documents/${order['id']}/material-advance', {'includeAllArticles': true}), status(409),
        reason: 'nur finalisierte Aufträge');
    final finalized = await post('/documents/${order['id']}/finalize', {'version': order['version']});
    await expectLater(post('/documents/${finalized['id']}/material-advance', {'includeAllArticles': false}), status(400),
        reason: 'ohne jede Position');

    final advance = await post('/documents/${finalized['id']}/material-advance', {
      'includeAllArticles': true,
      'textItemIndexes': [2],
    });
    expect(advance['kind'], 'invoice');
    expect(advance['status'], 'draft');
    expect(advance['isAdvancePayment'], isTrue);
    expect((advance['items'] as List).map((i) => (i as Map)['description']), ['Kabel', 'Kleinmaterial']);

    // Finalisiert zählt er bei der Schlussrechnung als Abschlag.
    await post('/documents/${advance['id']}/finalize', {'version': advance['version']});
    final finalInvoice = await post('/documents/${finalized['id']}/convert', {'kind': 'invoice'});
    expect((finalInvoice['advancePayments'] as List).single['grossCents'], 14280, reason: '(100 + 20) € + 19 %');

    await c.setModules({'orders'});
    await expectLater(post('/documents/${finalized['id']}/material-advance', {'includeAllArticles': true}), status(403),
        reason: 'Modul Abschlagsrechnungen nötig');
  });

  test('Finalisierter Auftrag bleibt bearbeitbar bis zur ersten Umwandlung (wie offline)', () async {
    Matcher conflict() => throwsA(isA<ApiException>().having((e) => e.isConflict, '409', isTrue));
    final order = await finalizedOrder();
    expect(order['editable'], isTrue);
    final number = order['number'];
    final edited = await put('/documents/${order['id']}', {
      'version': order['version'],
      'items': [orderItems.first],
      'notes': 'Nachtrag',
    });
    expect(edited['status'], 'finalized');
    expect(edited['number'], number, reason: 'Nummer bleibt beim Bearbeiten');
    expect(edited['notes'], 'Nachtrag');
    expect((edited['items'] as List), hasLength(1));

    // Kundenwechsel: Schnappschuss ist eingefroren.
    final other = (await c.createCustomer(const OnlineCustomer(id: '', name: 'Schulz'))).id;
    await expectLater(
        put('/documents/${order['id']}', {'version': edited['version'], 'items': orderItems, 'customerId': other}), conflict());

    // Umwandlung übernimmt die bearbeitete Fassung, danach gesperrt.
    final invoice = await post('/documents/${order['id']}/convert', {'kind': 'invoice'});
    expect((invoice['items'] as List).map((i) => (i as Map)['description']), ['Kabel']);
    final reloaded = await c.request('GET', '/documents/${order['id']}') as Map<String, Object?>;
    expect(reloaded['editable'], isFalse);
    await expectLater(put('/documents/${order['id']}', {'version': reloaded['version'], 'items': orderItems}), conflict());

    // Finalisierte Rechnung ist nie bearbeitbar.
    final finalInvoice = await post('/documents/${invoice['id']}/finalize', {'version': invoice['version']});
    expect(finalInvoice['editable'], isFalse);
    await expectLater(put('/documents/${invoice['id']}', {'version': finalInvoice['version'], 'items': orderItems}), conflict());
  });

  test('Umwandlung mit veralteter Quelle wird abgewiesen, Bearbeitung rutscht nicht durch', () async {
    final order = await finalizedOrder();
    final edited = await put('/documents/${order['id']}', {'version': order['version'], 'items': orderItems, 'notes': 'neu'});
    expect(edited['version'], (order['version'] as int) + 1);
    // Direkt am Repository: Umwandlung, die noch die alte Quellversion kennt.
    final (_, business) = repositories;
    final stale = (await business.findDocument(companyId, order['id'] as String))!;
    final draft = Document(
      id: 'stale-conversion',
      companyId: stale.companyId,
      customerId: stale.customerId,
      kind: 'invoice',
      status: 'draft',
      issueDate: stale.issueDate,
      serviceDate: stale.serviceDate,
      paymentTerms: null,
      notes: null,
      createdByUserId: stale.createdByUserId,
      createdAt: stale.createdAt,
      updatedAt: stale.updatedAt,
      version: 1,
      convertedFromId: stale.id,
    );
    await expectLater(
      business.createDocument(draft, const [], expectedSourceVersion: order['version'] as int),
      throwsA(isA<BusinessConflict>()),
    );
    expect(await business.listConvertedFrom(stale.companyId, stale.id), isEmpty);
  });

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

  test('C3.4: Ist-Stunden je Rolle, Preis aus Auftrags-Position der Rolle, sonst Verrechnungssatz', () async {
    final monteur = await post('/staff-roles', {'name': 'Monteur', 'hourlyCostCents': 4000, 'hourlyBillingCents': 6500});
    final meister = await post('/staff-roles', {'name': 'Meister', 'hourlyBillingCents': 8500});
    expect(monteur['hourlyBillingCents'], 6500);
    expect(meister['hourlyCostCents'], 0);
    final updated = await put('/staff-roles/${meister['id']}', {'hourlyBillingCents': 9000});
    expect(updated['hourlyBillingCents'], 9000);
    expect(updated['name'], 'Meister');

    final items = [
      orderItems.first,
      {...orderItems.last, 'unitPriceCents': 6000, 'staffRoleId': monteur['id']},
    ];
    // Rolle einer fremden/unbekannten Firma wird abgelehnt.
    await expectLater(
      post('/documents', {'kind': 'order', 'customerId': customerId, 'items': [{...orderItems.last, 'staffRoleId': 'fremd'}]}),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 400)),
    );
    final order = await post('/documents', {'kind': 'order', 'customerId': customerId, 'items': items});
    expect(((order['items'] as List).last as Map)['staffRoleId'], monteur['id']);
    final finalized = await post('/documents/${order['id']}/finalize', {'version': order['version']});
    for (final (hours, role) in [('4', monteur['id']), ('3.5', monteur['id']), ('2', meister['id'])]) {
      await post('/time-entries', {'date': '2026-10-24', 'hours': hours, 'documentId': finalized['id'], 'staffRoleId': role});
    }
    // Neue Buchung ohne Rolle geht nicht mehr, sobald es Rollen gibt …
    await expectLater(
      post('/time-entries', {'date': '2026-10-24', 'hours': '1', 'documentId': finalized['id']}),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 422)),
    );
    // … Altbestand ohne Rolle (vor C3.4 gebucht) wird trotzdem abgerechnet.
    final (_, business) = repositories;
    final now = DateTime.now().toUtc();
    await business.createTimeEntry(TimeEntry(
      id: 'alt-ohne-rolle',
      companyId: companyId,
      userId: (await business.listTimeEntries(companyId)).first.userId,
      documentId: finalized['id'] as String,
      workDate: DateTime.utc(2026, 10, 20),
      hours: '1',
      createdAt: now,
      updatedAt: now,
    ));
    final invoice = await post('/documents/${order['id']}/convert', {'kind': 'invoice'});
    final lines = (invoice['items'] as List).cast<Map>().where((i) => i['kind'] == 'hours').toList();
    expect(lines.map((i) => (i['staffRoleId'], i['quantity'], i['unitPriceCents'])), [
      (monteur['id'], '7.5', 6000),
      (meister['id'], '2', 9000),
      (null, '1', 6000),
    ]);
    expect(lines.first['description'], 'Monteur – geleistete Stunden (Ist-Zeit)');
    expect(lines[1]['unit'], 'h');
    // Gebucht je Rolle im Auftrag und in der daraus erzeugten Rechnung.
    Map<String?, String> byRole(Map<String, Object?> doc) => {
          for (final e in (doc['bookedHoursByRole'] as List).cast<Map>()) e['staffRoleId'] as String?: e['hours'] as String,
        };
    final orderView = await c.request('GET', '/documents/${order['id']}') as Map<String, Object?>;
    expect(byRole(orderView), {monteur['id']: '7.5', meister['id']: '2', null: '1'});
    expect(byRole(invoice), {monteur['id']: '7.5', meister['id']: '2', null: '1'});

    // Rolle löschen: Position bleibt, verliert nur den Bezug.
    await c.request('DELETE', '/staff-roles/${meister['id']}');
    final reloaded = await c.request('GET', '/documents/${invoice['id']}') as Map<String, Object?>;
    final meisterLine = (reloaded['items'] as List).cast<Map>().firstWhere((i) => i['unitPriceCents'] == 9000);
    expect(meisterLine['staffRoleId'], isNull);
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
  test('Storno, Rechnungskopie bearbeiten und neu ausstellen', () async {
    final draft = await post('/documents', {'customerId': customerId, 'items': orderItems, 'notes': 'Original'});
    final original = await c.finalizeDocument(draft['id'] as String, version: draft['version'] as int);
    final note = await c.cancelInvoice(original.id, version: original.version);
    expect(note.isCancellation, isTrue);
    expect(note.isDraft, isFalse);
    expect(note.number, startsWith('G-'));
    expect(note.convertedFromId, original.id);
    expect(note.items.map((i) => i.description), original.items.map((i) => i.description));
    expect(note.grossCents, original.grossCents);
    final after = await c.document(original.id);
    expect(after.number, original.number);
    expect(after.notes, 'Original');
    expect(after.cancellationId, note.id);
    final copy = await c.copyInvoice(original.id);
    expect(copy.isDraft, isTrue);
    expect(copy.number, isNull);
    expect(copy.isPaid, isFalse);
    expect(copy.isCancellation, isFalse);
    expect(copy.cancellationId, isNull);
    expect(copy.convertedFromId, original.id);
    final edited = await put('/documents/${copy.id}', {'version': copy.version, 'items': orderItems, 'notes': 'Korrigiert'});
    final issued = await c.finalizeDocument(copy.id, version: edited['version'] as int);
    expect(issued.number, isNot(original.number));
    expect(issued.notes, 'Korrigiert');
    expect((await c.document(original.id)).notes, 'Original');
    final conflict = throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 409));
    await expectLater(c.cancelInvoice(original.id, version: original.version), conflict);
    await expectLater(c.createCreditNote(original.id), conflict);
  });

  test('Storno prüft Version, vorhandene Gutschriften und Modul', () async {
    final draft = await post('/documents', {'customerId': customerId, 'items': orderItems});
    final conflict = throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 409));
    await expectLater(c.cancelInvoice(draft['id'] as String, version: draft['version'] as int), conflict);
    await expectLater(c.copyInvoice(draft['id'] as String), conflict);
    final original = await c.finalizeDocument(draft['id'] as String, version: draft['version'] as int);
    await expectLater(c.cancelInvoice(original.id, version: original.version - 1), conflict);
    expect((await c.document(original.id)).creditNotes, isEmpty);
    final copy = await c.copyInvoice(original.id);
    expect(copy.convertedFromId, isNull);
    await c.createCreditNote(original.id);
    await expectLater(c.cancelInvoice(original.id, version: original.version), conflict);
    await c.setModules({});
    await expectLater(c.cancelInvoice(original.id, version: original.version),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 403)));
  });

  test('Gleichzeitige Stornierungen erzeugen genau einen Gegenbeleg', () async {
    final draft = await post('/documents', {'customerId': customerId, 'items': orderItems});
    final original = await c.finalizeDocument(draft['id'] as String, version: draft['version'] as int);
    final results = await Future.wait([for (var i = 0; i < 2; i++)
      c.cancelInvoice(original.id, version: original.version).then<Object>((d) => d).catchError((Object e) => e)]);
    expect(results.whereType<OnlineDocument>(), hasLength(1));
    expect(results.whereType<ApiException>().single.statusCode, 409);
    expect((await c.document(original.id)).creditNotes, hasLength(1));
  });

  test('Storno entfernt offene Posten und Mahnungen, neue Rechnung bleibt offen', () async {
    await c.setModules({'creditNotes', 'buchhaltung', 'dunning'});
    final group = (await c.groups()).firstWhere((g) => g.name == 'Projektleiter').id;
    for (final permission in ['accounting.read', 'dunning.read', 'dunning.write', 'invoices.payment']) {
      await c.setGroupPermission(group, permission, granted: true);
    }
    final draft = await post('/documents', {'customerId': customerId, 'items': orderItems});
    final original = await c.finalizeDocument(draft['id'] as String, version: draft['version'] as int);
    final due = await c.setDueDate(original.id, DateTime(2020, 1, 1));
    final before = await c.request('GET', '/accounting/open-items') as Map;
    expect(before['totalCents'], original.grossCents);
    await c.cancelInvoice(original.id, version: due.version);
    final after = await c.request('GET', '/accounting/open-items') as Map;
    expect(after['totalCents'], 0);
    expect((await c.request('GET', '/dunning/overdue') as Map)['overdue'], isEmpty);
    final copy = await c.copyInvoice(original.id);
    await c.finalizeDocument(copy.id, version: copy.version);
    expect((await c.request('GET', '/accounting/open-items') as Map)['totalCents'], original.grossCents);
  });

  test('Volle Gutschrift schließt die Rechnung wie ein Storno, Teilgutschrift nicht', () async {
    await c.setModules({'creditNotes', 'buchhaltung', 'dunning'});
    final group = (await c.groups()).firstWhere((g) => g.name == 'Projektleiter').id;
    for (final permission in ['accounting.read', 'dunning.read', 'dunning.write', 'invoices.payment']) {
      await c.setGroupPermission(group, permission, granted: true);
    }
    final draft = await post('/documents', {'customerId': customerId, 'items': orderItems});
    final original = await c.finalizeDocument(draft['id'] as String, version: draft['version'] as int);
    await c.setDueDate(original.id, DateTime(2020, 1, 1));

    // Teilgutschrift (eine Position weniger): Rechnung bleibt offen.
    final partial = await c.createCreditNote(original.id);
    final partialEdited = await put('/documents/${partial.id}', {'version': partial.version, 'items': orderItems.take(1).toList()});
    await c.finalizeDocument(partial.id, version: partialEdited['version'] as int);
    expect((await c.document(original.id)).isClosed, isFalse);
    expect((await c.request('GET', '/dunning/overdue') as Map)['overdue'], hasLength(1));

    // Rest gutschreiben: zusammen der volle Betrag, Rechnung geschlossen.
    final rest = await c.createCreditNote(original.id);
    final restEdited = await put('/documents/${rest.id}', {'version': rest.version, 'items': orderItems.skip(1).toList()});
    await c.finalizeDocument(rest.id, version: restEdited['version'] as int);
    expect((await c.document(original.id)).isClosed, isTrue);
    expect((await c.request('GET', '/accounting/open-items') as Map)['totalCents'], 0);
    expect((await c.request('GET', '/dunning/overdue') as Map)['overdue'], isEmpty);
    expect((await c.documents(kind: 'invoice')).firstWhere((d) => d.id == original.id).isClosed, isTrue);
    final tiles = ((await c.request('GET', '/dashboard') as Map)['tiles'] as List).cast<Map>();
    expect(tiles.firstWhere((t) => t['key'] == 'openInvoices')['count'], 0);
  });

  test('Storno und Kopie respektieren Firmenbindung und Schreibrechte', () async {
    final draft = await post('/documents', {'customerId': customerId, 'items': orderItems});
    final original = await c.finalizeDocument(draft['id'] as String, version: draft['version'] as int);
    final notFound = throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 404));
    final otherCompany = await c.createCompany((await c.login('chef@example.com', 'passwort-12345')).identityToken, 'Andere Firma');
    await c.selectCompany((await c.login('chef@example.com', 'passwort-12345')).identityToken, otherCompany);
    await c.setModules({'creditNotes'});
    final otherGroup = (await c.groups()).firstWhere((g) => g.name == 'Projektleiter').id;
    for (final p in ['invoices.write', 'invoices.finalize']) { await c.setGroupPermission(otherGroup, p, granted: true); }
    await expectLater(c.copyInvoice(original.id), notFound);
    await expectLater(c.cancelInvoice(original.id, version: original.version), notFound);
    await c.selectCompany((await c.login('chef@example.com', 'passwort-12345')).identityToken, companyId);
    final group = (await c.groups()).firstWhere((g) => g.name == 'Projektleiter').id;
    await c.setGroupPermission(group, 'invoices.write', granted: false);
    final forbidden = throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 403));
    await expectLater(c.copyInvoice(original.id), forbidden);
    await expectLater(c.cancelInvoice(original.id, version: original.version), forbidden);
  });

  test('Stornierte Abschläge werden nach Neuausstellung nicht doppelt abgezogen', () async {
    final order = await finalizedOrder();
    final advance = await post('/documents/${order['id']}/material-advance', {'includeAllArticles': true});
    final issued = await c.finalizeDocument(advance['id'] as String, version: advance['version'] as int);
    await c.cancelInvoice(issued.id, version: issued.version);
    final copy = await c.copyInvoice(issued.id);
    expect(copy.isAdvancePayment, isTrue);
    expect(copy.convertedFromId, order['id']);
    final replacement = await c.finalizeDocument(copy.id, version: copy.version);
    final finalInvoice = await c.convertDocument(order['id'] as String, 'invoice');
    expect(finalInvoice.advancePayments.map((a) => a.id), [replacement.id]);
  });

  test('Agent darf Storno nur nach Freigabe ausführen', () async {
    await c.setModules({'creditNotes', 'aiAgents'});
    final draft = await post('/documents', {'customerId': customerId, 'items': orderItems});
    final original = await c.finalizeDocument(draft['id'] as String, version: draft['version'] as int);
    final token = await c.createAgentToken('Storno-Test');
    final agent = WerkkernApiClient(baseUrl: Uri.parse('http://127.0.0.1:${server.port}'))..token = token.token;
    final pending = await agent.request('POST', '/documents/${original.id}/cancel', body: {'version': original.version}) as Map;
    expect(pending['approvalId'], isA<String>());
    expect((await c.document(original.id)).cancellationId, isNull);
    await c.confirmApproval(pending['approvalId'] as String);
    expect((await c.document(original.id)).cancellationId, isNotNull);
  });

}
