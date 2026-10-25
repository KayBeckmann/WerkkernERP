import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/database/database.dart';
import '../../data/database/tables.dart';
import '../../data/repositories/company_repository.dart';
import '../../data/repositories/expense_category_repository.dart';
import '../../data/repositories/expense_repository.dart';
import '../../data/repositories/project_repository.dart';
import '../../domain/models/money.dart';
import '../../domain/services/active_company_service.dart';
import '../../domain/services/datev_export_service.dart';

/// C14.2 Belege/Ausgaben (Kay-Priorisierungsentscheidung 2026-10-18,
/// voller Umfang der Buchhaltung). Erfasst Ausgaben als Bruttobetrag +
/// Steuersatz (F2-Muster) mit optionaler Kategorie — die SKR03-
/// Kontonummer je Kategorie ist Kays eigene Angabe (siehe Doc-Kommentar
/// bei [ExpenseCategories] in tables.dart), nicht von dieser App
/// vorgegeben.
class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesData {
  const _ExpensesData({
    required this.expenses,
    required this.categories,
    required this.projects,
    required this.projectsEnabled,
  });
  final List<Expense> expenses;
  final List<ExpenseCategory> categories;

  /// Leer, wenn C1 Projekte nicht aktiviert ist (siehe [projectsEnabled]).
  final List<Project> projects;
  final bool projectsEnabled;
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  late Future<_ExpensesData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_ExpensesData> _load() async {
    // Provider-Zugriffe VOR dem ersten await abholen — siehe dieselbe
    // Begründung in dashboard_screen.dart (ein inzwischen dispose()ter
    // Context darf nicht mehr synchron verwendet werden).
    final company = context.read<ActiveCompanyService>().active!;
    final categoryRepo = context.read<ExpenseCategoryRepository>();
    final expenseRepo = context.read<ExpenseRepository>();
    final projectRepo = context.read<ProjectRepository>();
    // Lazy seed (siehe Doc-Kommentar bei `seedDefaultsIfNeverSeeded`) —
    // bewusst hier und nicht beim Aktivieren des Modul-Schalters.
    await categoryRepo.seedDefaultsIfNeverSeeded(company.id);
    final expenses = await expenseRepo.listForCompany(company.id);
    final categories = await categoryRepo.listForCompany(company.id);
    // C1 Projekte / Projekt-Ergebnisrechnung (Kay-Entscheidung
    // 2026-10-19) — Belege optional einem Projekt zuordnen, nur wenn
    // das Modul aktiviert ist.
    final projects = company.projectsEnabled ? await projectRepo.listForCompany(company.id) : const <Project>[];
    return _ExpensesData(
      expenses: expenses,
      categories: categories,
      projects: projects,
      projectsEnabled: company.projectsEnabled,
    );
  }

  // Bewusst ein Block-Body, nicht `setState(() => _future = _load())` —
  // siehe dieselbe Begründung in vehicles_screen.dart/projects_screen.dart.
  void _reload() => setState(() {
        _future = _load();
      });

  Future<void> _createOrEdit({Expense? existing, required _ExpensesData data}) async {
    final result = await showDialog<_ExpenseFormResult>(
      context: context,
      builder: (context) => _ExpenseFormDialog(
        categories: data.categories,
        projects: data.projects,
        projectsEnabled: data.projectsEnabled,
        existing: existing,
      ),
    );
    if (result == null || !mounted) return;
    final companyId = context.read<ActiveCompanyService>().active!.id;
    final repo = context.read<ExpenseRepository>();
    if (existing == null) {
      await repo.create(
        companyId: companyId,
        date: result.date,
        description: result.description,
        amountGrossCents: result.amountGrossCents,
        vatRatePercent: result.vatRatePercent,
        categoryId: result.categoryId,
        supplierReference: result.supplierReference,
        projectId: result.projectId,
      );
    } else {
      await repo.update(
        companyId: companyId,
        id: existing.id,
        date: result.date,
        description: result.description,
        amountGrossCents: result.amountGrossCents,
        vatRatePercent: result.vatRatePercent,
        categoryId: Value(result.categoryId),
        supplierReference: Value(result.supplierReference),
        projectId: Value(result.projectId),
      );
    }
    if (mounted) _reload();
  }

  Future<void> _delete(Expense expense) async {
    final companyId = context.read<ActiveCompanyService>().active!.id;
    await context.read<ExpenseRepository>().delete(companyId: companyId, id: expense.id);
    if (mounted) _reload();
  }

  Future<void> _manageCategories(List<ExpenseCategory> categories) async {
    await showDialog<void>(
      context: context,
      builder: (context) => _CategoryManagerDialog(categories: categories),
    );
    if (mounted) _reload();
  }

  Future<void> _exportDatev(_ExpensesData data) async {
    await showDialog<void>(
      context: context,
      builder: (context) => _DatevExportDialog(expenses: data.expenses, categories: data.categories),
    );
  }

  static String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Belege/Ausgaben'),
        actions: [
          FutureBuilder<_ExpensesData>(
            future: _future,
            builder: (context, snapshot) => IconButton(
              icon: const Icon(Icons.category_outlined),
              tooltip: 'Kategorien verwalten',
              onPressed: snapshot.hasData ? () => _manageCategories(snapshot.data!.categories) : null,
            ),
          ),
          FutureBuilder<_ExpensesData>(
            future: _future,
            builder: (context, snapshot) => IconButton(
              icon: const Icon(Icons.description_outlined),
              tooltip: 'DATEV-Export',
              onPressed: snapshot.hasData ? () => _exportDatev(snapshot.data!) : null,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            tooltip: 'Aktualisieren',
            onPressed: _reload,
          ),
        ],
      ),
      body: FutureBuilder<_ExpensesData>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final data = snapshot.data!;
          final categoryLabelById = {for (final c in data.categories) c.id: c.label};
          final projectNameById = {for (final p in data.projects) p.id: p.name};

          if (data.expenses.isEmpty) {
            return const Center(child: Text('Noch keine Belege erfasst.'));
          }

          return ListView(
            children: [
              for (final expense in data.expenses)
                ListTile(
                  title: Text(expense.description),
                  subtitle: Text(
                    '${_formatDate(expense.date)}'
                    '${expense.categoryId != null ? ' — ${categoryLabelById[expense.categoryId] ?? "Kategorie gelöscht"}' : ''}'
                    '${expense.projectId != null ? ' — ${projectNameById[expense.projectId] ?? "Projekt gelöscht"}' : ''}',
                  ),
                  trailing: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 4,
                    children: [
                      Text(Money.fromCents(expense.amountGrossCents).toString()),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        tooltip: 'Bearbeiten',
                        onPressed: () => _createOrEdit(existing: expense, data: data),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        tooltip: 'Löschen',
                        onPressed: () => _delete(expense),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
      floatingActionButton: FutureBuilder<_ExpensesData>(
        future: _future,
        builder: (context, snapshot) => FloatingActionButton.extended(
          icon: const Icon(Icons.add),
          label: const Text('Beleg erfassen'),
          onPressed: snapshot.hasData ? () => _createOrEdit(data: snapshot.data!) : null,
        ),
      ),
    );
  }
}

class _ExpenseFormResult {
  const _ExpenseFormResult({
    required this.date,
    required this.description,
    required this.amountGrossCents,
    required this.vatRatePercent,
    this.categoryId,
    this.supplierReference,
    this.projectId,
  });
  final DateTime date;
  final String description;
  final int amountGrossCents;
  final double vatRatePercent;
  final String? categoryId;
  final String? supplierReference;
  final String? projectId;
}

class _ExpenseFormDialog extends StatefulWidget {
  const _ExpenseFormDialog({
    required this.categories,
    required this.projects,
    required this.projectsEnabled,
    this.existing,
  });
  final List<ExpenseCategory> categories;
  final List<Project> projects;
  final bool projectsEnabled;
  final Expense? existing;

  @override
  State<_ExpenseFormDialog> createState() => _ExpenseFormDialogState();
}

class _ExpenseFormDialogState extends State<_ExpenseFormDialog> {
  late final TextEditingController _descriptionCtrl;
  late final TextEditingController _amountCtrl;
  late final TextEditingController _supplierCtrl;
  late DateTime _date;
  late double _vatRate;
  String? _categoryId;
  String? _projectId;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _descriptionCtrl = TextEditingController(text: existing?.description);
    _amountCtrl = TextEditingController(
      text: existing == null ? '' : Money.fromCents(existing.amountGrossCents).formatEuro(),
    );
    _supplierCtrl = TextEditingController(text: existing?.supplierReference);
    _date = existing?.date ?? DateTime.now();
    _vatRate = existing?.vatRatePercent ?? 19;
    _categoryId = existing?.categoryId;
    _projectId = existing?.projectId;
  }

  @override
  void dispose() {
    _descriptionCtrl.dispose();
    _amountCtrl.dispose();
    _supplierCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  static String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'Beleg erfassen' : 'Beleg bearbeiten'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Datum: ${_formatDate(_date)}'),
                trailing: const Icon(Icons.calendar_today_outlined),
                onTap: _pickDate,
              ),
              TextField(
                controller: _descriptionCtrl,
                decoration: const InputDecoration(labelText: 'Beschreibung *'),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _amountCtrl,
                      decoration: const InputDecoration(labelText: 'Betrag brutto (€) *'),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<double>(
                      initialValue: _vatRate,
                      decoration: const InputDecoration(labelText: 'USt.'),
                      items: const [
                        DropdownMenuItem(value: 19.0, child: Text('19 %')),
                        DropdownMenuItem(value: 7.0, child: Text('7 %')),
                        DropdownMenuItem(value: 0.0, child: Text('0 %')),
                      ],
                      onChanged: (value) => setState(() => _vatRate = value ?? 19),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String?>(
                isExpanded: true,
                initialValue: _categoryId,
                decoration: const InputDecoration(labelText: 'Kategorie'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Ohne Kategorie')),
                  for (final category in widget.categories)
                    DropdownMenuItem(value: category.id, child: Text(category.label)),
                ],
                onChanged: (value) => setState(() => _categoryId = value),
              ),
              if (widget.projectsEnabled) ...[
                const SizedBox(height: 8),
                DropdownButtonFormField<String?>(
                  isExpanded: true,
                  initialValue: _projectId,
                  decoration: const InputDecoration(labelText: 'Projekt (optional)'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Ohne Projekt')),
                    for (final project in widget.projects)
                      DropdownMenuItem(value: project.id, child: Text(project.name)),
                  ],
                  onChanged: (value) => setState(() => _projectId = value),
                ),
              ],
              const SizedBox(height: 8),
              TextField(
                controller: _supplierCtrl,
                decoration: const InputDecoration(labelText: 'Lieferant/Belegnummer (optional)'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
        FilledButton(
          onPressed: () {
            if (_descriptionCtrl.text.trim().isEmpty) return;
            Money amount;
            try {
              amount = Money.fromEuroString(_amountCtrl.text.trim());
            } catch (_) {
              return;
            }
            if (_amountCtrl.text.trim().isEmpty) return;
            Navigator.pop(
              context,
              _ExpenseFormResult(
                date: _date,
                description: _descriptionCtrl.text.trim(),
                amountGrossCents: amount.cents,
                vatRatePercent: _vatRate,
                categoryId: _categoryId,
                supplierReference:
                    _supplierCtrl.text.trim().isEmpty ? null : _supplierCtrl.text.trim(),
                projectId: _projectId,
              ),
            );
          },
          child: const Text('Speichern'),
        ),
      ],
    );
  }
}

/// Einfache Verwaltung: Kategorie anlegen/umbenennen/löschen, SKR03-
/// Kontonummer eintragen. Bewusst als eigener Dialog statt Vollbild-
/// Seite — das ist eine selten genutzte Einstellung, kein täglicher
/// Arbeitsablauf.
class _CategoryManagerDialog extends StatefulWidget {
  const _CategoryManagerDialog({required this.categories});
  final List<ExpenseCategory> categories;

  @override
  State<_CategoryManagerDialog> createState() => _CategoryManagerDialogState();
}

class _CategoryManagerDialogState extends State<_CategoryManagerDialog> {
  late List<ExpenseCategory> _categories;
  final _newLabelCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _categories = List.of(widget.categories);
  }

  @override
  void dispose() {
    _newLabelCtrl.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final companyId = context.read<ActiveCompanyService>().active!.id;
    final reloaded = await context.read<ExpenseCategoryRepository>().listForCompany(companyId);
    if (mounted) setState(() => _categories = reloaded);
  }

  Future<void> _addCategory() async {
    final label = _newLabelCtrl.text.trim();
    if (label.isEmpty) return;
    final companyId = context.read<ActiveCompanyService>().active!.id;
    await context.read<ExpenseCategoryRepository>().create(companyId: companyId, label: label);
    _newLabelCtrl.clear();
    await _refresh();
  }

  Future<void> _setAccount(ExpenseCategory category, String value) async {
    final companyId = context.read<ActiveCompanyService>().active!.id;
    await context.read<ExpenseCategoryRepository>().update(
          companyId: companyId,
          id: category.id,
          skr03Account: Value(value.trim().isEmpty ? null : value.trim()),
        );
    await _refresh();
  }

  Future<void> _deleteCategory(ExpenseCategory category) async {
    final companyId = context.read<ActiveCompanyService>().active!.id;
    await context.read<ExpenseCategoryRepository>().delete(companyId: companyId, id: category.id);
    await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Kategorien verwalten'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Die SKR03-Kontonummer ist deine eigene Angabe (am besten mit deinem '
                'Steuerberater abgestimmt) — diese App schlägt keine Kontonummern vor.',
              ),
              const SizedBox(height: 12),
              for (final category in _categories)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(flex: 2, child: Text(category.label)),
                      Expanded(
                        child: TextFormField(
                          initialValue: category.skr03Account,
                          decoration: const InputDecoration(labelText: 'SKR03-Konto'),
                          onFieldSubmitted: (value) => _setAccount(category, value),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        tooltip: 'Löschen',
                        onPressed: () => _deleteCategory(category),
                      ),
                    ],
                  ),
                ),
              const Divider(),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _newLabelCtrl,
                      decoration: const InputDecoration(labelText: 'Neue Kategorie'),
                      onSubmitted: (_) => _addCategory(),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add),
                    tooltip: 'Kategorie hinzufügen',
                    onPressed: _addCategory,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fertig')),
      ],
    );
  }
}

/// C14.5 DATEV-Export (Kay-Priorisierungsentscheidung 2026-10-18,
/// letzter Baustein der vollen Buchhaltung). Siehe ausführlichen
/// Disclaimer in `datev_export_service.dart` — exportiert bewusst nur
/// Belege/Ausgaben, BU-Schlüssel bleibt immer leer.
class _DatevExportDialog extends StatefulWidget {
  const _DatevExportDialog({required this.expenses, required this.categories});
  final List<Expense> expenses;
  final List<ExpenseCategory> categories;

  @override
  State<_DatevExportDialog> createState() => _DatevExportDialogState();
}

class _DatevExportDialogState extends State<_DatevExportDialog> {
  late final TextEditingController _beraterCtrl;
  late final TextEditingController _mandantCtrl;
  late final TextEditingController _gegenkontoCtrl;
  late DateTime _periodStart;
  late DateTime _periodEnd;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    final company = context.read<ActiveCompanyService>().active!;
    _beraterCtrl = TextEditingController(text: company.datevBeraterNummer);
    _mandantCtrl = TextEditingController(text: company.datevMandantNummer);
    _gegenkontoCtrl = TextEditingController(text: company.datevBankGegenkonto);
    final now = DateTime.now();
    _periodStart = DateTime(now.year, now.month, 1);
    _periodEnd = DateTime(now.year, now.month + 1, 1).subtract(const Duration(days: 1));
  }

  @override
  void dispose() {
    _beraterCtrl.dispose();
    _mandantCtrl.dispose();
    _gegenkontoCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickPeriodStart() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _periodStart,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _periodStart = picked);
  }

  Future<void> _pickPeriodEnd() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _periodEnd,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _periodEnd = picked);
  }

  Future<void> _export() async {
    final beraterNummer = _beraterCtrl.text.trim();
    final mandantNummer = _mandantCtrl.text.trim();
    final bankGegenkonto = _gegenkontoCtrl.text.trim();
    if (beraterNummer.isEmpty || mandantNummer.isEmpty || bankGegenkonto.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bitte Berater-, Mandantennummer und Gegenkonto eintragen.'),
        ),
      );
      return;
    }

    setState(() => _exporting = true);
    try {
      final service = context.read<ActiveCompanyService>();
      final company = service.active!;
      // Eingetragene Nummern gleich für den nächsten Export merken.
      await context.read<CompanyRepository>().update(
            company.copyWith(
              datevBeraterNummer: Value(beraterNummer),
              datevMandantNummer: Value(mandantNummer),
              datevBankGegenkonto: Value(bankGegenkonto),
            ),
          );
      await service.refreshActive();

      final expensesInPeriod = widget.expenses
          .where((e) => !e.date.isBefore(_periodStart) && !e.date.isAfter(_periodEnd))
          .toList();
      final result = buildDatevBuchungsstapel(
        expenses: expensesInPeriod,
        categoryById: {for (final c in widget.categories) c.id: c},
        config: DatevExportConfig(
          beraterNummer: beraterNummer,
          mandantNummer: mandantNummer,
          bankGegenkonto: bankGegenkonto,
          sachkontenlaenge: company.datevSachkontenlaenge,
          companyName: company.name,
        ),
        periodStart: _periodStart,
        periodEnd: _periodEnd,
        generatedAt: DateTime.now(),
      );

      // DATEV EXTF erwartet ANSI statt UTF-8 — `encodeDatevAnsi` statt
      // `latin1.encode`, das bei „€“/„–“ im Buchungstext abstürzte.
      final bytes = Uint8List.fromList(encodeDatevAnsi(result.csvContent));
      final timestamp =
          '${_periodStart.year}${_periodStart.month.toString().padLeft(2, '0')}';
      final savedUri = await FilePicker.saveFile(
        fileName: 'EXTF_Buchungsstapel_$timestamp.csv',
        bytes: bytes,
        dialogTitle: 'DATEV-Export speichern',
      );
      if (!mounted) return;
      if (savedUri == null) return; // Dialog abgebrochen, kein falscher Erfolg anzeigen.

      final messages = <String>[
        '${result.exportedCount} Beleg(e) exportiert',
        if (result.skippedExpenses.isNotEmpty)
          '${result.skippedExpenses.length} ohne SKR03-Konto übersprungen (in "Kategorien verwalten" ergänzen)',
      ];
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(messages.join(', '))));
      Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  static String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('DATEV-Export (Belege)'),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Exportiert Belege als DATEV-Buchungsstapel (SKR03). Keine Rechtsprüfung — '
                'der BU-Schlüssel bleibt immer leer und muss von deinem Steuerberater ergänzt '
                'werden. Belege ohne SKR03-Konto werden nicht exportiert.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Von: ${_formatDate(_periodStart)}'),
                trailing: const Icon(Icons.calendar_today_outlined),
                onTap: _pickPeriodStart,
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Bis: ${_formatDate(_periodEnd)}'),
                trailing: const Icon(Icons.calendar_today_outlined),
                onTap: _pickPeriodEnd,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _beraterCtrl,
                decoration: const InputDecoration(labelText: 'Beraternummer *'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _mandantCtrl,
                decoration: const InputDecoration(labelText: 'Mandantennummer *'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _gegenkontoCtrl,
                decoration: const InputDecoration(
                  labelText: 'Gegenkonto (Bank/Kasse) *',
                  hintText: 'z. B. 1200',
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _exporting ? null : () => Navigator.pop(context),
          child: const Text('Abbrechen'),
        ),
        FilledButton(
          onPressed: _exporting ? null : _export,
          child: _exporting
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Exportieren'),
        ),
      ],
    );
  }
}
