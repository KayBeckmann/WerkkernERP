import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:werkkernerp/data/database/database.dart';
import 'package:werkkernerp/data/repositories/article_repository.dart';
import 'package:werkkernerp/data/repositories/company_repository.dart';
import 'package:werkkernerp/domain/services/active_company_service.dart';
import 'package:werkkernerp/domain/services/stock_change_notifier.dart';
import 'package:werkkernerp/ui/screens/articles_screen.dart';

/// Bugfix 2026-10-19 (Kay: "Wenn ich den Bestand aus einer Bestellung
/// buche, wird dieser nicht angezeigt") — der eigentliche Mechanismus
/// hinter dem Fix ist `StockChangeNotifier` (siehe Doc-Kommentar dort):
/// jede Stelle, die den Lagerbestand ändert, pingt ihn an, und
/// `ArticlesScreen` hört darauf statt sich nur auf eine lokale Aktion
/// zu verlassen. Dieser Test prüft genau diesen Mechanismus direkt und
/// gezielt (`ArticlesScreen` + Repository + Notifier, ohne die
/// komplette App/Bestellungen-UI nachzubauen) — der Bestand wird hier
/// absichtlich NICHT über eine eigene Aktion DIESES Screens verändert
/// (das würde den eigentlichen Bugfix gar nicht prüfen), sondern "von
/// außen" über das Repository, exakt wie es `PurchaseOrderRepository.
/// receiveGoods()` in der echten App tut.
void main() {
  testWidgets(
    'Ein von außen (z. B. über eine Bestellung) gebuchter Bestand erscheint im bereits '
    'angezeigten Artikel-Tab, ohne dass der Screen selbst etwas unternimmt',
    (tester) async {
      final db = AppDatabase.forTesting(
        NativeDatabase.memory(setup: (d) => d.execute('PRAGMA foreign_keys = ON;')),
      );
      addTearDown(db.close);
      final companyRepo = CompanyRepository(db);
      final articleRepo = ArticleRepository(db);

      final company = await companyRepo.create(name: 'Elektro Beckmann');
      await companyRepo.update(company.copyWith(lagerbestandEnabled: true));
      final article = await articleRepo.create(companyId: company.id, name: 'Schraube');

      final activeCompanyService = ActiveCompanyService(companyRepo);
      activeCompanyService.select((await companyRepo.findById(company.id))!);
      final stockChangeNotifier = StockChangeNotifier();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<ArticleRepository>.value(value: articleRepo),
            ChangeNotifierProvider<ActiveCompanyService>.value(value: activeCompanyService),
            ChangeNotifierProvider<StockChangeNotifier>.value(value: stockChangeNotifier),
          ],
          child: const MaterialApp(home: ArticlesScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('Bestand: 0'), findsOneWidget);

      // Entspricht genau dem, was `PurchaseOrderRepository.
      // receiveGoods()` beim Wareneingang tut: den Bestand über das
      // Repository ändern, DANACH den Notifier anpingen — exakt wie
      // `PurchaseOrderDetailScreen._receiveGoods()` es nach einem
      // erfolgreichen Wareneingang tut.
      await articleRepo.setStock(companyId: company.id, id: article.id, newQuantity: 7);
      stockChangeNotifier.notifyStockChanged();
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Bestand: 7'),
        findsOneWidget,
        reason: 'StockChangeNotifier muss den bereits angezeigten Artikel-Tab neu laden',
      );
    },
  );
}
