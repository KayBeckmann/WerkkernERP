import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../database/database.dart';

/// Artikelgruppen (Stamm-/Preisgruppen mit prozentualem Aufschlag) je
/// Firma — ungleich den Positionsgruppen einer Rechnung.
class ArticleGroupRepository {
  ArticleGroupRepository(this._db);

  final AppDatabase _db;
  static const _uuid = Uuid();

  Future<List<ArticleGroup>> listForCompany(String companyId) =>
      (_db.select(_db.articleGroups)..where((g) => g.companyId.equals(companyId))).get();

  Future<ArticleGroup?> findById({required String companyId, required String id}) =>
      (_db.select(_db.articleGroups)
            ..where((g) => g.id.equals(id) & g.companyId.equals(companyId)))
          .getSingleOrNull();

  Future<ArticleGroup> create({
    required String companyId,
    required String name,
    required double markupPercent,
  }) async {
    final id = _uuid.v4();
    await _db.into(_db.articleGroups).insert(
          ArticleGroupsCompanion.insert(
            id: id,
            companyId: companyId,
            name: name,
            markupPercent: markupPercent,
            createdAt: DateTime.now(),
          ),
        );
    return (await findById(companyId: companyId, id: id))!;
  }
}
