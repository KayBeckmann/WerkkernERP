import 'dart:typed_data';

/// One stored rendering, never replaced by a later rendering or delivery.
class ArchivedPdf {
  ArchivedPdf({
    required this.companyId,
    required this.sourceType,
    required this.sourceId,
    required this.version,
    required this.createdAt,
    required this.sha256,
    required List<int> bytes,
  }) : bytes = Uint8List.fromList(bytes);

  final String companyId;
  final String sourceType;
  final String sourceId;
  final int version;
  final DateTime createdAt;
  final String sha256;
  final Uint8List bytes;

  Map<String, Object?> toJson() => {
    'version': version,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'sha256': sha256,
    'sizeBytes': bytes.length,
  };
}

/// Byte-free index entry for tenant-wide browsing.
class PdfArchiveEntry {
  const PdfArchiveEntry({required this.sourceType, required this.sourceId,
    required this.version, required this.createdAt, required this.sha256,
    required this.sizeBytes});
  final String sourceType;
  final String sourceId;
  final int version;
  final DateTime createdAt;
  final String sha256;
  final int sizeBytes;

  Map<String, Object?> toJson() => {
    'sourceType': sourceType, 'sourceId': sourceId, 'version': version,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'sha256': sha256, 'sizeBytes': sizeBytes,
  };
}

abstract interface class PdfArchiveStore {
  /// Returns at most [limit] metadata rows, after permission/owner filtering.
  Future<List<PdfArchiveEntry>> browsePdfVersions(String companyId, {
    required bool documents, required bool purchaseOrders,
    required bool allTimeSheets, String? ownTimeSheetsUserId,
    required int limit, required int offset,
  });
  Future<ArchivedPdf> archivePdf({
    required String companyId,
    required String sourceType,
    required String sourceId,
    required List<int> bytes,
    required DateTime now,
  });
  Future<List<ArchivedPdf>> listPdfVersions(
    String companyId,
    String sourceType,
    String sourceId,
  );
  Future<ArchivedPdf?> findPdfVersion(
    String companyId,
    String sourceType,
    String sourceId,
    int version,
  );
}
