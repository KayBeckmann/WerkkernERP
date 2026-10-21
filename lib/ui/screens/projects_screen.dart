import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/database/database.dart';
import '../../data/database/tables.dart';
import '../../data/repositories/customer_repository.dart';
import '../../data/repositories/expense_repository.dart';
import '../../data/repositories/invoice_repository.dart';
import '../../data/repositories/project_repository.dart';
import '../../data/repositories/time_entry_repository.dart';
import '../../domain/models/money.dart';
import '../../domain/services/active_company_service.dart';
import 'invoices_screen.dart' show DocumentLabels;

/// C2-Nachtrag (2026-10-21) — Anzeige von Gründungsjahr+PP, z. B. "26/01",
/// vor dem Projektnamen. `null`, solange die rückwirkende Vergabe
/// (`ProjectRepository.backfillProjectNumbersIfMissing`) noch nicht
/// gelaufen ist (kurzzeitig beim allerersten Laden nach dem Update).
String? _projectNumberLabel(Project project) {
  final year = project.foundingYear;
  final number = project.projectNumber;
  if (year == null || number == null) return null;
  final shortYear = (year % 100).toString().padLeft(2, '0');
  return '$shortYear/${number.toString().padLeft(2, '0')}';
}

/// Projektliste der aktiven Firma (C1-Kern, Kay-Priorisierungsentscheidung
/// 2026-10-17). Zeigt nur aktive Projekte — archivierte bleiben in der DB
/// erhalten (gleiches Prinzip wie die Modul-Schalter), tauchen hier aber
/// nicht mehr auf.
class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({super.key});

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  late Future<_ProjectsData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_ProjectsData> _load() async {
    final companyId = context.read<ActiveCompanyService>().active!.id;
    final projectRepo = context.read<ProjectRepository>();
    final customerRepo = context.read<CustomerRepository>();
    // C2-Nachtrag (2026-10-21): rückwirkende PP-Vergabe für Projekte von
    // vor diesem Nachtrag — lazy, gleiches Prinzip wie
    // ExpenseCategoryRepository.seedDefaultsIfNeverSeeded().
    await projectRepo.backfillProjectNumbersIfMissing(companyId);
    final projects = await projectRepo.listForCompany(companyId);
    final customers = await customerRepo.listForCompany(companyId);
    return _ProjectsData(projects: projects, customerById: {for (final c in customers) c.id: c});
  }

  // Bewusst ein Block-Body, nicht `setState(() => _future = _load())` —
  // eine Zuweisung als Ausdruck liefert ihren Wert (hier ein `Future`)
  // zurück, und Flutter wirft im Debug-Modus bei jedem `setState()`,
  // dessen Callback ein `Future` zurückgibt (bereits einmal in A5 so
  // gefunden).
  void _reload() => setState(() {
        _future = _load();
      });

  Future<void> _create() async {
    final companyId = context.read<ActiveCompanyService>().active!.id;
    final customers = await context.read<CustomerRepository>().listForCompany(companyId);
    if (!mounted) return;
    final result = await showDialog<_ProjectFormResult>(
      context: context,
      builder: (context) => _ProjectFormDialog(customers: customers),
    );
    if (result == null || !mounted) return;
    await context.read<ProjectRepository>().create(
          companyId: companyId,
          name: result.name,
          customerId: result.customerId,
          notes: result.notes,
        );
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<_ProjectsData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data!;
          if (data.projects.isEmpty) {
            return const Center(child: Text('Noch keine Projekte angelegt.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
            itemCount: data.projects.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final project = data.projects[index];
              final customer = project.customerId == null ? null : data.customerById[project.customerId];
              final numberLabel = _projectNumberLabel(project);
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.folder_outlined),
                  title: Text(numberLabel == null ? project.name : '$numberLabel · ${project.name}'),
                  subtitle: customer != null ? Text(customer.name) : const Text('Ohne Kundenbezug'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => ProjectDetailScreen(project: project)),
                    );
                    if (mounted) _reload();
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'projects-fab',
        onPressed: _create,
        icon: const Icon(Icons.add),
        label: const Text('Projekt anlegen'),
      ),
    );
  }
}

class _ProjectsData {
  const _ProjectsData({required this.projects, required this.customerById});
  final List<Project> projects;
  final Map<String, Customer> customerById;
}

class _ProjectFormResult {
  const _ProjectFormResult({required this.name, this.customerId, this.notes});
  final String name;
  final String? customerId;
  final String? notes;
}

class _ProjectFormDialog extends StatefulWidget {
  const _ProjectFormDialog({required this.customers});
  final List<Customer> customers;

  @override
  State<_ProjectFormDialog> createState() => _ProjectFormDialogState();
}

class _ProjectFormDialogState extends State<_ProjectFormDialog> {
  final _nameCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String? _customerId;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Neues Projekt'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nameCtrl,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Name *'),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String?>(
                isExpanded: true,
                initialValue: _customerId,
                decoration: const InputDecoration(labelText: 'Kunde (optional)'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Ohne Kundenbezug')),
                  for (final customer in widget.customers)
                    DropdownMenuItem(value: customer.id, child: Text(customer.name)),
                ],
                onChanged: (value) => setState(() => _customerId = value),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _notesCtrl,
                decoration: const InputDecoration(labelText: 'Notizen'),
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
        FilledButton(
          onPressed: () {
            if (_nameCtrl.text.trim().isEmpty) return;
            Navigator.pop(
              context,
              _ProjectFormResult(
                name: _nameCtrl.text.trim(),
                customerId: _customerId,
                notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
              ),
            );
          },
          child: const Text('Anlegen'),
        ),
      ],
    );
  }
}

/// Projektdetail: zugeordnete Dokumente **über alle Dokumentarten
/// hinweg** (C1) plus eine einfache Summe der finalisierten Rechnungen.
///
/// Seit Kay-Entscheidung 2026-10-19 ("Belege bekommen eine optionale
/// Projektzuordnung") gibt es zusätzlich eine **einfache**
/// Ergebnisrechnung (Erlöse aus zugeordneten Rechnungen minus direkte
/// Kosten aus zugeordneten Belegen), sichtbar wenn C14 Buchhaltung
/// aktiviert ist.
///
/// Seit C3.3 (Nachtrag 2026-10-20: "Im Projekt sollen die geplanten
/// Zeiten und die gebuchten Zeiten mit berücksichtigt werden. Gebuchte
/// Zeiten bringen Geld, Kosten aber auch Gehälter. Geplante Zeiten
/// dienen dem Abgleich") zusätzlich ein Stunden-Soll/Ist (geplant =
/// Summe der Stunden-Positionen aus zugeordneten Angeboten/Aufträgen,
/// "kalkuliert" bedeutet hier die Angebots-/Auftragsmengen, keine
/// separate Projektkalkulation; gebucht = `TimeEntryRepository.
/// totalHoursForProject()`) sowie eine Stundenkosten-Zeile
/// (`totalCostForProject()`) als zusätzlicher Abzug im Ergebnis,
/// sichtbar wenn `timeTrackingEnabled`. Die Erlösseite der gebuchten
/// Zeiten braucht hier keinen eigenen Code — sobald daraus eine
/// Zeit-und-Material-Rechnung entsteht (C3.2), zählt sie bereits ganz
/// normal über `invoiceSum`.
///
/// Fuhrparkkosten fließen hier **nicht** ein (Kay-Entscheidung
/// 2026-10-19: "Fuhrpark wird auf Gemeinkosten gerechnet, nicht auf die
/// Projekte" — die laufen stattdessen als eigene Kategorie in die
/// EÜR-Übersicht, siehe `euer_service.dart`).
class ProjectDetailScreen extends StatefulWidget {
  const ProjectDetailScreen({super.key, required this.project});
  final Project project;

  @override
  State<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<ProjectDetailScreen> {
  late Future<_ProjectDetailData> _future;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_ProjectDetailData> _load() async {
    final company = context.read<ActiveCompanyService>().active!;
    final invoiceRepo = context.read<InvoiceRepository>();
    final expenseRepo = context.read<ExpenseRepository>();
    final timeEntryRepo = context.read<TimeEntryRepository>();
    final documents = await invoiceRepo.listForProject(
      companyId: company.id,
      projectId: widget.project.id,
    );
    Money invoiceSum = Money.zero();
    Decimal plannedHours = Decimal.zero;
    for (final doc in documents) {
      if (doc.kind == DocumentKind.invoice && doc.status == InvoiceStatus.finalized) {
        invoiceSum = invoiceSum + (await invoiceRepo.totalsFor(doc.id)).totalGross;
      }
      // C3.3: "kalkuliert" sind die Angebots-/Auftragsmengen (keine
      // separate Projektkalkulation) — Rechnung/Lieferschein/Proforma/
      // Gutschrift zählen hier bewusst nicht mit, sonst würde eine aus
      // gebuchten Ist-Stunden erzeugte Rechnung (C3.2) fälschlich als
      // "geplant" mitgezählt.
      if (doc.kind == DocumentKind.quote || doc.kind == DocumentKind.order) {
        final items = await invoiceRepo.itemsFor(doc.id);
        for (final item in items) {
          if (item.kind == InvoiceItemKind.hours) {
            plannedHours = plannedHours + Decimal.parse(item.quantity);
          }
        }
      }
    }
    // Einfache Projekt-Ergebnisrechnung (Kay-Entscheidung 2026-10-19:
    // "Belege bekommen eine optionale Projektzuordnung") — Erlöse aus
    // zugeordneten Rechnungen minus direkte Kosten aus zugeordneten
    // Belegen. Nur sinnvoll/angezeigt, wenn C14 Buchhaltung aktiviert
    // ist (sonst gibt es gar keine Belege).
    final expenses = company.buchhaltungEnabled
        ? await expenseRepo.listForProject(companyId: company.id, projectId: widget.project.id)
        : const <Expense>[];
    final expenseSum = expenses.fold(Money.zero(), (sum, e) => sum + Money.fromCents(e.amountGrossCents));

    // C3.3 Stunden-Soll/Ist + Stundenkosten (Nachtrag 2026-10-20) — nur
    // wenn das Zeiterfassungs-Modul aktiv ist.
    final bookedHours = company.timeTrackingEnabled
        ? await timeEntryRepo.totalHoursForProject(companyId: company.id, projectId: widget.project.id)
        : null;
    final hoursCost = company.timeTrackingEnabled
        ? await timeEntryRepo.totalCostForProject(companyId: company.id, projectId: widget.project.id)
        : Money.zero();

    return _ProjectDetailData(
      documents: documents,
      invoiceSum: invoiceSum,
      expenseSum: expenseSum,
      plannedHours: plannedHours,
      bookedHours: bookedHours,
      hoursCost: hoursCost,
      showResult: company.buchhaltungEnabled || company.timeTrackingEnabled,
      showExpenses: company.buchhaltungEnabled,
      showHours: company.timeTrackingEnabled,
    );
  }

  Future<void> _toggleArchive(ProjectStatus current) async {
    setState(() => _busy = true);
    try {
      final companyId = context.read<ActiveCompanyService>().active!.id;
      final next = current == ProjectStatus.active ? ProjectStatus.archived : ProjectStatus.active;
      await context.read<ProjectRepository>().setStatus(
            companyId: companyId,
            id: widget.project.id,
            status: next,
          );
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _projectNumberLabel(widget.project) == null
              ? widget.project.name
              : '${_projectNumberLabel(widget.project)} · ${widget.project.name}',
        ),
        actions: [
          IconButton(
            icon: Icon(
              widget.project.status == ProjectStatus.active
                  ? Icons.archive_outlined
                  : Icons.unarchive_outlined,
            ),
            tooltip: widget.project.status == ProjectStatus.active ? 'Archivieren' : 'Reaktivieren',
            onPressed: _busy ? null : () => _toggleArchive(widget.project.status),
          ),
        ],
      ),
      body: FutureBuilder<_ProjectDetailData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (widget.project.notes != null) ...[
                Text(widget.project.notes!, style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 16),
              ],
              Card(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Summe finalisierter Rechnungen: ${data.invoiceSum}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (data.showHours) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Geplante Stunden (laut Angebot/Auftrag): ${data.plannedHours} · '
                          'Gebucht: ${data.bookedHours!.toStringAsFixed(1)}',
                        ),
                        Text('Stundenkosten: ${data.hoursCost}'),
                      ],
                      if (data.showResult) ...[
                        const SizedBox(height: 4),
                        if (data.showExpenses) Text('Zugeordnete Belege: ${data.expenseSum}'),
                        const Divider(),
                        Text(
                          'Ergebnis: ${data.invoiceSum - data.expenseSum - data.hoursCost}',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: (data.invoiceSum - data.expenseSum - data.hoursCost).cents < 0
                                    ? Theme.of(context).colorScheme.error
                                    : null,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Einfache Ergebnisrechnung (Erlöse aus zugeordneten Rechnungen minus '
                          'direkte Kosten aus zugeordneten Belegen und Stundenkosten) — ohne '
                          'Fuhrpark-Umlage (Fuhrpark läuft als Gemeinkosten, siehe '
                          'EÜR-Übersicht). Keine Rechtsprüfung.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ] else ...[
                        const SizedBox(height: 4),
                        Text(
                          'Keine Projekt-Ergebnisrechnung — reine Rechnungssumme ohne Kosten, '
                          'Stundensätze oder Umlagen (weder Buchhaltung- noch '
                          'Zeiterfassungs-Modul aktiviert).',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('Zugeordnete Dokumente', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              if (data.documents.isEmpty) const Text('Noch keine Dokumente zugeordnet.'),
              for (final doc in data.documents)
                Card(
                  child: ListTile(
                    leading: Icon(
                      doc.status == InvoiceStatus.finalized
                          ? Icons.receipt_long
                          : Icons.receipt_long_outlined,
                    ),
                    title: Text(DocumentLabels.title(doc.kind)),
                    subtitle: Text(
                      doc.status == InvoiceStatus.finalized ? doc.invoiceNumber! : 'Entwurf',
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _ProjectDetailData {
  const _ProjectDetailData({
    required this.documents,
    required this.invoiceSum,
    required this.expenseSum,
    required this.plannedHours,
    required this.bookedHours,
    required this.hoursCost,
    required this.showResult,
    required this.showExpenses,
    required this.showHours,
  });
  final List<Invoice> documents;
  final Money invoiceSum;
  final Money expenseSum;

  /// Summe der Stunden-Positionen aus zugeordneten Angeboten/Aufträgen
  /// (C3.3) — "kalkuliert" im Sinn der Angebots-/Auftragsmenge, siehe
  /// Klassendoc.
  final Decimal plannedHours;

  /// `null`, wenn `timeTrackingEnabled` aus ist (siehe [showHours]).
  final double? bookedHours;
  final Money hoursCost;

  /// `true`, wenn C14 Buchhaltung ODER C3 Zeiterfassung aktiviert ist —
  /// ohne beides wäre eine "Ergebnisrechnung" nur die reine
  /// Rechnungssumme, nicht irreführend als Ergebnis bezeichnen.
  final bool showResult;
  final bool showExpenses;
  final bool showHours;
}
