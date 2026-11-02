import 'dart:convert';

import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:uuid/uuid.dart';

import '../auth.dart';
import '../models.dart';
import '../repository.dart';
import '../util/responses.dart';
import 'company_import.dart';
import 'models.dart' show BusinessConflict;
import 'repository.dart';

/// B4 Umzug Einzelplatz → Online-Firma (Selbstbedienung aus der
/// Offline-App). Nur Firmen-Admins, nur in eine **leere** Firma, nur
/// einmal. `?dryRun=1` prüft und zählt, ohne zu schreiben — der
/// Assistent zeigt damit vorab, was ankommt, und welche Rollen noch einem
/// Mitglied zugeordnet werden müssen. Body:
/// `{package, roleAssignments: {Offline-Rollen-ID | "-" → Mitgliedschafts-ID}}`.
class CompanyImportRoutes {
  CompanyImportRoutes({required this.repository, required this.business, required this.auth});

  final PhaseBRepository repository;
  final BusinessRepository business;
  final SessionAuthenticator auth;
  static const _uuid = Uuid();

  /// Obergrenze für das Paket (Unterschriften als PNG eingeschlossen).
  static const maxBytes = 50 * 1024 * 1024;

  void mount(Router router) {
    router.post('/company/import', _import);
  }

  Future<Response> _import(Request request) async {
    final ctx = await auth.requireAdmin(request);
    if (ctx == null || ctx.session.isAgent) return jsonError('Nur für Firmen-Admins.', status: 403);
    final companyId = ctx.session.companyId;
    final dryRun = request.url.queryParameters['dryRun'] == '1';

    final length = request.contentLength;
    if (length != null && length > maxBytes) return jsonError('Umzugsdatei ist zu groß.', status: 413);
    final raw = await request.readAsString();
    if (raw.length > maxBytes) return jsonError('Umzugsdatei ist zu groß.', status: 413);
    final Object? body;
    try {
      body = jsonDecode(raw);
    } on FormatException {
      return jsonError('Kein gültiges JSON.');
    }
    if (body is! Map<String, Object?> || body['package'] is! Map<String, Object?>) {
      return jsonError('package (Umzugsdatei) ist Pflicht.');
    }
    final rawAssignments = body['roleAssignments'] ?? const <String, Object?>{};
    if (rawAssignments is! Map<String, Object?> || rawAssignments.values.any((v) => v is! String)) {
      return jsonError('roleAssignments: Rolle → Nutzer-ID erwartet.');
    }

    final settings = await business.getCompanySettings(companyId, 'import');
    if (settings['importedAt'] != null) {
      return jsonError('In diese Firma wurde bereits umgezogen (${settings['importedAt']}).', status: 409);
    }
    if (await business.companyHasBusinessData(companyId)) {
      return jsonError(
        'Die Firma enthält bereits Daten — ein Umzug ist nur in eine leere, neu angelegte Firma möglich.',
        status: 409,
      );
    }

    // Zuordnung kommt als Mitgliedschafts-ID (so kennt sie der Assistent).
    final members = {
      for (final m in await repository.listMembershipsForCompany(companyId))
        if (m.active) m.id: m.userId,
    };
    final assignments = {
      for (final e in rawAssignments.entries) e.key: members[e.value as String] ?? 'unbekannt:${e.value}',
    };
    final parsed = parseCompanyImport(
      body['package']! as Map<String, Object?>,
      companyId: companyId,
      userId: ctx.session.userId,
      roleAssignments: assignments,
      memberUserIds: members.values.toSet(),
      newId: _uuid.v4,
      now: DateTime.now().toUtc(),
    );
    final summary = {
      'counts': parsed.data.counts,
      'warnings': parsed.warnings,
      'errors': parsed.errors,
      'roles': [
        for (final r in parsed.roles) {'id': r.id, 'name': r.name, 'timeEntries': r.timeEntries},
      ],
      'missingAssignments': parsed.missingAssignments,
    };
    if (dryRun) return jsonOk({...summary, 'dryRun': true});
    if (parsed.errors.isNotEmpty) {
      return jsonError('Umzugsdatei fehlerhaft: ${parsed.errors.take(5).join(' · ')}', status: 422);
    }
    if (parsed.missingAssignments.isNotEmpty) {
      return jsonError('Für jede Rolle mit Zeitbuchungen muss ein Mitglied gewählt werden.', status: 422);
    }

    try {
      await business.importCompanyData(companyId, parsed.data);
    } on BusinessConflict catch (e) {
      return jsonError(e.message, status: 409);
    }
    // Profil und Module liegen im Plattform-Repository — nach den
    // Fachdaten setzen (die Firma ist ab hier nicht mehr leer).
    final company = await repository.findCompanyById(companyId);
    final p = parsed.profile;
    await repository.saveCompanyProfile(
      CompanyProfile(
        companyId: companyId,
        address: p.address,
        taxNumber: p.taxNumber,
        vatId: p.vatId,
        iban: p.iban,
        email: p.email,
        phone: p.phone,
        footerText: p.footerText,
        documentTexts: p.documentTexts,
        smallBusinessExempt: p.smallBusinessExempt,
      ),
    );
    await repository.setCompanyModules(
      companyId: companyId,
      enabledModules: {...?company?.enabledModules, ...p.modules},
    );
    await auth.audit(ctx, 'company.import', 'company', companyId);
    return jsonOk({...summary, 'dryRun': false}, status: 201);
  }
}
