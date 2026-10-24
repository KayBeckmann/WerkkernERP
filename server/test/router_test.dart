import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:test/test.dart';
import 'package:http/http.dart' as http;

import 'package:werkkernerp_server/src/permission_catalog.dart';
import 'package:werkkernerp_server/src/repository.dart';
import 'package:werkkernerp_server/src/repository_memory.dart';
import 'package:werkkernerp_server/src/router.dart';

void main() => runRouterTests(() async => InMemoryPhaseBRepository());

/// Gemeinsame Suite für beide Repository-Implementierungen — siehe
/// `router_postgres_test.dart` für denselben Lauf gegen echtes Postgres.
void runRouterTests(Future<PhaseBRepository> Function() createRepository) {
  late PhaseBRepository repository;
  late HttpServer server;
  late Uri baseUrl;

  setUp(() async {
    repository = await createRepository();
    final router = PhaseBRouter(repository: repository);
    server = await shelf_io.serve(router.handler.call, InternetAddress.loopbackIPv4, 0);
    baseUrl = Uri.parse('http://127.0.0.1:${server.port}');
  });

  tearDown(() => server.close(force: true));

  Future<void> register(String email, String password) async {
    final response = await http.post(
      baseUrl.resolve('/auth/register'),
      body: jsonEncode({'email': email, 'password': password}),
    );
    expect(response.statusCode, 201);
  }

  Future<String> loginIdentity(String email, String password) async {
    final response = await http.post(
      baseUrl.resolve('/auth/login'),
      body: jsonEncode({'email': email, 'password': password}),
    );
    expect(response.statusCode, 200);
    return (jsonDecode(response.body) as Map<String, Object?>)['identityToken'] as String;
  }

  Future<String> createCompany(String identityToken, String name) async {
    final response = await http.post(
      baseUrl.resolve('/companies'),
      body: jsonEncode({'identityToken': identityToken, 'name': name}),
    );
    expect(response.statusCode, 201);
    return (jsonDecode(response.body) as Map<String, Object?>)['companyId'] as String;
  }

  Future<String> selectCompany(String identityToken, String companyId) async {
    final response = await http.post(
      baseUrl.resolve('/auth/select-company'),
      body: jsonEncode({'identityToken': identityToken, 'companyId': companyId}),
    );
    expect(response.statusCode, 200);
    return (jsonDecode(response.body) as Map<String, Object?>)['token'] as String;
  }

  /// Registriert + legt eine neue Firma an + wählt sie aus — liefert
  /// direkt das firmengebundene Session-Token des Erst-Admins.
  Future<({String token, String companyId})> setUpCompanyWithAdmin(String email, String companyName) async {
    await register(email, 'passwort-12345');
    final identity1 = await loginIdentity(email, 'passwort-12345');
    final companyId = await createCompany(identity1, companyName);
    // identityToken wurde durch createCompany() bereits verbraucht
    // (consumePendingLogin) — für die Firmenauswahl erneut anmelden.
    final identity2 = await loginIdentity(email, 'passwort-12345');
    final token = await selectCompany(identity2, companyId);
    return (token: token, companyId: companyId);
  }

  test('GET /health ist ohne Anmeldung erreichbar', () async {
    final response = await http.get(baseUrl.resolve('/health'));
    expect(response.statusCode, 200);
  });

  test('Doppelte Registrierung derselben E-Mail wird abgelehnt', () async {
    await register('a@example.com', 'passwort-12345');
    final response = await http.post(
      baseUrl.resolve('/auth/register'),
      body: jsonEncode({'email': 'a@example.com', 'password': 'anderes-passwort'}),
    );
    expect(response.statusCode, 409);
  });

  test(
    'Firmenanlage seedet die drei Startgruppen (Projektleiter/Monteur/Buchhaltung) mit ihren '
    'Standardrechten, der Ersteller wird Admin',
    () async {
      final setup = await setUpCompanyWithAdmin('admin@a.example', 'Firma A');

      final meResponse = await http.get(baseUrl.resolve('/me'), headers: {'authorization': 'Bearer ${setup.token}'});
      final me = jsonDecode(meResponse.body) as Map<String, Object?>;
      expect(me['isAdmin'], isTrue);
      expect(me['companyName'], 'Firma A');

      final groupsResponse =
          await http.get(baseUrl.resolve('/groups'), headers: {'authorization': 'Bearer ${setup.token}'});
      final groups = (jsonDecode(groupsResponse.body) as Map<String, Object?>)['groups'] as List;
      expect(
        groups.map((g) => (g as Map<String, Object?>)['name']),
        unorderedEquals(['Projektleiter', 'Monteur', 'Buchhaltung']),
      );

      for (final group in groups.cast<Map<String, Object?>>()) {
        final permissionsResponse = await http.get(
          baseUrl.resolve('/groups/${group['id']}/permissions'),
          headers: {'authorization': 'Bearer ${setup.token}'},
        );
        final permissions = (jsonDecode(permissionsResponse.body) as Map<String, Object?>)['permissions'] as List;
        expect(permissions.toSet(), starterGroupPermissions[group['name']], reason: '${group['name']}');
      }
      // Stichproben der Matrix: Monteur finalisiert nicht und sieht nicht
      // die Zeiten aller, nur die Buchhaltung markiert Zahlungen.
      expect(starterGroupPermissions['Monteur'], isNot(contains('invoices.finalize')));
      expect(starterGroupPermissions['Monteur'], isNot(contains('timeTracking.read')));
      expect(starterGroupPermissions['Projektleiter'], isNot(contains('invoices.payment')));
      expect(starterGroupPermissions['Buchhaltung'], contains('invoices.payment'));
      expect(starterGroupPermissions.values.expand((p) => p).every(isKnownPermission), isTrue);
    },
  );

  test(
    'Admin A kann keine Mitgliedschaften/Gruppen in Firma B sehen/ändern, auch nicht über '
    'direkte API-Aufrufe mit bekannter ID (Cross-Tenant-Schutz)',
    () async {
      final companyA = await setUpCompanyWithAdmin('admin-a@example.com', 'Firma A');
      final companyB = await setUpCompanyWithAdmin('admin-b@example.com', 'Firma B');

      // Mitgliedschafts-Liste von B über A's Token abfragen -> nur A
      // sichtbar, nie B.
      final listResponse =
          await http.get(baseUrl.resolve('/memberships'), headers: {'authorization': 'Bearer ${companyA.token}'});
      final memberships = (jsonDecode(listResponse.body) as Map<String, Object?>)['memberships'] as List;
      expect(memberships, hasLength(1));
      expect((memberships.single as Map<String, Object?>)['email'], 'admin-a@example.com');

      // Admin A errät/kennt die Admin-Mitgliedschafts-ID von Firma B
      // (z. B. aus eigenen Tests) und versucht, sie zu deaktivieren.
      final bMembershipsListResponse =
          await http.get(baseUrl.resolve('/memberships'), headers: {'authorization': 'Bearer ${companyB.token}'});
      final bMembershipId = ((jsonDecode(bMembershipsListResponse.body) as Map<String, Object?>)['memberships']
              as List)
          .first['id'] as String;

      final crossTenantPatch = await http.patch(
        baseUrl.resolve('/memberships/$bMembershipId'),
        headers: {'authorization': 'Bearer ${companyA.token}'},
        body: jsonEncode({'active': false}),
      );
      expect(crossTenantPatch.statusCode, 404, reason: 'kein Oracle für fremde Mitgliedschafts-IDs');

      // Direkter Aufruf der Gruppen-Berechtigungen von B über A's Token.
      final bGroupsResponse =
          await http.get(baseUrl.resolve('/groups'), headers: {'authorization': 'Bearer ${companyB.token}'});
      final bGroupId = ((jsonDecode(bGroupsResponse.body) as Map<String, Object?>)['groups'] as List).first['id']
          as String;
      final crossTenantGroupRead =
          await http.get(baseUrl.resolve('/groups/$bGroupId/permissions'), headers: {'authorization': 'Bearer ${companyA.token}'});
      expect(crossTenantGroupRead.statusCode, 404);
    },
  );

  test('Nicht-Admin erreicht keine Mitgliedschaftsverwaltung, auch nicht über direkte API-Aufrufe', () async {
    final company = await setUpCompanyWithAdmin('admin@example.com', 'Firma A');
    await register('drafter@example.com', 'passwort-12345');

    final groupsResponse =
        await http.get(baseUrl.resolve('/groups'), headers: {'authorization': 'Bearer ${company.token}'});
    final groupId = ((jsonDecode(groupsResponse.body) as Map<String, Object?>)['groups'] as List).first['id']
        as String;

    final addResponse = await http.post(
      baseUrl.resolve('/memberships'),
      headers: {'authorization': 'Bearer ${company.token}'},
      body: jsonEncode({'email': 'drafter@example.com', 'groupId': groupId}),
    );
    expect(addResponse.statusCode, 201);

    final drafterIdentity = await loginIdentity('drafter@example.com', 'passwort-12345');
    final drafterToken = await selectCompany(drafterIdentity, company.companyId);

    final listAsDrafter =
        await http.get(baseUrl.resolve('/memberships'), headers: {'authorization': 'Bearer $drafterToken'});
    expect(listAsDrafter.statusCode, 403);

    final createGroupAsDrafter = await http.post(
      baseUrl.resolve('/groups'),
      headers: {'authorization': 'Bearer $drafterToken'},
      body: jsonEncode({'name': 'Neue Gruppe'}),
    );
    expect(createGroupAsDrafter.statusCode, 403);
  });

  test(
    'Individuelles Erlauben/Sperren je Berechtigung überschreibt die Gruppe (End-to-End über '
    'die echte API)',
    () async {
      final company = await setUpCompanyWithAdmin('admin@example.com', 'Firma A');
      await register('drafter@example.com', 'passwort-12345');

      final groupsResponse =
          await http.get(baseUrl.resolve('/groups'), headers: {'authorization': 'Bearer ${company.token}'});
      final groupId = ((jsonDecode(groupsResponse.body) as Map<String, Object?>)['groups'] as List)
          .firstWhere((g) => (g as Map<String, Object?>)['name'] == 'Projektleiter')['id'] as String;

      await http.post(
        baseUrl.resolve('/memberships'),
        headers: {'authorization': 'Bearer ${company.token}'},
        body: jsonEncode({'email': 'drafter@example.com', 'groupId': groupId}),
      );
      final drafterIdentity = await loginIdentity('drafter@example.com', 'passwort-12345');
      final drafterToken = await selectCompany(drafterIdentity, company.companyId);
      final membershipsResponse =
          await http.get(baseUrl.resolve('/memberships'), headers: {'authorization': 'Bearer ${company.token}'});
      final drafterMembershipId = ((jsonDecode(membershipsResponse.body) as Map<String, Object?>)['memberships']
              as List)
          .firstWhere((m) => (m as Map<String, Object?>)['email'] == 'drafter@example.com')['id'] as String;

      // Projektleiter hat kein Zahlungsrecht; ohne Override: verweigert.
      final before = await http.get(
        baseUrl.resolve('/permissions/effective?permission=invoices.payment'),
        headers: {'authorization': 'Bearer $drafterToken'},
      );
      expect((jsonDecode(before.body) as Map<String, Object?>)['granted'], isFalse);

      // Admin gewährt eine individuelle Ausnahme.
      final overrideResponse = await http.put(
        baseUrl.resolve('/memberships/$drafterMembershipId/overrides/invoices.payment'),
        headers: {'authorization': 'Bearer ${company.token}'},
        body: jsonEncode({'allowed': true}),
      );
      expect(overrideResponse.statusCode, 200);

      final after = await http.get(
        baseUrl.resolve('/permissions/effective?permission=invoices.payment'),
        headers: {'authorization': 'Bearer $drafterToken'},
      );
      expect((jsonDecode(after.body) as Map<String, Object?>)['granted'], isTrue);

      // Override wieder entfernen -> zurück auf Gruppenvorgabe (weiterhin verweigert).
      final removeResponse = await http.delete(
        baseUrl.resolve('/memberships/$drafterMembershipId/overrides/invoices.payment'),
        headers: {'authorization': 'Bearer ${company.token}'},
      );
      expect(removeResponse.statusCode, 204);
      final afterRemoval = await http.get(
        baseUrl.resolve('/permissions/effective?permission=invoices.payment'),
        headers: {'authorization': 'Bearer $drafterToken'},
      );
      expect((jsonDecode(afterRemoval.body) as Map<String, Object?>)['granted'], isFalse);
    },
  );

  test(
    'Deaktivierte Firmenfunktion bleibt vorrangig — auch ein Override ändert daran nichts',
    () async {
      final company = await setUpCompanyWithAdmin('admin@example.com', 'Firma A');
      final groupsResponse =
          await http.get(baseUrl.resolve('/groups'), headers: {'authorization': 'Bearer ${company.token}'});
      final groupId = ((jsonDecode(groupsResponse.body) as Map<String, Object?>)['groups'] as List).first['id']
          as String;
      await http.put(
        baseUrl.resolve('/groups/$groupId/permissions/projects.read'),
        headers: {'authorization': 'Bearer ${company.token}'},
        body: jsonEncode({'granted': true}),
      );

      // Modul "projects" ist auf dieser Firma nicht aktiviert (Default
      // leere Modulmenge) -> trotz Gruppenrecht verweigert.
      final response = await http.get(
        baseUrl.resolve('/permissions/effective?permission=projects.read&module=projects'),
        headers: {'authorization': 'Bearer ${company.token}'},
      );
      expect((jsonDecode(response.body) as Map<String, Object?>)['granted'], isFalse);
    },
  );

  test('Den letzten aktiven Admin einer Firma kann niemand deaktivieren', () async {
    final company = await setUpCompanyWithAdmin('admin@example.com', 'Firma A');
    final membershipsResponse =
        await http.get(baseUrl.resolve('/memberships'), headers: {'authorization': 'Bearer ${company.token}'});
    final adminMembershipId =
        ((jsonDecode(membershipsResponse.body) as Map<String, Object?>)['memberships'] as List).first['id']
            as String;

    final response = await http.patch(
      baseUrl.resolve('/memberships/$adminMembershipId'),
      headers: {'authorization': 'Bearer ${company.token}'},
      body: jsonEncode({'active': false}),
    );
    expect(response.statusCode, 409);
  });

  test(
    'Ein zum Admin befördertes zweites Mitglied kann den Erst-Admin deaktivieren (nicht mehr '
    '"letzter"); ihn selbst wieder zum Nicht-Admin zu machen wäre dann erneut blockiert',
    () async {
      final company = await setUpCompanyWithAdmin('admin@example.com', 'Firma A');
      await register('admin2@example.com', 'passwort-12345');
      final groupsResponse =
          await http.get(baseUrl.resolve('/groups'), headers: {'authorization': 'Bearer ${company.token}'});
      final groupId = ((jsonDecode(groupsResponse.body) as Map<String, Object?>)['groups'] as List).first['id']
          as String;
      final addResponse = await http.post(
        baseUrl.resolve('/memberships'),
        headers: {'authorization': 'Bearer ${company.token}'},
        body: jsonEncode({'email': 'admin2@example.com', 'groupId': groupId}),
      );
      final secondMembershipId = (jsonDecode(addResponse.body) as Map<String, Object?>)['id'] as String;

      // Zum echten zweiten Admin befördern.
      final promoteResponse = await http.patch(
        baseUrl.resolve('/memberships/$secondMembershipId'),
        headers: {'authorization': 'Bearer ${company.token}'},
        body: jsonEncode({'isAdmin': true}),
      );
      expect(promoteResponse.statusCode, 200);

      final admin2Identity = await loginIdentity('admin2@example.com', 'passwort-12345');
      final admin2Token = await selectCompany(admin2Identity, company.companyId);

      final membershipsResponse =
          await http.get(baseUrl.resolve('/memberships'), headers: {'authorization': 'Bearer ${company.token}'});
      final firstAdminId = ((jsonDecode(membershipsResponse.body) as Map<String, Object?>)['memberships'] as List)
          .firstWhere((m) => (m as Map<String, Object?>)['email'] == 'admin@example.com')['id'] as String;

      // Jetzt gibt es zwei aktive Admins -> Admin 2 kann Admin 1
      // deaktivieren.
      final deactivateFirst = await http.patch(
        baseUrl.resolve('/memberships/$firstAdminId'),
        headers: {'authorization': 'Bearer $admin2Token'},
        body: jsonEncode({'active': false}),
      );
      expect(deactivateFirst.statusCode, 200);

      // Jetzt ist Admin 2 wieder der letzte aktive Admin -> sich selbst
      // den Admin-Status zu entziehen ist blockiert.
      final selfDemote = await http.patch(
        baseUrl.resolve('/memberships/$secondMembershipId'),
        headers: {'authorization': 'Bearer $admin2Token'},
        body: jsonEncode({'isAdmin': false}),
      );
      expect(selfDemote.statusCode, 409);
    },
  );

  Future<String> firstGroupId(String token) async {
    final response = await http.get(baseUrl.resolve('/groups'), headers: {'authorization': 'Bearer $token'});
    return ((jsonDecode(response.body) as Map<String, Object?>)['groups'] as List).first['id'] as String;
  }

  test('Fehlerhaftes JSON liefert 400 statt eines Serverfehlers', () async {
    final invalid = await http.post(baseUrl.resolve('/auth/register'), body: '{kein json');
    expect(invalid.statusCode, 400);
    final wrongType = await http.post(
      baseUrl.resolve('/auth/register'),
      body: jsonEncode({'email': 42, 'password': 'passwort-12345'}),
    );
    expect(wrongType.statusCode, 400);
    final notAnObject = await http.post(baseUrl.resolve('/auth/register'), body: '[1,2]');
    expect(notAnObject.statusCode, 400);
  });

  test('Unbekannte Berechtigungs-Schlüssel werden beim Vergeben abgewiesen (Tippfehler-Schutz)', () async {
    final company = await setUpCompanyWithAdmin('admin@example.com', 'Firma A');
    final groupId = await firstGroupId(company.token);
    final typo = await http.put(
      baseUrl.resolve('/groups/$groupId/permissions/invoice.read'),
      headers: {'authorization': 'Bearer ${company.token}'},
      body: jsonEncode({'granted': true}),
    );
    expect(typo.statusCode, 400);
    final known = await http.put(
      baseUrl.resolve('/groups/$groupId/permissions/invoices.read'),
      headers: {'authorization': 'Bearer ${company.token}'},
      body: jsonEncode({'granted': true}),
    );
    expect(known.statusCode, 200);
  });

  test('Modul-Schalter: nur Admin, nur bekannte Module, Bestellwesen setzt Lagerbestand voraus; '
      'Modulrecht greift erst nach Aktivierung', () async {
    final company = await setUpCompanyWithAdmin('admin@example.com', 'Firma A');
    final auth = {'authorization': 'Bearer ${company.token}'};
    final groupId = await firstGroupId(company.token);
    // Recht der EIGENEN Gruppe des Admins geben — die Gruppenliste ist
    // nicht in Anlage-Reihenfolge sortiert (Postgres: nach Name).
    final me = jsonDecode((await http.get(baseUrl.resolve('/me'), headers: auth)).body) as Map<String, Object?>;
    await http.put(
      baseUrl.resolve('/groups/${me['groupId']}/permissions/projects.read'),
      headers: auth,
      body: jsonEncode({'granted': true}),
    );

    Future<bool> projectsGranted() async {
      final r = await http.get(baseUrl.resolve('/permissions/mine'), headers: auth);
      return ((jsonDecode(r.body) as Map<String, Object?>)['permissions'] as List).contains('projects.read');
    }

    expect(await projectsGranted(), isFalse, reason: 'Modul projects noch nicht aktiviert');

    final unknown = await http.put(baseUrl.resolve('/company/modules'), headers: auth, body: jsonEncode({
      'modules': ['projekte'],
    }));
    expect(unknown.statusCode, 400);
    final missingDependency = await http.put(baseUrl.resolve('/company/modules'), headers: auth, body: jsonEncode({
      'modules': ['bestellwesen'],
    }));
    expect(missingDependency.statusCode, 400);
    final ok = await http.put(baseUrl.resolve('/company/modules'), headers: auth, body: jsonEncode({
      'modules': ['projects', 'lagerbestand', 'bestellwesen'],
    }));
    expect(ok.statusCode, 200);
    expect(await projectsGranted(), isTrue);

    // Nicht-Admin darf Module nicht umschalten.
    await register('monteur@example.com', 'passwort-12345');
    await http.post(baseUrl.resolve('/memberships'), headers: auth, body: jsonEncode({
      'email': 'monteur@example.com',
      'groupId': groupId,
    }));
    final monteurToken = await selectCompany(await loginIdentity('monteur@example.com', 'passwort-12345'), company.companyId);
    final asMonteur = await http.put(
      baseUrl.resolve('/company/modules'),
      headers: {'authorization': 'Bearer $monteurToken'},
      body: jsonEncode({'modules': <String>[]}),
    );
    expect(asMonteur.statusCode, 403);
  });

  test('Einladung eines neuen Nutzers: einmal einlösbar, legt Konto + Mitgliedschaft in der '
      'eingeladenen Gruppe an', () async {
    final company = await setUpCompanyWithAdmin('admin@example.com', 'Firma A');
    final auth = {'authorization': 'Bearer ${company.token}'};
    final groupId = await firstGroupId(company.token);

    final invite = await http.post(baseUrl.resolve('/invitations'), headers: auth, body: jsonEncode({
      'email': 'neu@example.com',
      'groupId': groupId,
    }));
    expect(invite.statusCode, 201);
    final invitationToken = (jsonDecode(invite.body) as Map<String, Object?>)['invitationToken'] as String;

    final listed = await http.get(baseUrl.resolve('/invitations'), headers: auth);
    expect((jsonDecode(listed.body) as Map<String, Object?>)['invitations'] as List, hasLength(1));

    // Zu kurzes Passwort verbrennt die Einladung nicht.
    final tooShort = await http.post(baseUrl.resolve('/auth/accept-invitation'), body: jsonEncode({
      'invitationToken': invitationToken,
      'password': 'kurz',
    }));
    expect(tooShort.statusCode, 400);

    final accept = await http.post(baseUrl.resolve('/auth/accept-invitation'), body: jsonEncode({
      'invitationToken': invitationToken,
      'password': 'passwort-12345',
    }));
    expect(accept.statusCode, 201);

    final again = await http.post(baseUrl.resolve('/auth/accept-invitation'), body: jsonEncode({
      'invitationToken': invitationToken,
      'password': 'passwort-12345',
    }));
    expect(again.statusCode, 404, reason: 'Einladung ist nur einmal einlösbar');

    final token = await selectCompany(await loginIdentity('neu@example.com', 'passwort-12345'), company.companyId);
    final me = jsonDecode((await http.get(baseUrl.resolve('/me'), headers: {'authorization': 'Bearer $token'})).body)
        as Map<String, Object?>;
    expect(me['isAdmin'], isFalse);
    expect(me['companyName'], 'Firma A');
  });

  test('Einladung einer bereits registrierten E-Mail verlangt deren echtes Passwort', () async {
    final companyA = await setUpCompanyWithAdmin('admin-a@example.com', 'Firma A');
    await setUpCompanyWithAdmin('admin-b@example.com', 'Firma B');
    final groupId = await firstGroupId(companyA.token);
    final invite = await http.post(
      baseUrl.resolve('/invitations'),
      headers: {'authorization': 'Bearer ${companyA.token}'},
      body: jsonEncode({'email': 'admin-b@example.com', 'groupId': groupId}),
    );
    final invitationToken = (jsonDecode(invite.body) as Map<String, Object?>)['invitationToken'] as String;

    final wrongPassword = await http.post(baseUrl.resolve('/auth/accept-invitation'), body: jsonEncode({
      'invitationToken': invitationToken,
      'password': 'falsches-passwort',
    }));
    expect(wrongPassword.statusCode, 401);

    final accept = await http.post(baseUrl.resolve('/auth/accept-invitation'), body: jsonEncode({
      'invitationToken': invitationToken,
      'password': 'passwort-12345',
    }));
    expect(accept.statusCode, 201);

    final login = await http.post(
      baseUrl.resolve('/auth/login'),
      body: jsonEncode({'email': 'admin-b@example.com', 'password': 'passwort-12345'}),
    );
    final memberships = (jsonDecode(login.body) as Map<String, Object?>)['memberships'] as List;
    expect(memberships.map((m) => (m as Map<String, Object?>)['companyName']), unorderedEquals(['Firma A', 'Firma B']));
  });

  test('Einladungen: fremde Gruppe 404, Widerruf nur in der eigenen Firma, Nicht-Admin 403', () async {
    final companyA = await setUpCompanyWithAdmin('admin-a@example.com', 'Firma A');
    final companyB = await setUpCompanyWithAdmin('admin-b@example.com', 'Firma B');
    final groupB = await firstGroupId(companyB.token);

    final foreignGroup = await http.post(
      baseUrl.resolve('/invitations'),
      headers: {'authorization': 'Bearer ${companyA.token}'},
      body: jsonEncode({'email': 'x@example.com', 'groupId': groupB}),
    );
    expect(foreignGroup.statusCode, 404);

    await http.post(
      baseUrl.resolve('/invitations'),
      headers: {'authorization': 'Bearer ${companyB.token}'},
      body: jsonEncode({'email': 'y@example.com', 'groupId': groupB}),
    );
    final listB = await http.get(baseUrl.resolve('/invitations'), headers: {'authorization': 'Bearer ${companyB.token}'});
    final idB = ((jsonDecode(listB.body) as Map<String, Object?>)['invitations'] as List).single['id'] as String;

    final crossRevoke = await http.delete(
      baseUrl.resolve('/invitations/$idB'),
      headers: {'authorization': 'Bearer ${companyA.token}'},
    );
    expect(crossRevoke.statusCode, 404);

    final ownRevoke = await http.delete(
      baseUrl.resolve('/invitations/$idB'),
      headers: {'authorization': 'Bearer ${companyB.token}'},
    );
    expect(ownRevoke.statusCode, 204);
  });

  test('Deaktivierte Mitgliedschaft: bestehende Sitzung verliert sofort jeden Zugriff', () async {
    final company = await setUpCompanyWithAdmin('admin@example.com', 'Firma A');
    final auth = {'authorization': 'Bearer ${company.token}'};
    await register('monteur@example.com', 'passwort-12345');
    final add = await http.post(baseUrl.resolve('/memberships'), headers: auth, body: jsonEncode({
      'email': 'monteur@example.com',
      'groupId': await firstGroupId(company.token),
    }));
    final membershipId = (jsonDecode(add.body) as Map<String, Object?>)['id'] as String;
    final monteurToken = await selectCompany(await loginIdentity('monteur@example.com', 'passwort-12345'), company.companyId);
    expect((await http.get(baseUrl.resolve('/me'), headers: {'authorization': 'Bearer $monteurToken'})).statusCode, 200);

    await http.patch(baseUrl.resolve('/memberships/$membershipId'), headers: auth, body: jsonEncode({'active': false}));
    expect((await http.get(baseUrl.resolve('/me'), headers: {'authorization': 'Bearer $monteurToken'})).statusCode, 401);
  });
}
