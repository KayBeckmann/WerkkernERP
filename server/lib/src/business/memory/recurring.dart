part of '../repository_memory.dart';

mixin _InMemoryRecurring implements RecurringStore {
  List<Document> get _documents;
  List<DocumentItem> get _items;
  final List<RecurringTemplate> _recurringTemplates = [];
  final List<DocumentItem> _recurringItems = [];

  RecurringTemplate _withDue(RecurringTemplate t, DateTime due) => RecurringTemplate(
        id: t.id,
        companyId: t.companyId,
        customerId: t.customerId,
        label: t.label,
        interval: t.interval,
        nextDueDate: due,
        paymentTerms: t.paymentTerms,
        notes: t.notes,
        projectId: t.projectId,
        active: t.active,
        createdByUserId: t.createdByUserId,
        createdAt: t.createdAt,
      );

  @override
  Future<List<RecurringTemplate>> listRecurringTemplates(String companyId, {bool includeInactive = false}) async =>
      _recurringTemplates.where((t) => t.companyId == companyId && (includeInactive || t.active)).toList()
        ..sort((a, b) => a.nextDueDate.compareTo(b.nextDueDate));

  @override
  Future<RecurringTemplate?> findRecurringTemplate(String companyId, String id) async =>
      _recurringTemplates.where((t) => t.companyId == companyId && t.id == id).firstOrNull;

  @override
  Future<List<DocumentItem>> recurringTemplateItems(String companyId, String templateId) async {
    if (await findRecurringTemplate(companyId, templateId) == null) return const [];
    return _recurringItems.where((i) => i.documentId == templateId).toList()..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }

  @override
  Future<void> createRecurringTemplate(RecurringTemplate template, List<DocumentItem> items) async {
    _recurringTemplates.add(template);
    _recurringItems.addAll(items);
  }

  @override
  Future<bool> updateRecurringTemplate(RecurringTemplate template, List<DocumentItem> items) async {
    final index = _recurringTemplates.indexWhere((t) => t.companyId == template.companyId && t.id == template.id);
    if (index == -1) return false;
    _recurringTemplates[index] = template;
    _recurringItems.removeWhere((i) => i.documentId == template.id);
    _recurringItems.addAll(items);
    return true;
  }

  @override
  Future<bool> deleteRecurringTemplate(String companyId, String id) async {
    final before = _recurringTemplates.length;
    _recurringTemplates.removeWhere((t) => t.companyId == companyId && t.id == id);
    if (_recurringTemplates.length == before) return false;
    _recurringItems.removeWhere((i) => i.documentId == id);
    return true;
  }

  @override
  Future<List<RecurringTemplate>> listDueRecurringTemplatesForJob(DateTime day) async =>
      _recurringTemplates.where((t) => t.active && !t.nextDueDate.isAfter(day)).toList();

  @override
  Future<bool> generateRecurringDraft(
    RecurringTemplate template, {
    required DateTime expectedDueDate,
    required DateTime nextDueDate,
    required Document draft,
    required List<DocumentItem> items,
  }) async {
    final index = _recurringTemplates.indexWhere((t) => t.id == template.id);
    if (index == -1 || _recurringTemplates[index].nextDueDate != expectedDueDate) return false;
    _recurringTemplates[index] = _withDue(_recurringTemplates[index], nextDueDate);
    _documents.add(draft);
    _items.addAll(items);
    return true;
  }
}
