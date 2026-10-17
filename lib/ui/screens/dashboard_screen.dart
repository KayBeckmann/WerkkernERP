import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/database/tables.dart';
import '../../data/repositories/invoice_repository.dart';
import '../../data/repositories/project_repository.dart';
import '../../data/repositories/recurring_invoice_template_repository.dart';
import '../../data/repositories/vehicle_repository.dart';
import '../../domain/services/active_company_service.dart';
import '../../domain/services/dashboard_service.dart';
import '../../domain/services/dunning_service.dart';
import '../theme/app_theme.dart';

/// Einstiegspunkt nach der Firmenwahl (Kay-Anfrage 2026-10-17: "Ein
/// Dashboard hätte ich auch gerne als Einstiegspunkt, wenn man eine
/// Firma ausgewählt hat"). Reine Übersicht, keine eigenen Aktionen —
/// Zahlen kommen ausschließlich aus bereits vorhandenen Repositories,
/// nichts wird hier neu erfunden oder gebucht.
///
/// **Für die Multi-User-Variante (Phase B) ausdrücklich noch NICHT
/// umgesetzt:** rollenabhängige/individuell anpassbare Kacheln ("Die
/// Buchhaltung braucht andere Informationen als der Monteur oder der
/// Lagerist") brauchen Nutzer/Rollen, die es in der Offline-Single-
/// User-App bewusst nicht gibt (A0-Prinzip: kein Login). Dieses
/// Dashboard zeigt deshalb EINE feste Übersicht für den einen Nutzer,
/// die je Firma nur nach den bereits vorhandenen Modul-Schaltern
/// aus- oder einblendet — die rollenbasierte Variante ist ein eigener
/// B-Entscheidungspunkt (siehe Roadmap).
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<DashboardSummary> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<DashboardSummary> _load() async {
    // Alle Provider-Zugriffe VOR dem ersten await abholen — `context`
    // darf nach einem await nicht mehr synchron verwendet werden (siehe
    // dieselbe Fehlerklasse gerade in email_send_dialog.dart/
    // invoice_item_dialog.dart gefunden: ein inzwischen dispose()ter
    // Context wirft beim Zugriff, nicht nur bei setState()).
    final company = context.read<ActiveCompanyService>().active!;
    final invoiceRepo = context.read<InvoiceRepository>();
    final vehicleRepo = company.fleetEnabled ? context.read<VehicleRepository>() : null;
    final projectRepo = company.projectsEnabled ? context.read<ProjectRepository>() : null;
    final recurringRepo = company.recurringInvoicesEnabled
        ? context.read<RecurringInvoiceTemplateRepository>()
        : null;
    final now = DateTime.now();

    final allInvoices = await invoiceRepo.listAllForCompany(company.id);
    final finalized = allInvoices.where((i) => i.status == InvoiceStatus.finalized).toList();
    final withGross = <InvoiceWithGross>[];
    for (final invoice in finalized) {
      final totals = await invoiceRepo.totalsFor(invoice.id);
      withGross.add(InvoiceWithGross(invoice: invoice, gross: totals.totalGross));
    }

    var vehiclesDueSoonCount = 0;
    if (vehicleRepo != null) {
      final vehicles = await vehicleRepo.listForCompany(company.id);
      vehiclesDueSoonCount = vehicles
          .where(
            (v) =>
                v.nextInspectionDate != null && v.nextInspectionDate!.difference(now).inDays < 30,
          )
          .length;
    }

    var activeProjectsCount = 0;
    if (projectRepo != null) {
      activeProjectsCount = (await projectRepo.listForCompany(company.id)).length;
    }

    var activeRecurringTemplatesCount = 0;
    DateTime? nextRecurringDueDate;
    if (recurringRepo != null) {
      final templates = await recurringRepo.listForCompany(company.id);
      activeRecurringTemplatesCount = templates.length;
      for (final template in templates) {
        if (nextRecurringDueDate == null || template.nextDueDate.isBefore(nextRecurringDueDate)) {
          nextRecurringDueDate = template.nextDueDate;
        }
      }
    }

    return computeDashboardSummary(
      finalizedInvoices: withGross,
      now: now,
      dunningConfig: DunningConfig.fromCompany(company),
      vehiclesDueSoonCount: vehiclesDueSoonCount,
      activeProjectsCount: activeProjectsCount,
      activeRecurringTemplatesCount: activeRecurringTemplatesCount,
      nextRecurringDueDate: nextRecurringDueDate,
    );
  }

  // Bewusst ein Block-Body, nicht `setState(() => _future = _load())` —
  // siehe dieselbe Begründung in projects_screen.dart/vehicles_screen.dart.
  void _reload() => setState(() {
        _future = _load();
      });

  static String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';

  @override
  Widget build(BuildContext context) {
    final company = context.watch<ActiveCompanyService>().active;
    if (company == null) return const SizedBox.shrink();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            tooltip: 'Aktualisieren',
            onPressed: _reload,
          ),
        ],
      ),
      body: FutureBuilder<DashboardSummary>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final summary = snapshot.data!;
          final isWide = MediaQuery.sizeOf(context).width >= AppMetrics.wideLayoutBreakpoint;

          final cards = <Widget>[
            _KpiCard(
              icon: Icons.euro_outlined,
              label: 'Rechnungssumme diesen Monat',
              value: summary.revenueThisMonth.toString(),
            ),
            _KpiCard(
              icon: Icons.calendar_today_outlined,
              label: 'Rechnungssumme dieses Jahr',
              value: summary.revenueThisYear.toString(),
            ),
            if (company.dunningEnabled) ...[
              _KpiCard(
                icon: Icons.pending_actions_outlined,
                label: 'Offene Rechnungen',
                value: '${summary.openInvoicesCount} (${summary.openInvoicesSum})',
              ),
              _KpiCard(
                icon: Icons.warning_amber_outlined,
                label: 'Überfällig (Mahnstufe erreicht)',
                value: '${summary.overdueInvoicesCount}',
                highlight: summary.overdueInvoicesCount > 0,
              ),
            ],
            if (company.projectsEnabled)
              _KpiCard(
                icon: Icons.folder_outlined,
                label: 'Aktive Projekte',
                value: '${summary.activeProjectsCount}',
              ),
            if (company.fleetEnabled)
              _KpiCard(
                icon: Icons.directions_car_outlined,
                label: 'TÜV fällig (< 30 Tage)',
                value: '${summary.vehiclesDueSoonCount}',
                highlight: summary.vehiclesDueSoonCount > 0,
              ),
            if (company.recurringInvoicesEnabled)
              _KpiCard(
                icon: Icons.repeat_outlined,
                label: 'Aktive wiederkehrende Vorlagen',
                value: summary.nextRecurringDueDate == null
                    ? '${summary.activeRecurringTemplatesCount}'
                    : '${summary.activeRecurringTemplatesCount} — nächste Fälligkeit '
                        '${_formatDate(summary.nextRecurringDueDate!)}',
              ),
          ];

          return RefreshIndicator(
            onRefresh: () async {
              _reload();
              await _future;
            },
            child: GridView.count(
              padding: const EdgeInsets.all(16),
              crossAxisCount: isWide ? 3 : 2,
              childAspectRatio: 1.3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              children: cards,
            ),
          );
        },
      ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.icon,
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      color: highlight ? colorScheme.errorContainer : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: highlight ? colorScheme.onErrorContainer : colorScheme.primary),
            const Spacer(),
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: highlight ? colorScheme.onErrorContainer : null,
                  ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: highlight ? colorScheme.onErrorContainer : colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
