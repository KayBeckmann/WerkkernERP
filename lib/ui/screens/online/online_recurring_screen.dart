import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:werkkern_client/werkkern_client.dart';
import 'package:werkkern_core/werkkern_core.dart';

import '../../../domain/services/online_session.dart';
import 'online_documents_screen.dart' show OnlinePickCustomerDialog;
import 'online_form.dart';
import 'online_item_dialog.dart';

const recurrenceIntervalLabels = {'monthly': 'monatlich', 'quarterly': 'vierteljährlich', 'yearly': 'jährlich'};

/// Wiederkehrende Rechnungen (C11) — Bereich „Vorlagen“ wie offline
/// (`recurring_invoice_templates_screen.dart`). Der Server legt fällige
/// Entwürfe täglich selbst an (je verpasster Periode einer); „Fällige
/// jetzt erzeugen“ gibt es nur online.
class OnlineRecurringScreen extends StatelessWidget {
  const OnlineRecurringScreen({super.key, required this.session});
  final OnlineSession session;

  @override
  Widget build(BuildContext context) {
    final canWrite = session.can('invoices.write');
    return OnlineListView<OnlineRecurringTemplate>(
      load: (_) => session.client.recurringTemplates(includeInactive: true),
      emptyText: 'Noch keine wiederkehrenden Vorlagen angelegt.',
      header: (context, items, reload) => canWrite
          ? Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: () async {
                  var created = 0;
                  if (await runOnline(context, () async => created = await session.client.generateRecurringNow()) && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$created fällige(r) Entwurf/Entwürfe angelegt.')));
                  }
                  reload();
                },
                icon: const Icon(Icons.play_arrow_outlined),
                label: const Text('Fällige jetzt erzeugen'),
              ),
            )
          : const SizedBox.shrink(),
      itemBuilder: (context, t, reload) => Card(
        child: ListTile(
          leading: Icon(t.active ? Icons.repeat_outlined : Icons.pause_circle_outline),
          title: Text(t.label),
          subtitle: Text(
            '${t.customerName ?? '(unbekannter Kunde)'} — ${recurrenceIntervalLabels[t.interval] ?? t.interval} '
            '— nächste Rechnung: ${formatOnlineDate(t.nextDueDate)}${t.active ? '' : ' — pausiert'}',
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: canWrite
              ? () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => OnlineRecurringTemplateScreen(session: session, templateId: t.id)),
                  );
                  reload();
                }
              : null,
        ),
      ),
      floatingActionButton: canWrite
          ? (reload) => Builder(
                builder: (context) => FloatingActionButton.extended(
                  heroTag: 'online-recurring-fab',
                  onPressed: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => OnlineRecurringTemplateScreen(session: session)),
                    );
                    reload();
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Neue Vorlage'),
                ),
              )
          : null,
    );
  }
}

/// Vorlage anlegen/bearbeiten inkl. Positionen.
class OnlineRecurringTemplateScreen extends StatefulWidget {
  const OnlineRecurringTemplateScreen({super.key, required this.session, this.templateId});
  final OnlineSession session;
  final String? templateId;

  @override
  State<OnlineRecurringTemplateScreen> createState() => _OnlineRecurringTemplateScreenState();
}

class _OnlineRecurringTemplateScreenState extends State<OnlineRecurringTemplateScreen> {
  List<OnlineCustomer> _customers = const [];
  final _label = TextEditingController();
  final _terms = TextEditingController();
  final _notes = TextEditingController();
  String? _customerId;
  String _interval = 'monthly';
  DateTime _nextDue = DateTime.now();
  bool _active = true;
  List<OnlineDocumentItem> _items = [];
  bool _loading = true;

  WerkkernApiClient get _client => widget.session.client;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [_label, _terms, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    await runOnline(context, () async {
      _customers = await _client.customers();
      if (widget.session.can('articles.read')) _articles = await _client.articles(includeInactive: true);
      _smallBusiness = (await _client.companyProfile()).smallBusinessExempt;
      if (widget.templateId != null) {
        final t = await _client.recurringTemplate(widget.templateId!);
        _label.text = t.label;
        _terms.text = t.paymentTerms ?? '';
        _notes.text = t.notes ?? '';
        _customerId = t.customerId;
        _interval = t.interval;
        _nextDue = t.nextDueDate;
        _active = t.active;
        _items = [...t.items];
      }
    });
    if (mounted) setState(() => _loading = false);
  }

  List<OnlineArticle> _articles = const [];
  bool _smallBusiness = false;

  Future<void> _addItem() async {
    final item = await showOnlineItemDialog(
      context,
      articles: _articles,
      existingGroupLabels: onlineGroupLabels(_items),
      forceZeroVat: _smallBusiness,
    );
    if (item != null) setState(() => _items = [..._items, item]);
  }

  Future<void> _editItem(int index) async {
    final item = await showOnlineItemDialog(
      context,
      articles: _articles,
      existingGroupLabels: onlineGroupLabels(_items),
      existing: _items[index],
      forceZeroVat: _smallBusiness,
    );
    if (item != null) setState(() => _items = [..._items]..[index] = item);
  }

  /// Wie offline: Pausieren/Reaktivieren speichert sofort und schließt.
  Future<void> _togglePause() async {
    _active = !_active;
    await _save();
  }

  Future<void> _save() async {
    if (_customerId == null || _label.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bitte Bezeichnung und Kunde angeben.')));
      return;
    }
    if (await runOnline(
      context,
      () => _client.saveRecurringTemplate(
        id: widget.templateId,
        customerId: _customerId!,
        label: _label.text.trim(),
        interval: _interval,
        nextDueDate: DateTime.utc(_nextDue.year, _nextDue.month, _nextDue.day),
        paymentTerms: _terms.text.trim().isEmpty ? null : _terms.text.trim(),
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        active: _active,
        items: _items,
      ),
    )) {
      if (mounted) Navigator.of(context).pop();
    }
  }

  static InvoiceTotals _totalsOf(Iterable<OnlineDocumentItem> items) => calculateInvoiceTotals([
        for (final i in items)
          InvoiceLineInput(
            quantity: Decimal.parse(i.quantity),
            unitPriceCents: i.unitPriceCents,
            vatRatePercent: i.vatRatePercent,
            discountPercent: i.discountPercent,
          ),
      ]);

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.templateId != null;
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Vorlage bearbeiten' : 'Neue Vorlage'),
        actions: [
          if (isEdit)
            IconButton(
              icon: Icon(_active ? Icons.pause_outlined : Icons.play_arrow_outlined),
              tooltip: _active ? 'Pausieren' : 'Reaktivieren',
              onPressed: _togglePause,
            ),
          if (isEdit)
            IconButton(
              tooltip: 'Löschen',
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                if (!await confirmOnline(
                  context,
                  'Vorlage löschen?',
                  'Bereits erzeugte Rechnungsentwürfe bleiben erhalten — nur die Vorlage selbst wird '
                      'entfernt. Diese Aktion kann nicht rückgängig gemacht werden.',
                )) {
                  return;
                }
                if (!context.mounted) return;
                if (await runOnline(context, () => _client.deleteRecurringTemplate(widget.templateId!)) && context.mounted) {
                  Navigator.of(context).pop();
                }
              },
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(key: const Key('recurring-label'), controller: _label, decoration: const InputDecoration(labelText: 'Bezeichnung *')),
          const SizedBox(height: 8),
          if (isEdit)
            // Kunde ist nach dem Anlegen nicht mehr änderbar (wie offline).
            InputDecorator(
              decoration: const InputDecoration(labelText: 'Kunde *', enabled: false),
              child: Text(_customers.where((c) => c.id == _customerId).firstOrNull?.name ?? ''),
            )
          else
            InkWell(
              key: const Key('recurring-customer'),
              onTap: () async {
                final picked = await showDialog<OnlineCustomer>(
                  context: context,
                  builder: (_) => OnlinePickCustomerDialog(customers: _customers),
                );
                if (picked != null) setState(() => _customerId = picked.id);
              },
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'Kunde *', suffixIcon: Icon(Icons.search)),
                child: Text(_customers.where((c) => c.id == _customerId).firstOrNull?.name ?? 'Kunde wählen'),
              ),
            ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: _interval,
            decoration: const InputDecoration(labelText: 'Intervall'),
            items: [
              for (final e in recurrenceIntervalLabels.entries)
                DropdownMenuItem(value: e.key, child: Text('${e.value[0].toUpperCase()}${e.value.substring(1)}')),
            ],
            onChanged: (v) => setState(() => _interval = v!),
          ),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('Nächste Rechnung: ${formatOnlineDate(_nextDue)}'),
            trailing: const Icon(Icons.calendar_today_outlined),
            onTap: () async {
              final picked = await showDatePicker(context: context, initialDate: _nextDue, firstDate: DateTime(2000), lastDate: DateTime(2100));
              if (picked != null) setState(() => _nextDue = picked);
            },
          ),
          const SizedBox(height: 8),
          TextField(controller: _terms, decoration: const InputDecoration(labelText: 'Zahlungsbedingungen')),
          const SizedBox(height: 8),
          TextField(controller: _notes, maxLines: 2, decoration: const InputDecoration(labelText: 'Notizen')),
          const SizedBox(height: 16),
          Text('Positionen', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          for (final (index, i) in _items.indexed)
            Card(
              child: ListTile(
                title: Text(i.description),
                subtitle: Text('${i.quantity.replaceAll('.', ',')} × ${Money.fromCents(i.unitPriceCents)}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_totalsOf([i]).totalGross.toString()),
                    IconButton(
                      tooltip: 'Position entfernen',
                      icon: const Icon(Icons.delete_outline, size: 20),
                      onPressed: () => setState(() => _items = [..._items]..removeAt(index)),
                    ),
                  ],
                ),
                onTap: () => _editItem(index),
              ),
            ),
          const SizedBox(height: 8),
          OutlinedButton.icon(onPressed: _addItem, icon: const Icon(Icons.add), label: const Text('Position hinzufügen')),
          const SizedBox(height: 8),
          Text(
            'Der Server legt fällige Rechnungen täglich als Entwurf an — je verpasster Periode einer. Finalisiert wird nie automatisch.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 24),
          FilledButton(onPressed: _save, child: const Text('Speichern')),
        ],
      ),
    );
  }
}
