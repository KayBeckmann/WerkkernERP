import 'package:test/test.dart';

import 'support/module_harness.dart';

void main() => runAccountingTests(inMemoryRepositories);

/// C14 online: Belege, offene Posten, EÜR, Bankabgleich, DATEV.
void runAccountingTests(RepositoryFactory create) {
  final h = ModuleHarness(create)..install();
  const permissions = [
    'customers.read', 'customers.write', 'invoices.read', 'invoices.write', 'invoices.finalize', 'invoices.payment',
    'accounting.read', 'accounting.write', 'projects.read', 'projects.write', 'fleet.read', 'fleet.write',
  ];
  const modules = {'buchhaltung', 'orders', 'creditNotes', 'projects', 'fleet'};

  Map<String, Object?> line(int cents, {double vat = 19}) =>
      {'kind': 'text', 'description': 'Leistung', 'quantity': '1', 'unitPriceCents': cents, 'vatRatePercent': vat};

  Future<Map<String, Object?>> finalized(CompanyClient c, String customerId, String kind, int netCents, {String? projectId}) async {
    final draft = await c.post('/documents', {'kind': kind, 'customerId': customerId, 'items': [line(netCents)], 'projectId': ?projectId});
    return c.post('/documents/${draft['id']}/finalize', {'version': draft['version']});
  }

  test('Standardkategorien, Belege mit Kategorie/Projekt, Löschen der Kategorie behält den Beleg', () async {
    final c = await h.company('a@example.com', permissions: permissions, modules: modules);
    final categories = (await c.get('/expense-categories'))['categories'] as List;
    expect(categories.map((x) => (x as Map)['label']), contains('Material/Wareneinkauf'));
    expect(categories, hasLength(7));
    final material = categories.firstWhere((x) => (x as Map)['label'] == 'Material/Wareneinkauf') as Map;
    await c.put('/expense-categories/${material['id']}', {'label': 'Material/Wareneinkauf', 'skr03Account': '3400'});

    final expense = await c.post('/expenses', {
      'date': '2026-03-05',
      'description': 'Kabel Großhandel',
      'amountGrossCents': 11900,
      'vatRatePercent': 19,
      'categoryId': material['id'],
      'supplierReference': 'RE-4711',
    });
    await expectLater(c.post('/expenses', {'date': '2026-03-05', 'description': 'x', 'amountGrossCents': -1, 'vatRatePercent': 19}), throwsStatus(400));
    await c.delete('/expense-categories/${material['id']}');
    final list = await c.get('/expenses', query: {'from': '2026-03-01', 'to': '2026-03-31'});
    expect((list['expenses'] as List).single, containsPair('categoryId', null));
    expect(list['totalGrossCents'], 11900);
    await c.put('/expenses/${expense['id']}', {'date': '2026-03-06', 'description': 'Kabel', 'amountGrossCents': 5950, 'vatRatePercent': 19});
    expect(((await c.get('/expenses'))['expenses'] as List).single, containsPair('amountGrossCents', 5950));
    expect((await c.get('/expense-categories'))['categories'] as List, hasLength(6), reason: 'kein erneutes Seeding');
  });

  test('Offene Posten nur Rechnungen; EÜR: Rechnung − Gutschrift, Auftrag nie, Belege + Fuhrpark', () async {
    final c = await h.company('a@example.com', permissions: permissions, modules: modules);
    final customer = (await c.post('/customers', {'name': 'Meyer'}))['id'] as String;
    final other = (await c.post('/customers', {'name': 'Schulz'}))['id'] as String;
    await finalized(c, customer, 'order', 100000);
    final invoice = await finalized(c, customer, 'invoice', 10000); // 119 €
    await finalized(c, other, 'invoice', 50000); // 595 €
    final paid = await finalized(c, customer, 'invoice', 1000);
    await c.post('/documents/${paid['id']}/payment', {'paid': true});
    final credit = await c.post('/documents/${invoice['id']}/credit-note');
    await c.put('/documents/${credit['id']}', {'version': credit['version'], 'items': [line(2000)]});
    final reloaded = await c.get('/documents/${credit['id']}');
    await c.post('/documents/${credit['id']}/finalize', {'version': reloaded['version']});

    final open = await c.get('/accounting/open-items');
    final groups = (open['customers'] as List).cast<Map<String, Object?>>();
    expect(groups.map((g) => g['customerName']), ['Schulz', 'Meyer'], reason: 'größte Summe zuerst');
    expect(groups[1]['totalCents'], 11900, reason: 'Auftrag/Gutschrift/bezahlte Rechnung sind keine offenen Posten');
    expect(open['totalCents'], 59500 + 11900);

    await c.post('/expenses', {'date': dateToday(), 'description': 'Material', 'amountGrossCents': 5000, 'vatRatePercent': 19});
    final van = await c.post('/vehicles', {'name': 'Caddy'});
    await c.post('/vehicle-costs', {'vehicleId': van['id'], 'date': dateToday(), 'amountCents': 3000, 'category': 'fuel'});
    final year = DateTime.now().year;
    final euer = await c.get('/accounting/euer', query: {'from': '$year-01-01', 'to': '$year-12-31'});
    expect(euer['incomeCents'], 11900 + 59500 + 1190 - 2380, reason: 'Rechnungen − Gutschrift, Auftrag zählt nicht');
    expect(euer['expensesCents'], 8000);
    expect((euer['expensesByCategory'] as List).map((l) => (l as Map)['label']), ['Ohne Kategorie', 'Fuhrpark (Gemeinkosten)']);
    expect(euer['surplusCents'], 11900 + 59500 + 1190 - 2380 - 8000);
    await expectLater(c.get('/accounting/euer'), throwsStatus(400));
  });

  test('Projektergebnis: Erlöse − Gutschriften − Stunden − Belege', () async {
    final c = await h.company('a@example.com', permissions: [...permissions, 'timeTracking.read'], modules: modules);
    final customer = (await c.post('/customers', {'name': 'Meyer'}))['id'] as String;
    final project = await c.post('/projects', {'name': 'Neubau'});
    final invoice = await finalized(c, customer, 'invoice', 100000, projectId: project['id'] as String);
    final credit = await c.post('/documents/${invoice['id']}/credit-note');
    await c.put('/documents/${credit['id']}', {'version': credit['version'], 'items': [line(10000)]});
    final reloaded = await c.get('/documents/${credit['id']}');
    expect(reloaded['projectId'], project['id'], reason: 'Gutschrift erbt das Projekt');
    await c.post('/documents/${credit['id']}/finalize', {'version': reloaded['version']});
    await c.post('/expenses', {
      'date': dateToday(),
      'description': 'Material Neubau',
      'amountGrossCents': 20000,
      'vatRatePercent': 19,
      'projectId': project['id'],
    });
    final result = (await c.get('/projects/${project['id']}'))['result'] as Map;
    expect(result['invoiceGrossCents'], 119000 - 11900);
    expect(result['expenseCostCents'], 20000);
    expect(result['resultCents'], 119000 - 11900 - 20000);
  });

  test('Bankimport mit Duplikaterkennung, Zuordnung + Zahlungseingang, nur Rechnungen', () async {
    final c = await h.company('a@example.com', permissions: permissions, modules: modules);
    final customer = (await c.post('/customers', {'name': 'Meyer'}))['id'] as String;
    final invoice = await finalized(c, customer, 'invoice', 10000);
    final order = await finalized(c, customer, 'order', 10000);
    final rows = [
      {'date': '2026-04-01', 'amountCents': 11900, 'purpose': 'Rechnung ${invoice['number']}', 'counterparty': 'Meyer'},
      {'date': '2026-04-02', 'amountCents': -5000, 'purpose': 'Miete'},
    ];
    expect(await c.post('/bank-transactions/import', {'transactions': rows}), {'imported': 2, 'skippedDuplicates': 0});
    expect(await c.post('/bank-transactions/import', {'transactions': rows}), {'imported': 0, 'skippedDuplicates': 2});
    final transactions = ((await c.get('/bank-transactions', query: {'unmatched': 'true'}))['transactions'] as List).cast<Map>();
    final incoming = transactions.firstWhere((t) => t['amountCents'] == 11900);

    await expectLater(c.put('/bank-transactions/${incoming['id']}/match', {'documentId': order['id']}), throwsStatus(409));
    await c.put('/bank-transactions/${incoming['id']}/match', {'documentId': invoice['id'], 'markPaid': true});
    expect((await c.get('/documents/${invoice['id']}'))['paymentStatus'], 'paid');
    expect((await c.get('/bank-transactions', query: {'unmatched': 'true'}))['transactions'] as List, hasLength(1));
    await c.put('/bank-transactions/${incoming['id']}/match', {'documentId': null});
    expect((await c.get('/bank-transactions', query: {'unmatched': 'true'}))['transactions'] as List, hasLength(2));

    final noPayment = await h.company('b@example.com', permissions: ['accounting.read', 'accounting.write', 'customers.read', 'customers.write', 'invoices.read', 'invoices.write', 'invoices.finalize'], modules: modules);
    final bCustomer = (await noPayment.post('/customers', {'name': 'X'}))['id'] as String;
    final bInvoice = await finalized(noPayment, bCustomer, 'invoice', 100);
    await noPayment.post('/bank-transactions/import', {'transactions': [{'date': '2026-04-01', 'amountCents': 119}]});
    final bTx = ((await noPayment.get('/bank-transactions'))['transactions'] as List).single as Map;
    await expectLater(
      noPayment.put('/bank-transactions/${bTx['id']}/match', {'documentId': bInvoice['id'], 'markPaid': true}),
      throwsStatus(403),
    );
    await expectLater(c.put('/bank-transactions/${bTx['id']}/match', {'documentId': invoice['id']}), throwsStatus(404));
    await expectLater(c.put('/bank-transactions/${incoming['id']}/match', {'documentId': bInvoice['id']}), throwsStatus(404));
  });

  test('Einstellungen und DATEV: unvollständig 409, Beleg ohne Konto übersprungen', () async {
    final c = await h.company('a@example.com', permissions: permissions, modules: modules);
    await expectLater(c.get('/accounting/datev', query: {'from': '2026-01-01', 'to': '2026-12-31'}), throwsStatus(409));
    await expectLater(c.put('/accounting/settings', {'datev': {'geheim': '1'}}), throwsStatus(400));
    await expectLater(c.put('/accounting/settings', {'datev': {'sachkontenlaenge': 12}}), throwsStatus(400));
    final settings = await c.put('/accounting/settings', {
      'datev': {'beraterNummer': '1234567', 'mandantNummer': '10001', 'bankGegenkonto': '1200'},
      'bankCsv': {'dateColumn': 'Buchungstag', 'amountColumn': 'Betrag'},
    });
    expect((settings['datev'] as Map)['sachkontenlaenge'], 4);
    expect((settings['bankCsv'] as Map)['delimiter'], ';');

    final category = await c.post('/expense-categories', {'label': 'Material', 'skr03Account': '3400'});
    await c.post('/expenses', {'date': '2026-02-03', 'description': 'Kabel; NYM', 'amountGrossCents': 11900, 'vatRatePercent': 19, 'categoryId': category['id']});
    await c.post('/expenses', {'date': '2026-02-04', 'description': 'Ohne Konto', 'amountGrossCents': 100, 'vatRatePercent': 19});
    final export = await c.get('/accounting/datev', query: {'from': '2026-01-01', 'to': '2026-12-31'});
    expect(export['exportedCount'], 1);
    expect((export['skipped'] as List).single, containsPair('description', 'Ohne Konto'));
    final csvLines = (export['csv'] as String).split('\r\n');
    expect(csvLines.first, startsWith('EXTF;700;21;Buchungsstapel;13;'));
    expect(csvLines[2], startsWith('119,00;S;EUR;;;;3400;1200;;0302;;;;"Kabel; NYM"'));
    expect(csvLines[2].split(';').length, greaterThanOrEqualTo(125));
  });

  test('Modul, Rechte und Firmentrennung', () async {
    final a = await h.company('a@example.com', permissions: permissions, modules: modules);
    final b = await h.company('b@example.com', permissions: permissions, modules: modules);
    final expense = await a.post('/expenses', {'date': '2026-01-01', 'description': 'A', 'amountGrossCents': 1, 'vatRatePercent': 0});
    await expectLater(b.put('/expenses/${expense['id']}', {'date': '2026-01-01', 'description': 'B', 'amountGrossCents': 1, 'vatRatePercent': 0}), throwsStatus(404));
    await expectLater(b.delete('/expenses/${expense['id']}'), throwsStatus(404));
    expect((await b.get('/expenses'))['expenses'], isEmpty);
    final aCategory = ((await a.get('/expense-categories'))['categories'] as List).first as Map;
    await expectLater(b.post('/expenses', {'date': '2026-01-01', 'description': 'B', 'amountGrossCents': 1, 'vatRatePercent': 0, 'categoryId': aCategory['id']}), throwsStatus(404));

    final reader = await h.company('r@example.com', permissions: ['accounting.read'], modules: modules);
    expect((await reader.get('/expense-categories'))['categories'], isEmpty, reason: 'ohne Schreibrecht kein Seeding');
    await expectLater(reader.post('/expenses', {'date': '2026-01-01', 'description': 'x', 'amountGrossCents': 1, 'vatRatePercent': 0}), throwsStatus(403));
    await a.client.setModules({});
    await expectLater(a.get('/expenses'), throwsStatus(403));
  });
}

String dateToday() {
  final d = DateTime.now();
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
