import 'package:drift/drift.dart' show Value;
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
import 'package:werkkernerp/main.dart';
import 'package:werkkernerp/ui/widgets/barcode_scanner.dart';
import 'package:werkkernerp/ui/widgets/sidebar_nav_item.dart';

/// A1-Nachtrag (Barcode im Artikelstamm) und C5.5-Nachtrag (Scan auf der
/// Baustelle), Kay 16.11.2026 — offline.
void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory(setup: (d) => d.execute('PRAGMA foreign_keys = ON;'))));

  test('Barcode: Text mit führender Null, je Firma eindeutig, fremde Firma kein Treffer', () async {
    final companies = CompanyRepository(db);
    final a = await companies.create(name: 'Nord-Impuls');
    final b = await companies.create(name: 'Fremdfirma');
    final articles = ArticleRepository(db);
    final fi = await articles.create(companyId: a.id, name: 'FI-Schalter', barcode: ' 04012345 678901 ');
    expect(fi.barcode, '04012345678901');
    expect((await articles.findByBarcode(companyId: a.id, barcode: '04012345678901'))!.id, fi.id);
    expect(await articles.findByBarcode(companyId: b.id, barcode: '04012345678901'), isNull);
    await expectLater(
      articles.create(companyId: a.id, name: 'Doppelt', barcode: '04012345678901'),
      throwsA(isA<BarcodeInUseException>()),
    );
    // Gleicher Code in anderer Firma ist erlaubt.
    final other = await articles.create(companyId: b.id, name: 'Fremd', barcode: '04012345678901');
    expect(other.barcode, '04012345678901');
    final ls = await articles.create(companyId: a.id, name: 'LS-Schalter');
    await expectLater(
      articles.update(companyId: a.id, id: ls.id, barcode: const Value('04012345678901')),
      throwsA(isA<BarcodeInUseException>()),
    );
    // Entfernen und eigener Code beim Speichern bleiben möglich.
    await articles.update(companyId: a.id, id: fi.id, barcode: const Value('04012345678901'));
    expect((await articles.update(companyId: a.id, id: fi.id, barcode: const Value('  ')))!.barcode, isNull);
    await db.close();
  });

  testWidgets('Scan im Auftrag: Menge und Gruppe, gleiche Gruppe addieren/neu, andere Gruppe neu, unbekannt → manuell',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final codes = <String>[];
    barcodeScanner = (_) async => codes.removeAt(0);
    addTearDown(() => barcodeScanner = (_) async => null);

    late String orderId;
    late String companyId;
    await tester.runAsync(() async {
      final companies = CompanyRepository(db);
      var company = await companies.create(name: 'Nord-Impuls');
      await companies.update(company.copyWith(ordersEnabled: true));
      companyId = company.id;
      await ArticleRepository(db).create(companyId: company.id, name: 'NYM-J 3x1,5', unit: 'm', barcode: '0401', manualSalePriceCents: 120);
      final customer = await CustomerRepository(db).create(companyId: company.id, name: 'Baustelle Meyer');
      orderId = (await InvoiceRepository(db, NumberSequenceRepository(db)).createDraft(
        companyId: company.id,
        customerId: customer.id,
        kind: DocumentKind.order,
        issueDate: DateTime(2026, 11, 16),
        serviceDate: DateTime(2026, 11, 16),
      )).id;
    });

    await tester.pumpWidget(WerkkernErpApp(database: db));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nord-Impuls'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(SidebarNavItem, 'Aufträge'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Baustelle Meyer').first);
    await tester.pumpAndSettle();

    Future<void> scan(String code, {String? quantity, String? group, String? button}) async {
      codes.add(code);
      await tester.tap(find.byTooltip('Barcode scannen'));
      await tester.pumpAndSettle();
      if (quantity == null) return;
      await tester.enterText(find.byKey(const Key('scan-quantity')), quantity);
      if (group != null) await tester.enterText(find.byKey(const Key('scan-group')), group);
      await tester.pumpAndSettle();
      await tester.tap(find.text(button ?? 'Hinzufügen'));
      await tester.pumpAndSettle();
    }

    // Menge ist Pflicht — ohne Eingabe keine Position.
    codes.add('0401');
    await tester.tap(find.byTooltip('Barcode scannen'));
    await tester.pumpAndSettle();
    expect(find.text('Artikel erkannt'), findsOneWidget);
    expect(find.text('Einheit: m'), findsOneWidget);
    await tester.tap(find.text('Hinzufügen'));
    await tester.pumpAndSettle();
    expect(find.text('Bitte die verbaute Menge eingeben (größer 0).'), findsOneWidget);
    await tester.tap(find.text('Abbrechen'));
    await tester.pumpAndSettle();

    await scan('0401', quantity: '25', group: 'Küche');
    expect(find.textContaining('25 m × 1,20 € · '), findsOneWidget);
    // Gleiche Gruppe: Rückfrage → addieren.
    await scan('0401', quantity: '5', group: 'Küche', button: 'Zur Position addieren');
    expect(find.textContaining('30 m × 1,20 € · '), findsOneWidget);
    // Gleiche Gruppe: als neue Position.
    await scan('0401', quantity: '2', group: 'Küche', button: 'Als neue Position');
    expect(find.textContaining('2 m × 1,20 € · '), findsOneWidget);
    // Andere Gruppe: ohne Rückfrage eigene Position.
    await scan('0401', quantity: '10', group: 'Bad');
    expect(find.textContaining('10 m × 1,20 € · '), findsOneWidget);

    // Unbekannter Code: keine Position, Hinweis, manuelle Auswahl öffnet sich.
    await scan('9999');
    expect(find.text('Position hinzufügen'), findsWidgets);
    await tester.tap(find.text('Abbrechen'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Entwurf speichern'));
    await tester.pumpAndSettle();
    final items = await tester.runAsync(() => InvoiceRepository(db, NumberSequenceRepository(db)).itemsFor(orderId));
    expect(
      [for (final i in items!) (i.quantity, i.groupLabel, i.kind)],
      unorderedEquals([
        ('30', 'Küche', InvoiceItemKind.article),
        ('2', 'Küche', InvoiceItemKind.article),
        ('10', 'Bad', InvoiceItemKind.article),
      ]),
    );
    // Kein Lagerabgang durch den Scan.
    final article = await tester.runAsync(
      () => ArticleRepository(db).findByBarcode(companyId: companyId, barcode: '0401'),
    );
    expect(article!.stockQuantity, 0);
  });
}
