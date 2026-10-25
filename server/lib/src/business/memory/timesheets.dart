part of '../repository_memory.dart';

mixin _InMemoryTimeSheets implements TimeSheetStore {
  final List<TimeSheet> _timeSheets = [];
  final Map<String, String> _sheetByEntry = {};

  @override
  Future<List<TimeSheet>> listTimeSheets(String companyId, {String? createdByUserId}) async => _timeSheets
      .where((s) => s.companyId == companyId && (createdByUserId == null || s.createdByUserId == createdByUserId))
      .toList()
    ..sort((a, b) => b.date != a.date ? b.date.compareTo(a.date) : b.createdAt.compareTo(a.createdAt));

  @override
  Future<TimeSheet?> findTimeSheet(String companyId, String id) async =>
      _timeSheets.where((s) => s.companyId == companyId && s.id == id).firstOrNull;

  @override
  Future<List<String>> timeSheetEntryIds(String companyId, String sheetId) async {
    if (await findTimeSheet(companyId, sheetId) == null) return const [];
    return [for (final e in _sheetByEntry.entries) if (e.value == sheetId) e.key];
  }

  @override
  Future<TimeSheet?> timeSheetForEntry(String companyId, String entryId) async {
    final sheetId = _sheetByEntry[entryId];
    return sheetId == null ? null : findTimeSheet(companyId, sheetId);
  }

  @override
  Future<void> createTimeSheet(TimeSheet sheet) async => _timeSheets.add(sheet);

  @override
  Future<void> addTimeSheetEntries(String companyId, String sheetId, List<String> entryIds) async {
    final sheet = await findTimeSheet(companyId, sheetId);
    if (sheet == null) return;
    if (sheet.isSigned) throw const BusinessConflict('Stundenzettel ist unterschrieben und unveränderlich.');
    for (final id in entryIds) {
      final current = _sheetByEntry[id];
      if (current != null && current != sheetId) throw const BusinessConflict('Buchung liegt bereits auf einem anderen Stundenzettel.');
    }
    for (final id in entryIds) {
      _sheetByEntry[id] = sheetId;
    }
  }

  @override
  Future<bool> removeTimeSheetEntry(String companyId, String sheetId, String entryId) async {
    final sheet = await findTimeSheet(companyId, sheetId);
    if (sheet == null || _sheetByEntry[entryId] != sheetId) return false;
    if (sheet.isSigned) throw const BusinessConflict('Stundenzettel ist unterschrieben und unveränderlich.');
    _sheetByEntry.remove(entryId);
    return true;
  }

  @override
  Future<bool> deleteTimeSheetDraft(String companyId, String sheetId) async {
    final sheet = await findTimeSheet(companyId, sheetId);
    if (sheet == null) return false;
    if (sheet.isSigned) throw const BusinessConflict('Unterschriebene Stundenzettel bleiben als Nachweis erhalten.');
    _timeSheets.removeWhere((s) => s.id == sheetId);
    _sheetByEntry.removeWhere((_, v) => v == sheetId);
    return true;
  }

  @override
  Future<TimeSheet?> signTimeSheet(String companyId, String sheetId, {required Uint8List png, String? signerName, required DateTime now}) async {
    final index = _timeSheets.indexWhere((s) => s.companyId == companyId && s.id == sheetId);
    if (index == -1) return null;
    final sheet = _timeSheets[index];
    if (sheet.isSigned) throw const BusinessConflict('Stundenzettel ist bereits unterschrieben.');
    if (!_sheetByEntry.values.contains(sheetId)) throw const BusinessConflict('Ein leerer Stundenzettel kann nicht unterschrieben werden.');
    final signed = TimeSheet(
      id: sheet.id,
      companyId: companyId,
      date: sheet.date,
      documentId: sheet.documentId,
      projectId: sheet.projectId,
      status: 'signed',
      signaturePng: png,
      signerName: signerName,
      signedAt: now,
      supersedesId: sheet.supersedesId,
      createdByUserId: sheet.createdByUserId,
      createdAt: sheet.createdAt,
    );
    _timeSheets[index] = signed;
    return signed;
  }
}
