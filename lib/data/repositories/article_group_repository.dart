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

  Future<int?> countArticles({required String companyId, required String id}) async {
    if (await findById(companyId: companyId, id: id) == null) return null;
    final count = _db.articles.id.count();
    final row = await (_db.selectOnly(_db.articles)
          ..addColumns([count])
          ..where(_db.articles.companyId.equals(companyId) & _db.articles.articleGroupId.equals(id)))
        .getSingle();
    return row.read<int>(count) ?? 0;
  }

  Future<bool> update({required String companyId, required String id, required String name, required double markupPercent}) async {
    if (name.trim().isEmpty || !markupPercent.isFinite || markupPercent < 0) throw ArgumentError('Ungültige Artikelgruppe');
    return (await (_db.update(_db.articleGroups)
          ..where((g) => g.companyId.equals(companyId) & g.id.equals(id)))
        .write(ArticleGroupsCompanion(name: Value(name.trim()), markupPercent: Value(markupPercent)))) > 0;
  }

  Future<bool> delete({required String companyId, required String id, required bool deleteArticles, required int expectedCount}) =>
      _db.transaction(() async {
        final count = await countArticles(companyId: companyId, id: id);
        if (count == null) return false;
        if (count != expectedCount) throw StateError('Artikelanzahl geändert. Bitte erneut prüfen.');
        if (deleteArticles) {
          final stocked = await (_db.select(_db.articles)..where((a) =>
              a.companyId.equals(companyId) & a.articleGroupId.equals(id) & a.stockQuantity.equals(0))).get();
          if (stocked.length != count) throw StateError('Artikel haben Bestand und können nicht gelöscht werden.');
          await (_db.delete(_db.articles)..where((a) => a.companyId.equals(companyId) & a.articleGroupId.equals(id))).go();
        } else {
          await (_db.update(_db.articles)..where((a) => a.companyId.equals(companyId) & a.articleGroupId.equals(id)))
              .write(const ArticlesCompanion(articleGroupId: Value(null)));
        }
        await (_db.delete(_db.articleGroups)..where((g) => g.companyId.equals(companyId) & g.id.equals(id))).go();
        return true;
      });

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
