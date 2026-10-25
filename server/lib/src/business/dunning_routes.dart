import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:uuid/uuid.dart';
import 'package:werkkern_core/werkkern_core.dart';

import '../auth.dart';
import '../util/responses.dart';
import 'accounting_routes.dart' show documentGrossCents;
import 'dunning.dart';
import 'models.dart';
import 'repository.dart';
import 'request_util.dart';

/// Mahnwesen (C12) — `dunning.read`/`dunning.write`, Modul `dunning`.
/// Fristen, Gebühren und Zinssatz sind Kays eigene Werte (keine
/// Rechtsprüfung, wie offline).
class DunningRoutes {
  DunningRoutes({required this.business, required this.auth});

  final BusinessRepository business;
  final SessionAuthenticator auth;
  static const _uuid = Uuid();

  static const _defaults = <String, Object?>{
    'reminder2AfterDays': 14,
    'reminder3AfterDays': 28,
    'feeLevel1Cents': 0,
    'feeLevel2Cents': 0,
    'feeLevel3Cents': 0,
    'interestRatePercent': 0,
    'introText': null,
    'closingText': null,
  };

  void mount(Router router) {
    router.get('/dunning/settings', _getSettings);
    router.put('/dunning/settings', _setSettings);
    router.get('/dunning/overdue', _overdue);
    router.get('/documents/<id>/dunning-notices', _listNotices);
    router.post('/documents/<id>/dunning-notices', _createNotice);
  }

  Future<Map<String, Object?>> settings(String companyId) async =>
      {..._defaults, ...await business.getCompanySettings(companyId, 'dunning')};

  DunningConfig _config(Map<String, Object?> s) => DunningConfig(
        reminder2AfterDays: s['reminder2AfterDays'] as int,
        reminder3AfterDays: s['reminder3AfterDays'] as int,
        feeLevel1: Money.fromCents(s['feeLevel1Cents'] as int),
        feeLevel2: Money.fromCents(s['feeLevel2Cents'] as int),
        feeLevel3: Money.fromCents(s['feeLevel3Cents'] as int),
        interestRatePercent: (s['interestRatePercent'] as num).toDouble(),
      );

  /// Stand einer Rechnung heute: Stufe, Tage, Gebühr, Zins.
  Future<({DunningLevel level, int overdueDays, int grossCents, int feeCents, int interestCents})> assess(
    String companyId,
    Document d,
    DunningConfig config,
    DateTime now,
  ) async {
    final level = hasPaymentStatusKind(d.kind)
        ? dunningLevelForDue(isFinalized: !d.isDraft, isPaid: d.paymentStatus == 'paid', dueDate: d.dueDate, now: now, config: config)
        : DunningLevel.none;
    final gross = documentGrossCents(await business.itemsFor(companyId, d.id));
    final overdueDays = d.dueDate == null ? 0 : now.difference(d.dueDate!).inDays;
    return (
      level: level,
      overdueDays: overdueDays,
      grossCents: gross,
      feeCents: config.feeFor(level).cents,
      interestCents: level == DunningLevel.none
          ? 0
          : dunningInterestFor(principal: Money.fromCents(gross), overdueDays: overdueDays, ratePercent: config.interestRatePercent).cents,
    );
  }

  Future<Response> _getSettings(Request request) async {
    final check = await auth.requirePermission(request, 'dunning.read');
    if (check.error != null) return check.error!;
    return jsonOk(await settings(check.auth!.session.companyId));
  }

  Future<Response> _setSettings(Request request) async {
    final check = await auth.requirePermission(request, 'dunning.write');
    if (check.error != null) return check.error!;
    final companyId = check.auth!.session.companyId;
    final body = await readJsonBody(request);
    final merged = await settings(companyId);
    for (final entry in body.entries) {
      if (!_defaults.containsKey(entry.key)) return jsonError('Unbekanntes Feld: ${entry.key}');
      final v = entry.value;
      final isText = entry.key == 'introText' || entry.key == 'closingText';
      if (isText) {
        merged[entry.key] = trimmedOrNull(v);
      } else if (entry.key == 'interestRatePercent') {
        if (v is! num || v < 0 || v > 100) return jsonError('interestRatePercent muss zwischen 0 und 100 liegen.');
        merged[entry.key] = v;
      } else {
        if (v is! int || v < 0) return jsonError('${entry.key} muss eine Ganzzahl >= 0 sein.');
        merged[entry.key] = v;
      }
    }
    if ((merged['reminder3AfterDays'] as int) < (merged['reminder2AfterDays'] as int)) {
      return jsonError('Die 3. Stufe darf nicht vor der 2. beginnen.');
    }
    await business.setCompanySettings(companyId, 'dunning', merged);
    await auth.audit(check.auth!, 'dunning.settings', 'company', companyId);
    return jsonOk(merged);
  }

  /// Überfällige, unbezahlte Rechnungen mit heutiger Stufe und Beträgen,
  /// am längsten überfällige zuerst.
  Future<Response> _overdue(Request request) async {
    final check = await auth.requirePermission(request, 'dunning.read');
    if (check.error != null) return check.error!;
    final companyId = check.auth!.session.companyId;
    final config = _config(await settings(companyId));
    final now = DateTime.now().toUtc();
    final notices = await business.listDunningNotices(companyId);
    final result = <Map<String, Object?>>[];
    for (final d in await business.listDocuments(companyId, kind: 'invoice', status: 'finalized')) {
      final a = await assess(companyId, d, config, now);
      if (a.level == DunningLevel.none) continue;
      final last = notices.where((n) => n.documentId == d.id).firstOrNull;
      result.add({
        'documentId': d.id,
        'number': d.number,
        'customerName': d.customerSnapshotName,
        'dueDate': dateJson(d.dueDate!),
        'level': a.level.index,
        'levelLabel': dunningLevelLabel(a.level),
        'overdueDays': a.overdueDays,
        'invoiceGrossCents': a.grossCents,
        'feeCents': a.feeCents,
        'interestCents': a.interestCents,
        'totalDueCents': a.grossCents + a.feeCents + a.interestCents,
        'lastNotice': last?.toJson(),
      });
    }
    result.sort((a, b) => (b['overdueDays'] as int).compareTo(a['overdueDays'] as int));
    return jsonOk({'overdue': result});
  }

  Future<Response> _listNotices(Request request, String id) async {
    final check = await auth.requirePermission(request, 'dunning.read');
    if (check.error != null) return check.error!;
    final companyId = check.auth!.session.companyId;
    if (await business.findDocument(companyId, id) == null) return jsonError('Dokument nicht gefunden.', status: 404);
    final notices = await business.listDunningNotices(companyId, documentId: id);
    return jsonOk({'notices': [for (final n in notices) n.toJson()]});
  }

  /// Erstellt eine Mahnung zur **heutigen** Stufe und protokolliert sie;
  /// liefert die Daten für das Mahnschreiben (Texte aus den Einstellungen).
  Future<Response> _createNotice(Request request, String id) async {
    final check = await auth.requirePermission(request, 'dunning.write');
    if (check.error != null) return check.error!;
    final companyId = check.auth!.session.companyId;
    final document = await business.findDocument(companyId, id);
    if (document == null) return jsonError('Dokument nicht gefunden.', status: 404);
    final s = await settings(companyId);
    final now = DateTime.now().toUtc();
    final a = await assess(companyId, document, _config(s), now);
    if (a.level == DunningLevel.none) {
      return jsonError('Rechnung ist nicht überfällig (bezahlt, ohne Fälligkeit oder noch nicht fällig).', status: 409);
    }
    final notice = DunningNotice(
      id: _uuid.v4(),
      companyId: companyId,
      documentId: id,
      level: a.level.index,
      invoiceGrossCents: a.grossCents,
      feeCents: a.feeCents,
      interestCents: a.interestCents,
      overdueDays: a.overdueDays,
      createdByUserId: check.auth!.session.userId,
      createdAt: now,
    );
    await business.createDunningNotice(notice);
    await auth.audit(check.auth!, 'dunning.notice', 'document', id);
    return jsonOk({
      ...notice.toJson(),
      'title': dunningLetterTitle(a.level),
      'interestRatePercent': s['interestRatePercent'],
      'introText': s['introText'],
      'closingText': s['closingText'],
    }, status: 201);
  }
}
