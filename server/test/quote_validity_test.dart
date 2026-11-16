import 'package:test/test.dart';
import 'package:werkkern_client/werkkern_client.dart';

import 'support/module_harness.dart';

void main() => runQuoteValidityTests(inMemoryRepositories);

/// A5-Nachtrag (Kay, 16.11.2026) online: Angebotsbindefrist wie offline.
void runQuoteValidityTests(RepositoryFactory create) {
  final h = ModuleHarness(create)..install();
  const permissions = ['customers.read', 'customers.write', 'invoices.read', 'invoices.write', 'invoices.finalize'];
  Matcher status(int code) => throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', code));
  const items = [
    {'kind': 'text', 'description': 'Montage', 'quantity': '1', 'unitPriceCents': 10000, 'vatRatePercent': 19},
  ];
  String day(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  test('Standard 14, Entwurf änderbar, Frist ab Finalisierung, Anpassung nur ausdrücklich', () async {
    final c = await h.company('quote@example.com', permissions: permissions, modules: const {'quotes', 'orders'});
    final customer = (await c.post('/customers', {'name': 'REMONDIS'}))['id'] as String;
    Future<Map<String, Object?>> quote([Map<String, Object?> extra = const {}]) => c.post('/documents', {
      'kind': 'quote',
      'customerId': customer,
      'issueDate': '2026-11-01',
      'items': items,
      ...extra,
    });

    final standard = await quote();
    expect(standard['quoteValidityDays'], 14);
    expect((await quote({'quoteValidityDays': 30}))['quoteValidityDays'], 30);
    await expectLater(quote({'quoteValidityDays': -1}), status(400));
    final order = await c.post('/documents', {'kind': 'order', 'customerId': customer, 'items': const []});
    expect(order['quoteValidityDays'], isNull);

    final edited = await c.put('/documents/${standard['id']}', {
      'items': items,
      'version': standard['version'],
      'quoteValidityDays': 21,
    });
    expect((edited['quoteValidityDays'], edited['quoteValidUntil']), (21, null));
    await expectLater(
      c.put('/documents/${standard['id']}', {
        'items': items,
        'version': edited['version'],
        'quoteValidUntil': '2026-12-01',
      }),
      status(400),
    );
    final finalized = await c.post('/documents/${standard['id']}/finalize', {'version': edited['version']});
    final now = DateTime.now().toUtc();
    final today = DateTime.utc(now.year, now.month, now.day);
    expect(finalized['quoteValidFrom'], day(today), reason: 'ab Finalisierung, nicht ab Belegdatum');
    expect(finalized['quoteValidUntil'], day(today.add(const Duration(days: 21))));

    // Firmenstandard ändern wirkt nicht zurück; ältere Clients ohne Feld lassen ihn.
    final profile = await c.get('/company/profile');
    expect(profile['quoteValidityDays'], 14);
    await c.put('/company/profile', {...profile, 'quoteValidityDays': 60});
    final withoutField = Map<String, Object?>.of(await c.get('/company/profile'))..remove('quoteValidityDays');
    expect((await c.put('/company/profile', withoutField))['quoteValidityDays'], 60);
    expect((await c.get('/documents/${standard['id']}'))['quoteValidUntil'], day(today.add(const Duration(days: 21))));

    // Finalisiert: ohne Feld bleibt die Frist („Nein“); Dauer-Feld ändert nichts.
    final kept = await c.put('/documents/${standard['id']}', {
      'items': items,
      'version': finalized['version'],
      'notes': 'geändert',
      'quoteValidityDays': 99,
    });
    expect((kept['quoteValidUntil'], kept['quoteValidityDays']), (finalized['quoteValidUntil'], 21));
    // „Ja“: ausdrücklich bestätigtes Enddatum.
    final later = today.add(const Duration(days: 30));
    final extended = await c.put('/documents/${standard['id']}', {
      'items': items,
      'version': kept['version'],
      'quoteValidUntil': day(later),
    });
    expect(
      (extended['quoteValidFrom'], extended['quoteValidUntil'], extended['quoteValidityDays']),
      (day(today), day(later), 30),
    );
    await expectLater(
      c.put('/documents/${standard['id']}', {
        'items': items,
        'version': extended['version'],
        'quoteValidUntil': '2000-01-01',
      }),
      status(400),
    );
    // Nach Umwandlung gesperrt.
    await c.post('/documents/${standard['id']}/convert', {'kind': 'order'});
    await expectLater(
      c.put('/documents/${standard['id']}', {
        'items': items,
        'version': extended['version'],
        'quoteValidUntil': day(later),
      }),
      throwsA(isA<ApiException>()),
    );
  });
}
