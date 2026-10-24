import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:test/test.dart';
import 'package:werkkernerp_server/src/login_throttle.dart';
import 'package:werkkernerp_server/src/models.dart';
import 'package:werkkernerp_server/src/repository.dart';
import 'package:werkkernerp_server/src/repository_memory.dart';
import 'package:werkkernerp_server/src/router.dart';

void main() => runHardeningTests(() async => InMemoryPhaseBRepository());

void runHardeningTests(Future<PhaseBRepository> Function() create) {
  test('LoginThrottle: Sperre nach Fehlversuchen, Fenster läuft ab, Erfolg setzt Konto zurück', () {
    var now = DateTime.utc(2026, 10, 24, 12);
    final throttle = LoginThrottle(maxFailuresPerAccount: 3, maxFailuresPerAddress: 5, clock: () => now);
    for (var i = 0; i < 3; i++) {
      expect(throttle.blockedFor(account: 'A@x.de', address: '1.2.3.4'), isNull);
      throttle.recordFailure(account: 'a@x.de', address: '1.2.3.4');
    }
    expect(throttle.blockedFor(account: 'a@x.de'), const Duration(minutes: 15));
    now = now.add(const Duration(minutes: 16));
    expect(throttle.blockedFor(account: 'a@x.de'), isNull);

    // Adresse: viele Konten von derselben IP durchprobieren.
    for (var i = 0; i < 5; i++) {
      throttle.recordFailure(account: 'user$i@x.de', address: '9.9.9.9');
    }
    expect(throttle.blockedFor(account: 'neu@x.de', address: '9.9.9.9'), isNotNull);
    expect(throttle.blockedFor(account: 'neu@x.de', address: '8.8.8.8'), isNull);

    throttle.recordFailure(account: 'b@x.de');
    throttle.recordSuccess(account: 'b@x.de');
    expect(throttle.blockedFor(account: 'b@x.de'), isNull);
  });

  group('über die API', () {
    late HttpServer server;
    late Uri base;
    late PhaseBRepository repository;
    var now = DateTime.now().toUtc();

    setUp(() async {
      now = DateTime.now().toUtc();
      repository = await create();
      final router = PhaseBRouter(
        repository: repository,
        loginThrottle: LoginThrottle(maxFailuresPerAccount: 3, clock: () => now),
      );
      server = await shelf_io.serve(router.handler.call, InternetAddress.loopbackIPv4, 0);
      base = Uri.parse('http://127.0.0.1:${server.port}');
      await http.post(base.resolve('/auth/register'), body: jsonEncode({'email': 'a@example.com', 'password': 'passwort-12345'}));
    });
    tearDown(() => server.close(force: true));

    Future<http.Response> login(String password) =>
        http.post(base.resolve('/auth/login'), body: jsonEncode({'email': 'a@example.com', 'password': password}));

    Future<String> session(String password) async {
      final identity = (jsonDecode((await login(password)).body) as Map)['identityToken'];
      final companies = await http.post(base.resolve('/companies'), body: jsonEncode({'identityToken': identity, 'name': 'A'}));
      final companyId = (jsonDecode(companies.body) as Map)['companyId'];
      final identity2 = (jsonDecode((await login(password)).body) as Map)['identityToken'];
      final selected = await http.post(base.resolve('/auth/select-company'),
          body: jsonEncode({'identityToken': identity2, 'companyId': companyId}));
      return (jsonDecode(selected.body) as Map)['token'] as String;
    }

    test('Nach 3 Fehlversuchen 429 mit Retry-After — auch mit richtigem Passwort; nach Ablauf wieder möglich', () async {
      for (var i = 0; i < 3; i++) {
        expect((await login('falsch-falsch')).statusCode, 401);
      }
      final blocked = await login('passwort-12345');
      expect(blocked.statusCode, 429);
      expect(int.parse(blocked.headers['retry-after']!), greaterThan(0));
      now = now.add(const Duration(minutes: 16));
      expect((await login('passwort-12345')).statusCode, 200);
    });

    test('Passwort ändern: falsches aktuelles 403; danach altes ungültig, andere Sitzungen beendet, eigene bleibt', () async {
      final mine = await session('passwort-12345');
      final otherIdentity = (jsonDecode((await login('passwort-12345')).body) as Map)['identityToken'];
      final companyId = ((jsonDecode((await login('passwort-12345')).body) as Map)['memberships'] as List).single['companyId'];
      final other = (jsonDecode((await http.post(base.resolve('/auth/select-company'),
              body: jsonEncode({'identityToken': otherIdentity, 'companyId': companyId})))
          .body) as Map)['token'];

      Future<http.Response> change(String current, String next) => http.post(
            base.resolve('/auth/change-password'),
            headers: {'authorization': 'Bearer $mine'},
            body: jsonEncode({'currentPassword': current, 'newPassword': next}),
          );
      expect((await change('daneben-123', 'neues-passwort-1')).statusCode, 403);
      expect((await change('passwort-12345', 'kurz')).statusCode, 400);
      expect((await change('passwort-12345', 'neues-passwort-1')).statusCode, 204);

      expect((await login('passwort-12345')).statusCode, 401);
      expect((await login('neues-passwort-1')).statusCode, 200);
      expect((await http.get(base.resolve('/me'), headers: {'authorization': 'Bearer $other'})).statusCode, 401);
      expect((await http.get(base.resolve('/me'), headers: {'authorization': 'Bearer $mine'})).statusCode, 200);
    });

    test('purgeExpired entfernt abgelaufene Sitzungen und Login-Token, gültige bleiben', () async {
      final user = (await repository.findUserByEmail('a@example.com'))!;
      await repository.createCompany(id: 'c-purge', name: 'P');
      await repository.createGroup(id: 'g-purge', companyId: 'c-purge', name: 'G');
      await repository.createMembership(id: 'm-purge', userId: user.id, companyId: 'c-purge', groupId: 'g-purge', isAdmin: true);
      final t = DateTime.now().toUtc();
      CompanySession s(String hash, Duration ttl) => CompanySession(
            tokenHash: hash,
            membershipId: 'm-purge',
            userId: user.id,
            companyId: 'c-purge',
            createdAt: t.subtract(const Duration(hours: 9)),
            expiresAt: t.add(ttl),
          );
      await repository.saveSession(s('alt', const Duration(hours: -1)));
      await repository.saveSession(s('frisch', const Duration(hours: 1)));
      await repository.savePendingLogin(tokenHash: 'p-alt', userId: user.id, expiresAt: t.subtract(const Duration(minutes: 1)));
      await repository.purgeExpired(t);
      expect(await repository.findSession('alt'), isNull);
      expect(await repository.findSession('frisch'), isNotNull);
      expect(await repository.consumePendingLogin('p-alt', t.subtract(const Duration(hours: 1))), isNull);
    });
  });
}
