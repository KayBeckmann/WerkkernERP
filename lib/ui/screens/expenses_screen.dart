import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/database/database.dart';
import '../../data/database/tables.dart';
import '../../data/repositories/expense_category_repository.dart';
import '../../data/repositories/expense_repository.dart';
import '../../domain/models/money.dart';
import '../../domain/services/active_company_service.dart';

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
  const _ExpensesData({required this.expenses, required this.categories});
  final List<Expense> expenses;
  final List<ExpenseCategory> categories;
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
    final companyId = context.read<ActiveCompanyService>().active!.id;
    final categoryRepo = context.read<ExpenseCategoryRepository>();
    final expenseRepo = context.read<ExpenseRepository>();
    // Lazy seed (siehe Doc-Kommentar bei `seedDefaultsIfNeverSeeded`) —
    // bewusst hier und nicht beim Aktivieren des Modul-Schalters.
    await categoryRepo.seedDefaultsIfNeverSeeded(companyId);
    final expenses = await expenseRepo.listForCompany(companyId);
    final categories = await categoryRepo.listForCompany(companyId);
    return _ExpensesData(expenses: expenses, categories: categories);
  }

  // Bewusst ein Block-Body, nicht `setState(() => _future = _load())` —
  // siehe dieselbe Begründung in vehicles_screen.dart/projects_screen.dart.
  void _reload() => setState(() {
        _future = _load();
      });

  Future<void> _createOrEdit({Expense? existing, required List<ExpenseCategory> categories}) async {
    final result = await showDialog<_ExpenseFormResult>(
      context: context,
      builder: (context) => _ExpenseFormDialog(categories: categories, existing: existing),
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
                    '${expense.categoryId != null ? ' — ${categoryLabelById[expense.categoryId] ?? "Kategorie gelöscht"}' : ''}',
                  ),
                  trailing: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 4,
                    children: [
                      Text(Money.fromCents(expense.amountGrossCents).toString()),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        tooltip: 'Bearbeiten',
                        onPressed: () => _createOrEdit(existing: expense, categories: data.categories),
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
          onPressed: snapshot.hasData
              ? () => _createOrEdit(categories: snapshot.data!.categories)
              : null,
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
  });
  final DateTime date;
  final String description;
  final int amountGrossCents;
  final double vatRatePercent;
  final String? categoryId;
  final String? supplierReference;
}

class _ExpenseFormDialog extends StatefulWidget {
  const _ExpenseFormDialog({required this.categories, this.existing});
  final List<ExpenseCategory> categories;
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
