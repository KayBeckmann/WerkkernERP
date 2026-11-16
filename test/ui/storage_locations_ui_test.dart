import 'package:decimal/decimal.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:werkkernerp/data/database/database.dart';
import 'package:werkkernerp/data/database/tables.dart';
import 'package:werkkernerp/data/repositories/article_repository.dart';
import 'package:werkkernerp/data/repositories/company_repository.dart';
import 'package:werkkernerp/data/repositories/customer_repository.dart';
import 'package:werkkernerp/data/repositories/invoice_repository.dart';
import 'package:werkkernerp/data/repositories/number_sequence_repository.dart';
import 'package:werkkernerp/data/repositories/stock_ledger.dart';
import 'package:werkkernerp/main.dart';
import 'package:werkkernerp/ui/widgets/sidebar_nav_item.dart';

/// C5.4-Nachtrag (Kay, 16.11.2026) offline: Lagerort und Platz anlegen,
/// Altbestand umlagern, Entnahme mit Platzvorschlag, Inventur nach
/// Lagerort Platz für Platz.
void main() {
  testWidgets('Lagerorte: anlegen, umlagern, Entnahme-Vorschlag, Inventur nach Lagerort', (tester) async {
    tester.view.physicalSize = const Size(1400, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final db = AppDatabase.forTesting(NativeDatabase.memory(setup: (d) => d.execute('PRAGMA foreign_keys = ON;')));
    late String companyId;
    late String articleId;
    late String orderId;
    await tester.runAsync(() async {
      final companies = CompanyRepository(db);
      final company = await companies.create(name: 'Nord-Impuls');
      await companies.update(company.copyWith(ordersEnabled: true, lagerbestandEnabled: true));
      companyId = company.id;
      final articles = ArticleRepository(db);
      final a = await articles.create(companyId: company.id, name: 'Abzweigdose', manualSalePriceCents: 150);
      await articles.setStock(companyId: company.id, id: a.id, newQuantity: 5);
      articleId = a.id;
      final customer = await CustomerRepository(db).create(companyId: company.id, name: 'Baustelle Meyer');
      orderId = (await InvoiceRepository(db, NumberSequenceRepository(db)).createDraft(
        companyId: company.id,
        customerId: customer.id,
        kind: DocumentKind.order,
        issueDate: DateTime(2026, 11, 16),
        serviceDate: DateTime(2026, 11, 16),
        items: [
          InvoiceItemInput(
            kind: InvoiceItemKind.article,
            articleId: a.id,
            description: 'Abzweigdose',
            quantity: Decimal.fromInt(2),
            unitPriceCents: 150,
            vatRatePercent: 19,
          ),
        ],
      )).id;
    });

    await tester.pumpWidget(WerkkernErpApp(database: db));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nord-Impuls'));
    await tester.pumpAndSettle();

    // Lagerort und Platz anlegen (über Inventur → Lagerorte & Plätze).
    await tester.tap(find.widgetWithText(SidebarNavItem, 'Inventur'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open-storage-locations')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lagerort anlegen'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('storage-location-name')), 'Lager');
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Platz anlegen').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('bin-row')), '1');
    await tester.enterText(find.byKey(const Key('bin-compartment')), '2');
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();
    expect(find.text('Reihe 1 / Fach 2'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    // Artikel: Altbestand „nicht zugeordnet“ → umlagern.
    await tester.tap(find.widgetWithText(SidebarNavItem, 'Artikel'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Abzweigdose'));
    await tester.pumpAndSettle();
    expect(find.text('Platz noch nicht zugeordnet: 5'), findsOneWidget);
    await tester.tap(find.byKey(const Key('article-transfer')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('transfer-quantity')), '5');
    await tester.tap(find.widgetWithText(FilledButton, 'Umlagern'));
    await tester.pumpAndSettle();
    expect(find.text('Lager · Reihe 1 / Fach 2: 5'), findsOneWidget);
    expect(find.text('Platz noch nicht zugeordnet: 5'), findsNothing);
    await tester.pageBack();
    await tester.pumpAndSettle();

    // Auftrag finalisieren: Entnahme-Dialog schlägt den Platz vor.
    await tester.tap(find.widgetWithText(SidebarNavItem, 'Aufträge'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Baustelle Meyer').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Finalisieren'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Finalisieren'));
    await tester.pumpAndSettle();
    expect(find.text('Entnahme aus Lagerplatz'), findsOneWidget);
    expect(find.text('Lager · Reihe 1 / Fach 2 (5)'), findsOneWidget);
    await tester.tap(find.text('Weiter'));
    await tester.pumpAndSettle();
    final ledger = StockLedger(db);
    final afterOrder = await tester.runAsync(() => ledger.stocksFor(companyId: companyId, articleId: articleId));
    expect([for (final s in afterOrder!) (s.label, s.quantity)], [('Lager · Reihe 1 / Fach 2', 3.0)]);
    final order = await tester.runAsync(
      () => InvoiceRepository(db, NumberSequenceRepository(db)).findById(companyId: companyId, id: orderId),
    );
    expect(order!.status, InvoiceStatus.finalized);

    // Inventur nach Lagerort: Platz für Platz, Zählung 4 bucht +1 am Platz.
    await tester.tap(find.widgetWithText(SidebarNavItem, 'Inventur'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Neue Inventur'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Bezeichnung *'), 'Lager 11/2026');
    await tester.tap(find.byKey(const Key('inventory-location')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lagerort Lager (Platz für Platz)').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Starten'));
    await tester.pumpAndSettle();
    expect(find.text('Reihe 1 / Fach 2'), findsOneWidget);
    expect(find.text('Soll: 3'), findsOneWidget);
    await tester.enterText(find.byWidgetPredicate((w) => w is TextField && w.key.toString().contains('inventory-count-')), '4');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('inventory-complete')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Abschließen'));
    await tester.pumpAndSettle();
    final afterCount = await tester.runAsync(() => ledger.stocksFor(companyId: companyId, articleId: articleId));
    expect([for (final s in afterCount!) s.quantity], [4.0]);
    final article = await tester.runAsync(() => ArticleRepository(db).findById(companyId: companyId, id: articleId));
    expect(article!.stockQuantity, 4);

    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(db.close);
  });
}
