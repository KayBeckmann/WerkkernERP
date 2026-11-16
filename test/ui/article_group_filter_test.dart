import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:werkkernerp/data/database/database.dart';
import 'package:werkkernerp/data/repositories/article_group_repository.dart';
import 'package:werkkernerp/data/repositories/article_repository.dart';
import 'package:werkkernerp/data/repositories/company_repository.dart';
import 'package:werkkernerp/main.dart';
import 'package:werkkernerp/ui/widgets/sidebar_nav_item.dart';

/// A1-Nachtrag (Kay, 15.11.2026): Artikelübersicht nach Artikelgruppe
/// filtern — Abnahmebeispiel aus der Roadmap (Nord-Impuls), offline.
void main() {
  testWidgets('Gruppenfilter: Gruppe, leere Gruppe, ohne Gruppe, zurück auf alle, mit Suche kombinierbar', (tester) async {
    tester.view.physicalSize = const Size(1400, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final db = AppDatabase.forTesting(NativeDatabase.memory(setup: (d) => d.execute('PRAGMA foreign_keys = ON;')));

    await tester.runAsync(() async {
      final companyId = (await CompanyRepository(db).create(name: 'Nord-Impuls')).id;
      // Firmenfremde Gruppe mit gleichem Namen darf nie auftauchen.
      final other = await CompanyRepository(db).create(name: 'Fremdfirma');
      await ArticleGroupRepository(db).create(companyId: other.id, name: 'Fremdgruppe', markupPercent: 0);
      final groups = ArticleGroupRepository(db);
      final verteiler = await groups.create(companyId: companyId, name: 'Verteilereinbau', markupPercent: 30);
      final kabel = await groups.create(companyId: companyId, name: 'Kabel', markupPercent: 20);
      await groups.create(companyId: companyId, name: 'Schaltermaterial', markupPercent: 25);
      final articles = ArticleRepository(db);
      await articles.create(companyId: companyId, name: 'FI-Schalter 40A', articleGroupId: verteiler.id);
      await articles.create(companyId: companyId, name: 'LS-Schalter B16', articleGroupId: verteiler.id);
      await articles.create(companyId: companyId, name: 'NYM-J 3x1,5', articleGroupId: kabel.id);
      await articles.create(companyId: companyId, name: 'Anfahrt pauschal');
    });

    await tester.pumpWidget(WerkkernErpApp(database: db));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nord-Impuls'));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(SidebarNavItem, 'Artikel'));
    await tester.pumpAndSettle();
    expect(find.text('FI-Schalter 40A'), findsOneWidget);
    expect(find.text('Anfahrt pauschal'), findsOneWidget);

    Future<void> choose(String label) async {
      await tester.tap(find.byKey(const Key('article-group-filter')));
      await tester.pumpAndSettle();
      await tester.tap(find.text(label).last);
      await tester.pumpAndSettle();
    }

    await tester.tap(find.byKey(const Key('article-group-filter')));
    await tester.pumpAndSettle();
    expect(find.text('Fremdgruppe'), findsNothing);
    expect(find.text('Ohne Gruppe'), findsWidgets);
    await tester.tap(find.text('Verteilereinbau').last);
    await tester.pumpAndSettle();
    expect(find.text('FI-Schalter 40A'), findsOneWidget);
    expect(find.text('LS-Schalter B16'), findsOneWidget);
    expect(find.text('NYM-J 3x1,5'), findsNothing);

    await choose('Kabel');
    expect(find.text('NYM-J 3x1,5'), findsOneWidget);
    expect(find.text('FI-Schalter 40A'), findsNothing);

    await choose('Schaltermaterial');
    expect(find.text('Keine Artikel für diese Auswahl.'), findsOneWidget);

    await choose('Ohne Gruppe');
    expect(find.text('Anfahrt pauschal'), findsOneWidget);
    expect(find.text('NYM-J 3x1,5'), findsNothing);

    await choose('Alle Gruppen');
    for (final name in ['FI-Schalter 40A', 'LS-Schalter B16', 'NYM-J 3x1,5', 'Anfahrt pauschal']) {
      expect(find.text(name), findsOneWidget);
    }

    // Kombination mit der Suche.
    await choose('Verteilereinbau');
    await tester.enterText(find.byKey(const Key('article-search')), 'ls-');
    await tester.pumpAndSettle();
    expect(find.text('LS-Schalter B16'), findsOneWidget);
    expect(find.text('FI-Schalter 40A'), findsNothing);
  });
}
