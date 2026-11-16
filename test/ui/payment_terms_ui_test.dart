import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:werkkernerp/data/database/database.dart';
import 'package:werkkernerp/data/repositories/company_repository.dart';
import 'package:werkkernerp/data/repositories/customer_repository.dart';
import 'package:werkkernerp/main.dart';
import 'package:werkkernerp/ui/widgets/sidebar_nav_item.dart';

/// A2-Nachtrag (Kay, 15./16.11.2026): Zahlungsziel und Skonto im Editor.
void main() {
  testWidgets('Rechnung: Firmenstandard vorbelegt, Wechsel auf 30 Tage, Skonto netto mit Vorschau, gespeichert', (tester) async {
    tester.view.physicalSize = const Size(1400, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final db = AppDatabase.forTesting(NativeDatabase.memory(setup: (d) => d.execute('PRAGMA foreign_keys = ON;')));
    await tester.runAsync(() async {
      final company = await CompanyRepository(db).create(name: 'Nord-Impuls');
      await CompanyRepository(db).update(company.copyWith(skontoPercent: const Value(2), skontoDays: const Value(7)));
      await CustomerRepository(db).create(companyId: company.id, name: 'Baustelle Meyer');
    });
    await tester.pumpWidget(WerkkernErpApp(database: db));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nord-Impuls'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(SidebarNavItem, 'Rechnungen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Neue Rechnung'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Baustelle Meyer'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(DropdownButtonFormField<String?>, '14 Tage'), findsOneWidget);
    await tester.tap(find.text('Position hinzufügen'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Beschreibung *'), 'Montage');
    await tester.enterText(find.widgetWithText(TextField, 'Einzelpreis (€) *'), '100');
    await tester.tap(find.text('Hinzufügen'));
    await tester.pumpAndSettle();
    // Skonto aus Firmenvorgabe auf den Nettobetrag: 100 € × 2 % = 2,00 €, zu zahlen 117,00 €.
    expect(find.textContaining('2 % Skonto auf den Nettobetrag (2,00 €), zu zahlen 117,00 €'), findsOneWidget);

    await tester.tap(find.byKey(const Key('document-payment-term')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('30 Tage').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('Zahlbar innerhalb von 30 Tagen'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('document-skonto-percent')), '3');
    await tester.pumpAndSettle();
    expect(find.textContaining('3 % Skonto auf den Nettobetrag (3,00 €), zu zahlen 116,00 €'), findsOneWidget);

    await tester.tap(find.byTooltip('Entwurf speichern'));
    await tester.pumpAndSettle();
    final saved = await tester.runAsync(() async {
      final company = (await CompanyRepository(db).listAll()).single;
      return (await (db.select(db.invoices)..where((i) => i.companyId.equals(company.id))).get()).single;
    });
    expect((saved!.paymentTermLabel, saved.paymentNetDays, saved.skontoPercent, saved.skontoDays), ('30 Tage', 30, 3.0, 7));
  });
}
