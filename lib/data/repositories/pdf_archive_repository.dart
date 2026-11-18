import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../database/database.dart';

/// An archive belongs to one source namespace; IDs in different namespaces
/// never share a PDF sequence. Add new source kinds without changing storage.
enum PdfArchiveSource { customerDocument, purchaseOrder, signedTimeSheet }

class ArchivedPdf {
  const ArchivedPdf({required this.id, required this.companyId, required this.sourceType,
    required this.sourceId, required this.version, required this.createdAt});
  final String id;
  final String companyId;
  final PdfArchiveSource sourceType;
  final String sourceId;
  final int version;
  final DateTime createdAt;
}

/// Stores the PDF itself inside SQLite, so a VACUUM INTO backup carries the
/// original bytes along with all other offline data. No file-system sidecar.
/// The additive table is initialized on first use rather than modifying the
/// concurrently edited generated Drift schema/migration files.
class PdfArchiveRepository {
  PdfArchiveRepository(this._db);
  final AppDatabase _db;
  static const _uuid = Uuid();

  Future<void> _ensureTable() async {
    await _db.customStatement('''
      CREATE TABLE IF NOT EXISTS archived_pdfs (
        id TEXT NOT NULL PRIMARY KEY,
        company_id TEXT NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
        source_type TEXT NOT NULL,
        source_id TEXT NOT NULL,
        version INTEGER NOT NULL CHECK (version >= 1),
        created_at_utc TEXT NOT NULL,
        pdf_bytes BLOB NOT NULL,
        UNIQUE (company_id, source_type, source_id, version)
      )
    ''');
  }

  ArchivedPdf _fromRow(QueryRow row) => ArchivedPdf(
    id: row.read<String>('id'), companyId: row.read<String>('company_id'),
    sourceType: PdfArchiveSource.values.byName(row.read<String>('source_type')),
    sourceId: row.read<String>('source_id'), version: row.read<int>('version'),
    createdAt: DateTime.parse(row.read<String>('created_at_utc')).toUtc(),
  );

  /// Call only after *new* PDF bytes have been generated. Opening an artifact
  /// uses [readBytes] and never calls the renderer or allocates a new version.
  Future<ArchivedPdf> storeGenerated({required String companyId,
    required PdfArchiveSource sourceType, required String sourceId,
    required Uint8List bytes}) async {
    if (bytes.isEmpty) throw ArgumentError.value(bytes, 'bytes', 'PDF is empty');
    return _db.transaction(() async {
      await _ensureTable();
      final company = await _db.customSelect('SELECT id FROM companies WHERE id = ?',
        variables: [Variable.withString(companyId)]).getSingleOrNull();
      if (company == null) throw StateError('Company does not exist');
      final rows = await _db.customSelect('''
        SELECT COALESCE(MAX(version), 0) AS latest FROM archived_pdfs
        WHERE company_id = ? AND source_type = ? AND source_id = ?
      ''', variables: [Variable.withString(companyId), Variable.withString(sourceType.name),
        Variable.withString(sourceId)]).getSingle();
      final artifact = ArchivedPdf(id: _uuid.v4(), companyId: companyId,
        sourceType: sourceType, sourceId: sourceId,
        version: rows.read<int>('latest') + 1, createdAt: DateTime.now().toUtc());
      await _db.customStatement('''
        INSERT INTO archived_pdfs (id, company_id, source_type, source_id, version, created_at_utc, pdf_bytes)
        VALUES (?, ?, ?, ?, ?, ?, ?)
      ''', [artifact.id, companyId, sourceType.name, sourceId, artifact.version,
        artifact.createdAt.toIso8601String(), Uint8List.fromList(bytes)]);
      return artifact;
    });
  }

  Future<List<ArchivedPdf>> list({required String companyId,
    required PdfArchiveSource sourceType, required String sourceId}) async {
    await _ensureTable();
    final rows = await _db.customSelect('''
      SELECT id, company_id, source_type, source_id, version, created_at_utc
      FROM archived_pdfs WHERE company_id = ? AND source_type = ? AND source_id = ?
      ORDER BY version DESC
    ''', variables: [Variable.withString(companyId), Variable.withString(sourceType.name),
      Variable.withString(sourceId)]).get();
    return rows.map(_fromRow).toList();
  }

  /// Every saved rendition for this company, including disabled source modules.
  Future<List<ArchivedPdf>> listAll({required String companyId}) async {
    await _ensureTable();
    final rows = await _db.customSelect('''
      SELECT id, company_id, source_type, source_id, version, created_at_utc
      FROM archived_pdfs WHERE company_id = ?
      ORDER BY created_at_utc DESC, source_type, source_id, version DESC
    ''', variables: [Variable.withString(companyId)]).get();
    return rows.map(_fromRow).toList();
  }

  Future<Uint8List?> readBytes({required String companyId,
    required String artifactId}) async {
    await _ensureTable();
    final row = await _db.customSelect('''
      SELECT pdf_bytes FROM archived_pdfs WHERE company_id = ? AND id = ?
    ''', variables: [Variable.withString(companyId), Variable.withString(artifactId)]).getSingleOrNull();
    return row == null ? null : Uint8List.fromList(row.read<Uint8List>('pdf_bytes'));
  }
}
