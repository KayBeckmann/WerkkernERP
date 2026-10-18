import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' show Value;
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
import 'package:werkkernerp/ui/widgets/sidebar_nav_item.dart';

/// C14.4 Bankabgleich (Kay-Priorisierungsentscheidung 2026-10-18).
///
/// Die finalisierte Rechnung wird bewusst über die Repositories direkt
/// angelegt (gleicher Grund wie in euer_screen_test.dart: vermeidet
/// eine SnackBar-Overlay-Kollision mit dem FAB/Buttons im Breit-
/// Layout).
Finder _sidebarItem(String label) => find.widgetWithText(SidebarNavItem, label);

void main() {
  testWidgets(
    'CSV-Spaltenzuordnung konfigurieren, eine Transaktion zuordnen markiert die passende '
    'Rechnung als bezahlt',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final db = AppDatabase.forTesting(
        NativeDatabase.memory(setup: (rawDb) => rawDb.execute('PRAGMA foreign_keys = ON;')),
      );
      final companyRepo = CompanyRepository(db);
      final customerRepo = CustomerRepository(db);
      final invoiceRepo = InvoiceRepository(db, NumberSequenceRepository(db));

      final company = await companyRepo.create(name: 'Elektro Beckmann');
      await companyRepo.update(company.copyWith(buchhaltungEnabled: true));
      final customer = await customerRepo.create(companyId: company.id, name: 'Testkunde');
      final draft = await invoiceRepo.createDraft(
        companyId: company.id,
        customerId: customer.id,
        issueDate: DateTime(2026, 10, 1),
        serviceDate: DateTime(2026, 10, 1),
        items: [
          InvoiceItemInput(
            kind: InvoiceItemKind.text,
            description: 'Beratung',
            quantity: Decimal.one,
            unitPriceCents: 10000,
            vatRatePercent: 19,
          ),
        ],
      );
      final invoice = await invoiceRepo.finalize(companyId: company.id, id: draft.id);
      expect(invoice!.paymentStatus, PaymentStatus.open);

      await tester.pumpWidget(WerkkernErpApp(database: db));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Elektro Beckmann'));
      await tester.pumpAndSettle();

      await tester.tap(_sidebarItem('Bankabgleich'));
      await tester.pumpAndSettle();
      expect(find.text('Noch keine Bank-Transaktionen importiert.'), findsOneWidget);

      // CSV-Spaltenzuordnung einstellen (deutsche Konvention).
      await tester.tap(find.byTooltip('CSV-Spaltenzuordnung'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Datumsspalte *'), 'Buchungstag');
      await tester.enterText(find.widgetWithText(TextField, 'Betragsspalte *'), 'Betrag');
      await tester.tap(find.text('Speichern'));
      await tester.pumpAndSettle();

      // Statt eines echten Datei-Dialogs (im Widget-Test nicht
      // steuerbar) direkt über das Repository importieren — getestet
      // wird hier die Zuordnungs-/Markierungslogik, der CSV-Parser
      // selbst ist bereits in bank_csv_import_service_test.dart
      // vollständig abgedeckt.
      await db.into(db.bankTransactions).insert(
            BankTransactionsCompanion.insert(
              id: 'bank-tx-1',
              companyId: company.id,
              date: DateTime(2026, 10, 15),
              amountCents: 11900,
              purpose: const Value('Rechnung R-26001'),
              counterparty: const Value('Testkunde'),
              importHash: 'hash-1',
              importedAt: DateTime.now(),
            ),
          );

      await tester.tap(find.byTooltip('Aktualisieren'));
      await tester.pumpAndSettle();

      expect(find.text('119,00 €'), findsOneWidget);
      await tester.tap(find.text('Zuordnen'));
      await tester.pumpAndSettle();
      expect(find.textContaining(invoice.invoiceNumber!), findsWidgets);
      await tester.tap(find.text('119,00 €').last);
      await tester.pumpAndSettle();

      expect(find.text('Zuordnung lösen'), findsOneWidget);
      final reloadedInvoice =
          await invoiceRepo.findById(companyId: company.id, id: invoice.id);
      expect(reloadedInvoice!.paymentStatus, PaymentStatus.paid);

      await db.close();
    },
  );
}
