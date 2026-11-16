import 'package:test/test.dart';
import 'package:werkkern_client/werkkern_client.dart';

import 'support/module_harness.dart';

void main() => runPaymentTermTests(inMemoryRepositories);

/// A2-Nachtrag (Kay, 15./16.11.2026): Zahlungsbedingungen und Skonto online.
void runPaymentTermTests(RepositoryFactory create) {
  final h = ModuleHarness(create)..install();
  const permissions = ['customers.read', 'customers.write', 'invoices.read', 'invoices.write', 'invoices.finalize'];
  Matcher status(int code) => throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', code));

  test('Vorgaben, Firmen- vor Kundenstandard, manuelle Wahl, Skonto, Umwandlung, Fälligkeit, Schnappschuss', () async {
    final c = await h.company('pt1@example.com', permissions: permissions, modules: {'orders', 'quotes'});
    final terms = await c.client.paymentTerms();
    expect([for (final t in terms) (t.label, t.netDays, t.isDefault)], [
      ('Sofort netto', 0, false),
      ('7 Tage', 7, false),
      ('14 Tage', 14, true),
      ('30 Tage', 30, false),
    ]);
    await c.put('/company/profile', {'skontoPercent': 2, 'skontoDays': 7});
    final plain = await c.post('/customers', {'name': 'Ohne Abweichung'});
    final own = await c.post('/customers', {
      'name': 'Eigener Standard',
      'paymentTermId': terms.last.id,
      'skontoMode': 'custom',
      'skontoPercent': 3,
      'skontoDays': 10,
    });
    final none = await c.post('/customers', {'name': 'Ohne Skonto', 'skontoMode': 'none'});

    Future<Map<String, Object?>> doc(Map<String, Object?> customer, {String kind = 'invoice', Map<String, Object?>? extra}) =>
        c.post('/documents', {
          'kind': kind,
          'customerId': customer['id'],
          'issueDate': '2026-11-16',
          'items': [
            {'kind': 'text', 'description': 'Montage', 'quantity': '1', 'unitPriceCents': 10000, 'vatRatePercent': 19},
          ],
          ...?extra,
        });

    final a = await doc(plain);
    expect(a['paymentTerm'], {'termId': terms[2].id, 'label': '14 Tage', 'netDays': 14, 'skontoPercent': 2.0, 'skontoDays': 7});
    expect(a['dueDate'], '2026-11-30');
    final b = await doc(own);
    expect((b['paymentTerm'] as Map)['label'], '30 Tage');
    expect((b['paymentTerm'] as Map)['skontoPercent'], 3.0);
    expect((await doc(none))['paymentTerm'], containsPair('skontoPercent', null));
    final manual = await doc(plain, extra: {
      'paymentTerm': {'termId': terms.first.id, 'label': 'Sofort netto', 'netDays': 0},
    });
    expect((manual['paymentTerm'] as Map)['label'], 'Sofort netto');
    expect((await doc(plain, kind: 'quote', extra: {}))['paymentTerm'], isNull, reason: 'Angebot ohne Vorbelegung');
    await expectLater(doc(plain, extra: {'paymentTerm': {'label': 'x'}}), status(400));

    // Ändern und entfernen.
    final changed = await c.put('/documents/${a['id']}', {
      'version': a['version'],
      'items': [{'kind': 'text', 'description': 'Montage', 'quantity': '1', 'unitPriceCents': 10000, 'vatRatePercent': 19}],
      'paymentTerm': {'termId': terms[1].id, 'label': '7 Tage', 'netDays': 7, 'skontoPercent': 2, 'skontoDays': 3},
    });
    expect((changed['paymentTerm'] as Map)['netDays'], 7);
    final kept = await c.put('/documents/${a['id']}', {'version': changed['version'], 'items': [{'kind': 'text', 'description': 'M', 'quantity': '1', 'unitPriceCents': 100, 'vatRatePercent': 19}]});
    expect((kept['paymentTerm'] as Map)['netDays'], 7, reason: 'nicht genannt = unverändert');

    // Finalisieren: Fälligkeit aus Belegdatum + Ziel; spätere Änderungen lassen den Beleg unverändert.
    final finalized = await c.post('/documents/${a['id']}/finalize', {'version': kept['version']});
    expect(finalized['dueDate'], '2026-11-23');
    await c.put('/payment-terms/${terms[1].id}', {'label': '10 Tage', 'netDays': 10});
    await c.put('/company/profile', {'skontoPercent': 5, 'skontoDays': 7});
    final reread = await c.get('/documents/${a['id']}');
    expect((reread['paymentTerm'] as Map)['label'], '7 Tage');

    // Auftrag → Rechnung übernimmt die Bedingung.
    final order = await doc(plain, kind: 'order');
    final finalizedOrder = await c.post('/documents/${order['id']}/finalize', {'version': order['version']});
    final invoice = await c.post('/documents/${finalizedOrder['id']}/convert', {'kind': 'invoice'});
    expect((invoice['paymentTerm'] as Map)['label'], '14 Tage');
  });

  test('Pflege nur für Admins, Standard umsetzen, letzte Bedingung bleibt, Kundenzuordnung fällt weg', () async {
    final c = await h.company('pt2@example.com', permissions: permissions);
    final terms = await c.client.paymentTerms();
    final member = await h.member(c, 'monteur-pt@example.com');
    expect(await member.paymentTerms(), hasLength(4), reason: 'Lesen darf jedes Mitglied');
    await expectLater(member.request('POST', '/payment-terms', body: {'label': 'x', 'netDays': 1}), status(403));
    final created = await c.client.savePaymentTerm(label: '60 Tage', netDays: 60);
    await c.client.setDefaultPaymentTerm(created.id);
    expect((await c.client.paymentTerms()).where((t) => t.isDefault).single.label, '60 Tage');
    final customer = await c.post('/customers', {'name': 'K', 'paymentTermId': created.id});
    await c.client.deletePaymentTerm(created.id);
    expect((await c.get('/customers/${customer['id']}'))['paymentTermId'], isNull);
    expect((await c.client.paymentTerms()).where((t) => t.isDefault), hasLength(1));
    for (final t in terms.skip(1)) {
      await c.client.deletePaymentTerm(t.id);
    }
    await expectLater(c.client.deletePaymentTerm(terms.first.id), status(409));
    await expectLater(c.put('/company/profile', {'skontoPercent': 2}), status(400));
  });
}
