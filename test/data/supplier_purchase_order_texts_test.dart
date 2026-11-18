import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:werkkernerp/data/database/database.dart';
import 'package:werkkernerp/data/repositories/company_repository.dart';
import 'package:werkkernerp/data/migration/migration_package_builder.dart';
import 'package:werkkernerp/domain/services/active_company_service.dart';
import 'package:werkkernerp/ui/screens/settings_document_texts_screen.dart';

void main() {
  test('Lieferanten-Bestelltexte werden unabhängig vom Kundenauftrag gespeichert', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final companies = CompanyRepository(db);
    final company = await companies.create(name: 'Testfirma');
    await companies.update(company.copyWith(
      pdfIntroTextOrder: const Value('Kunden-Einleitung'),
      pdfClosingTextOrder: const Value('Kunden-Schluss'),
      pdfIntroTextPurchaseOrder: const Value('Bitte liefern'),
      pdfClosingTextPurchaseOrder: const Value('Mit freundlichen Grüßen'),
    ));
    final saved = (await companies.findById(company.id))!;
    expect(saved.pdfIntroTextPurchaseOrder, 'Bitte liefern');
    expect(saved.pdfClosingTextPurchaseOrder, 'Mit freundlichen Grüßen');
    expect(saved.pdfIntroTextOrder, 'Kunden-Einleitung');
    expect(saved.pdfClosingTextOrder, 'Kunden-Schluss');
  });

  test('Migration v42→v43 erhält Kundenauftrag und ergänzt leere Lieferantentexte', () async {
    final directory = await Directory.systemTemp.createTemp('purchase_text_migration_');
    addTearDown(() => directory.delete(recursive: true));
    final file = File(p.join(directory.path, 'company.sqlite'));
    var db = AppDatabase.forTesting(NativeDatabase(file));
    final company = await CompanyRepository(db).create(name: 'Bestandsfirma');
    await CompanyRepository(db).update(company.copyWith(pdfIntroTextOrder: const Value('Kundenauftrag')));
    await db.close();
    final raw = sqlite3.open(file.path);
    raw.execute('ALTER TABLE companies DROP COLUMN pdf_intro_text_purchase_order');
    raw.execute('ALTER TABLE companies DROP COLUMN pdf_closing_text_purchase_order');
    raw.execute('PRAGMA user_version = 42');
    raw.close();
    db = AppDatabase.forTesting(NativeDatabase(file));
    final upgraded = (await CompanyRepository(db).findById(company.id))!;
    expect(upgraded.pdfIntroTextOrder, 'Kundenauftrag');
    expect(upgraded.pdfIntroTextPurchaseOrder, isNull);
    await db.close();
  });

  test('Umzugspaket überträgt Lieferantenbestellung separat vom Kundenauftrag', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = CompanyRepository(db);
    final company = await repo.create(name: 'Testfirma');
    await repo.update(company.copyWith(
      pdfIntroTextOrder: const Value('Kundenauftrag'),
      pdfIntroTextPurchaseOrder: const Value('Lieferantenbestellung'),
      pdfClosingTextPurchaseOrder: const Value('Vielen Dank'),
    ));
    final package = await MigrationPackageBuilder(db).build(company.id);
    final texts = (package['company'] as Map)['documentTexts'] as Map;
    expect(texts['purchaseOrder'], {'intro': 'Lieferantenbestellung', 'closing': 'Vielen Dank'});
    expect((texts['order'] as Map)['intro'], 'Kundenauftrag');
  });

  testWidgets('Dokumenttexte: Lieferantenbestellung bearbeitbar und unabhängig vom Auftrag', (tester) async {
    tester.view.physicalSize = const Size(1200, 1900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final repository = CompanyRepository(db);
    var company = await repository.create(name: 'Testfirma');
    await repository.update(company.copyWith(bestellwesenEnabled: true, ordersEnabled: true));
    company = (await repository.findById(company.id))!;
    final active = ActiveCompanyService(repository)..select(company);
    await tester.pumpWidget(MultiProvider(
      providers: [Provider<CompanyRepository>.value(value: repository), ChangeNotifierProvider<ActiveCompanyService>.value(value: active)],
      child: const MaterialApp(home: SettingsDocumentTextsScreen()),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Lieferantenbestellung (Bestellungen)'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('purchase-order-intro')), 'Bitte liefern');
    await tester.enterText(find.byKey(const Key('purchase-order-closing')), 'Danke');
    await tester.ensureVisible(find.text('Speichern'));
    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();
    final saved = (await repository.findById(company.id))!;
    expect(saved.pdfIntroTextPurchaseOrder, 'Bitte liefern');
    expect(saved.pdfClosingTextPurchaseOrder, 'Danke');
    expect(saved.pdfIntroTextOrder, isNull);
  });
}