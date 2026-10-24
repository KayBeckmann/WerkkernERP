import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:test/test.dart';
import 'package:werkkern_client/werkkern_client.dart';

import 'package:werkkernerp_server/src/business/repository.dart';
import 'package:werkkernerp_server/src/business/repository_memory.dart';
import 'package:werkkernerp_server/src/repository.dart';
import 'package:werkkernerp_server/src/repository_memory.dart';
import 'package:werkkernerp_server/src/router.dart';

/// HTTP-Client, der sich auf Kommando wie ein Funkloch verhält:
/// [offline] = keine Verbindung; [loseNextResponse] = Server bekommt
/// und verarbeitet die Anfrage, die Antwort geht aber verloren.
class FlakyHttpClient extends http.BaseClient {
  final _inner = http.Client();
  bool offline = false;
  bool loseNextResponse = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (offline) throw http.ClientException('Netz weg');
    final response = await _inner.send(request);
    if (loseNextResponse) {
      loseNextResponse = false;
      await response.stream.drain<void>();
      throw http.ClientException('Verbindung während der Antwort abgerissen');
    }
    return response;
  }
}

void main() => runOfflineSyncTests(() async => (InMemoryPhaseBRepository(), InMemoryBusinessRepository()));

/// B2-Abnahme (Roadmap B2 Punkt 3): Netzausfall während Änderung,
/// Doppelübertragung, zwei konkurrierende Geräte, widerrufene Rechte/
/// Mitgliedschaft — mit dem echten App-Client gegen den echten Router.
void runOfflineSyncTests(Future<(PhaseBRepository, BusinessRepository)> Function() create) {
  late HttpServer server;
  late Uri base;
  late String companyId;
  late Map<String, String> adminAuth;
  late String groupId;

  setUp(() async {
    final (repository, business) = await create();
    server = await shelf_io.serve(PhaseBRouter(repository: repository, business: business).handler.call, InternetAddress.loopbackIPv4, 0);
    base = Uri.parse('http://127.0.0.1:${server.port}');
    final admin = WerkkernApiClient(baseUrl: base);
    await admin.register('chef@example.com', 'passwort-12345');
    companyId = await admin.createCompany((await admin.login('chef@example.com', 'passwort-12345')).identityToken, 'Firma');
    await admin.selectCompany((await admin.login('chef@example.com', 'passwort-12345')).identityToken, companyId);
    adminAuth = {'authorization': 'Bearer ${admin.token}'};
    groupId = (await admin.groups()).firstWhere((g) => g.name == 'Monteur').id;
    for (final p in ['customers.read', 'invoices.read', 'invoices.write']) {
      await admin.setGroupPermission(groupId, p, granted: true);
    }
    final ownGroup = (jsonDecode((await http.get(base.resolve('/me'), headers: adminAuth)).body) as Map)['groupId'] as String;
    for (final p in ['customers.read', 'customers.write', 'invoices.read', 'invoices.write']) {
      await admin.setGroupPermission(ownGroup, p, granted: true);
    }
  });
  tearDown(() => server.close(force: true));

  /// Monteur mit eigenem (flakigem) Gerät und Offline-Bestand.
  Future<({WerkkernApiClient client, FlakyHttpClient net, OfflineStore store, InMemoryOfflineVault vault})> device(
    String email,
  ) async {
    final admin = WerkkernApiClient(baseUrl: base)..token = adminAuth['authorization']!.substring(7);
    final invitation = await admin.createInvitation(email, groupId);
    final net = FlakyHttpClient();
    final client = WerkkernApiClient(baseUrl: base, httpClient: net);
    await client.acceptInvitation(invitation, 'passwort-12345');
    await client.selectCompany((await client.login(email, 'passwort-12345')).identityToken, companyId);
    final vault = InMemoryOfflineVault();
    final store = OfflineStore(vault);
    await store.bind(OfflineScope(serverUrl: base.toString(), email: email, companyId: companyId, companyName: 'Firma'));
    return (client: client, net: net, store: store, vault: vault);
  }

  Future<String> draftForCustomer() async {
    final admin = WerkkernApiClient(baseUrl: base)..token = adminAuth['authorization']!.substring(7);
    final customer = await admin.createCustomer(const OnlineCustomer(id: '', name: 'Baustelle Meyer'));
    final draft = await admin.createDocument(customerId: customer.id, items: const [
      OnlineDocumentItem(kind: OnlineItemKind.hours, description: 'Montage', quantity: '1', unitPriceCents: 6000, vatRatePercent: 19),
    ]);
    return draft.id;
  }

  Future<void> pin(({WerkkernApiClient client, FlakyHttpClient net, OfflineStore store, InMemoryOfflineVault vault}) d, String id) async {
    final json = await d.client.documentJson(id);
    final customer = (await d.client.customers()).firstWhere((c) => c.id == json['customerId']);
    await d.store.pin(json, customer);
  }

  const extraItem = OnlineDocumentItem(kind: OnlineItemKind.text, description: 'Material vor Ort', quantity: '1', unitPriceCents: 2500, vatRatePercent: 19);

  test('Offline bearbeiten, Bestand überlebt Neustart, Abgleich bei Rückkehr online', () async {
    final d = await device('monteur@example.com');
    final id = await draftForCustomer();
    await pin(d, id);

    d.net.offline = true;
    final local = d.store.document(id)!;
    await d.store.enqueueUpdate(id, items: [...local.items, extraItem], notes: 'im Keller');
    expect((await const SyncService().sync(d.client, d.store)).unreachable, isTrue);

    // "App-Neustart": neuer Store aus derselben (verschlüsselten) Ablage.
    final restarted = OfflineStore(d.vault);
    await restarted.load();
    expect(restarted.outbox, hasLength(1));
    expect(restarted.document(id)!.items, hasLength(2));
    expect(restarted.customer(restarted.document(id)!.customerId)!.name, 'Baustelle Meyer');

    d.net.offline = false;
    final result = await const SyncService().sync(d.client, restarted);
    expect(result.clean, isTrue);
    expect(result.sent, 1);
    expect(restarted.outbox, isEmpty);
    final serverState = await d.client.document(id);
    expect(serverState.items, hasLength(2));
    expect(serverState.notes, 'im Keller');
    expect(restarted.document(id)!.version, serverState.version);
  });

  test('Netzausfall während der Übertragung (Antwort verloren) + erneutes Senden: genau einmal angewendet', () async {
    final d = await device('monteur@example.com');
    final id = await draftForCustomer();
    await pin(d, id);
    await d.store.enqueueUpdate(id, items: [...d.store.document(id)!.items, extraItem]);

    d.net.loseNextResponse = true;
    final first = await const SyncService().sync(d.client, d.store);
    expect(first.unreachable, isTrue);
    expect(d.store.outbox.single.attempted, isTrue);

    final second = await const SyncService().sync(d.client, d.store);
    expect(second.clean, isTrue, reason: 'Wiederholung bekommt die gespeicherte Antwort, kein falscher 409');
    expect(d.store.outbox, isEmpty);
    final serverState = await d.client.document(id);
    expect(serverState.version, 2, reason: 'genau eine Änderung, nicht zwei');
    expect(serverState.items, hasLength(2));
  });

  test('Zwei konkurrierende Geräte: Konflikt wird sichtbar, nichts überschrieben; Folgeänderung blockiert', () async {
    final a = await device('a@example.com');
    final b = await device('b@example.com');
    final id = await draftForCustomer();
    await pin(a, id);

    a.net.offline = true;
    await a.store.enqueueUpdate(id, items: [...a.store.document(id)!.items, extraItem], notes: 'Gerät A');
    a.net.loseNextResponse = false;

    // Gerät B speichert online dazwischen.
    final current = await b.client.document(id);
    await b.client.updateDocument(id: id, version: current.version, items: current.items, notes: 'Gerät B');

    a.net.offline = false;
    final firstSync = await const SyncService().sync(a.client, a.store);
    expect(firstSync.conflicts, hasLength(1));
    expect((await a.client.document(id)).notes, 'Gerät B', reason: 'B wurde nicht überschrieben');

    // Weitere Offline-Änderung auf A baut auf der abgelehnten auf -> blockiert.
    await a.store.enqueueUpdate(id, items: a.store.document(id)!.items, notes: 'Gerät A, zweiter Versuch');
    final secondSync = await const SyncService().sync(a.client, a.store);
    expect(secondSync.conflicts.single.message, contains('abgelehnten'));
    expect((await a.client.document(id)).notes, 'Gerät B');

    // Nutzer entscheidet: lokale Änderungen verwerfen -> Serverstand.
    for (final o in [...a.store.outbox]) {
      await a.store.discard(o.opId);
    }
    final finalSync = await const SyncService().sync(a.client, a.store);
    expect(finalSync.clean, isTrue);
    expect(a.store.document(id)!.notes, 'Gerät B');
  });

  test('Entzogenes Leserecht: lokale Kopie wird beim Abgleich entfernt; offene Änderung abgewiesen', () async {
    final d = await device('monteur@example.com');
    final id = await draftForCustomer();
    await pin(d, id);
    await d.store.enqueueUpdate(id, items: [...d.store.document(id)!.items, extraItem]);

    final admin = WerkkernApiClient(baseUrl: base)..token = adminAuth['authorization']!.substring(7);
    await admin.setGroupPermission(groupId, 'invoices.write', granted: false);
    await admin.setGroupPermission(groupId, 'invoices.read', granted: false);

    final result = await const SyncService().sync(d.client, d.store);
    expect(result.rejected, hasLength(1), reason: 'Server prüft Rechte bei Rückkehr online neu');
    expect((await admin.document(id)).items, hasLength(1), reason: 'nichts übernommen');

    // Nach Entscheidung des Nutzers (verwerfen) wird die Kopie entfernt.
    await d.store.discard(d.store.outbox.single.opId);
    final again = await const SyncService().sync(d.client, d.store);
    expect(again.revoked, [id]);
    expect(d.store.isPinned(id), isFalse);
  });

  test('Deaktivierte Mitgliedschaft: Abgleich verlangt Anmeldung, Anmeldung für die Firma scheitert', () async {
    final d = await device('monteur@example.com');
    final id = await draftForCustomer();
    await pin(d, id);
    await d.store.enqueueUpdate(id, items: [...d.store.document(id)!.items, extraItem]);

    final admin = WerkkernApiClient(baseUrl: base)..token = adminAuth['authorization']!.substring(7);
    final member = (await admin.members()).firstWhere((m) => m.email == 'monteur@example.com');
    await admin.updateMember(member.id, active: false);

    final result = await const SyncService().sync(d.client, d.store);
    expect(result.needsLogin, isTrue);
    expect(d.store.outbox, hasLength(1), reason: 'bleibt sichtbar, wird nicht still verworfen');
    final login = await d.client.login('monteur@example.com', 'passwort-12345');
    expect(login.memberships, isEmpty, reason: 'keine aktive Mitgliedschaft mehr');
    expect((await admin.document(id)).items, hasLength(1));
  });

  test('Bestand ist an Server/Konto/Firma gebunden; mit offenen Änderungen kein stiller Wechsel', () async {
    final d = await device('monteur@example.com');
    final id = await draftForCustomer();
    await pin(d, id);
    await d.store.enqueueUpdate(id, items: d.store.document(id)!.items, notes: 'x');
    expect(
      () => d.store.bind(OfflineScope(serverUrl: base.toString(), email: 'anderer@example.com', companyId: companyId, companyName: 'Firma')),
      throwsStateError,
    );
    expect(() => d.store.unpin(id), throwsStateError);
    await d.store.wipe();
    expect(d.store.isEmpty, isTrue);
    expect(d.vault.content, isNull);
  });
}
