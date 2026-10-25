part of '../repository_memory.dart';

mixin _InMemoryDunning implements DunningStore {
  final List<DunningNotice> _dunningNotices = [];

  @override
  Future<List<DunningNotice>> listDunningNotices(String companyId, {String? documentId}) async =>
      _dunningNotices.where((n) => n.companyId == companyId && (documentId == null || n.documentId == documentId)).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  @override
  Future<DunningNotice?> findDunningNotice(String companyId, String id) async =>
      _dunningNotices.where((n) => n.companyId == companyId && n.id == id).firstOrNull;

  @override
  Future<void> createDunningNotice(DunningNotice notice) async => _dunningNotices.add(notice);

  @override
  Future<bool> markDunningNoticeSent(String companyId, String id, DateTime sentAt) async {
    final index = _dunningNotices.indexWhere((n) => n.companyId == companyId && n.id == id);
    if (index == -1) return false;
    final n = _dunningNotices[index];
    _dunningNotices[index] = DunningNotice(
      id: n.id,
      companyId: n.companyId,
      documentId: n.documentId,
      level: n.level,
      invoiceGrossCents: n.invoiceGrossCents,
      feeCents: n.feeCents,
      interestCents: n.interestCents,
      overdueDays: n.overdueDays,
      createdByUserId: n.createdByUserId,
      createdAt: n.createdAt,
      sentAt: sentAt,
    );
    return true;
  }
}
