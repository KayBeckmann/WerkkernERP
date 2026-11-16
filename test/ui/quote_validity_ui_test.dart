import 'package:decimal/decimal.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:werkkernerp/data/database/database.dart';
import 'package:werkkernerp/data/database/tables.dart';
import 'package:werkkernerp/data/repositories/company_repository.dart';
import 'package:werkkernerp/data/repositories/customer_repository.dart';
import 'package:werkkernerp/data/repositories/invoice_repository.dart';
import 'package:werkkernerp/data/repositories/number_sequence_repository.dart';
import 'package:werkkernerp/main.dart';
import 'package:werkkernerp/ui/widgets/quote_validity_dialog.dart' show formatValidityDate;
import 'package:werkkernerp/ui/widgets/sidebar_nav_item.dart';

/// A5-Nachtrag (Kay, 16.11.2026) offline: Bindefrist im Entwurf,
/// Anzeige nach Finalisierung, Rückfrage beim Ändern.
void main() {
  testWidgets('Angebot: Bindefrist vorbelegt, finalisiert „bindend bis“, Rückfrage Nein/Ja', (tester) async {
    tester.view.physicalSize = const Size(1400, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final db = AppDatabase.forTesting(NativeDatabase.memory(setup: (d) => d.execute('PRAGMA foreign_keys = ON;')));
    late String quoteId;
    late String companyId;
    final repo = InvoiceRepository(db, NumberSequenceRepository(db));
    await tester.runAsync(() async {
      final companies = CompanyRepository(db);
      final company = await companies.create(name: 'Nord-Impuls');
      await companies.update(company.copyWith(quotesEnabled: true));
      companyId = company.id;
      final customer = await CustomerRepository(db).create(companyId: company.id, name: 'REMONDIS');
      final draft = await repo.createDraft(
        companyId: company.id,
        customerId: customer.id,
        kind: DocumentKind.quote,
        issueDate: DateTime(2026, 11, 16),
        serviceDate: DateTime(2026, 11, 16),
        items: [
          InvoiceItemInput(kind: InvoiceItemKind.text, description: 'Außenbeleuchtung', quantity: Decimal.one, unitPriceCents: 10000, vatRatePercent: 19),
        ],
      );
      quoteId = draft.id;
    });

    await tester.pumpWidget(WerkkernErpApp(database: db));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nord-Impuls'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(SidebarNavItem, 'Angebote'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('REMONDIS').first);
    await tester.pumpAndSettle();

    // Entwurf: Firmenstandard 14 vorbelegt, auf 21 ändern.
    final field = find.byKey(const Key('quote-validity-days'));
    expect(tester.widget<TextField>(field).controller!.text, '14');
    await tester.enterText(field, '21');
    await tester.tap(find.byTooltip('Entwurf speichern'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Finalisieren'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Finalisieren'));
    await tester.pumpAndSettle();

    final now = DateTime.now();
    final until = DateTime(now.year, now.month, now.day + 21);
    expect(find.textContaining('Bindend bis ${formatValidityDate(until)}'), findsOneWidget);

    // Änderung am finalisierten Angebot: „Nein“ behält die Frist.
    await tester.tap(find.byTooltip('Änderungen speichern'));
    await tester.pumpAndSettle();
    expect(find.text('Bindefrist anpassen?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('quote-validity-keep')));
    await tester.pumpAndSettle();
    var stored = await tester.runAsync(() => repo.findById(companyId: companyId, id: quoteId));
    expect(stored!.quoteValidUntil, until);

    // „Ja“: Datum wählen (Vorschlag = bisheriges Ende) und bestätigen.
    await tester.tap(find.byTooltip('Änderungen speichern'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('quote-validity-change')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text('Neue Bindefrist bestätigen'), findsOneWidget);
    expect(find.textContaining('Bindend bis ${formatValidityDate(until)} — 21 Tage'), findsOneWidget);
    await tester.tap(find.byKey(const Key('quote-validity-confirm')));
    await tester.pumpAndSettle();
    stored = await tester.runAsync(() => repo.findById(companyId: companyId, id: quoteId));
    expect((stored!.quoteValidUntil, stored.quoteValidityDays), (until, 21));

    // Abbrechen speichert nichts.
    await tester.tap(find.byTooltip('Änderungen speichern'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Abbrechen'));
    await tester.pumpAndSettle();
    expect(find.text('Änderungen gespeichert.'), findsNothing);

    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(db.close);
  });
}
