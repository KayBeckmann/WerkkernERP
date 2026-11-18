part of '../repository_memory.dart';

mixin _InMemoryPdfArchive {
  final List<ArchivedPdf> _pdfVersions = [];

  Future<List<PdfArchiveEntry>> browsePdfVersions(String companyId, {
    required bool documents, required bool purchaseOrders,
    required bool allTimeSheets, String? ownTimeSheetsUserId,
    required int limit, required int offset,
  }) async {
    final visible = <ArchivedPdf>[];
    for (final pdf in _pdfVersions.where((p) => p.companyId == companyId)) {
      if (pdf.sourceType == 'document' && documents ||
          pdf.sourceType == 'purchase-order' && purchaseOrders ||
          pdf.sourceType == 'time-sheet' && (allTimeSheets ||
              ownTimeSheetsUserId != null &&
              (await (this as BusinessRepository).findTimeSheet(companyId, pdf.sourceId))?.createdByUserId == ownTimeSheetsUserId)) {
        visible.add(pdf);
      }
    }
    visible.sort((a, b) {
      final date = b.createdAt.compareTo(a.createdAt);
      if (date != 0) return date;
      final type = a.sourceType.compareTo(b.sourceType);
      if (type != 0) return type;
      final id = a.sourceId.compareTo(b.sourceId);
      return id != 0 ? id : b.version.compareTo(a.version);
    });
    return [for (final p in visible.skip(offset).take(limit)) PdfArchiveEntry(
      sourceType: p.sourceType, sourceId: p.sourceId, version: p.version,
      createdAt: p.createdAt, sha256: p.sha256, sizeBytes: p.bytes.length,
    )];
  }

  Future<ArchivedPdf> archivePdf({
    required String companyId,
    required String sourceType,
    required String sourceId,
    required List<int> bytes,
    required DateTime now,
  }) async {
    final version =
        _pdfVersions
            .where(
              (v) =>
                  v.companyId == companyId &&
                  v.sourceType == sourceType &&
                  v.sourceId == sourceId,
            )
            .length +
        1;
    final pdf = ArchivedPdf(
      companyId: companyId,
      sourceType: sourceType,
      sourceId: sourceId,
      version: version,
      createdAt: now,
      sha256: sha256.convert(bytes).toString(),
      bytes: bytes,
    );
    _pdfVersions.add(pdf);
    return pdf;
  }

  Future<List<ArchivedPdf>> listPdfVersions(
    String companyId,
    String sourceType,
    String sourceId,
  ) async => _pdfVersions
      .where(
        (v) =>
            v.companyId == companyId &&
            v.sourceType == sourceType &&
            v.sourceId == sourceId,
      )
      .toList();

  Future<ArchivedPdf?> findPdfVersion(
    String companyId,
    String sourceType,
    String sourceId,
    int version,
  ) async => _pdfVersions
      .where(
        (v) =>
            v.companyId == companyId &&
            v.sourceType == sourceType &&
            v.sourceId == sourceId &&
            v.version == version,
      )
      .firstOrNull;
}
