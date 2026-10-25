import 'package:test/test.dart';
import 'package:werkkern_core/werkkern_core.dart';
import 'package:werkkernerp_server/src/business/recurring_job.dart';

import 'support/module_harness.dart';

void main() => runRecurringTests(inMemoryRepositories);

String _date(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// C11 online: Server-Tagesjob, je fälliger Periode ein Entwurf.
void runRecurringTests(RepositoryFactory create) {
  final h = ModuleHarness(create)..install();
  const permissions = ['customers.read', 'customers.write', 'invoices.read', 'invoices.write'];
  const modules = {'recurringInvoices'};
  final today = DateTime.utc(2026, 10, 15);

  Future<({CompanyClient c, String customerId, Map<String, Object?> template})> setup(String email, {required String due, String interval = 'monthly'}) async {
    final c = await h.company(email, permissions: permissions, modules: modules);
    final customer = (await c.post('/customers', {'name': 'Hausverwaltung Meyer'}))['id'] as String;
    final template = await c.post('/recurring-templates', {
      'label': 'Wartungsvertrag',
      'customerId': customer,
      'interval': interval,
      'nextDueDate': due,
      'paymentTerms': '14 Tage netto',
      'items': [
        {'kind': 'text', 'description': 'Wartungspauschale', 'quantity': '1', 'unitPriceCents': 9900, 'vatRatePercent': 19},
      ],
    });
    return (c: c, customerId: customer, template: template);
  }

  test('Job holt jede verpasste Periode nach, rückt die Fälligkeit vor, finalisiert nie', () async {
    final s = await setup('a@example.com', due: '2026-08-15');
    expect(s.template['grossCents'], 11781);
    final created = await runRecurringInvoiceJob(repository: h.repository, business: h.business, now: today.add(const Duration(hours: 9)));
    expect(created, 3, reason: '15.08., 15.09., 15.10.');
    final docs = ((await s.c.get('/documents', query: {'kind': 'invoice'}))['documents'] as List).cast<Map<String, Object?>>();
    expect(docs, hasLength(3));
    expect(docs.every((d) => d['status'] == 'draft' && d['paymentTerms'] == '14 Tage netto' && d['issueDate'] == '2026-10-15'), isTrue);
    final template = await s.c.get('/recurring-templates/${s.template['id']}');
    expect(template['nextDueDate'], '2026-11-15');
    expect(await runRecurringInvoiceJob(repository: h.repository, business: h.business, now: today), 0, reason: 'idempotent');
    final items = (await s.c.get('/documents/${docs.first['id']}'))['items'] as List;
    expect((items.single as Map)['description'], 'Wartungspauschale');
  });

  test('Parallele Läufe erzeugen keine Periode doppelt', () async {
    final s = await setup('a@example.com', due: '2026-04-15', interval: 'quarterly');
    final results = await Future.wait([
      for (var i = 0; i < 3; i++) runRecurringInvoiceJob(repository: h.repository, business: h.business, now: today),
    ]);
    expect(results.fold<int>(0, (a, b) => a + b), 3, reason: '15.04., 15.07., 15.10.');
    expect(((await s.c.get('/documents'))['documents'] as List), hasLength(3));
    expect((await s.c.get('/recurring-templates/${s.template['id']}'))['nextDueDate'], '2027-01-15');
  });

  test('Pausiert oder Modul aus: nichts; manueller Auslöser nur für die eigene Firma', () async {
    final a = await setup('a@example.com', due: _date(DateTime.now().toUtc().subtract(const Duration(days: 1))));
    final b = await setup('b@example.com', due: _date(DateTime.now().toUtc().subtract(const Duration(days: 1))));
    await a.c.put('/recurring-templates/${a.template['id']}', {'active': false});
    expect((await a.c.post('/recurring-templates/generate'))['created'], 0);
    expect((await a.c.get('/recurring-templates'))['templates'], isEmpty);
    expect(((await a.c.get('/recurring-templates', query: {'includeInactive': 'true'}))['templates'] as List), hasLength(1));

    expect((await b.c.post('/recurring-templates/generate'))['created'], 1);
    expect(((await a.c.get('/documents'))['documents'] as List), isEmpty, reason: 'Firma A unberührt');

    await a.c.put('/recurring-templates/${a.template['id']}', {'active': true});
    await a.c.client.setModules({});
    expect(await runRecurringInvoiceJob(repository: h.repository, business: h.business, now: DateTime.now().toUtc()), 0);
  });

  test('Validierung, Positionsregeln, Firmentrennung', () async {
    final a = await setup('a@example.com', due: '2027-01-01');
    final b = await setup('b@example.com', due: '2027-01-01');
    await expectLater(a.c.post('/recurring-templates', {'label': 'X', 'customerId': a.customerId, 'interval': 'weekly', 'nextDueDate': '2027-01-01'}), throwsStatus(400));
    await expectLater(a.c.post('/recurring-templates', {'label': 'X', 'customerId': b.customerId, 'interval': 'monthly', 'nextDueDate': '2027-01-01'}), throwsStatus(404));
    await expectLater(
      a.c.post('/recurring-templates', {
        'label': 'X',
        'customerId': a.customerId,
        'interval': 'monthly',
        'nextDueDate': '2027-01-01',
        'items': [{'kind': 'text', 'description': 'x', 'quantity': '1', 'unitPriceCents': 1, 'vatRatePercent': 150}],
      }),
      throwsStatus(400),
    );
    await expectLater(b.c.get('/recurring-templates/${a.template['id']}'), throwsStatus(404));
    await expectLater(b.c.delete('/recurring-templates/${a.template['id']}'), throwsStatus(404));
    await a.c.delete('/recurring-templates/${a.template['id']}');
    expect((await a.c.get('/recurring-templates'))['templates'], isEmpty);
    expect(nextRecurrenceDate(DateTime.utc(2026, 1, 31), 'monthly'), DateTime.utc(2026, 3, 3), reason: 'dokumentierte Einschränkung wie offline');
  });
}
