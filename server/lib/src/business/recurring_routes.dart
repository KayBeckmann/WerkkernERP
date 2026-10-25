import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:uuid/uuid.dart';
import 'package:werkkern_core/werkkern_core.dart';

import '../auth.dart';
import '../repository.dart';
import '../util/responses.dart';
import 'accounting_routes.dart' show documentGrossCents;
import 'models.dart';
import 'recurring.dart';
import 'recurring_job.dart';
import 'repository.dart';
import 'request_util.dart';

typedef ItemParser = Future<({List<DocumentItem>? items, String? error})> Function(Object? raw, String companyId, String ownerId);

/// Vorlagen wiederkehrender Rechnungen (C11) — `invoices.read`/
/// `invoices.write`, Modul `recurringInvoices`. Positionen werden mit
/// denselben Regeln wie Dokumentpositionen geprüft ([parseItems]).
class RecurringRoutes {
  RecurringRoutes({required this.repository, required this.business, required this.auth, required this.parseItems});

  final PhaseBRepository repository;
  final BusinessRepository business;
  final SessionAuthenticator auth;
  final ItemParser parseItems;
  static const _uuid = Uuid();
  static const _module = 'recurringInvoices';

  void mount(Router router) {
    router.get('/recurring-templates', _list);
    router.post('/recurring-templates', _create);
    router.post('/recurring-templates/generate', _generate);
    router.get('/recurring-templates/<id>', _get);
    router.put('/recurring-templates/<id>', _update);
    router.delete('/recurring-templates/<id>', _delete);
  }

  Future<({AuthContext? auth, Response? error})> _require(Request request, String permission) =>
      auth.requirePermission(request, permission, requiredModule: _module);

  Future<Response> _response(String companyId, RecurringTemplate t, {int status = 200}) async {
    final items = await business.recurringTemplateItems(companyId, t.id);
    final customer = await business.findCustomer(companyId, t.customerId);
    return jsonOk({
      ...t.toJson(),
      'customerName': customer?.name,
      'items': [for (final i in items) i.toJson()],
      'grossCents': documentGrossCents(items),
    }, status: status);
  }

  Future<({RecurringTemplate? template, List<DocumentItem>? items, Response? error})> _fromBody(
    Map<String, Object?> body, {
    required String id,
    required AuthContext ctx,
    RecurringTemplate? existing,
  }) async {
    final companyId = ctx.session.companyId;
    final label = trimmedOrNull(body['label']) ?? existing?.label;
    final customerId = trimmedOrNull(body['customerId']) ?? existing?.customerId;
    final interval = body['interval'] as String? ?? existing?.interval;
    final due = body.containsKey('nextDueDate') ? dateOrNull(body['nextDueDate']) : existing?.nextDueDate;
    if (label == null || customerId == null || due == null || !recurrenceIntervals.contains(interval)) {
      return (
        template: null,
        items: null,
        error: jsonError('label, customerId, interval (${recurrenceIntervals.join('/')}) und nextDueDate (JJJJ-MM-TT) sind Pflicht.'),
      );
    }
    if (await business.findCustomer(companyId, customerId) == null) {
      return (template: null, items: null, error: jsonError('Kunde nicht gefunden.', status: 404));
    }
    final projectId = body.containsKey('projectId') ? trimmedOrNull(body['projectId']) : existing?.projectId;
    if (projectId != null && await business.findProject(companyId, projectId) == null) {
      return (template: null, items: null, error: jsonError('Projekt nicht gefunden.', status: 404));
    }
    final parsed = body.containsKey('items')
        ? await parseItems(body['items'], companyId, id)
        : (items: existing == null ? <DocumentItem>[] : await business.recurringTemplateItems(companyId, id), error: null);
    if (parsed.error != null) return (template: null, items: null, error: jsonError(parsed.error!));
    return (
      template: RecurringTemplate(
        id: id,
        companyId: companyId,
        customerId: customerId,
        label: label,
        interval: interval!,
        nextDueDate: due,
        paymentTerms: body.containsKey('paymentTerms') ? trimmedOrNull(body['paymentTerms']) : existing?.paymentTerms,
        notes: body.containsKey('notes') ? trimmedOrNull(body['notes']) : existing?.notes,
        projectId: projectId,
        active: body['active'] as bool? ?? existing?.active ?? true,
        createdByUserId: existing?.createdByUserId ?? ctx.session.userId,
        createdAt: existing?.createdAt ?? DateTime.now().toUtc(),
      ),
      items: parsed.items,
      error: null,
    );
  }

  Future<Response> _list(Request request) async {
    final check = await _require(request, 'invoices.read');
    if (check.error != null) return check.error!;
    final companyId = check.auth!.session.companyId;
    final templates = await business.listRecurringTemplates(
      companyId,
      includeInactive: request.url.queryParameters['includeInactive'] == 'true',
    );
    final names = {for (final c in await business.listCustomers(companyId)) c.id: c.name};
    return jsonOk({
      'templates': [
        for (final t in templates)
          {...t.toJson(), 'customerName': names[t.customerId], 'grossCents': documentGrossCents(await business.recurringTemplateItems(companyId, t.id))},
      ],
    });
  }

  Future<Response> _get(Request request, String id) async {
    final check = await _require(request, 'invoices.read');
    if (check.error != null) return check.error!;
    final companyId = check.auth!.session.companyId;
    final t = await business.findRecurringTemplate(companyId, id);
    if (t == null) return jsonError('Vorlage nicht gefunden.', status: 404);
    return _response(companyId, t);
  }

  Future<Response> _create(Request request) async {
    final check = await _require(request, 'invoices.write');
    if (check.error != null) return check.error!;
    final result = await _fromBody(await readJsonBody(request), id: _uuid.v4(), ctx: check.auth!);
    if (result.error != null) return result.error!;
    await business.createRecurringTemplate(result.template!, result.items!);
    await auth.audit(check.auth!, 'recurring.create', 'recurringTemplate', result.template!.id);
    return _response(check.auth!.session.companyId, result.template!, status: 201);
  }

  Future<Response> _update(Request request, String id) async {
    final check = await _require(request, 'invoices.write');
    if (check.error != null) return check.error!;
    final companyId = check.auth!.session.companyId;
    final existing = await business.findRecurringTemplate(companyId, id);
    if (existing == null) return jsonError('Vorlage nicht gefunden.', status: 404);
    final result = await _fromBody(await readJsonBody(request), id: id, ctx: check.auth!, existing: existing);
    if (result.error != null) return result.error!;
    await business.updateRecurringTemplate(result.template!, result.items!);
    await auth.audit(check.auth!, 'recurring.update', 'recurringTemplate', id);
    return _response(companyId, result.template!);
  }

  Future<Response> _delete(Request request, String id) async {
    final check = await _require(request, 'invoices.write');
    if (check.error != null) return check.error!;
    if (!await business.deleteRecurringTemplate(check.auth!.session.companyId, id)) {
      return jsonError('Vorlage nicht gefunden.', status: 404);
    }
    await auth.audit(check.auth!, 'recurring.delete', 'recurringTemplate', id);
    return Response(204);
  }

  /// Fällige Entwürfe dieser Firma sofort erzeugen (der Server macht das
  /// sonst selbst, stündlich geprüft).
  Future<Response> _generate(Request request) async {
    final check = await _require(request, 'invoices.write');
    if (check.error != null) return check.error!;
    final created = await runRecurringInvoiceJob(
      repository: repository,
      business: business,
      now: DateTime.now().toUtc(),
      onlyCompanyId: check.auth!.session.companyId,
    );
    return jsonOk({'created': created});
  }
}
