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
import 'package:werkkernerp/ui/widgets/sidebar_nav_item.dart';

/// C14.3 EÜR-Übersicht (Kay-Priorisierungsentscheidung 2026-10-18).
///
/// Die finalisierte Rechnung wird bewusst über die Repositories direkt
/// angelegt statt über den vollen UI-Weg (Entwurf speichern →
/// Finalisieren) — letzterer löst mehrere SnackBars aus, die im
/// Breit-Layout denselben Bildschirmbereich wie der "Beleg erfassen"-
/// FAB überlagern und dort Tipp-Treffer verhindern können. Die
/// Finalisierungs-UI selbst ist bereits in anderen Tests abgedeckt
/// (z. B. `document_conversion_ui_test.dart`) — hier geht es nur um
/// die EÜR-Aggregation.
Finder _sidebarItem(String label) => find.widgetWithText(SidebarNavItem, label);

void main() {
  testWidgets(
    'EÜR-Übersicht zeigt Einnahmen aus einer finalisierten Rechnung und Ausgaben aus einem '
    'Beleg im selben Monat gegenübergestellt',
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
      final now = DateTime.now();
      final draft = await invoiceRepo.createDraft(
        companyId: company.id,
        customerId: customer.id,
        issueDate: now,
        serviceDate: now,
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
      await invoiceRepo.finalize(companyId: company.id, id: draft.id);

      await tester.pumpWidget(WerkkernErpApp(database: db));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Elektro Beckmann'));
      await tester.pumpAndSettle();

      // Beleg über 59,50 € (heute, also "dieser Monat").
      await tester.tap(_sidebarItem('Belege'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Beleg erfassen'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Beschreibung *'), 'Kabel');
      await tester.enterText(find.widgetWithText(TextField, 'Betrag brutto (€) *'), '59,50');
      await tester.tap(find.text('Speichern'));
      await tester.pumpAndSettle();

      await tester.tap(_sidebarItem('EÜR-Übersicht'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Aktualisieren'));
      await tester.pumpAndSettle();

      expect(find.text('119,00 €'), findsOneWidget);
      expect(find.text('59,50 €'), findsWidgets);
      expect(find.text('Ohne Kategorie'), findsOneWidget);

      await db.close();
    },
  );
}
