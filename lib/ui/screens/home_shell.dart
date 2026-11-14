import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/database/database.dart';
import '../../data/database/tables.dart';
import '../../domain/services/active_company_service.dart';
import '../widgets/app_shell.dart';
import 'articles_screen.dart';
import 'company_switcher_screen.dart';
import 'customers_screen.dart';
import 'bank_reconciliation_screen.dart';
import 'dashboard_screen.dart';
import 'euer_screen.dart';
import 'expenses_screen.dart';
import 'invoices_screen.dart';
import 'open_items_screen.dart';
import 'inventory_counts_screen.dart';
import 'projects_screen.dart';
import 'purchase_orders_screen.dart';
import 'time_entries_screen.dart';
import 'time_sheets_screen.dart';
import 'recurring_invoice_templates_screen.dart';
import 'settings_screen.dart';
import 'suppliers_screen.dart';
import 'vehicles_screen.dart';

/// Stabile Kennung eines Tabs, unabhängig von seiner **Position** in der
/// Liste. A5 fügt Angebot/Auftrag mittendrin ein (zwischen Rechnungen
/// und Kunden) — ein reiner Positions-Index ("Index 4 ist Einstellungen")
/// würde dadurch beim Umschalten eines Moduls plötzlich auf einen ganz
/// anderen Tab zeigen, obwohl der Nutzer gar nicht navigiert hat
/// (gefunden über einen Widget-Test: Angebote auf der Einstellungen-
/// Seite aktivieren sprang kommentarlos auf "Lieferanten", weil
/// Einstellungen von Index 4 auf Index 5 rutschte). Die ID bleibt
/// stabil, die tatsächliche Listenposition wird bei jedem Build neu
/// aufgelöst.
enum _TabId {
  dashboard,
  invoice,
  quote,
  order,
  deliveryNote,
  proforma,
  creditNote,
  customers,
  articles,
  suppliers,
  projects,
  vehicles,
  purchaseOrders,
  inventoryCounts,
  timeEntries,
  timeSheets,
  recurringTemplates,
  openItems,
  expenses,
  euer,
  bankReconciliation,
  settings,
}

/// Navigationsrahmen innerhalb einer gewählten (lokalen) Firma. Das
/// Layout (Sidebar breit, Bottom-Bar + „Mehr“ schmal, eigener
/// Inhalts-Navigator) liegt in [AppShell] und ist online dasselbe.
///
/// A5: Angebote/Aufträge erscheinen als zusätzliche Fakturierung-Tabs,
/// sobald die Firma das jeweilige Modul aktiviert (`SettingsScreen`).
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  List<ShellTab> _buildTabs(Company company) => [
        const ShellTab(
          id: _TabId.dashboard,
          icon: Icons.dashboard_outlined,
          title: 'Dashboard',
          screen: DashboardScreen(),
          section: ShellSection.dashboard,
        ),
        const ShellTab(
          id: _TabId.invoice,
          icon: Icons.receipt_long_outlined,
          title: 'Rechnungen',
          screen: InvoicesScreen(),
          section: ShellSection.fakturierung,
        ),
        if (company.quotesEnabled)
          const ShellTab(
            id: _TabId.quote,
            icon: Icons.request_quote_outlined,
            title: 'Angebote',
            screen: InvoicesScreen(kind: DocumentKind.quote),
            section: ShellSection.fakturierung,
          ),
        if (company.ordersEnabled)
          const ShellTab(
            id: _TabId.order,
            icon: Icons.assignment_outlined,
            title: 'Aufträge',
            screen: InvoicesScreen(kind: DocumentKind.order),
            section: ShellSection.fakturierung,
          ),
        if (company.deliveryNotesEnabled)
          const ShellTab(
            id: _TabId.deliveryNote,
            icon: Icons.outbox_outlined,
            title: 'Lieferscheine',
            screen: InvoicesScreen(kind: DocumentKind.deliveryNote),
            section: ShellSection.fakturierung,
          ),
        // C10 (Kay-Priorisierungsentscheidung 2026-10-17).
        if (company.proformaEnabled)
          const ShellTab(
            id: _TabId.proforma,
            icon: Icons.fact_check_outlined,
            title: 'Proforma-Rechnungen',
            screen: InvoicesScreen(kind: DocumentKind.proforma),
            section: ShellSection.fakturierung,
          ),
        // Gutschriften (Kay-Entscheidung 2026-10-19) — ebenfalls bei
        // Fakturierung eingruppiert (gleicher Grund wie bei den
        // Vorlagen unten: direkt neben den übrigen Fakturierung-Tabs,
        // sonst doppelte Sektionsbeschriftung in der Sidebar).
        if (company.creditNotesEnabled)
          const ShellTab(
            id: _TabId.creditNote,
            icon: Icons.receipt_long_outlined,
            title: 'Gutschriften',
            screen: InvoicesScreen(kind: DocumentKind.creditNote),
            section: ShellSection.fakturierung,
          ),
        // C11 Wiederkehrende Rechnungen (Kay-Priorisierungsentscheidung
        // 2026-10-17) — bei Fakturierung eingruppiert (muss direkt neben
        // den übrigen Fakturierung-Tabs stehen, sonst würde die Sidebar
        // die Sektionsbeschriftung "Fakturierung" ein zweites Mal
        // einfügen, siehe Gruppierung nach `ShellSection` in `AppShell`).
        if (company.recurringInvoicesEnabled)
          const ShellTab(
            id: _TabId.recurringTemplates,
            icon: Icons.repeat_outlined,
            title: 'Vorlagen',
            screen: RecurringInvoiceTemplatesScreen(),
            section: ShellSection.fakturierung,
          ),
        const ShellTab(
          id: _TabId.customers,
          icon: Icons.group_outlined,
          title: 'Kunden',
          screen: CustomersScreen(),
          section: ShellSection.stammdaten,
        ),
        const ShellTab(
          id: _TabId.articles,
          icon: Icons.inventory_2_outlined,
          title: 'Artikel',
          screen: ArticlesScreen(),
          section: ShellSection.stammdaten,
        ),
        const ShellTab(
          id: _TabId.suppliers,
          icon: Icons.local_shipping_outlined,
          title: 'Lieferanten',
          screen: SuppliersScreen(),
          section: ShellSection.stammdaten,
        ),
        // C1 Projekte (Kay-Priorisierungsentscheidung 2026-10-17).
        if (company.projectsEnabled)
          const ShellTab(
            id: _TabId.projects,
            icon: Icons.folder_outlined,
            title: 'Projekte',
            screen: ProjectsScreen(),
            section: ShellSection.stammdaten,
          ),
        // C6 Fuhrpark/Auswärtsmontage (Kay-Priorisierungsentscheidung
        // 2026-10-17).
        if (company.fleetEnabled)
          const ShellTab(
            id: _TabId.vehicles,
            icon: Icons.directions_car_outlined,
            title: 'Fuhrpark',
            screen: VehiclesScreen(),
            section: ShellSection.stammdaten,
          ),
        // C5.2 Bestellwesen (Nachtrag 2026-10-19) — setzt Lagerbestand
        // voraus, siehe `Companies.bestellwesenEnabled`.
        if (company.bestellwesenEnabled)
          const ShellTab(
            id: _TabId.purchaseOrders,
            icon: Icons.shopping_cart_outlined,
            title: 'Bestellungen',
            screen: PurchaseOrdersScreen(),
            section: ShellSection.stammdaten,
          ),
        // C5.3 Inventur (Nachtrag 2026-10-19) — Unterfunktion des
        // bestehenden Lagerbestand-Moduls, kein eigener Schalter.
        if (company.lagerbestandEnabled)
          const ShellTab(
            id: _TabId.inventoryCounts,
            icon: Icons.fact_check_outlined,
            title: 'Inventur',
            screen: InventoryCountsScreen(),
            section: ShellSection.stammdaten,
          ),
        // C3.1 Zeiterfassung (Nachtrag 2026-10-20).
        if (company.timeTrackingEnabled) ...[
          const ShellTab(
            id: _TabId.timeEntries,
            icon: Icons.schedule_outlined,
            title: 'Zeiterfassung',
            screen: TimeEntriesScreen(),
            section: ShellSection.stammdaten,
          ),
          // C3-Rest Kunden-Stundenzettel/Unterschrift (Nachtrag
          // 2026-10-21) — Unterfunktion der Zeiterfassung, kein eigener
          // Modul-Schalter (gleiches Prinzip wie "Inventur" unter
          // Lagerbestand).
          const ShellTab(
            id: _TabId.timeSheets,
            icon: Icons.draw_outlined,
            title: 'Stundenzettel',
            screen: TimeSheetsScreen(),
            section: ShellSection.stammdaten,
          ),
        ],
        // C14.1 Offene-Posten-Übersicht (Kay-Priorisierungsentscheidung
        // 2026-10-18 — erster Baustein der vollen Buchhaltung).
        if (company.buchhaltungEnabled) ...[
          const ShellTab(
            id: _TabId.openItems,
            icon: Icons.account_balance_wallet_outlined,
            title: 'Offene Posten',
            screen: OpenItemsScreen(),
            section: ShellSection.buchhaltung,
          ),
          // C14.2 Belege/Ausgaben (Kay-Priorisierungsentscheidung
          // 2026-10-18).
          const ShellTab(
            id: _TabId.expenses,
            icon: Icons.receipt_outlined,
            title: 'Belege',
            screen: ExpensesScreen(),
            section: ShellSection.buchhaltung,
          ),
          // C14.3 EÜR-Übersicht (Kay-Priorisierungsentscheidung
          // 2026-10-18).
          const ShellTab(
            id: _TabId.euer,
            icon: Icons.insights_outlined,
            title: 'EÜR-Übersicht',
            screen: EuerScreen(),
            section: ShellSection.buchhaltung,
          ),
          // C14.4 Bankabgleich (Kay-Priorisierungsentscheidung
          // 2026-10-18).
          const ShellTab(
            id: _TabId.bankReconciliation,
            icon: Icons.sync_alt_outlined,
            title: 'Bankabgleich',
            screen: BankReconciliationScreen(),
            section: ShellSection.buchhaltung,
          ),
        ],
        const ShellTab(
          id: _TabId.settings,
          icon: Icons.settings_outlined,
          title: 'Einstellungen',
          screen: SettingsScreen(),
          section: ShellSection.einstellungen,
        ),
      ];

  /// Kay-Feedback 2026-10-19: feste, nie wachsende Bottom-Bar — nur die
  /// drei immer vorhandenen Tabs plus „Mehr“ (siehe [AppShell]).
  static const _pinnedNarrowIds = [_TabId.dashboard, _TabId.invoice, _TabId.customers];

  @override
  Widget build(BuildContext context) {
    final service = context.watch<ActiveCompanyService>();
    final company = service.active;

    if (company == null) {
      return const CompanySwitcherScreen();
    }

    return AppShell(
      companyName: company.name,
      tabs: _buildTabs(company),
      pinnedNarrowIds: _pinnedNarrowIds,
      // Schnellzugriff je Gerät und lokaler Firma (siehe `QuickAccessStore`).
      quickAccessScope: 'local:${company.id}',
      onSwitchCompany: () => Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const CompanySwitcherScreen()),
      ),
    );
  }
}
