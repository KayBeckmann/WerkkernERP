import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:uuid/uuid.dart';

import '../auth.dart';
import '../util/responses.dart';
import 'models.dart';
import 'repository.dart';
import 'request_util.dart';
import 'timesheets.dart';

/// PNG-Signatur höchstens 512 KiB (eine Touch-Zeichnung liegt weit darunter).
const _maxSignatureBytes = 512 * 1024;

/// Kunden-Stundenzettel (C3-Rest) — `timeTracking.write` zum Anlegen/
/// Unterschreiben, Modul `timeTracking`. Ohne `timeTracking.read` sieht
/// und bündelt jeder nur eigene Zettel und Buchungen.
class TimeSheetRoutes {
  TimeSheetRoutes({required this.business, required this.auth});

  final BusinessRepository business;
  final SessionAuthenticator auth;
  static const _uuid = Uuid();

  void mount(Router router) {
    router.get('/time-sheets', _list);
    router.post('/time-sheets', _create);
    router.get('/time-sheets/<id>', _get);
    router.delete('/time-sheets/<id>', _delete);
    router.post('/time-sheets/<id>/entries', _addEntries);
    router.delete('/time-sheets/<id>/entries/<entryId>', _removeEntry);
    router.post('/time-sheets/<id>/sign', _sign);
    router.post('/time-sheets/<id>/correction', _correction);
  }

  Future<bool> _seesAll(AuthContext ctx) => auth.isGranted(ctx, 'timeTracking.read');

  /// Zettel nur für Ersteller oder mit `timeTracking.read` — sonst wie
  /// nicht existent.
  Future<({AuthContext? ctx, TimeSheet? sheet, Response? error})> _visible(Request request, String id, String permission) async {
    final check = await auth.requirePermission(request, permission);
    if (check.error != null) return (ctx: null, sheet: null, error: check.error);
    final ctx = check.auth!;
    final sheet = await business.findTimeSheet(ctx.session.companyId, id);
    if (sheet == null || (sheet.createdByUserId != ctx.session.userId && !await _seesAll(ctx))) {
      return (ctx: null, sheet: null, error: jsonError('Stundenzettel nicht gefunden.', status: 404));
    }
    return (ctx: ctx, sheet: sheet, error: null);
  }

  Future<Response> _response(AuthContext ctx, TimeSheet sheet, {int status = 200}) async {
    final companyId = ctx.session.companyId;
    final ids = (await business.timeSheetEntryIds(companyId, sheet.id)).toSet();
    final entries = [
      for (final e in await business.listTimeEntries(companyId))
        if (ids.contains(e.id)) e,
    ]..sort((a, b) => a.workDate.compareTo(b.workDate));
    final document = sheet.documentId == null ? null : await business.findDocument(companyId, sheet.documentId!);
    final project = sheet.projectId == null ? null : await business.findProject(companyId, sheet.projectId!);
    final customerId = document?.customerId ?? project?.customerId;
    final customer = customerId == null ? null : await business.findCustomer(companyId, customerId);
    return jsonOk({
      ...sheet.toJson(withSignature: true),
      'documentNumber': document?.number,
      'projectName': project?.name,
      'customerName': customer?.name,
      'entries': [for (final e in entries) e.toJson()],
      'totalHours': entries.fold<Decimal>(Decimal.zero, (sum, e) => sum + Decimal.parse(e.hours)).toString(),
    }, status: status);
  }

  /// Buchungen, die der Aufrufer bündeln darf: eigene, mit Leserecht alle.
  Future<Response?> _checkEntries(AuthContext ctx, List<String> entryIds) async {
    final seesAll = await _seesAll(ctx);
    for (final id in entryIds) {
      final entry = await business.findTimeEntry(ctx.session.companyId, id);
      if (entry == null || (!seesAll && entry.userId != ctx.session.userId)) {
        return jsonError('Buchung nicht gefunden.', status: 404);
      }
    }
    return null;
  }

  Future<Response> _list(Request request) async {
    final check = await auth.requirePermission(request, 'timeTracking.write');
    if (check.error != null) return check.error!;
    final ctx = check.auth!;
    final sheets = await business.listTimeSheets(
      ctx.session.companyId,
      createdByUserId: await _seesAll(ctx) ? null : ctx.session.userId,
    );
    return jsonOk({'timeSheets': [for (final s in sheets) s.toJson()]});
  }

  Future<Response> _get(Request request, String id) async {
    final v = await _visible(request, id, 'timeTracking.write');
    if (v.error != null) return v.error!;
    return _response(v.ctx!, v.sheet!);
  }

  Future<Response> _create(Request request) async {
    final check = await auth.requirePermission(request, 'timeTracking.write');
    if (check.error != null) return check.error!;
    final ctx = check.auth!;
    final companyId = ctx.session.companyId;
    final body = await readJsonBody(request);
    final documentId = trimmedOrNull(body['documentId']);
    final projectId = trimmedOrNull(body['projectId']);
    if (documentId == null && projectId == null) return jsonError('documentId (Auftrag/Rechnung) oder projectId ist Pflicht.');
    if (documentId != null) {
      final d = await business.findDocument(companyId, documentId);
      if (d == null) return jsonError('Dokument nicht gefunden.', status: 404);
      if (d.kind != 'order' && d.kind != 'invoice') return jsonError('Stundenzettel nur zu Auftrag oder Rechnung.');
    }
    if (projectId != null && await business.findProject(companyId, projectId) == null) {
      return jsonError('Projekt nicht gefunden.', status: 404);
    }
    final entryIds = (body['entryIds'] as List? ?? const []).cast<String>();
    final invalid = await _checkEntries(ctx, entryIds);
    if (invalid != null) return invalid;
    final now = DateTime.now().toUtc();
    final sheet = TimeSheet(
      id: _uuid.v4(),
      companyId: companyId,
      date: dateOrNull(body['date']) ?? DateTime.utc(now.year, now.month, now.day),
      documentId: documentId,
      projectId: projectId,
      status: 'draft',
      createdByUserId: ctx.session.userId,
      createdAt: now,
    );
    await business.createTimeSheet(sheet);
    try {
      if (entryIds.isNotEmpty) await business.addTimeSheetEntries(companyId, sheet.id, entryIds);
    } on BusinessConflict catch (e) {
      await business.deleteTimeSheetDraft(companyId, sheet.id);
      return jsonError(e.message, status: 409);
    }
    await auth.audit(ctx, 'timeSheet.create', 'timeSheet', sheet.id);
    return _response(ctx, sheet, status: 201);
  }

  Future<Response> _delete(Request request, String id) async {
    final v = await _visible(request, id, 'timeTracking.write');
    if (v.error != null) return v.error!;
    if (v.ctx!.session.isAgent) {
      if (v.sheet!.isSigned) return jsonError('Unterschriebene Stundenzettel sind unveränderlich.', status: 409);
      return auth.requestApproval(
        v.ctx!,
        method: 'DELETE',
        path: '/time-sheets/$id',
        body: const {},
        summary: 'Stundenzettel vom ${dateJson(v.sheet!.date)} (Entwurf) löschen',
      );
    }
    try {
      await business.deleteTimeSheetDraft(v.ctx!.session.companyId, id);
    } on BusinessConflict catch (e) {
      return jsonError(e.message, status: 409);
    }
    await auth.audit(v.ctx!, 'timeSheet.delete', 'timeSheet', id);
    return Response(204);
  }

  Future<Response> _addEntries(Request request, String id) async {
    final v = await _visible(request, id, 'timeTracking.write');
    if (v.error != null) return v.error!;
    final entryIds = ((await readJsonBody(request))['entryIds'] as List? ?? const []).cast<String>();
    if (entryIds.isEmpty) return jsonError('entryIds ist Pflicht.');
    final invalid = await _checkEntries(v.ctx!, entryIds);
    if (invalid != null) return invalid;
    try {
      await business.addTimeSheetEntries(v.ctx!.session.companyId, id, entryIds);
    } on BusinessConflict catch (e) {
      return jsonError(e.message, status: 409);
    }
    return _response(v.ctx!, (await business.findTimeSheet(v.ctx!.session.companyId, id))!);
  }

  Future<Response> _removeEntry(Request request, String id, String entryId) async {
    final v = await _visible(request, id, 'timeTracking.write');
    if (v.error != null) return v.error!;
    try {
      if (!await business.removeTimeSheetEntry(v.ctx!.session.companyId, id, entryId)) {
        return jsonError('Buchung nicht auf diesem Stundenzettel.', status: 404);
      }
    } on BusinessConflict catch (e) {
      return jsonError(e.message, status: 409);
    }
    return _response(v.ctx!, v.sheet!);
  }

  /// `{"signaturePng": "<base64>", "signerName": "…"}`.
  Future<Response> _sign(Request request, String id) async {
    final v = await _visible(request, id, 'timeTracking.write');
    if (v.error != null) return v.error!;
    // Die Unterschrift leistet der Kunde selbst auf dem Gerät — nie ein Agent.
    if (v.ctx!.session.isAgent) {
      return jsonError('Unterschreiben nur in der App, nicht über ein Agent-Token.', status: 403);
    }
    final body = await readJsonBody(request);
    final raw = body['signaturePng'];
    if (raw is! String) return jsonError('signaturePng (Base64) ist Pflicht.');
    final png = base64Decode(raw);
    // PNG-Signatur prüfen, damit keine beliebigen Daten gespeichert werden.
    const magic = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
    if (png.length < 8 || png.length > _maxSignatureBytes || [for (var i = 0; i < 8; i++) png[i]].join() != magic.join()) {
      return jsonError('signaturePng muss ein PNG bis 512 KiB sein.');
    }
    try {
      final signed = await business.signTimeSheet(
        v.ctx!.session.companyId,
        id,
        png: png,
        signerName: trimmedOrNull(body['signerName']),
        now: DateTime.now().toUtc(),
      );
      if (signed == null) return jsonError('Stundenzettel nicht gefunden.', status: 404);
      await auth.audit(v.ctx!, 'timeSheet.sign', 'timeSheet', id);
      return await _response(v.ctx!, signed);
    } on BusinessConflict catch (e) {
      return jsonError(e.message, status: 409);
    }
  }

  /// Nachtrag zu einem unterschriebenen Zettel: neuer Entwurf mit gleicher
  /// Zuordnung und Datum, ohne Buchungen (die alten bleiben am alten).
  Future<Response> _correction(Request request, String id) async {
    final v = await _visible(request, id, 'timeTracking.write');
    if (v.error != null) return v.error!;
    final old = v.sheet!;
    if (!old.isSigned) return jsonError('Nur unterschriebene Stundenzettel brauchen einen Nachtrag.', status: 409);
    final now = DateTime.now().toUtc();
    final sheet = TimeSheet(
      id: _uuid.v4(),
      companyId: old.companyId,
      date: old.date,
      documentId: old.documentId,
      projectId: old.projectId,
      status: 'draft',
      supersedesId: old.id,
      createdByUserId: v.ctx!.session.userId,
      createdAt: now,
    );
    await business.createTimeSheet(sheet);
    await auth.audit(v.ctx!, 'timeSheet.correction', 'timeSheet', sheet.id);
    return _response(v.ctx!, sheet, status: 201);
  }
}
