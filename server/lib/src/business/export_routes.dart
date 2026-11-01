import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../auth.dart';
import '../repository.dart';
import '../util/responses.dart';
import 'repository.dart';

/// Firmen-Datenexport (online Gegenstück zu „Daten & Sicherung“ offline):
/// alle Fachdaten der Firma als JSON — für den Admin, z. B. zur Ablage
/// beim Steuerberater oder vor einem Anbieterwechsel. Bewusst **ohne**
/// Passwörter, Sitzungen, Agent-Token und SMTP-Zugangsdaten. Ein Import
/// ist nicht vorgesehen (Server-Backups macht der Betreiber).
class ExportRoutes {
  ExportRoutes({required this.repository, required this.business, required this.auth});

  final PhaseBRepository repository;
  final BusinessRepository business;
  final SessionAuthenticator auth;

  /// Formatversion der Datei — steigt, wenn sich der Aufbau ändert.
  static const formatVersion = 1;

  void mount(Router router) {
    router.get('/company/export', _export);
  }

  Future<Response> _export(Request request) async {
    final ctx = await auth.requireAdmin(request);
    if (ctx == null) return jsonError('Nur für Firmen-Admins.', status: 403);
    final companyId = ctx.session.companyId;
    final company = await repository.findCompanyById(companyId);
    if (company == null) return jsonError('Firma nicht gefunden.', status: 404);

    final groups = await repository.listGroupsForCompany(companyId);
    final groupNames = {for (final g in groups) g.id: g.name};
    final members = <Map<String, Object?>>[];
    for (final m in await repository.listMembershipsForCompany(companyId)) {
      members.add({
        'email': (await repository.findUserById(m.userId))?.email,
        'group': groupNames[m.groupId],
        'isAdmin': m.isAdmin,
        'active': m.active,
        'hourlyCostCents': m.hourlyCostCents,
      });
    }

    final documents = <Map<String, Object?>>[];
    for (final d in await business.listDocuments(companyId)) {
      documents.add({...d.toJson(), 'items': [for (final i in await business.itemsFor(companyId, d.id)) i.toJson()]});
    }
    final purchaseOrders = <Map<String, Object?>>[];
    for (final o in await business.listPurchaseOrders(companyId)) {
      purchaseOrders.add({
        ...o.toJson(),
        'items': [for (final i in await business.purchaseOrderItems(companyId, o.id)) i.toJson()],
      });
    }
    final recurring = <Map<String, Object?>>[];
    for (final t in await business.listRecurringTemplates(companyId, includeInactive: true)) {
      recurring.add({
        ...t.toJson(),
        'items': [for (final i in await business.recurringTemplateItems(companyId, t.id)) i.toJson()],
      });
    }
    final inventoryCounts = <Map<String, Object?>>[];
    for (final c in await business.listInventoryCounts(companyId)) {
      inventoryCounts.add({
        ...c.toJson(),
        'items': [for (final i in await business.inventoryItems(companyId, c.id)) i.toJson()],
      });
    }
    final timeSheets = <Map<String, Object?>>[];
    for (final s in await business.listTimeSheets(companyId)) {
      timeSheets.add({...s.toJson(withSignature: true), 'entryIds': await business.timeSheetEntryIds(companyId, s.id)});
    }

    await auth.audit(ctx, 'company.export', 'company', companyId);
    final now = DateTime.now().toUtc();
    return jsonOk({
      'format': 'werkkernerp-export',
      'formatVersion': formatVersion,
      'exportedAt': now.toIso8601String(),
      'company': {
        'name': company.name,
        'modules': company.enabledModules.toList()..sort(),
        ...(await repository.getCompanyProfile(companyId)).toJson(),
      },
      'settings': {
        for (final section in ['datev', 'bankCsv', 'dunning']) section: await business.getCompanySettings(companyId, section),
      },
      'members': members,
      'groups': [
        for (final g in groups)
          {
            'name': g.name,
            'permissions': [
              for (final p in await repository.listGroupPermissions(g.id)) p.permission,
            ],
          },
      ],
      'customers': [for (final c in await business.listCustomers(companyId)) c.toJson()],
      'suppliers': [for (final s in await business.listSuppliers(companyId)) s.toJson()],
      'articleGroups': [for (final g in await business.listArticleGroups(companyId)) g.toJson()],
      'articles': [for (final a in await business.listArticles(companyId, includeInactive: true)) a.toJson()],
      'articlePrices': [for (final p in await business.listArticlePrices(companyId)) p.toJson()],
      'documents': documents,
      'dunningNotices': [for (final n in await business.listDunningNotices(companyId)) n.toJson()],
      'recurringTemplates': recurring,
      'projects': [for (final p in await business.listProjects(companyId, includeArchived: true)) p.toJson()],
      'staffRoles': [for (final r in await business.listStaffRoles(companyId)) r.toJson()],
      'timeEntries': [for (final t in await business.listTimeEntries(companyId)) t.toJson()],
      'timeSheets': timeSheets,
      'vehicles': [for (final v in await business.listVehicles(companyId, includeInactive: true)) v.toJson()],
      'vehicleCosts': [for (final c in await business.listVehicleCosts(companyId)) c.toJson()],
      'stockMovements': [for (final m in await business.listStockMovements(companyId, limit: 1 << 30)) m.toJson()],
      'inventoryCounts': inventoryCounts,
      'purchaseOrders': purchaseOrders,
      'expenseCategories': [for (final c in await business.listExpenseCategories(companyId)) c.toJson()],
      'expenses': [for (final e in await business.listExpenses(companyId)) e.toJson()],
      'bankTransactions': [for (final t in await business.listBankTransactions(companyId)) t.toJson()],
    });
  }
}
