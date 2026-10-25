import 'dart:convert';

import 'package:test/test.dart';

import 'support/module_harness.dart';

void main() => runTimeSheetTests(inMemoryRepositories);

/// 1×1-PNG (gültige Signatur am Dateianfang).
final _png = base64Encode([
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, //
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89,
]);

/// C3-Rest online: Stundenzettel, Unterschrift, Sperre, Nachtrag.
void runTimeSheetTests(RepositoryFactory create) {
  final h = ModuleHarness(create)..install();
  const chefPermissions = [
    'customers.read', 'customers.write', 'invoices.read', 'invoices.write', 'invoices.finalize',
    'timeTracking.read', 'timeTracking.write',
  ];
  const modules = {'timeTracking', 'orders'};

  test('Monteur bündelt eigene Buchungen, Kunde unterschreibt, danach gesperrt; Nachtrag statt Änderung', () async {
    final chef = await h.company('chef@example.com', permissions: chefPermissions, modules: modules);
    await chef.client.setGroupPermission(chef.groups['Monteur']!, 'timeTracking.write', granted: true);
    await chef.client.setGroupPermission(chef.groups['Monteur']!, 'invoices.read', granted: true);
    final customer = (await chef.post('/customers', {'name': 'Meyer'}))['id'] as String;
    final draft = await chef.post('/documents', {'kind': 'order', 'customerId': customer, 'items': []});
    final monteur = CompanyClient(await h.member(chef, 'monteur@example.com'), chef.companyId, '', const {});
    final mine1 = await monteur.post('/time-entries', {'date': '2026-10-20', 'hours': '3', 'documentId': draft['id']});
    final mine2 = await monteur.post('/time-entries', {'date': '2026-10-20', 'hours': '1.5', 'documentId': draft['id']});
    final chefs = await chef.post('/time-entries', {'date': '2026-10-20', 'hours': '2', 'documentId': draft['id']});

    await expectLater(
      monteur.post('/time-sheets', {'documentId': draft['id'], 'date': '2026-10-20', 'entryIds': [chefs['id']]}),
      throwsStatus(404),
      reason: 'fremde Buchung ohne Leserecht wie nicht existent',
    );
    final sheet = await monteur.post('/time-sheets', {'documentId': draft['id'], 'date': '2026-10-20', 'entryIds': [mine1['id'], mine2['id']]});
    expect(sheet['totalHours'], '4.5');
    expect(sheet['customerName'], 'Meyer');
    await expectLater(
      chef.post('/time-sheets', {'documentId': draft['id'], 'entryIds': [mine1['id']]}),
      throwsStatus(409),
      reason: 'eine Buchung liegt auf höchstens einem Zettel',
    );

    await expectLater(monteur.post('/time-sheets/${sheet['id']}/sign', {'signaturePng': base64Encode(utf8.encode('kein png'))}), throwsStatus(400));
    final signed = await monteur.post('/time-sheets/${sheet['id']}/sign', {'signaturePng': _png, 'signerName': 'Herr Meyer'});
    expect(signed['status'], 'signed');
    expect(signed['signaturePng'], _png);
    expect(signed['signerName'], 'Herr Meyer');

    await expectLater(monteur.put('/time-entries/${mine1['id']}', {'date': '2026-10-20', 'hours': '5'}), throwsStatus(409));
    await expectLater(monteur.delete('/time-entries/${mine1['id']}'), throwsStatus(409));
    await expectLater(monteur.delete('/time-sheets/${sheet['id']}/entries/${mine1['id']}'), throwsStatus(409));
    await expectLater(monteur.post('/time-sheets/${sheet['id']}/sign', {'signaturePng': _png}), throwsStatus(409));
    await expectLater(monteur.delete('/time-sheets/${sheet['id']}'), throwsStatus(409));

    final correction = await monteur.post('/time-sheets/${sheet['id']}/correction');
    expect(correction['supersedesId'], sheet['id']);
    expect(correction['entries'], isEmpty);
    final extra = await monteur.post('/time-entries', {'date': '2026-10-20', 'hours': '0.5', 'documentId': draft['id']});
    await monteur.post('/time-sheets/${correction['id']}/entries', {'entryIds': [extra['id']]});
    await expectLater(monteur.post('/time-sheets/${correction['id']}/entries', {'entryIds': [mine2['id']]}), throwsStatus(409));

    // Sichtbarkeit: Monteur nur eigene, Chef mit Leserecht alle.
    final chefSheet = await chef.post('/time-sheets', {'documentId': draft['id'], 'entryIds': [chefs['id']]});
    expect(((await monteur.get('/time-sheets'))['timeSheets'] as List), hasLength(2));
    expect(((await chef.get('/time-sheets'))['timeSheets'] as List), hasLength(3));
    await expectLater(monteur.get('/time-sheets/${chefSheet['id']}'), throwsStatus(404));
  });

  test('Leerer Zettel nicht unterschreibbar, Entwurf löschbar, Validierung und Firmentrennung', () async {
    final a = await h.company('a@example.com', permissions: chefPermissions, modules: modules);
    final b = await h.company('b@example.com', permissions: chefPermissions, modules: modules);
    final customer = (await a.post('/customers', {'name': 'Meyer'}))['id'] as String;
    final order = await a.post('/documents', {'kind': 'order', 'customerId': customer, 'items': []});
    await expectLater(a.post('/time-sheets', {}), throwsStatus(400));
    final empty = await a.post('/time-sheets', {'documentId': order['id']});
    await expectLater(a.post('/time-sheets/${empty['id']}/sign', {'signaturePng': _png}), throwsStatus(409));
    await expectLater(b.get('/time-sheets/${empty['id']}'), throwsStatus(404));
    await expectLater(b.post('/time-sheets', {'documentId': order['id']}), throwsStatus(404));
    await a.delete('/time-sheets/${empty['id']}');
    expect((await a.get('/time-sheets'))['timeSheets'], isEmpty);
    await a.client.setModules({'orders'});
    await expectLater(a.get('/time-sheets'), throwsStatus(403));
  });
}
