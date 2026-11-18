import 'api_client.dart';

/// Byte-free metadata returned by the tenant-wide archive index.
class OnlineArchivedPdf {
  const OnlineArchivedPdf({required this.sourceType, required this.sourceId,
    required this.version, required this.createdAt, required this.sha256,
    required this.sizeBytes});

  factory OnlineArchivedPdf.fromJson(Map<String, Object?> json) => OnlineArchivedPdf(
    sourceType: json['sourceType'] as String,
    sourceId: json['sourceId'] as String,
    version: json['version'] as int,
    createdAt: DateTime.parse(json['createdAt'] as String),
    sha256: json['sha256'] as String,
    sizeBytes: json['sizeBytes'] as int,
  );

  final String sourceType;
  final String sourceId;
  final int version;
  final DateTime createdAt;
  final String sha256;
  final int sizeBytes;
}

class PdfArchivePage {
  const PdfArchivePage({required this.versions, required this.limit,
    required this.offset, required this.hasMore});
  final List<OnlineArchivedPdf> versions;
  final int limit;
  final int offset;
  final bool hasMore;
}

extension PdfArchiveApi on WerkkernApiClient {
  Future<PdfArchivePage> browsePdfArchive({int limit = 50, int offset = 0}) async {
    if (limit < 1 || limit > 100 || offset < 0) {
      throw ArgumentError('limit must be 1–100 and offset nonnegative');
    }
    final json = await request('GET', '/pdf-archive/versions', query: {
      'limit': '$limit', 'offset': '$offset',
    }) as Map<String, Object?>;
    return PdfArchivePage(
      versions: [for (final entry in json['versions'] as List)
        OnlineArchivedPdf.fromJson(entry as Map<String, Object?>)],
      limit: json['limit'] as int,
      offset: json['offset'] as int,
      hasMore: json['hasMore'] as bool,
    );
  }
}
