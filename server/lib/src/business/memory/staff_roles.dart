part of '../repository_memory.dart';

mixin _InMemoryStaffRoles implements StaffRoleStore {
  final List<StaffRole> _staffRoles = [];
  List<TimeEntry> get _timeEntries;
  List<DocumentItem> get _items;

  @override
  Future<List<StaffRole>> listStaffRoles(String companyId) async =>
      _staffRoles.where((r) => r.companyId == companyId).toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  @override
  Future<StaffRole?> findStaffRole(String companyId, String id) async =>
      _staffRoles.where((r) => r.companyId == companyId && r.id == id).firstOrNull;

  @override
  Future<void> createStaffRole(StaffRole role) async => _staffRoles.add(role);

  @override
  Future<bool> updateStaffRole(StaffRole role) async {
    final index = _staffRoles.indexWhere((r) => r.companyId == role.companyId && r.id == role.id);
    if (index == -1) return false;
    _staffRoles[index] = role;
    return true;
  }

  @override
  Future<bool> deleteStaffRole(String companyId, String id) async {
    final before = _staffRoles.length;
    _staffRoles.removeWhere((r) => r.companyId == companyId && r.id == id);
    if (_staffRoles.length == before) return false;
    for (var i = 0; i < _timeEntries.length; i++) {
      final t = _timeEntries[i];
      if (t.companyId == companyId && t.staffRoleId == id) {
        _timeEntries[i] = TimeEntry(
          id: t.id,
          companyId: t.companyId,
          userId: t.userId,
          documentId: t.documentId,
          projectId: t.projectId,
          workDate: t.workDate,
          hours: t.hours,
          note: t.note,
          hourlyCostCents: t.hourlyCostCents,
          createdAt: t.createdAt,
          updatedAt: t.updatedAt,
        );
      }
    }
    // Positionen behalten Preis und Text, verlieren nur den Rollenbezug
    // (wie offline `onDelete: setNull`).
    for (var i = 0; i < _items.length; i++) {
      final it = _items[i];
      if (it.staffRoleId != id) continue;
      _items[i] = DocumentItem(
        id: it.id,
        documentId: it.documentId,
        kind: it.kind,
        articleId: it.articleId,
        description: it.description,
        quantity: it.quantity,
        unitPriceCents: it.unitPriceCents,
        vatRatePercent: it.vatRatePercent,
        unit: it.unit,
        discountPercent: it.discountPercent,
        groupLabel: it.groupLabel,
        sortOrder: it.sortOrder,
      );
    }
    return true;
  }
}
