import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../auth.dart';
import '../mail.dart';
import '../util/responses.dart';
import 'models.dart';
import 'repository.dart';
import 'request_util.dart';

/// Upload happens when the app creates a PDF, not when email is sent.
class PdfArchiveRoutes {
  PdfArchiveRoutes({required this.business, required this.auth});
  final BusinessRepository business;
  final SessionAuthenticator auth;

  void mount(Router router) {
    router.get('/pdf-archive/versions', _browse);
    router.get('/pdf-archive/<type>/<id>/versions', _list);
    router.post('/pdf-archive/<type>/<id>/versions', _create);
    router.get('/pdf-archive/<type>/<id>/versions/<version>', _download);
  }

  Future<Response> _browse(Request request) async {
    final ctx = await auth.requireSession(request);
    if (ctx == null) return jsonError('Nicht angemeldet.', status: 401);
    final params = request.url.queryParameters;
    final limit = int.tryParse(params['limit'] ?? '50');
    final offset = int.tryParse(params['offset'] ?? '0');
    if (limit == null || limit < 1 || limit > 100 || offset == null || offset < 0) {
      return jsonError('limit muss 1–100 und offset mindestens 0 sein.');
    }
    // Archive access follows resource read rights, not today's module toggles.
    final documents = await auth.isGranted(ctx, 'invoices.read', ignoreModule: true);
    final orders = await auth.isGranted(ctx, 'purchaseOrders.read', ignoreModule: true);
    final sheets = await auth.isGranted(ctx, 'timeTracking.read', ignoreModule: true);
    final ownSheets = await auth.isGranted(ctx, 'timeTracking.write', ignoreModule: true);
    final rows = await business.browsePdfVersions(ctx.session.companyId,
      documents: documents, purchaseOrders: orders, allTimeSheets: sheets,
      ownTimeSheetsUserId: !sheets && ownSheets ? ctx.session.userId : null,
      limit: limit + 1, offset: offset);
    return jsonOk({
      'versions': [for (final row in rows.take(limit)) row.toJson()],
      'limit': limit, 'offset': offset, 'hasMore': rows.length > limit,
    });
  }

  Future<({String? companyId, Response? error, AuthContext? context})>
  _authorize(Request request, String type, String id, bool writing) async {
    final permission = switch (type) {
      'document' => 'invoices.${writing ? 'write' : 'read'}',
      'purchase-order' => 'purchaseOrders.${writing ? 'write' : 'read'}',
      'time-sheet' => writing ? 'timeTracking.write' : 'timeTracking.read',
      _ => null,
    };
    if (permission == null)
      return (
        companyId: null,
        error: jsonError('PDF-Quelle nicht gefunden.', status: 404),
        context: null,
      );
    final checked = writing
        ? await auth.requirePermission(request, permission)
        : await (() async {
            final ctx = await auth.requireSession(request);
            if (ctx == null) return (auth: null, error: jsonError('Nicht angemeldet.', status: 401));
            if (!await auth.isGranted(ctx, permission, ignoreModule: true) &&
                !(type == 'time-sheet' &&
                    await auth.isGranted(ctx, 'timeTracking.write', ignoreModule: true))) {
              return (auth: null, error: jsonError('Keine Berechtigung: $permission', status: 403));
            }
            return (auth: ctx, error: null);
          })();
    if (checked.error != null)
      return (companyId: null, error: checked.error, context: null);
    final ctx = checked.auth!;
    final companyId = ctx.session.companyId;
    if (type == 'document') {
      final document = await business.findDocument(companyId, id);
      if (document == null)
        return (
          companyId: null,
          error: jsonError('Dokument nicht gefunden.', status: 404),
          context: null,
        );
      final module = documentKindModules[document.kind];
      if (!documentKindModules.containsKey(document.kind))
        return (
          companyId: null,
          error: jsonError('Dokumentart nicht verfügbar.', status: 404),
          context: null,
        );
      if (writing && module != null) {
        final gated = await auth.requirePermission(
          request,
          permission,
          requiredModule: module,
        );
        if (gated.error != null)
          return (companyId: null, error: gated.error, context: null);
      }
    } else if (type == 'purchase-order') {
      if (await business.findPurchaseOrder(companyId, id) == null)
        return (
          companyId: null,
          error: jsonError('Bestellung nicht gefunden.', status: 404),
          context: null,
        );
    } else {
      final sheet = await business.findTimeSheet(companyId, id);
      if (sheet == null ||
          (sheet.createdByUserId != ctx.session.userId &&
              !await auth.isGranted(ctx, 'timeTracking.read', ignoreModule: !writing))) {
        return (
          companyId: null,
          error: jsonError('Stundenzettel nicht gefunden.', status: 404),
          context: null,
        );
      }
      if (writing && !sheet.isSigned)
        return (
          companyId: null,
          error: jsonError(
            'Stundenzettel muss unterschrieben sein.',
            status: 409,
          ),
          context: null,
        );
    }
    return (companyId: companyId, error: null, context: ctx);
  }

  Future<Response> _list(Request request, String type, String id) async {
    final v = await _authorize(request, type, id, false);
    if (v.error != null) return v.error!;
    final versions = await business.listPdfVersions(v.companyId!, type, id);
    return jsonOk({
      'versions': [for (final pdf in versions) pdf.toJson()],
    });
  }

  Future<Response> _create(Request request, String type, String id) async {
    final v = await _authorize(request, type, id, true);
    if (v.error != null) return v.error!;
    final body = await readJsonBody(request);
    final pdf = decodePdfAttachment(body['pdfBase64']);
    if (pdf == null) return jsonError('pdfBase64 muss ein PDF bis 10 MB sein.');
    final entry = await business.archivePdf(
      companyId: v.companyId!,
      sourceType: type,
      sourceId: id,
      bytes: pdf,
      now: DateTime.now().toUtc(),
    );
    await auth.audit(v.context!, 'pdf.archive', type, id);
    return jsonOk(entry.toJson(), status: 201);
  }

  Future<Response> _download(
    Request request,
    String type,
    String id,
    String version,
  ) async {
    final v = await _authorize(request, type, id, false);
    if (v.error != null) return v.error!;
    final number = int.tryParse(version);
    if (number == null || number <= 0)
      return jsonError('PDF-Fassung nicht gefunden.', status: 404);
    final pdf = await business.findPdfVersion(v.companyId!, type, id, number);
    if (pdf == null)
      return jsonError('PDF-Fassung nicht gefunden.', status: 404);
    return Response.ok(
      pdf.bytes,
      headers: {
        'content-type': 'application/pdf',
        'content-disposition':
            'attachment; filename="${type}_${id}_v$number.pdf"',
        'cache-control': 'private, no-store',
        'x-content-type-options': 'nosniff',
      },
    );
  }
}
