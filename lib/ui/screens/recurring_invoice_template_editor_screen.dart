import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/database/database.dart';
import '../../data/database/tables.dart';
import '../../data/repositories/article_repository.dart';
import '../../data/repositories/customer_repository.dart';
import '../../data/repositories/invoice_repository.dart';
import '../../data/repositories/recurring_invoice_template_repository.dart';
import '../../domain/models/money.dart';
import '../../domain/services/active_company_service.dart';
import '../widgets/invoice_item_dialog.dart';

/// Anlegen/Bearbeiten einer wiederkehrenden Rechnungsvorlage (C11-Kern,
/// Kay-Priorisierungsentscheidung 2026-10-17). Positionen funktionieren
/// bewusst genauso wie im `InvoiceEditorScreen` (gleicher Dialog,
/// gleiche Felder) — eine Vorlage ist inhaltlich nichts anderes als eine
/// Rechnung ohne Status/Nummer, nur mit Intervall und Fälligkeitsdatum
/// zusätzlich.
class RecurringInvoiceTemplateEditorScreen extends StatefulWidget {
  const RecurringInvoiceTemplateEditorScreen({super.key, this.template});

  /// `null` = neue Vorlage.
  final RecurringInvoiceTemplate? template;

  @override
  State<RecurringInvoiceTemplateEditorScreen> createState() =>
      _RecurringInvoiceTemplateEditorScreenState();
}

class _TemplateItem {
  _TemplateItem({
    required this.kind,
    this.articleId,
    required this.description,
    required this.quantity,
    required this.unitPriceCents,
    required this.vatRatePercent,
    this.unit,
    this.discountPercent = 0,
    this.groupLabel,
  });

  final InvoiceItemKind kind;
  final String? articleId;
  final String description;
  final Decimal quantity;
  final int unitPriceCents;
  final double vatRatePercent;
  final String? unit;
  final double discountPercent;
  final String? groupLabel;

  Money get lineGross => Money.fromCents(unitPriceCents).multiplyByQuantity(quantity);

  InvoiceItemInput toInput() => InvoiceItemInput(
        kind: kind,
        articleId: articleId,
        description: description,
        quantity: quantity,
        unitPriceCents: unitPriceCents,
        vatRatePercent: vatRatePercent,
        unit: unit,
        discountPercent: discountPercent,
        groupLabel: groupLabel,
      );

  InvoiceItemInputResult toResult() => InvoiceItemInputResult(
        kind: kind,
        articleId: articleId,
        description: description,
        quantity: quantity,
        unitPriceCents: unitPriceCents,
        vatRatePercent: vatRatePercent,
        unit: unit,
        discountPercent: discountPercent,
        groupLabel: groupLabel,
      );
}

class _RecurringInvoiceTemplateEditorScreenState extends State<RecurringInvoiceTemplateEditorScreen> {
  bool _loading = true;
  bool _saving = false;
  final _labelCtrl = TextEditingController();
  final _paymentTermsCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  RecurrenceInterval _interval = RecurrenceInterval.monthly;
  DateTime _nextDueDate = DateTime.now();
  String? _customerId;
  List<Customer> _customers = [];
  List<Article> _articles = [];
  final List<_TemplateItem> _items = [];

  // Kleinunternehmerregelung §19 UStG (Nachtrag 2026-10-18) — erzwingt
  // 0 % USt im Positions-Dialog, siehe `invoice_item_dialog.dart`.
  bool _isSmallBusinessExempt = false;

  bool get _isEdit => widget.template != null;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final company = context.read<ActiveCompanyService>().active!;
    final companyId = company.id;
    final customerRepo = context.read<CustomerRepository>();
    final articleRepo = context.read<ArticleRepository>();
    final templateRepo = context.read<RecurringInvoiceTemplateRepository>();
    _customers = await customerRepo.listForCompany(companyId);
    _articles = await articleRepo.listForCompany(companyId);
    _isSmallBusinessExempt = company.isSmallBusinessExempt;

    final template = widget.template;
    if (template != null) {
      _labelCtrl.text = template.label;
      _paymentTermsCtrl.text = template.paymentTerms ?? '';
      _notesCtrl.text = template.notes ?? '';
      _interval = template.interval;
      _nextDueDate = template.nextDueDate;
      _customerId = template.customerId;
      final items = await templateRepo.itemsFor(template.id);
      _items.addAll([
        for (final item in items)
          _TemplateItem(
            kind: item.kind,
            articleId: item.articleId,
            description: item.description,
            quantity: Decimal.parse(item.quantity),
            unitPriceCents: item.unitPriceCents,
            vatRatePercent: item.vatRatePercent,
            unit: item.unit,
            discountPercent: item.discountPercent,
            groupLabel: item.groupLabel,
          ),
      ]);
    } else if (_customers.isNotEmpty) {
      _customerId = _customers.first.id;
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _labelCtrl.dispose();
    _paymentTermsCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _nextDueDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _nextDueDate = picked);
  }

  Future<void> _addItem() async {
    final result = await showInvoiceItemDialog(
      context: context,
      articles: _articles,
      forceZeroVat: _isSmallBusinessExempt,
    );
    if (result == null) return;
    setState(() {
      _items.add(
        _TemplateItem(
          kind: result.kind,
          articleId: result.articleId,
          description: result.description,
          quantity: result.quantity,
          unitPriceCents: result.unitPriceCents,
          vatRatePercent: result.vatRatePercent,
          unit: result.unit,
          discountPercent: result.discountPercent,
          groupLabel: result.groupLabel,
        ),
      );
    });
  }

  Future<void> _editItem(_TemplateItem item) async {
    final result = await showInvoiceItemDialog(
      context: context,
      articles: _articles,
      existing: item.toResult(),
      forceZeroVat: _isSmallBusinessExempt,
    );
    if (result == null) return;
    setState(() {
      final index = _items.indexOf(item);
      _items[index] = _TemplateItem(
        kind: result.kind,
        articleId: result.articleId,
        description: result.description,
        quantity: result.quantity,
        unitPriceCents: result.unitPriceCents,
        vatRatePercent: result.vatRatePercent,
        unit: result.unit,
        discountPercent: result.discountPercent,
        groupLabel: result.groupLabel,
      );
    });
  }

  Future<void> _save() async {
    if (_labelCtrl.text.trim().isEmpty || _customerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bitte Bezeichnung und Kunde angeben.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final companyId = context.read<ActiveCompanyService>().active!.id;
      final repo = context.read<RecurringInvoiceTemplateRepository>();
      final items = [for (final item in _items) item.toInput()];
      final paymentTerms = _paymentTermsCtrl.text.trim().isEmpty ? null : _paymentTermsCtrl.text.trim();
      final notes = _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim();

      if (_isEdit) {
        await repo.update(
          companyId: companyId,
          id: widget.template!.id,
          label: _labelCtrl.text.trim(),
          interval: _interval,
          nextDueDate: _nextDueDate,
          paymentTerms: paymentTerms,
          notes: notes,
          items: items,
        );
      } else {
        await repo.create(
          companyId: companyId,
          customerId: _customerId!,
          label: _labelCtrl.text.trim(),
          interval: _interval,
          nextDueDate: _nextDueDate,
          paymentTerms: paymentTerms,
          notes: notes,
          items: items,
        );
      }
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _togglePause() async {
    final template = widget.template;
    if (template == null) return;
    final companyId = context.read<ActiveCompanyService>().active!.id;
    await context.read<RecurringInvoiceTemplateRepository>().setActive(
          companyId: companyId,
          id: template.id,
          active: !template.active,
        );
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final template = widget.template;
    if (template == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Vorlage löschen?'),
        content: const Text(
          'Bereits erzeugte Rechnungsentwürfe bleiben erhalten — nur die Vorlage selbst wird '
          'entfernt. Diese Aktion kann nicht rückgängig gemacht werden.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Abbrechen')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Löschen')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final companyId = context.read<ActiveCompanyService>().active!.id;
    await context.read<RecurringInvoiceTemplateRepository>().delete(companyId: companyId, id: template.id);
    if (mounted) Navigator.of(context).pop();
  }

  static String _intervalLabel(RecurrenceInterval interval) => switch (interval) {
        RecurrenceInterval.monthly => 'Monatlich',
        RecurrenceInterval.quarterly => 'Vierteljährlich',
        RecurrenceInterval.yearly => 'Jährlich',
      };

  String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Vorlage bearbeiten' : 'Neue Vorlage'),
        actions: [
          if (_isEdit)
            IconButton(
              icon: Icon(widget.template!.active ? Icons.pause_outlined : Icons.play_arrow_outlined),
              tooltip: widget.template!.active ? 'Pausieren' : 'Reaktivieren',
              onPressed: _togglePause,
            ),
          if (_isEdit)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Löschen',
              onPressed: _delete,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _labelCtrl,
            decoration: const InputDecoration(labelText: 'Bezeichnung *'),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String?>(
            isExpanded: true,
            initialValue: _customerId,
            decoration: const InputDecoration(labelText: 'Kunde *'),
            // Kunde ist nach dem Anlegen nicht mehr änderbar — gleiches
            // Prinzip wie bei einer Rechnung (customer ist final).
            onChanged: _isEdit ? null : (value) => setState(() => _customerId = value),
            items: [
              for (final customer in _customers)
                DropdownMenuItem(value: customer.id, child: Text(customer.name)),
            ],
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<RecurrenceInterval>(
            isExpanded: true,
            initialValue: _interval,
            decoration: const InputDecoration(labelText: 'Intervall'),
            items: [
              for (final interval in RecurrenceInterval.values)
                DropdownMenuItem(value: interval, child: Text(_intervalLabel(interval))),
            ],
            onChanged: (value) => setState(() => _interval = value!),
          ),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Nächste Rechnung: ${_formatDate(_nextDueDate)}'),
            trailing: const Icon(Icons.calendar_today_outlined),
            onTap: _pickDate,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _paymentTermsCtrl,
            decoration: const InputDecoration(labelText: 'Zahlungsbedingungen'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _notesCtrl,
            decoration: const InputDecoration(labelText: 'Notizen'),
            maxLines: 2,
          ),
          const SizedBox(height: 16),
          Text('Positionen', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          for (final item in _items)
            Card(
              child: ListTile(
                title: Text(item.description),
                subtitle: Text('${item.quantity} × ${Money.fromCents(item.unitPriceCents)}'),
                trailing: Text(item.lineGross.toString()),
                onTap: () => _editItem(item),
              ),
            ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _addItem,
            icon: const Icon(Icons.add),
            label: const Text('Position hinzufügen'),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Speichern'),
          ),
        ],
      ),
    );
  }
}
