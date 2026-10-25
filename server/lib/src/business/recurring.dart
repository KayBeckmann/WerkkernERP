/// Wiederkehrende Rechnungen online (C11). Anders als offline (nur beim
/// Öffnen der App) erzeugt der **Server täglich** die fälligen Entwürfe
/// (Kay-Entscheidung 2026-10-25) — je überfälliger Periode einer, nie
/// automatisch finalisiert.
library;

import 'models.dart';
import 'request_util.dart';

class RecurringTemplate {
  const RecurringTemplate({
    required this.id,
    required this.companyId,
    required this.customerId,
    required this.label,
    required this.interval,
    required this.nextDueDate,
    this.paymentTerms,
    this.notes,
    this.projectId,
    required this.active,
    required this.createdByUserId,
    required this.createdAt,
  });
  final String id;
  final String companyId;
  final String customerId;
  final String label;

  /// `monthly`, `quarterly`, `yearly`.
  final String interval;
  final DateTime nextDueDate;
  final String? paymentTerms;
  final String? notes;
  final String? projectId;
  final bool active;

  /// Gilt als Ersteller der erzeugten Entwürfe.
  final String createdByUserId;
  final DateTime createdAt;

  Map<String, Object?> toJson() => {
        'id': id,
        'customerId': customerId,
        'label': label,
        'interval': interval,
        'nextDueDate': dateJson(nextDueDate),
        'paymentTerms': paymentTerms,
        'notes': notes,
        'projectId': projectId,
        'active': active,
        'createdAt': createdAt.toIso8601String(),
      };
}

abstract interface class RecurringStore {
  Future<List<RecurringTemplate>> listRecurringTemplates(String companyId, {bool includeInactive = false});
  Future<RecurringTemplate?> findRecurringTemplate(String companyId, String id);

  /// Positionen als [DocumentItem] mit `documentId` = Vorlagen-ID.
  Future<List<DocumentItem>> recurringTemplateItems(String companyId, String templateId);
  Future<void> createRecurringTemplate(RecurringTemplate template, List<DocumentItem> items);
  Future<bool> updateRecurringTemplate(RecurringTemplate template, List<DocumentItem> items);
  Future<bool> deleteRecurringTemplate(String companyId, String id);

  /// **Nur für den internen Tagesjob**, nie über die API: aktive Vorlagen
  /// aller Firmen mit Fälligkeit `<= day` (einzige firmenübergreifende
  /// Abfrage, bewusst).
  Future<List<RecurringTemplate>> listDueRecurringTemplatesForJob(DateTime day);

  /// Atomar: Fälligkeit von [expectedDueDate] auf [nextDueDate] vorrücken
  /// **und** den Entwurf anlegen. `false`, wenn eine andere Instanz die
  /// Periode schon erzeugt hat (Fälligkeit nicht mehr [expectedDueDate]).
  Future<bool> generateRecurringDraft(
    RecurringTemplate template, {
    required DateTime expectedDueDate,
    required DateTime nextDueDate,
    required Document draft,
    required List<DocumentItem> items,
  });
}
