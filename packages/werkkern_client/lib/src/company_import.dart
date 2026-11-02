import 'api_client.dart';

/// B4 Umzug Einzelplatz → Online-Firma: Ergebnis von Probelauf bzw.
/// Import (`POST /company/import`).
class CompanyImportResult {
  const CompanyImportResult({
    required this.dryRun,
    required this.counts,
    required this.warnings,
    required this.errors,
    required this.roles,
    required this.missingAssignments,
  });
  factory CompanyImportResult.fromJson(Map<String, Object?> j) => CompanyImportResult(
        dryRun: j['dryRun'] as bool? ?? false,
        counts: (j['counts'] as Map<String, Object?>? ?? const {}).map((k, v) => MapEntry(k, v as int)),
        warnings: [for (final w in j['warnings'] as List? ?? const []) w as String],
        errors: [for (final e in j['errors'] as List? ?? const []) e as String],
        roles: [
          for (final r in j['roles'] as List? ?? const [])
            (
              id: (r as Map<String, Object?>)['id'] as String,
              name: r['name'] as String,
              timeEntries: r['timeEntries'] as int,
            ),
        ],
        missingAssignments: [for (final m in j['missingAssignments'] as List? ?? const []) m as String],
      );

  final bool dryRun;

  /// Anzahl je Bereich (`customers`, `documents`, …).
  final Map<String, int> counts;
  final List<String> warnings;

  /// Nicht leer → der Server lehnt den Import ab.
  final List<String> errors;

  /// Rollen mit Zeitbuchungen (`id` = Offline-Rollen-ID bzw. „-“ für
  /// Buchungen ohne Rolle) — jede braucht ein Mitglied.
  final List<({String id, String name, int timeEntries})> roles;
  final List<String> missingAssignments;
}

extension CompanyImportApi on WerkkernApiClient {
  /// [roleAssignments]: Offline-Rollen-ID (bzw. „-“) → Mitgliedschafts-ID.
  /// [dryRun] prüft nur. 409 = Firma nicht leer/bereits umgezogen,
  /// 422 = Paket fehlerhaft oder Zuordnung fehlt.
  Future<CompanyImportResult> importCompany(
    Map<String, Object?> package, {
    Map<String, String> roleAssignments = const {},
    bool dryRun = false,
  }) async =>
      CompanyImportResult.fromJson(await request(
        'POST',
        '/company/import',
        query: dryRun ? const {'dryRun': '1'} : null,
        body: {'package': package, 'roleAssignments': roleAssignments},
      ) as Map<String, Object?>);
}
