import 'package:test/test.dart';
import 'package:werkkern_core/werkkern_core.dart';
import 'package:werkkernerp_server/src/business/company_import.dart';
import 'package:werkkernerp_server/src/business/models.dart';

import 'support/migration_fixture.dart';
import 'support/module_harness.dart';

void main() => runCompanyImportTests(inMemoryRepositories);

/// B4 Umzug Einzelplatz → Online-Firma (`POST /company/import`).
void runCompanyImportTests(RepositoryFactory create, {bool transactional = false}) {
  final h = ModuleHarness(create)..install();
  const permissions = [
    'customers.read',
    'customers.write',
    'invoices.read',
    'invoices.write',
    'invoices.finalize',
    'projects.read',
    'projects.write',
    'timeTracking.read',
    'timeTracking.write',
  ];
  final year = DateTime.now().toUtc().year;
  final yy = (year % 100).toString().padLeft(2, '0');

  Future<Map<String, Object?>> dryRun(CompanyClient company, Map<String, Object?> body) async =>
      await company.client.request('POST', '/company/import', query: {'dryRun': '1'}, body: body)
          as Map<String, Object?>;

  Future<String> membershipOf(CompanyClient company, String email) async =>
      (await company.client.members()).firstWhere((m) => m.email == email).id;

  test('Probelauf zählt, nennt offene Rollen-Zuordnungen und schreibt nichts', () async {
    final chef = await h.company('chef@example.com', permissions: permissions, modules: const {'timeTracking'});
    final result = await dryRun(chef, {'package': sampleMigrationPackage()});
    expect(result['dryRun'], true);
    expect(result['errors'], isEmpty);
    final counts = result['counts']! as Map<String, Object?>;
    expect(counts['documents'], 3);
    expect(counts['timeEntries'], 2);
    expect(counts['staffRoles'], 2);
    expect(
      result['roles'],
      containsAll([
        {'id': 'r1', 'name': 'Monteur', 'timeEntries': 1},
        {'id': migrationNoRoleKey, 'name': 'Ohne Rolle', 'timeEntries': 1},
      ]),
    );
    expect(result['missingAssignments'], unorderedEquals(['r1', migrationNoRoleKey]));
    expect(result['warnings'], contains(contains('SMTP')));
    expect(await h.business.companyHasBusinessData(chef.companyId), isFalse);
    expect((await chef.get('/customers'))['customers'], isEmpty);
  });

  test('Umzug übernimmt alles unverändert; Nummernkreise laufen weiter; nur einmal', () async {
    final chef = await h.company('chef@example.com', permissions: permissions, modules: const {'timeTracking'});
    await h.member(chef, 'monteur@example.com');
    // Vorschlags-Rollen (vom ersten Öffnen) werden ersetzt, nicht verdoppelt.
    expect(((await chef.get('/staff-roles', query: const {'seed': '1'}))['staffRoles'] as List), hasLength(3));
    final monteur = await membershipOf(chef, 'monteur@example.com');
    final admin = await membershipOf(chef, 'chef@example.com');

    final result = await chef.post('/company/import', {
      'package': sampleMigrationPackage(),
      'roleAssignments': {'r1': monteur, migrationNoRoleKey: admin},
    });
    expect(result['dryRun'], false);

    final export = await chef.get('/company/export');
    final documents = (export['documents']! as List).cast<Map<String, Object?>>();
    final invoice = documents.firstWhere((d) => d['number'] == 'R-${yy}003');
    final order = documents.firstWhere((d) => d['number'] == 'A-${yy}001');
    expect(invoice['status'], 'finalized');
    expect(invoice['paymentStatus'], 'paid');
    expect(invoice['dueDate'], '$year-02-03');
    expect(invoice['convertedFromId'], order['id']);
    expect(invoice['customerSnapshot'], {'name': 'Meyer', 'address': 'Weg 2', 'vatId': null});
    expect((invoice['companySnapshot']! as Map)['iban'], 'DE02120300000000202051');
    expect((invoice['textSnapshot']! as Map)['intro'], 'Wir berechnen:');
    expect(invoice['stockBooked'], true);
    expect((invoice['items']! as List).map((i) => (i as Map)['quantity']), ['2.5', '2']);
    expect(((invoice['items']! as List).last as Map)['groupLabel'], 'Arbeit');
    expect(documents.where((d) => d['status'] == 'draft'), hasLength(1));

    final projects = (export['projects']! as List).cast<Map<String, Object?>>();
    expect(projects.map((p) => p['displayNumber']), unorderedEquals(['$yy/01', '$yy/02']));
    expect(invoice['projectId'], projects.firstWhere((p) => p['name'] == 'Neubau')['id']);

    final articles = (export['articles']! as List).cast<Map<String, Object?>>();
    expect(articles.firstWhere((a) => a['name'] == 'NYM 3x1,5')['stockQuantity'], '7.5');
    expect(articles.firstWhere((a) => a['name'] == 'Alte Dose')['active'], false);
    expect(export['articlePrices'], hasLength(1));
    expect(export['stockMovements'], hasLength(2));
    expect(((export['inventoryCounts']! as List).single as Map)['status'], 'completed');
    final po = (export['purchaseOrders']! as List).single as Map<String, Object?>;
    expect(po['number'], 'B-${yy}001');
    expect(po['sourceOrderId'], order['id']);
    expect(((po['items']! as List).single as Map)['receivedQuantity'], '10');
    expect(((export['bankTransactions']! as List).single as Map)['matchedDocumentId'], invoice['id']);
    expect(export['expenses'], hasLength(1));
    expect(export['vehicleCosts'], hasLength(1));
    expect(((export['recurringTemplates']! as List).single as Map)['items'], hasLength(1));

    final roles = (export['staffRoles']! as List).cast<Map<String, Object?>>();
    expect(roles.map((r) => r['name']), unorderedEquals(['Monteur', 'Meister']));
    // C3.4 (Umzugsformat 2): Verrechnungssatz und Rolle an der Position.
    final monteurRole = roles.firstWhere((r) => r['name'] == 'Monteur');
    expect(monteurRole['hourlyBillingCents'], 6800);
    expect(roles.firstWhere((r) => r['name'] == 'Meister')['hourlyBillingCents'], 0);
    expect(((order['items']! as List).single as Map)['staffRoleId'], monteurRole['id']);
    final monteurUser = (await h.repository.findUserByEmail('monteur@example.com'))!.id;
    final chefUser = (await h.repository.findUserByEmail('chef@example.com'))!.id;
    final entries = (export['timeEntries']! as List).cast<Map<String, Object?>>();
    final withRole = entries.firstWhere((e) => e['staffRoleId'] != null);
    expect(withRole['userId'], monteurUser);
    expect(withRole['hourlyCostCents'], 4500, reason: 'Satz der Rolle eingefroren');
    expect(withRole['documentId'], order['id']);
    final withoutRole = entries.firstWhere((e) => e['staffRoleId'] == null);
    expect(withoutRole['userId'], chefUser);
    expect(withoutRole['hourlyCostCents'], isNull);
    final sheet = (export['timeSheets']! as List).single as Map<String, Object?>;
    expect(sheet['status'], 'signed');
    expect(sheet['signaturePng'], migrationSignaturePng);
    expect(sheet['entryIds'], [withRole['id']]);

    final company = export['company']! as Map<String, Object?>;
    expect(company['iban'], 'DE02120300000000202051');
    expect(company['footerText'], 'Danke für Ihren Auftrag.');
    expect((company['documentTexts']! as Map)['invoice'], {'intro': 'Wir berechnen:', 'closing': 'Zahlbar sofort.'});
    expect(company['modules'], containsAll(['orders', 'projects', 'timeTracking', 'lagerbestand']));
    expect(company['modules'], isNot(contains('smtp')));
    final settings = export['settings']! as Map<String, Object?>;
    expect((settings['dunning']! as Map)['feeLevel1Cents'], 500);
    expect((settings['datev']! as Map)['beraterNummer'], '1234');

    // Nahtlos weiter: nächste Rechnung R-JJ004, nächstes Projekt JJ/03.
    final customerId = invoice['customerId'];
    final draft = await chef.post('/documents', {
      'kind': 'invoice',
      'customerId': customerId,
      'items': [
        {'kind': 'text', 'description': 'Nachtrag', 'quantity': '1', 'unitPriceCents': 100, 'vatRatePercent': 19},
      ],
    });
    final finalized = await chef.post('/documents/${draft['id']}/finalize', {'version': draft['version']});
    expect(finalized['number'], 'R-${yy}004');
    final project = await chef.post('/projects', {'name': 'Nach dem Umzug'});
    expect(project['displayNumber'], '$yy/03');

    // Nur einmal, nur in eine leere Firma.
    await expectLater(
      chef.post('/company/import', {
        'package': sampleMigrationPackage(),
        'roleAssignments': {'r1': monteur, '-': admin},
      }),
      throwsStatus(409),
    );
  });

  test('Ablehnung: Firma mit Daten, kein Admin, fehlende/fremde Zuordnung, kaputtes Paket', () async {
    final chef = await h.company('chef@example.com', permissions: permissions, modules: const {'timeTracking'});
    final monteurClient = await h.member(chef, 'monteur@example.com');
    final admin = await membershipOf(chef, 'chef@example.com');
    final all = {'r1': admin, migrationNoRoleKey: admin};

    await expectLater(
      CompanyClient(
        monteurClient,
        chef.companyId,
        '',
        const {},
      ).post('/company/import', {'package': sampleMigrationPackage(), 'roleAssignments': all}),
      throwsStatus(403),
    );
    await expectLater(
      chef.post('/company/import', {
        'package': sampleMigrationPackage(),
        'roleAssignments': {'r1': admin},
      }),
      throwsStatus(422),
      reason: 'Buchungen ohne Rolle brauchen ebenfalls ein Mitglied',
    );
    await expectLater(
      chef.post('/company/import', {
        'package': sampleMigrationPackage(),
        'roleAssignments': {'r1': 'fremd', '-': admin},
      }),
      throwsStatus(422),
    );

    final broken = sampleMigrationPackage();
    ((broken['documents']! as List).first as Map<String, Object?>)['customerId'] = 'gibt-es-nicht';
    final dry = await dryRun(chef, {'package': broken, 'roleAssignments': all});
    expect(dry['errors'], [contains('gibt-es-nicht')]);
    await expectLater(chef.post('/company/import', {'package': broken, 'roleAssignments': all}), throwsStatus(422));

    final duplicate = sampleMigrationPackage();
    ((duplicate['documents']! as List)[1] as Map<String, Object?>)['number'] = 'R-${yy}003';
    await expectLater(chef.post('/company/import', {'package': duplicate, 'roleAssignments': all}), throwsStatus(422));

    await expectLater(
      chef.post('/company/import', {
        'package': {...sampleMigrationPackage(), 'formatVersion': 99},
        'roleAssignments': all,
      }),
      throwsStatus(422),
    );
    // Umzugsformat 1 (App vor C3.4) wird weiter angenommen.
    final v1 = await dryRun(chef, {'package': {...sampleMigrationPackage(), 'formatVersion': 1}, 'roleAssignments': all});
    expect(v1['errors'], isEmpty);
    await expectLater(chef.post('/company/import', {'roleAssignments': all}), throwsStatus(400));
    expect(await h.business.companyHasBusinessData(chef.companyId), isFalse, reason: 'nichts halb geschrieben');

    await chef.post('/customers', {'name': 'Schon da'});
    await expectLater(
      chef.post('/company/import', {'package': sampleMigrationPackage(), 'roleAssignments': all}),
      throwsStatus(409),
    );
  });

  if (transactional) {
    test('Scheitert eine Zeile in der Datenbank, bleibt die Firma leer (eine Transaktion)', () async {
      final chef = await h.company('chef@example.com', permissions: permissions, modules: const {'timeTracking'});
      final chefUser = (await h.repository.findUserByEmail('chef@example.com'))!.id;
      final parsed = parseCompanyImport(
        sampleMigrationPackage(),
        companyId: chef.companyId,
        userId: chefUser,
        roleAssignments: {'r1': chefUser, migrationNoRoleKey: chefUser},
        memberUserIds: {chefUser},
        newId: () => 'id-${_counter++}',
        now: DateTime.now().toUtc(),
      );
      expect(parsed.errors, isEmpty);
      // Kaputter Verweis, den erst die Datenbank bemerkt (Fremdschlüssel).
      parsed.data.documentItems.add(
        const DocumentItem(
          id: 'kaputt',
          documentId: 'gibt-es-nicht',
          kind: 'text',
          description: 'x',
          quantity: '1',
          unitPriceCents: 1,
          vatRatePercent: 19,
          sortOrder: 0,
        ),
      );
      await expectLater(h.business.importCompanyData(chef.companyId, parsed.data), throwsA(anything));
      expect(await h.business.companyHasBusinessData(chef.companyId), isFalse);
    });
  }
}

var _counter = 0;
