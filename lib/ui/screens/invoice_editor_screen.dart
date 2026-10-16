import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/database/database.dart';
import '../../data/database/tables.dart';
import '../../data/repositories/article_repository.dart';
import '../../data/repositories/invoice_repository.dart';
import '../../domain/models/money.dart';
import '../../domain/services/active_company_service.dart';
import '../../domain/services/invoice_totals_service.dart';
import '../widgets/invoice_item_dialog.dart';

/// Editiert einen Rechnungsentwurf (A2) — Entwürfe sind frei bearbeitbar
/// und nummernlos (F3); Finalisierung kommt mit A3.
class InvoiceEditorScreen extends StatefulWidget {
  const InvoiceEditorScreen({super.key, required this.customer, this.invoice});

  final Customer customer;

  /// `null` = neue Rechnung.
  final Invoice? invoice;

  @override
  State<InvoiceEditorScreen> createState() => _InvoiceEditorScreenState();
}

class _EditableItem {
  _EditableItem({
    required this.kind,
    this.articleId,
    required this.description,
    required this.quantity,
    required this.unitPriceCents,
    required this.vatRatePercent,
    this.groupLabel,
    this.existingId,
  });

  final InvoiceItemKind kind;
  final String? articleId;
  final String description;
  final Decimal quantity;
  final int unitPriceCents;
  final double vatRatePercent;
  final String? groupLabel;
  final String? existingId;

  InvoiceItemInput toInput() => InvoiceItemInput(
        id: existingId,
        kind: kind,
        articleId: articleId,
        description: description,
        quantity: quantity,
        unitPriceCents: unitPriceCents,
        vatRatePercent: vatRatePercent,
        groupLabel: groupLabel,
      );
}

class _InvoiceEditorScreenState extends State<InvoiceEditorScreen> {
  final List<_EditableItem> _items = [];
  late DateTime _issueDate;
  late DateTime _serviceDate;
  final _notesCtrl = TextEditingController();
  final _paymentTermsCtrl = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  List<Article> _articles = [];

  @override
  void initState() {
    super.initState();
    _issueDate = DateTime.now();
    _serviceDate = DateTime.now();
    _init();
  }

  Future<void> _init() async {
    final companyId = context.read<ActiveCompanyService>().active!.id;
    final articleRepo = context.read<ArticleRepository>();
    final invoiceRepo = context.read<InvoiceRepository>();
    _articles = await articleRepo.listForCompany(companyId);

    final invoice = widget.invoice;
    if (invoice != null) {
      _issueDate = invoice.issueDate;
      _serviceDate = invoice.serviceDate;
      _notesCtrl.text = invoice.notes ?? '';
      _paymentTermsCtrl.text = invoice.paymentTerms ?? '';
      final items = await invoiceRepo.itemsFor(invoice.id);
      _items.addAll([
        for (final item in items)
          _EditableItem(
            existingId: item.id,
            kind: item.kind,
            articleId: item.articleId,
            description: item.description,
            quantity: Decimal.parse(item.quantity),
            unitPriceCents: item.unitPriceCents,
            vatRatePercent: item.vatRatePercent,
            groupLabel: item.groupLabel,
          ),
      ]);
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    _paymentTermsCtrl.dispose();
    super.dispose();
  }

  InvoiceTotals get _totals => calculateInvoiceTotals([
        for (final item in _items)
          InvoiceLineInput(
            quantity: item.quantity,
            unitPriceCents: item.unitPriceCents,
            vatRatePercent: item.vatRatePercent,
          ),
      ]);

  Future<void> _addItem() async {
    final result = await showInvoiceItemDialog(context: context, articles: _articles);
    if (result == null) return;
    setState(() {
      _items.add(
        _EditableItem(
          kind: result.kind,
          articleId: result.articleId,
          description: result.description,
          quantity: result.quantity,
          unitPriceCents: result.unitPriceCents,
          vatRatePercent: result.vatRatePercent,
          groupLabel: result.groupLabel,
        ),
      );
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final companyId = context.read<ActiveCompanyService>().active!.id;
      final repo = context.read<InvoiceRepository>();
      final items = [for (final item in _items) item.toInput()];
      final invoice = widget.invoice;
      if (invoice == null) {
        await repo.createDraft(
          companyId: companyId,
          customerId: widget.customer.id,
          issueDate: _issueDate,
          serviceDate: _serviceDate,
          paymentTerms: _paymentTermsCtrl.text.trim().isEmpty ? null : _paymentTermsCtrl.text.trim(),
          notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
          items: items,
        );
      } else {
        await repo.update(
          companyId: companyId,
          id: invoice.id,
          issueDate: _issueDate,
          serviceDate: _serviceDate,
          paymentTerms: _paymentTermsCtrl.text.trim().isEmpty ? null : _paymentTermsCtrl.text.trim(),
          notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
          items: items,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Positionen nach Gruppe sortiert anzeigen (ungruppierte zuletzt).
    final groups = <String?, List<_EditableItem>>{};
    for (final item in _items) {
      groups.putIfAbsent(item.groupLabel, () => []).add(item);
    }
    final orderedKeys = groups.keys.toList()
      ..sort((a, b) {
        if (a == null) return 1;
        if (b == null) return -1;
        return a.compareTo(b);
      });

    final totals = _totals;

    return Scaffold(
      appBar: AppBar(
        title: Text('Rechnung — ${widget.customer.name}'),
        actions: [
          IconButton(
            icon: _saving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.save_outlined),
            tooltip: 'Entwurf speichern',
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
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
          for (final key in orderedKeys) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                key ?? 'Ohne Gruppe',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            for (final item in groups[key]!)
              Card(
                child: ListTile(
                  title: Text(item.description),
                  subtitle: Text(
                    '${item.quantity} × ${Money.fromCents(item.unitPriceCents)} '
                    '(${item.vatRatePercent.toStringAsFixed(0)} %)',
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => setState(() => _items.remove(item)),
                  ),
                ),
              ),
          ],
          const SizedBox(height: 16),
          Card(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final rate in totals.sortedRates)
                    Text(
                      'Netto ${rate.toStringAsFixed(0)} %: ${totals.netByRate[rate]}   '
                      'Steuer: ${totals.taxByRate[rate]}',
                    ),
                  const Divider(),
                  Text(
                    'Gesamt: ${totals.totalGross}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'invoice-editor-fab',
        onPressed: _addItem,
        icon: const Icon(Icons.add),
        label: const Text('Position hinzufügen'),
      ),
    );
  }
}
