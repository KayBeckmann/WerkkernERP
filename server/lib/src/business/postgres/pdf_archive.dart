part of '../repository_postgres.dart';

mixin _PostgresPdfArchive {
  SessionExecutor get _db;
  Future<Result> _q(String sql, [Map<String, Object?> parameters]);

  Future<List<PdfArchiveEntry>> browsePdfVersions(String companyId, {
    required bool documents, required bool purchaseOrders,
    required bool allTimeSheets, String? ownTimeSheetsUserId,
    required int limit, required int offset,
  }) async {
    final rows = await _q('''
      SELECT a.source_type, a.source_id, a.version, a.created_at, a.sha256,
             octet_length(a.pdf_bytes)
      FROM pdf_archive a
      WHERE a.company_id = @companyId AND (
        (a.source_type = 'document' AND @documents) OR
        (a.source_type = 'purchase-order' AND @purchaseOrders) OR
        (a.source_type = 'time-sheet' AND (
          @allTimeSheets OR (@ownUser::text IS NOT NULL AND EXISTS (
            SELECT 1 FROM time_sheets s WHERE s.company_id = a.company_id
              AND s.id = a.source_id AND s.created_by_user_id = @ownUser
          ))))
      )
      ORDER BY a.created_at DESC, a.source_type, a.source_id, a.version DESC
      LIMIT @limit OFFSET @offset
    ''', {
      'companyId': companyId, 'documents': documents,
      'purchaseOrders': purchaseOrders, 'allTimeSheets': allTimeSheets,
      'ownUser': ownTimeSheetsUserId, 'limit': limit, 'offset': offset,
    });
    return [for (final r in rows) PdfArchiveEntry(
      sourceType: r[0] as String, sourceId: r[1] as String,
      version: r[2] as int, createdAt: r[3] as DateTime,
      sha256: r[4] as String, sizeBytes: r[5] as int,
    )];
  }

  ArchivedPdf _pdfRow(ResultRow r) => ArchivedPdf(
    companyId: r[0] as String,
    sourceType: r[1] as String,
    sourceId: r[2] as String,
    version: r[3] as int,
    createdAt: r[4] as DateTime,
    sha256: r[5] as String,
    bytes: r[6] as List<int>,
  );

  Future<ArchivedPdf> archivePdf({
    required String companyId,
    required String sourceType,
    required String sourceId,
    required List<int> bytes,
    required DateTime now,
  }) => _db.runTx((tx) async {
    // Serialize version allocation within the tenant even for concurrent renders.
    await tx.execute(
      Sql.named('SELECT id FROM companies WHERE id = @companyId FOR UPDATE'),
      parameters: {'companyId': companyId},
    );
    final result = await tx.execute(
      Sql.named('''
      INSERT INTO pdf_archive (company_id, source_type, source_id, version, created_at, sha256, pdf_bytes)
      SELECT @companyId, @type, @id,
        coalesce((SELECT max(version) FROM pdf_archive WHERE company_id = @companyId AND source_type = @type AND source_id = @id), 0) + 1,
        @now, @hash, @bytes
      RETURNING company_id, source_type, source_id, version, created_at, sha256, pdf_bytes
    '''),
      parameters: {
        'companyId': companyId,
        'type': sourceType,
        'id': sourceId,
        'now': now,
        'hash': sha256.convert(bytes).toString(),
        'bytes': Uint8List.fromList(bytes),
      },
    );
    return _pdfRow(result.single);
  });

  Future<List<ArchivedPdf>> listPdfVersions(
    String companyId,
    String sourceType,
    String sourceId,
  ) async {
    final rows = await _q(
      'SELECT company_id, source_type, source_id, version, created_at, sha256, pdf_bytes FROM pdf_archive WHERE company_id = @companyId AND source_type = @type AND source_id = @id ORDER BY version',
      {'companyId': companyId, 'type': sourceType, 'id': sourceId},
    );
    return rows.map(_pdfRow).toList();
  }

  Future<ArchivedPdf?> findPdfVersion(
    String companyId,
    String sourceType,
    String sourceId,
    int version,
  ) async {
    final rows = await _q(
      'SELECT company_id, source_type, source_id, version, created_at, sha256, pdf_bytes FROM pdf_archive WHERE company_id = @companyId AND source_type = @type AND source_id = @id AND version = @version',
      {
        'companyId': companyId,
        'type': sourceType,
        'id': sourceId,
        'version': version,
      },
    );
    return rows.isEmpty ? null : _pdfRow(rows.single);
  }
}
