part of '../repository_postgres.dart';

mixin _PostgresTimeSheets implements TimeSheetStore {
  Future<Result> _q(String sql, [Map<String, Object?> parameters = const {}]);
  SessionExecutor get _db;

  static const _sheetColumns = 'id, company_id, sheet_date, document_id, project_id, status, signature_png, signer_name, '
      'signed_at, supersedes_id, created_by_user_id, created_at';

  TimeSheet _toSheet(ResultRow r) => TimeSheet(
        id: r[0] as String,
        companyId: r[1] as String,
        date: r[2] as DateTime,
        documentId: r[3] as String?,
        projectId: r[4] as String?,
        status: r[5] as String,
        signaturePng: r[6] == null ? null : Uint8List.fromList(r[6] as List<int>),
        signerName: r[7] as String?,
        signedAt: r[8] as DateTime?,
        supersedesId: r[9] as String?,
        createdByUserId: r[10] as String,
        createdAt: r[11] as DateTime,
      );

  @override
  Future<List<TimeSheet>> listTimeSheets(String companyId, {String? createdByUserId}) async {
    final result = await _q(
      'SELECT $_sheetColumns FROM time_sheets WHERE company_id = @companyId '
      'AND (@userId::text IS NULL OR created_by_user_id = @userId) ORDER BY sheet_date DESC, created_at DESC',
      {'companyId': companyId, 'userId': createdByUserId},
    );
    return [for (final r in result) _toSheet(r)];
  }

  @override
  Future<TimeSheet?> findTimeSheet(String companyId, String id) async {
    final result = await _q('SELECT $_sheetColumns FROM time_sheets WHERE company_id = @companyId AND id = @id', {
      'companyId': companyId,
      'id': id,
    });
    return result.isEmpty ? null : _toSheet(result.first);
  }

  @override
  Future<List<String>> timeSheetEntryIds(String companyId, String sheetId) async {
    final result = await _q(
      'SELECT e.entry_id FROM time_sheet_entries e JOIN time_sheets s ON s.id = e.sheet_id '
      'WHERE s.company_id = @companyId AND s.id = @sheetId ORDER BY e.entry_id',
      {'companyId': companyId, 'sheetId': sheetId},
    );
    return [for (final r in result) r[0] as String];
  }

  @override
  Future<TimeSheet?> timeSheetForEntry(String companyId, String entryId) async {
    final result = await _q(
      'SELECT s.${_sheetColumns.replaceAll(', ', ', s.')} FROM time_sheets s JOIN time_sheet_entries e ON e.sheet_id = s.id '
      'WHERE s.company_id = @companyId AND e.entry_id = @entryId',
      {'companyId': companyId, 'entryId': entryId},
    );
    return result.isEmpty ? null : _toSheet(result.first);
  }

  @override
  Future<void> createTimeSheet(TimeSheet t) async {
    await _q(
      'INSERT INTO time_sheets ($_sheetColumns) VALUES (@id, @companyId, @date, @documentId, @projectId, @status, NULL, NULL, '
      'NULL, @supersedes, @createdBy, @createdAt)',
      {
        'id': t.id,
        'companyId': t.companyId,
        'date': TypedValue(Type.date, t.date),
        'documentId': t.documentId,
        'projectId': t.projectId,
        'status': t.status,
        'supersedes': t.supersedesId,
        'createdBy': t.createdByUserId,
        'createdAt': t.createdAt,
      },
    );
  }

  Future<bool> _lockSheet(TxSession s, String companyId, String sheetId, {required String signedMessage}) async {
    final row = await s.execute(
      Sql.named('SELECT status FROM time_sheets WHERE company_id = @companyId AND id = @id FOR UPDATE'),
      parameters: {'companyId': companyId, 'id': sheetId},
    );
    if (row.isEmpty) return false;
    if (row.first[0] == 'signed') throw BusinessConflict(signedMessage);
    return true;
  }

  @override
  Future<void> addTimeSheetEntries(String companyId, String sheetId, List<String> entryIds) => _db.runTx((s) async {
        if (!await _lockSheet(s, companyId, sheetId, signedMessage: 'Stundenzettel ist unterschrieben und unveränderlich.')) return;
        for (final id in entryIds) {
          final result = await s.execute(
            Sql.named(
              'INSERT INTO time_sheet_entries (sheet_id, entry_id) VALUES (@sheetId, @entryId) '
              'ON CONFLICT (entry_id) DO UPDATE SET sheet_id = EXCLUDED.sheet_id WHERE time_sheet_entries.sheet_id = @sheetId',
            ),
            parameters: {'sheetId': sheetId, 'entryId': id},
          );
          if (result.affectedRows == 0) throw const BusinessConflict('Buchung liegt bereits auf einem anderen Stundenzettel.');
        }
      });

  @override
  Future<bool> removeTimeSheetEntry(String companyId, String sheetId, String entryId) => _db.runTx((s) async {
        if (!await _lockSheet(s, companyId, sheetId, signedMessage: 'Stundenzettel ist unterschrieben und unveränderlich.')) {
          return false;
        }
        final result = await s.execute(
          Sql.named('DELETE FROM time_sheet_entries WHERE sheet_id = @sheetId AND entry_id = @entryId'),
          parameters: {'sheetId': sheetId, 'entryId': entryId},
        );
        return result.affectedRows > 0;
      });

  @override
  Future<bool> deleteTimeSheetDraft(String companyId, String sheetId) => _db.runTx((s) async {
        if (!await _lockSheet(s, companyId, sheetId, signedMessage: 'Unterschriebene Stundenzettel bleiben als Nachweis erhalten.')) {
          return false;
        }
        await s.execute(Sql.named('DELETE FROM time_sheets WHERE id = @id'), parameters: {'id': sheetId});
        return true;
      });

  @override
  Future<TimeSheet?> signTimeSheet(String companyId, String sheetId, {required Uint8List png, String? signerName, required DateTime now}) async {
    final ok = await _db.runTx((s) async {
      if (!await _lockSheet(s, companyId, sheetId, signedMessage: 'Stundenzettel ist bereits unterschrieben.')) return false;
      final count = await s.execute(
        Sql.named('SELECT count(*) FROM time_sheet_entries WHERE sheet_id = @id'),
        parameters: {'id': sheetId},
      );
      if ((count.first[0] as int) == 0) throw const BusinessConflict('Ein leerer Stundenzettel kann nicht unterschrieben werden.');
      await s.execute(
        Sql.named("UPDATE time_sheets SET status = 'signed', signature_png = @png, signer_name = @name, signed_at = @now WHERE id = @id"),
        parameters: {'png': TypedValue(Type.byteArray, png), 'name': signerName, 'now': now, 'id': sheetId},
      );
      return true;
    });
    return ok ? findTimeSheet(companyId, sheetId) : null;
  }
}
