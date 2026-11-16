import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:uuid/uuid.dart';

import '../auth.dart';
import '../util/responses.dart';
import 'payment_terms.dart';
import 'repository.dart';
import 'request_util.dart';

/// A2-Nachtrag (Kay, 15./16.11.2026): Zahlungsbedingungen der Firma.
/// Lesen darf jedes Mitglied (Auswahl im Beleg/Kunden), pflegen nur der
/// Firmen-Admin (Firmeneinstellung wie Dokumenttexte).
class PaymentTermRoutes {
  PaymentTermRoutes({required this.business, required this.auth, required this.ensureDefaults});

  final BusinessRepository business;
  final SessionAuthenticator auth;

  /// Liefert die Bedingungen und legt beim ersten Zugriff die Vorgaben an.
  final Future<List<PaymentTerm>> Function(String companyId) ensureDefaults;
  static const _uuid = Uuid();

  void mount(Router router) {
    router.get('/payment-terms', _list);
    router.post('/payment-terms', _create);
    router.put('/payment-terms/<id>', _update);
    router.put('/payment-terms/<id>/default', _setDefault);
    router.delete('/payment-terms/<id>', _delete);
  }

  Future<Response> _list(Request request) async {
    final session = await auth.requireSession(request);
    if (session == null) return jsonError('Nicht angemeldet.', status: 401);
    final terms = await ensureDefaults(session.session.companyId);
    return jsonOk({'paymentTerms': [for (final t in terms) t.toJson()]});
  }

  Future<({AuthContext? admin, Response? error})> _admin(Request request) async {
    final session = await auth.requireSession(request);
    if (session == null) return (admin: null, error: jsonError('Nicht angemeldet.', status: 401));
    final admin = await auth.requireAdmin(request);
    if (admin == null) return (admin: null, error: jsonError('Nur für Firmen-Admins.', status: 403));
    return (admin: admin, error: null);
  }

  ({String? label, int? days, String? error}) _parse(Map<String, Object?> body) {
    final label = trimmedOrNull(body['label']);
    final days = body['netDays'];
    if (label == null || days is! int || days < 0) return (label: null, days: null, error: 'label und netDays (≥ 0) sind Pflicht.');
    return (label: label, days: days, error: null);
  }

  Future<Response> _create(Request request) async {
    final check = await _admin(request);
    if (check.error != null) return check.error!;
    final companyId = check.admin!.session.companyId;
    final parsed = _parse(await readJsonBody(request));
    if (parsed.error != null) return jsonError(parsed.error!);
    final existing = await ensureDefaults(companyId);
    final term = PaymentTerm(id: _uuid.v4(), companyId: companyId, label: parsed.label!, netDays: parsed.days!, sortOrder: existing.length);
    await business.savePaymentTerm(term);
    await auth.audit(check.admin!, 'paymentTerm.create', 'paymentTerm', term.id);
    return jsonOk(term.toJson(), status: 201);
  }

  Future<Response> _update(Request request, String id) async {
    final check = await _admin(request);
    if (check.error != null) return check.error!;
    final companyId = check.admin!.session.companyId;
    final existing = (await ensureDefaults(companyId)).where((t) => t.id == id).firstOrNull;
    if (existing == null) return jsonError('Zahlungsbedingung nicht gefunden.', status: 404);
    final parsed = _parse(await readJsonBody(request));
    if (parsed.error != null) return jsonError(parsed.error!);
    final term = existing.copyWith(label: parsed.label, netDays: parsed.days);
    await business.savePaymentTerm(term);
    await auth.audit(check.admin!, 'paymentTerm.update', 'paymentTerm', id);
    return jsonOk(term.toJson());
  }

  Future<Response> _setDefault(Request request, String id) async {
    final check = await _admin(request);
    if (check.error != null) return check.error!;
    final companyId = check.admin!.session.companyId;
    if (!(await ensureDefaults(companyId)).any((t) => t.id == id)) {
      return jsonError('Zahlungsbedingung nicht gefunden.', status: 404);
    }
    await business.setDefaultPaymentTerm(companyId, id);
    await auth.audit(check.admin!, 'paymentTerm.default', 'paymentTerm', id);
    return jsonOk({'paymentTerms': [for (final t in await business.listPaymentTerms(companyId)) t.toJson()]});
  }

  Future<Response> _delete(Request request, String id) async {
    final check = await _admin(request);
    if (check.error != null) return check.error!;
    final companyId = check.admin!.session.companyId;
    final all = await ensureDefaults(companyId);
    final removed = all.where((t) => t.id == id).firstOrNull;
    if (removed == null) return jsonError('Zahlungsbedingung nicht gefunden.', status: 404);
    if (all.length <= 1) return jsonError('Mindestens eine Zahlungsbedingung muss bleiben.', status: 409);
    await business.deletePaymentTerm(companyId, id);
    if (removed.isDefault) await business.setDefaultPaymentTerm(companyId, all.firstWhere((t) => t.id != id).id);
    await auth.audit(check.admin!, 'paymentTerm.delete', 'paymentTerm', id);
    return Response(204);
  }
}
