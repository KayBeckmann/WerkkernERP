import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:werkkernerp/data/database/database.dart';
import 'package:werkkernerp/data/repositories/article_group_repository.dart';
import 'package:werkkernerp/data/repositories/article_repository.dart';
import 'package:werkkernerp/data/repositories/company_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory(setup: (d) => d.execute('PRAGMA foreign_keys = ON;'))));
  tearDown(() => db.close());

  test('count guard and both choices are tenant-scoped and atomic', () async {
    final companies = CompanyRepository(db);
    final a = await companies.create(name: 'A');
    final b = await companies.create(name: 'B');
    final groups = ArticleGroupRepository(db);
    final articles = ArticleRepository(db);
    final g = await groups.create(companyId: a.id, name: 'G', markupPercent: 10);
    final item = await articles.create(companyId: a.id, name: 'Teil', articleGroupId: g.id, manualSalePriceCents: 1234);
    expect(await groups.countArticles(companyId: b.id, id: g.id), isNull);
    expect(await groups.delete(companyId: b.id, id: g.id, deleteArticles: true, expectedCount: 1), false);
    expect(await groups.countArticles(companyId: a.id, id: g.id), 1);
    await expectLater(groups.delete(companyId: a.id, id: g.id, deleteArticles: true, expectedCount: 0), throwsStateError);
    expect(await groups.findById(companyId: a.id, id: g.id), isNotNull);
    expect(await groups.delete(companyId: a.id, id: g.id, deleteArticles: false, expectedCount: 1), true);
    final kept = await articles.findById(companyId: a.id, id: item.id);
    expect(kept?.articleGroupId, isNull);
    expect(kept?.manualSalePriceCents, 1234);
    final next = await groups.create(companyId: a.id, name: 'Next', markupPercent: 0);
    final doomed = await articles.create(companyId: a.id, name: 'Doomed', articleGroupId: next.id);
    expect(await groups.delete(companyId: a.id, id: next.id, deleteArticles: true, expectedCount: 1), true);
    expect(await articles.findById(companyId: a.id, id: doomed.id), isNull);
  });

  test('nonzero stock blocks destructive choice without deleting the group', () async {
    final company = await CompanyRepository(db).create(name: 'Stock');
    final groups = ArticleGroupRepository(db);
    final articles = ArticleRepository(db);
    final group = await groups.create(companyId: company.id, name: 'Material', markupPercent: 0);
    final item = await articles.create(companyId: company.id, name: 'Kabel', articleGroupId: group.id);
    await articles.setStock(companyId: company.id, id: item.id, newQuantity: 5);
    await expectLater(groups.delete(companyId: company.id, id: group.id,
        deleteArticles: true, expectedCount: 1), throwsStateError);
    expect(await groups.countArticles(companyId: company.id, id: group.id), 1);
    expect((await articles.findById(companyId: company.id, id: item.id))?.stockQuantity, 5);
  });
}
