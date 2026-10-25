import 'package:werkkern_core/werkkern_core.dart' as core;

import '../../data/database/database.dart';

export 'package:werkkern_core/werkkern_core.dart' show DatevExportConfig, encodeDatevAnsi;

/// C14.5 DATEV-Export — der Formatkern liegt seit Phase B in
/// `werkkern_core` (`buildDatevExport`, gemeinsam mit dem Server); hier
/// nur die Anbindung an die Offline-Tabellen. Format, Disclaimer und
/// Grenzen siehe Doc-Kommentar dort.
/// Belege ohne SKR03-Konto landen in [skippedExpenses] statt im Export.
class DatevExportResult {
  const DatevExportResult({required this.csvContent, required this.exportedCount, required this.skippedExpenses});
  final String csvContent;
  final int exportedCount;
  final List<Expense> skippedExpenses;
}

DatevExportResult buildDatevBuchungsstapel({
  required List<Expense> expenses,
  required Map<String, ExpenseCategory> categoryById,
  required core.DatevExportConfig config,
  required DateTime periodStart,
  required DateTime periodEnd,
  required DateTime generatedAt,
}) {
  final result = core.buildDatevExport<Expense>(
    expenses: [
      for (final e in expenses)
        core.DatevExpenseInput(
          source: e,
          date: e.date,
          amountGrossCents: e.amountGrossCents,
          description: e.description,
          account: e.categoryId == null ? null : categoryById[e.categoryId]?.skr03Account,
          supplierReference: e.supplierReference,
        ),
    ],
    config: config,
    periodStart: periodStart,
    periodEnd: periodEnd,
    generatedAt: generatedAt,
  );
  return DatevExportResult(
    csvContent: result.csvContent,
    exportedCount: result.exportedCount,
    skippedExpenses: result.skipped,
  );
}
