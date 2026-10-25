import 'package:test/test.dart';

import 'support/module_harness.dart';

void main() => runFleetTests(inMemoryRepositories);

/// C6 online: Fahrzeuge, Kostenbuchungen, Summen, Leasing-Aufteilung.
void runFleetTests(RepositoryFactory create) {
  final h = ModuleHarness(create)..install();
  const all = ['fleet.read', 'fleet.write', 'projects.read', 'projects.write'];

  test('Fahrzeug anlegen, Kosten buchen, Summen je Kategorie und Zeitraum, Tilgung/Zins', () async {
    final a = await h.company('a@example.com', permissions: all, modules: {'fleet', 'projects'});
    final van = await a.post('/vehicles', {'name': 'Sprinter', 'licensePlate': 'HH-EK 1', 'nextInspectionDate': '2027-03-01'});
    expect(van['nextInspectionDate'], '2027-03-01');
    final project = await a.post('/projects', {'name': 'Neubau'});
    await a.post('/vehicle-costs', {'vehicleId': van['id'], 'date': '2026-01-10', 'amountCents': 8000, 'category': 'fuel'});
    await a.post('/vehicle-costs', {
      'vehicleId': van['id'],
      'date': '2026-02-01',
      'amountCents': 45000,
      'category': 'leasing',
      'principalAmountCents': 40000,
      'interestAmountCents': 5000,
      'projectId': project['id'],
    });
    await a.post('/vehicle-costs', {'vehicleId': van['id'], 'date': '2025-12-31', 'amountCents': 1000, 'category': 'fuel'});

    final year = await a.get('/vehicle-costs', query: {'vehicleId': van['id'] as String, 'from': '2026-01-01', 'to': '2026-12-31'});
    final totals = year['totals'] as Map;
    expect(totals['totalCents'], 53000);
    expect((totals['byCategory'] as Map)['fuel'], 8000);
    expect((totals['byCategory'] as Map)['leasing'], 45000);
    expect(totals['principalCents'], 40000);
    expect(totals['interestCents'], 5000);
    expect((year['costs'] as List).map((c) => (c as Map)['date']), ['2026-02-01', '2026-01-10']);

    // Projekt-Ergebnis enthält keine Fuhrparkkosten (Gemeinkosten).
    final detail = await a.get('/projects/${project['id']}');
    expect(detail.toString(), isNot(contains('45000')));

    // Deaktivieren statt löschen, Kosten bleiben.
    await a.put('/vehicles/${van['id']}', {'name': 'Sprinter', 'active': false});
    expect((await a.get('/vehicles'))['vehicles'], isEmpty);
    expect((await a.get('/vehicles', query: {'includeInactive': 'true'}))['vehicles'] as List, hasLength(1));
    expect(((await a.get('/vehicle-costs'))['costs'] as List), hasLength(3));

    final cost = ((await a.get('/vehicle-costs'))['costs'] as List).first as Map;
    await a.delete('/vehicle-costs/${cost['id']}');
    expect(((await a.get('/vehicle-costs'))['costs'] as List), hasLength(2));
  });

  test('Validierung, Modul, Rechte und Firmentrennung', () async {
    final a = await h.company('a@example.com', permissions: all, modules: {'fleet'});
    final b = await h.company('b@example.com', permissions: all, modules: {'fleet'});
    final van = await a.post('/vehicles', {'name': 'Caddy'});
    Future<Object?> cost(Map<String, Object?> body) =>
        a.post('/vehicle-costs', {'vehicleId': van['id'], 'date': '2026-01-01', 'amountCents': 100, 'category': 'fuel', ...body});
    await expectLater(cost({'category': 'party'}), throwsStatus(400));
    await expectLater(cost({'amountCents': -1}), throwsStatus(400));
    await expectLater(cost({'date': '1.1.2026'}), throwsStatus(400));
    await expectLater(cost({'category': 'leasing', 'principalAmountCents': 90, 'interestAmountCents': 20}), throwsStatus(400));
    await expectLater(a.post('/vehicles', {'name': 'X', 'nextInspectionDate': 'bald'}), throwsStatus(400));

    await expectLater(b.get('/vehicles/${van['id']}'), throwsStatus(404));
    await expectLater(
      b.post('/vehicle-costs', {'vehicleId': van['id'], 'date': '2026-01-01', 'amountCents': 1, 'category': 'fuel'}),
      throwsStatus(404),
    );
    final costA = await cost({});
    await expectLater(b.delete('/vehicle-costs/${(costA as Map)['id']}'), throwsStatus(404));

    await a.client.setModules({});
    await expectLater(a.get('/vehicles'), throwsStatus(403));
    final reader = await h.company('r@example.com', permissions: ['fleet.read'], modules: {'fleet'});
    await expectLater(reader.post('/vehicles', {'name': 'X'}), throwsStatus(403));
  });
}
