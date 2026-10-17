import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../database/database.dart';
import '../database/tables.dart';
import 'invoice_repository.dart';

/// Wiederkehrende Rechnungsvorlagen je Firma (C11, Kay-Priorisierungs-
/// entscheidung 2026-10-17) — gleiche companyId-Isolation wie alle
/// übrigen A0-Repositories. Erzeugt bei Fälligkeit neue **Entwürfe**
/// über das bestehende [InvoiceRepository] statt eine eigene
/// Finalisierungslogik zu duplizieren.
class RecurringInvoiceTemplateRepository {
  RecurringInvoiceTemplateRepository(this._db, this._invoices);

  final AppDatabase _db;
  final InvoiceRepository _invoices;
  static const _uuid = Uuid();

  Future<List<RecurringInvoiceTemplate>> listForCompany(
    String companyId, {
    bool includeInactive = false,
  }) {
    final query = _db.select(_db.recurringInvoiceTemplates)
      ..where((t) => t.companyId.equals(companyId));
    if (!includeInactive) {
      query.where((t) => t.active.equals(true));
    }
    query.orderBy([(t) => OrderingTerm.asc(t.label)]);
    return query.get();
  }

  Future<RecurringInvoiceTemplate?> findById({required String companyId, required String id}) =>
      (_db.select(_db.recurringInvoiceTemplates)
            ..where((t) => t.id.equals(id) & t.companyId.equals(companyId)))
          .getSingleOrNull();

  Future<List<RecurringInvoiceTemplateItem>> itemsFor(String templateId) =>
      (_db.select(_db.recurringInvoiceTemplateItems)
            ..where((i) => i.templateId.equals(templateId))
            ..orderBy([(i) => OrderingTerm.asc(i.sortOrder)]))
          .get();

  Future<RecurringInvoiceTemplate> create({
    required String companyId,
    required String customerId,
    required String label,
    required RecurrenceInterval interval,
    required DateTime nextDueDate,
    String? paymentTerms,
    String? notes,
    List<InvoiceItemInput> items = const [],
  }) async {
    final id = _uuid.v4();
    return _db.transaction(() async {
      await _db.into(_db.recurringInvoiceTemplates).insert(
            RecurringInvoiceTemplatesCompanion.insert(
              id: id,
              companyId: companyId,
              customerId: customerId,
              label: label,
              interval: interval,
              nextDueDate: nextDueDate,
              paymentTerms: Value(paymentTerms),
              notes: Value(notes),
              createdAt: DateTime.now(),
            ),
          );
      await _replaceItems(id, items);
      return (await findById(companyId: companyId, id: id))!;
    });
  }

  Future<RecurringInvoiceTemplate?> update({
    required String companyId,
    required String id,
    String? label,
    RecurrenceInterval? interval,
    DateTime? nextDueDate,
    String? paymentTerms,
    String? notes,
    List<InvoiceItemInput>? items,
  }) async {
    return _db.transaction(() async {
      final existing = await findById(companyId: companyId, id: id);
      if (existing == null) return null;
      await (_db.update(_db.recurringInvoiceTemplates)..where((t) => t.id.equals(id))).write(
        RecurringInvoiceTemplatesCompanion(
          label: label == null ? const Value.absent() : Value(label),
          interval: interval == null ? const Value.absent() : Value(interval),
          nextDueDate: nextDueDate == null ? const Value.absent() : Value(nextDueDate),
          paymentTerms: Value(paymentTerms ?? existing.paymentTerms),
          notes: Value(notes ?? existing.notes),
        ),
      );
      if (items != null) await _replaceItems(id, items);
      return findById(companyId: companyId, id: id);
    });
  }

  Future<bool> setActive({required String companyId, required String id, required bool active}) async {
    final rows = await (_db.update(_db.recurringInvoiceTemplates)
          ..where((t) => t.id.equals(id) & t.companyId.equals(companyId)))
        .write(RecurringInvoiceTemplatesCompanion(active: Value(active)));
    return rows > 0;
  }

  Future<bool> delete({required String companyId, required String id}) async {
    final rows = await (_db.delete(_db.recurringInvoiceTemplates)
          ..where((t) => t.id.equals(id) & t.companyId.equals(companyId)))
        .go();
    return rows > 0;
  }

  /// Nächster Fälligkeitstermin nach [interval] — bewusst über den
  /// `DateTime`-Konstruktor (Monats-/Jahresüberlauf normalisiert Dart
  /// automatisch, z. B. Monat 13 → Januar des Folgejahres); ein 31. bei
  /// einem kürzeren Zielmonat rutscht dadurch in den übernächsten Monat
  /// vor, statt auf den Monatsletzten zu fallen — bekannte, dokumentierte
  /// Einschränkung, keine stillschweigende Annahme.
  static DateTime _advance(DateTime date, RecurrenceInterval interval) => switch (interval) {
        RecurrenceInterval.monthly => DateTime(date.year, date.month + 1, date.day),
        RecurrenceInterval.quarterly => DateTime(date.year, date.month + 3, date.day),
        RecurrenceInterval.yearly => DateTime(date.year + 1, date.month, date.day),
      };

  /// Erzeugt für jede aktive, fällige Vorlage **einen Entwurf je
  /// überfälliger Periode** — nicht nur die aktuell fällige. Ohne
  /// Server/Hintergrunddienst läuft diese Prüfung nur beim Öffnen der
  /// App (siehe Klassendoc); eine länger nicht geöffnete App holt beim
  /// nächsten Start alle inzwischen fälligen Perioden nach, statt sie
  /// stillschweigend zu überspringen. Nie automatisch finalisiert.
  Future<List<Invoice>> generateDueDrafts({required String companyId}) async {
    final templates = await listForCompany(companyId);
    final created = <Invoice>[];
    final now = DateTime.now();

    for (final template in templates) {
      var dueDate = template.nextDueDate;
      while (!dueDate.isAfter(now)) {
        final items = await itemsFor(template.id);
        final draft = await _invoices.createDraft(
          companyId: companyId,
          customerId: template.customerId,
          issueDate: now,
          serviceDate: now,
          paymentTerms: template.paymentTerms,
          notes: template.notes,
          items: [
            for (final item in items)
              InvoiceItemInput(
                kind: item.kind,
                articleId: item.articleId,
                description: item.description,
                quantity: Decimal.parse(item.quantity),
                unitPriceCents: item.unitPriceCents,
                vatRatePercent: item.vatRatePercent,
                unit: item.unit,
                discountPercent: item.discountPercent,
                groupLabel: item.groupLabel,
              ),
          ],
        );
        created.add(draft);
        dueDate = _advance(dueDate, template.interval);
      }
      if (dueDate != template.nextDueDate) {
        await (_db.update(_db.recurringInvoiceTemplates)..where((t) => t.id.equals(template.id)))
            .write(RecurringInvoiceTemplatesCompanion(nextDueDate: Value(dueDate)));
      }
    }
    return created;
  }

  Future<void> _replaceItems(String templateId, List<InvoiceItemInput> items) async {
    await (_db.delete(_db.recurringInvoiceTemplateItems)..where((i) => i.templateId.equals(templateId)))
        .go();
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      await _db.into(_db.recurringInvoiceTemplateItems).insert(
            RecurringInvoiceTemplateItemsCompanion.insert(
              id: _uuid.v4(),
              templateId: templateId,
              kind: item.kind,
              articleId: Value(item.articleId),
              description: item.description,
              quantity: item.quantity.toString(),
              unitPriceCents: item.unitPriceCents,
              vatRatePercent: item.vatRatePercent,
              unit: Value(item.unit),
              discountPercent: Value(item.discountPercent),
              groupLabel: Value(item.groupLabel),
              sortOrder: i,
            ),
          );
    }
  }
}
