import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../auth.dart';
import '../mail.dart';
import '../repository.dart';
import '../util/responses.dart';
import 'repository.dart';
import 'request_util.dart';

/// Mailversand über den Server (Kay-Entscheidung 2026-10-25). SMTP-Zugang
/// pflegt nur der Firmen-Admin; versenden darf, wer das jeweilige
/// Fachrecht hat — immer mit Modul `smtp` und nie über ein Agent-Token
/// (Versand ist nach außen wirksam und nicht rückholbar). Die PDFs rendert
/// die App (kein eigener Server-PDF-Generator, siehe Dokument-PDF).
class MailRoutes {
  MailRoutes({required this.repository, required this.business, required this.auth, required this.mail});

  final PhaseBRepository repository;
  final BusinessRepository business;
  final SessionAuthenticator auth;
  final MailService mail;

  static const _settingsKeys = {'host', 'port', 'username', 'fromAddress', 'fromName', 'useTls'};

  void mount(Router router) {
    router.get('/mail/settings', _getSettings);
    router.put('/mail/settings', _setSettings);
    router.post('/mail/test', _test);
    router.post('/documents/<id>/send', _sendDocument);
    router.post('/dunning-notices/<id>/send', _sendDunning);
    router.post('/purchase-orders/<id>/send', _sendPurchaseOrder);
  }

  Future<Map<String, Object?>> _stored(String companyId) => business.getCompanySettings(companyId, 'smtp');

  Map<String, Object?> _public(Map<String, Object?> s) => {
        'available': mail.available,
        'host': s['host'],
        'port': s['port'] ?? 587,
        'username': s['username'],
        'fromAddress': s['fromAddress'],
        'fromName': s['fromName'],
        'useTls': s['useTls'] ?? true,
        'hasPassword': s['passwordSealed'] != null,
        'templates': {...defaultMailTemplates, ...?(s['templates'] as Map?)?.cast<String, String>()},
      };

  /// Fertige Zugangsdaten oder eine verständliche Fehlerantwort.
  Future<({SmtpSettings? settings, String? password, Map<String, String> templates, Response? error})> resolve(
    String companyId,
  ) async {
    final s = await _stored(companyId);
    final templates = {...defaultMailTemplates, ...?(s['templates'] as Map?)?.cast<String, String>()};
    if (!mail.available) {
      return (
        settings: null,
        password: null,
        templates: templates,
        error: jsonError('Mailversand ist auf diesem Server nicht eingerichtet (WERKKERN_SECRET_KEY fehlt).', status: 409),
      );
    }
    final host = s['host'] as String?;
    final from = s['fromAddress'] as String?;
    if (host == null || host.isEmpty || from == null || from.isEmpty) {
      return (
        settings: null,
        password: null,
        templates: templates,
        error: jsonError('SMTP ist nicht vollständig eingerichtet (Server/Absenderadresse fehlt).', status: 409),
      );
    }
    final sealed = s['passwordSealed'] as String?;
    return (
      settings: SmtpSettings(
        host: host,
        port: s['port'] as int? ?? 587,
        username: s['username'] as String?,
        fromAddress: from,
        fromName: s['fromName'] as String?,
        useTls: s['useTls'] as bool? ?? true,
      ),
      password: sealed == null ? null : await mail.secrets!.decrypt(sealed),
      templates: templates,
      error: null,
    );
  }

  Future<Response> _getSettings(Request request) async {
    final ctx = await auth.requireAdmin(request);
    if (ctx == null) return jsonError('Nicht angemeldet oder keine Admin-Rechte.', status: 403);
    return jsonOk(_public(await _stored(ctx.session.companyId)));
  }

  /// Passwort: fehlt = unverändert, `""` = entfernen, sonst neu (wird
  /// verschlüsselt, nie zurückgegeben).
  Future<Response> _setSettings(Request request) async {
    final ctx = await auth.requireAdmin(request);
    if (ctx == null) return jsonError('Nicht angemeldet oder keine Admin-Rechte.', status: 403);
    final companyId = ctx.session.companyId;
    final body = await readJsonBody(request);
    final stored = Map<String, Object?>.of(await _stored(companyId));
    for (final key in _settingsKeys) {
      if (!body.containsKey(key)) continue;
      final v = body[key];
      if (key == 'port') {
        if (v is! int || v < 1 || v > 65535) return jsonError('port 1–65535.');
        stored[key] = v;
      } else if (key == 'useTls') {
        if (v is! bool) return jsonError('useTls (bool).');
        stored[key] = v;
      } else {
        stored[key] = trimmedOrNull(v);
      }
    }
    final from = stored['fromAddress'] as String?;
    if (from != null && !from.contains('@')) return jsonError('fromAddress ist keine E-Mail-Adresse.');
    if (body.containsKey('password')) {
      final password = body['password'];
      if (password is! String) return jsonError('password (Text) erwartet.');
      if (password.isEmpty) {
        stored.remove('passwordSealed');
      } else {
        if (!mail.available) {
          return jsonError('Mailversand ist auf diesem Server nicht eingerichtet (WERKKERN_SECRET_KEY fehlt).', status: 409);
        }
        stored['passwordSealed'] = await mail.secrets!.encrypt(password);
      }
    }
    final templates = body['templates'];
    if (templates != null) {
      if (templates is! Map) return jsonError('templates (Objekt) erwartet.');
      final cleaned = <String, String>{};
      for (final e in templates.entries) {
        if (!defaultMailTemplates.containsKey(e.key)) return jsonError('Unbekannte Vorlage: ${e.key}');
        final text = trimmedOrNull(e.value);
        if (text != null) cleaned[e.key as String] = text;
      }
      stored['templates'] = cleaned;
    }
    await business.setCompanySettings(companyId, 'smtp', stored);
    await auth.audit(ctx, 'mail.settings', 'company', companyId);
    return jsonOk(_public(stored));
  }

  Future<Response> _send(
    AuthContext ctx, {
    required String to,
    required String subject,
    required String body,
    List<MailAttachment> attachments = const [],
    required String auditAction,
    required String entityType,
    String? entityId,
  }) async {
    final resolved = await resolve(ctx.session.companyId);
    if (resolved.error != null) return resolved.error!;
    try {
      await mail.transport.send(
        resolved.settings!,
        resolved.password,
        OutgoingMail(to: to, subject: subject, body: body, attachments: attachments),
      );
    } on MailDeliveryException catch (e) {
      return jsonError(e.message, status: 502);
    }
    await auth.audit(ctx, auditAction, entityType, entityId);
    return jsonOk({'sent': true, 'to': to, 'subject': subject});
  }

  /// Gemeinsame Vorprüfung: echte App-Sitzung, Recht, Modul `smtp`.
  Future<({AuthContext? ctx, Response? error})> _require(Request request, String permission) async {
    final check = await auth.requirePermission(request, permission, requiredModule: 'smtp');
    if (check.error != null) return (ctx: null, error: check.error);
    if (check.auth!.session.isAgent) {
      return (ctx: null, error: jsonError('Mailversand nur aus der App, nicht über ein Agent-Token.', status: 403));
    }
    return (ctx: check.auth, error: null);
  }

  String? _recipient(Object? requested, String? fallback) {
    final to = trimmedOrNull(requested) ?? fallback;
    return to != null && to.contains('@') ? to : null;
  }

  Future<String> _companyName(String companyId) async => (await repository.findCompanyById(companyId))?.name ?? '';

  Future<Response> _test(Request request) async {
    final ctx = await auth.requireAdmin(request);
    if (ctx == null) return jsonError('Nicht angemeldet oder keine Admin-Rechte.', status: 403);
    final to = _recipient((await readJsonBody(request))['to'], null);
    if (to == null) return jsonError('to (E-Mail) ist Pflicht.');
    return _send(
      ctx,
      to: to,
      subject: 'WerkkernERP: Testnachricht',
      body: 'Der Mailversand für ${await _companyName(ctx.session.companyId)} ist eingerichtet.',
      auditAction: 'mail.test',
      entityType: 'company',
      entityId: ctx.session.companyId,
    );
  }

  ({String subject, String body}) _compose(Map<String, String> templates, String kind, Map<String, Object?> body,
      {required String kunde, required String nummer, required String firma}) {
    final subject = trimmedOrNull(body['subject']) ?? templates['${kind}Subject']!;
    final text = trimmedOrNull(body['body']) ?? templates['${kind}Body']!;
    return (
      subject: applyMailPlaceholders(subject, kunde: kunde, nummer: nummer, firma: firma),
      body: applyMailPlaceholders(text, kunde: kunde, nummer: nummer, firma: firma),
    );
  }

  /// Finalisiertes Dokument an den Kunden (Standard: dessen E-Mail).
  Future<Response> _sendDocument(Request request, String id) async {
    final check = await _require(request, 'invoices.read');
    if (check.error != null) return check.error!;
    final ctx = check.ctx!;
    final companyId = ctx.session.companyId;
    final document = await business.findDocument(companyId, id);
    if (document == null) return jsonError('Dokument nicht gefunden.', status: 404);
    if (document.isDraft) return jsonError('Nur finalisierte Dokumente werden versendet.', status: 409);
    final body = await readJsonBody(request);
    final customer = await business.findCustomer(companyId, document.customerId);
    final to = _recipient(body['to'], customer?.email);
    if (to == null) return jsonError('Empfänger fehlt (beim Kunden ist keine E-Mail hinterlegt).');
    final pdf = decodePdfAttachment(body['pdfBase64']);
    if (pdf == null) return jsonError('pdfBase64 muss ein PDF bis 10 MB sein.');
    final templates = (await resolve(companyId)).templates;
    final composed = _compose(templates, 'document', body,
        kunde: document.customerSnapshotName ?? customer?.name ?? '', nummer: document.number ?? '', firma: await _companyName(companyId));
    return _send(
      ctx,
      to: to,
      subject: composed.subject,
      body: composed.body,
      attachments: [MailAttachment(fileName: '${document.number}.pdf', contentType: 'application/pdf', bytes: pdf)],
      auditAction: 'mail.document',
      entityType: document.kind,
      entityId: id,
    );
  }

  Future<Response> _sendDunning(Request request, String id) async {
    final check = await _require(request, 'dunning.write');
    if (check.error != null) return check.error!;
    final ctx = check.ctx!;
    final companyId = ctx.session.companyId;
    final notice = await business.findDunningNotice(companyId, id);
    if (notice == null) return jsonError('Mahnung nicht gefunden.', status: 404);
    final document = (await business.findDocument(companyId, notice.documentId))!;
    final body = await readJsonBody(request);
    final customer = await business.findCustomer(companyId, document.customerId);
    final to = _recipient(body['to'], customer?.email);
    if (to == null) return jsonError('Empfänger fehlt (beim Kunden ist keine E-Mail hinterlegt).');
    final pdf = decodePdfAttachment(body['pdfBase64']);
    if (pdf == null) return jsonError('pdfBase64 muss ein PDF bis 10 MB sein.');
    final templates = (await resolve(companyId)).templates;
    final composed = _compose(templates, 'dunning', body,
        kunde: document.customerSnapshotName ?? '', nummer: document.number ?? '', firma: await _companyName(companyId));
    final response = await _send(
      ctx,
      to: to,
      subject: composed.subject,
      body: composed.body,
      attachments: [
        MailAttachment(fileName: 'Mahnung-${notice.level}-${document.number}.pdf', contentType: 'application/pdf', bytes: pdf),
      ],
      auditAction: 'mail.dunning',
      entityType: 'dunningNotice',
      entityId: id,
    );
    if (response.statusCode == 200) await business.markDunningNoticeSent(companyId, id, DateTime.now().toUtc());
    return response;
  }

  Future<Response> _sendPurchaseOrder(Request request, String id) async {
    final check = await _require(request, 'purchaseOrders.write');
    if (check.error != null) return check.error!;
    final ctx = check.ctx!;
    final companyId = ctx.session.companyId;
    final order = await business.findPurchaseOrder(companyId, id);
    if (order == null) return jsonError('Bestellung nicht gefunden.', status: 404);
    if (order.isDraft) return jsonError('Nur finalisierte Bestellungen werden versendet.', status: 409);
    final body = await readJsonBody(request);
    final supplier = await business.findSupplier(companyId, order.supplierId);
    final to = _recipient(body['to'], supplier?.email);
    if (to == null) return jsonError('Empfänger fehlt (beim Lieferanten ist keine E-Mail hinterlegt).');
    final pdf = decodePdfAttachment(body['pdfBase64']);
    if (pdf == null) return jsonError('pdfBase64 muss ein PDF bis 10 MB sein.');
    final templates = (await resolve(companyId)).templates;
    final composed =
        _compose(templates, 'purchaseOrder', body, kunde: supplier?.name ?? '', nummer: order.number ?? '', firma: await _companyName(companyId));
    return _send(
      ctx,
      to: to,
      subject: composed.subject,
      body: composed.body,
      attachments: [MailAttachment(fileName: '${order.number}.pdf', contentType: 'application/pdf', bytes: pdf)],
      auditAction: 'mail.purchaseOrder',
      entityType: 'purchaseOrder',
      entityId: id,
    );
  }

  /// Für die Einladung (PhaseBRouter): Mail mit Code, `null` bei Erfolg,
  /// sonst die Fehlermeldung (die Einladung selbst bleibt gültig).
  Future<String?> sendInvitation(AuthContext ctx, {required String to, required String code}) async {
    final companyId = ctx.session.companyId;
    final modules = (await repository.findCompanyById(companyId))?.enabledModules ?? const {};
    if (!modules.contains('smtp')) return 'Modul "smtp" ist nicht aktiviert.';
    final resolved = await resolve(companyId);
    if (resolved.error != null) return 'Mailversand nicht eingerichtet.';
    final firma = await _companyName(companyId);
    try {
      await mail.transport.send(
        resolved.settings!,
        resolved.password,
        OutgoingMail(
          to: to,
          subject: applyMailPlaceholders(resolved.templates['invitationSubject']!, firma: firma),
          body: applyMailPlaceholders(resolved.templates['invitationBody']!, firma: firma, code: code),
        ),
      );
    } on MailDeliveryException catch (e) {
      return e.message;
    }
    await auth.audit(ctx, 'mail.invitation', 'invitation');
    return null;
  }
}
