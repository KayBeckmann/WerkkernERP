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
import 'package:werkkernerp/data/repositories/staff_role_repository.dart';
import 'package:werkkernerp/data/repositories/time_entry_repository.dart';
import 'package:werkkernerp/main.dart';
import 'package:werkkernerp/ui/widgets/sidebar_nav_item.dart';

/// C3.4 (Nachtrag 2026-11-03): „Aktuell sehe ich ‚nur‘, dass 2h gebucht
/// wurden, aber nicht auf welche Rolle.“ — Auftrag zeigt geplant/gebucht
/// je Rolle, die daraus erzeugte Rechnung eine Position je Rolle.
AppDatabase _inMemoryDb() =>
    AppDatabase.forTesting(NativeDatabase.memory(setup: (db) => db.execute('PRAGMA foreign_keys = ON;')));

void main() {
  testWidgets('Auftrag zeigt Stunden je Rolle; Umwandeln erzeugt eine Position je Rolle', (tester) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final db = _inMemoryDb();

    await tester.runAsync(() async {
      final companies = CompanyRepository(db);
      final company = await companies.create(name: 'Elektro Beckmann');
      await companies.update(company.copyWith(ordersEnabled: true, timeTrackingEnabled: true));
      final customer = await CustomerRepository(db).create(companyId: company.id, name: 'Meyer');
      final roles = StaffRoleRepository(db);
      final monteur = await roles.create(companyId: company.id, name: 'Monteur', hourlyBillingRateCents: 6500);
      final meister = await roles.create(companyId: company.id, name: 'Meister', hourlyBillingRateCents: 8500);
      final invoices = InvoiceRepository(db, NumberSequenceRepository(db));
      final draft = await invoices.createDraft(
        companyId: company.id,
        customerId: customer.id,
        kind: DocumentKind.order,
        issueDate: DateTime.now(),
        serviceDate: DateTime.now(),
        items: [
          InvoiceItemInput(
            kind: InvoiceItemKind.hours,
            description: 'Monteur',
            quantity: Decimal.parse('6'),
            unitPriceCents: 6000,
            vatRatePercent: 19,
            unit: 'h',
            staffRoleId: monteur.id,
          ),
        ],
      );
      final order = (await invoices.finalize(companyId: company.id, id: draft.id))!;
      final times = TimeEntryRepository(db);
      for (final (hours, role) in [(4.0, monteur.id), (3.5, monteur.id), (2.0, meister.id)]) {
        await times.create(companyId: company.id, date: DateTime.now(), hours: hours, staffRoleId: role, invoiceId: order.id);
      }
    });

    await tester.pumpWidget(WerkkernErpApp(database: db));
    await tester.pumpAndSettle();
    if (find.text('Elektro Beckmann').evaluate().isNotEmpty && find.byType(SidebarNavItem).evaluate().isEmpty) {
      await tester.tap(find.text('Elektro Beckmann'));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.widgetWithText(SidebarNavItem, 'Aufträge'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('A-').first);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('hours-by-role')), findsOneWidget);
    expect(find.text('Monteur: geplant 6 h · gebucht 7,5 h'), findsOneWidget);
    expect(find.text('Meister: geplant 0 h · gebucht 2 h'), findsOneWidget);

    await tester.tap(find.byTooltip('Umwandeln'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('In Rechnung umwandeln'));
    await tester.pumpAndSettle();

    expect(find.text('Monteur – geleistete Stunden (Ist-Zeit)'), findsOneWidget);
    expect(find.text('7.5 h × 60,00 € · 19 % MwSt.'), findsOneWidget);
    expect(find.text('Meister – geleistete Stunden (Ist-Zeit)'), findsOneWidget);
    expect(find.text('2 h × 85,00 € · 19 % MwSt.'), findsOneWidget);
    expect(find.text('Monteur: berechnet 7,5 h · gebucht 7,5 h'), findsOneWidget);
    expect(find.text('Meister: berechnet 2 h · gebucht 2 h'), findsOneWidget);
  });
}
