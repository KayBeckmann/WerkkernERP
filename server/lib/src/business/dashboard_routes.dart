import 'package:decimal/decimal.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:werkkern_core/werkkern_core.dart';

import '../auth.dart';
import '../repository.dart';
import '../util/responses.dart';
import 'accounting_routes.dart' show documentGrossCents;
import 'dunning_routes.dart';
import 'models.dart';
import 'repository.dart';
import 'request_util.dart';

/// Dashboard je Nutzer (Kay-Entscheidung 2026-10-25: Kacheln ergeben sich
/// aus den wirksamen Rechten + Modulen; jeder kann Kacheln für sich
/// ausblenden). Eine Kachel, für die Recht oder Modul fehlt, wird gar
/// nicht berechnet — ein Monteur bekommt nie Finanzkennzahlen.
class DashboardRoutes {
  DashboardRoutes({required this.repository, required this.business, required this.auth, required this.dunning});

  final PhaseBRepository repository;
  final BusinessRepository business;
  final SessionAuthenticator auth;
  final DunningRoutes dunning;

  /// Kachel → (Modul oder `null`, mindestens eines dieser Rechte).
  static const tiles = <String, ({String? module, List<String> anyOf})>{
    'openInvoices': (module: null, anyOf: ['invoices.payment', 'accounting.read']),
    'revenue': (module: null, anyOf: ['accounting.read', 'invoices.finalize']),
    'drafts': (module: null, anyOf: ['invoices.write']),
    'overdue': (module: 'dunning', anyOf: ['dunning.read']),
    'projects': (module: 'projects', anyOf: ['projects.read']),
    'myHours': (module: 'timeTracking', anyOf: ['timeTracking.write']),
    'timeSheets': (module: 'timeTracking', anyOf: ['timeTracking.write']),
    'lowStock': (module: 'lagerbestand', anyOf: ['stock.read']),
    'purchaseOrders': (module: 'bestellwesen', anyOf: ['purchaseOrders.read']),
    'vehicles': (module: 'fleet', anyOf: ['fleet.read']),
    'recurring': (module: 'recurringInvoices', anyOf: ['invoices.read']),
  };

  void mount(Router router) {
    router.get('/dashboard', _get);
    router.put('/dashboard/preferences', _setPreferences);
  }

  String _section(String userId) => 'dashboard:$userId';

  Future<Response> _get(Request request) async {
    final ctx = await auth.requireSession(request);
    if (ctx == null) return jsonError('Nicht angemeldet.', status: 401);
    final companyId = ctx.session.companyId;
    final modules = (await repository.findCompanyById(companyId))?.enabledModules ?? const {};
    final available = <String>[];
    for (final entry in tiles.entries) {
      if (entry.value.module != null && !modules.contains(entry.value.module)) continue;
      for (final p in entry.value.anyOf) {
        if (await auth.isGranted(ctx, p)) {
          available.add(entry.key);
          break;
        }
      }
    }
    final hidden = ((await business.getCompanySettings(companyId, _section(ctx.session.userId)))['hidden'] as List? ?? const [])
        .cast<String>()
        .toSet();
    final now = DateTime.now().toUtc();
    final today = DateTime.utc(now.year, now.month, now.day);
    final result = <Map<String, Object?>>[];
    for (final key in available) {
      if (hidden.contains(key)) continue;
      result.add({'key': key, ...await _tile(key, ctx, today)});
    }
    return jsonOk({'tiles': result, 'available': available, 'hidden': hidden.toList()});
  }

  Future<Map<String, Object?>> _tile(String key, AuthContext ctx, DateTime today) async {
    final companyId = ctx.session.companyId;
    switch (key) {
      case 'openInvoices':
        var count = 0, sum = 0, overdue = 0;
        for (final d in await business.listDocuments(companyId, kind: 'invoice', status: 'finalized')) {
          if (d.paymentStatus != 'open') continue;
          count++;
          sum += documentGrossCents(await business.itemsFor(companyId, d.id));
          if (d.dueDate != null && d.dueDate!.isBefore(today)) overdue++;
        }
        return {'title': 'Offene Rechnungen', 'count': count, 'amountCents': sum, 'detail': overdue == 0 ? null : '$overdue überfällig'};
      case 'revenue':
        var month = 0, year = 0;
        for (final d in await business.listDocuments(companyId, status: 'finalized')) {
          final sign = revenueSignForKind(d.kind);
          if (sign == 0 || d.issueDate.year != today.year) continue;
          final gross = documentGrossCents(await business.itemsFor(companyId, d.id)) * sign;
          year += gross;
          if (d.issueDate.month == today.month) month += gross;
        }
        return {'title': 'Umsatz (Rechnungen − Gutschriften)', 'amountCents': month, 'detail': 'Jahr ${Money.fromCents(year)}'};
      case 'drafts':
        final drafts = (await business.listDocuments(companyId, status: 'draft')).where((d) => d.createdByUserId == ctx.session.userId);
        return {'title': 'Meine Entwürfe', 'count': drafts.length};
      case 'overdue':
        final s = await dunning.settings(companyId);
        final config = DunningConfig(
          reminder2AfterDays: s['reminder2AfterDays'] as int,
          reminder3AfterDays: s['reminder3AfterDays'] as int,
          feeLevel1: Money.zero(),
          feeLevel2: Money.zero(),
          feeLevel3: Money.zero(),
          interestRatePercent: 0,
        );
        var count = 0;
        for (final d in await business.listDocuments(companyId, kind: 'invoice', status: 'finalized')) {
          final level = dunningLevelForDue(isFinalized: true, isPaid: d.paymentStatus == 'paid', dueDate: d.dueDate, now: today, config: config);
          if (level != DunningLevel.none) count++;
        }
        return {'title': 'Zu mahnen', 'count': count};
      case 'projects':
        return {'title': 'Aktive Projekte', 'count': (await business.listProjects(companyId)).length};
      case 'myHours':
        final monday = today.subtract(Duration(days: today.weekday - 1));
        final entries = await business.listTimeEntries(companyId, userId: ctx.session.userId, from: DateTime.utc(today.year, today.month));
        Decimal sum(Iterable<TimeEntry> list) => list.fold<Decimal>(Decimal.zero, (a, e) => a + Decimal.parse(e.hours));
        return {
          'title': 'Meine Stunden',
          'value': sum(entries.where((e) => !e.workDate.isBefore(monday))).toString(),
          'detail': 'Monat ${sum(entries).toString().replaceAll('.', ',')} Std.',
        };
      case 'timeSheets':
        final open = (await business.listTimeSheets(companyId, createdByUserId: ctx.session.userId)).where((s) => !s.isSigned);
        return {'title': 'Offene Stundenzettel', 'count': open.length};
      case 'lowStock':
        var count = 0;
        for (final a in await business.listArticles(companyId)) {
          if (a.minimumStock != null && Decimal.parse(a.stockQuantity) < Decimal.parse(a.minimumStock!)) count++;
        }
        return {'title': 'Unter Mindestbestand', 'count': count};
      case 'purchaseOrders':
        final open = (await business.listPurchaseOrders(companyId)).where((o) => o.canReceive);
        return {'title': 'Offene Bestellungen', 'count': open.length};
      case 'vehicles':
        final soon = today.add(const Duration(days: 30));
        final due = (await business.listVehicles(companyId)).where((v) => v.nextInspectionDate != null && v.nextInspectionDate!.isBefore(soon));
        return {'title': 'TÜV in 30 Tagen', 'count': due.length};
      case 'recurring':
        final templates = await business.listRecurringTemplates(companyId);
        return {
          'title': 'Wiederkehrende Rechnungen',
          'count': templates.length,
          'detail': templates.isEmpty ? null : 'nächste ${dateJson(templates.first.nextDueDate)}',
        };
    }
    return const {};
  }

  Future<Response> _setPreferences(Request request) async {
    final ctx = await auth.requireSession(request);
    if (ctx == null) return jsonError('Nicht angemeldet.', status: 401);
    final hidden = (await readJsonBody(request))['hidden'];
    if (hidden is! List || hidden.any((k) => !tiles.containsKey(k))) return jsonError('hidden: Liste bekannter Kacheln.');
    await business.setCompanySettings(ctx.session.companyId, _section(ctx.session.userId), {'hidden': hidden});
    return jsonOk({'hidden': hidden});
  }
}
