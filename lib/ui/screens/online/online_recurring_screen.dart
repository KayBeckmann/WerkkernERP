import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:werkkern_client/werkkern_client.dart';
import 'package:werkkern_core/werkkern_core.dart';

import '../../../domain/services/online_session.dart';
import 'online_form.dart';

const recurrenceIntervalLabels = {'monthly': 'monatlich', 'quarterly': 'vierteljährlich', 'yearly': 'jährlich'};

/// Wiederkehrende Rechnungen (C11): Vorlagen pflegen; der Server legt
/// fällige Entwürfe täglich selbst an (je verpasster Periode einer).
class OnlineRecurringScreen extends StatelessWidget {
  const OnlineRecurringScreen({super.key, required this.session});
  final OnlineSession session;

  @override
  Widget build(BuildContext context) {
    final canWrite = session.can('invoices.write');
    return OnlineListView<OnlineRecurringTemplate>(
      load: (_) => session.client.recurringTemplates(includeInactive: true),
      emptyText: 'Noch keine Vorlagen.',
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
          leading: Icon(t.active ? Icons.autorenew : Icons.pause_circle_outline),
          title: Text('${t.label} · ${t.customerName ?? ''}'),
          subtitle: Text([
            recurrenceIntervalLabels[t.interval] ?? t.interval,
            'nächste ${formatOnlineDate(t.nextDueDate)}',
            if (!t.active) 'pausiert',
          ].join(' · ')),
          trailing: Text(Money.fromCents(t.grossCents).toString()),
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
                  label: const Text('Vorlage anlegen'),
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

  Future<void> _addItem() async {
    final values = await showOnlineForm(
      context,
      title: 'Position',
      submitLabel: 'Übernehmen',
      fields: const [
        OnlineField('kind', 'Art', type: OnlineFieldType.choice, required: true, initial: 'text',
            options: {'text': 'Freitext/Pauschale', 'hours': 'Stunden', 'article': 'Artikel'}),
        OnlineField('description', 'Beschreibung', required: true),
        OnlineField('quantity', 'Menge', type: OnlineFieldType.decimal, required: true, initial: '1'),
        OnlineField('price', 'Einzelpreis (netto)', type: OnlineFieldType.money, required: true),
        OnlineField('vat', 'Steuersatz', type: OnlineFieldType.choice, required: true, initial: '19',
            options: {'19': '19 %', '7': '7 %', '0': '0 %'}),
      ],
    );
    if (values == null) return;
    setState(() => _items = [
          ..._items,
          OnlineDocumentItem(
            kind: OnlineItemKind.values.byName(values['kind'] as String),
            description: values['description'] as String,
            quantity: values['quantity'] as String,
            unitPriceCents: values['price'] as int,
            vatRatePercent: double.parse(values['vat'] as String),
          ),
        ]);
  }

  Future<void> _save() async {
    if (_customerId == null || _label.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bezeichnung und Kunde sind Pflicht.')));
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

  @override
  Widget build(BuildContext context) {
    final totals = calculateInvoiceTotals([
      for (final i in _items)
        InvoiceLineInput(
          quantity: Decimal.parse(i.quantity),
          unitPriceCents: i.unitPriceCents,
          vatRatePercent: i.vatRatePercent,
          discountPercent: i.discountPercent,
        ),
    ]);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.templateId == null ? 'Neue Vorlage' : 'Vorlage'),
        actions: [
          if (widget.templateId != null)
            IconButton(
              tooltip: 'Vorlage löschen',
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                if (!await confirmOnline(context, 'Vorlage löschen?', 'Bereits erzeugte Rechnungen bleiben erhalten.')) return;
                if (!context.mounted) return;
                if (await runOnline(context, () => _client.deleteRecurringTemplate(widget.templateId!)) && context.mounted) {
                  Navigator.of(context).pop();
                }
              },
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(padding: const EdgeInsets.all(12), child: FilledButton(onPressed: _loading ? null : _save, child: const Text('Speichern'))),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                TextField(key: const Key('recurring-label'), controller: _label, decoration: const InputDecoration(labelText: 'Bezeichnung *')),
                DropdownButtonFormField<String>(
                  key: const Key('recurring-customer'),
                  initialValue: _customerId,
                  decoration: const InputDecoration(labelText: 'Kunde *'),
                  items: [for (final c in _customers) DropdownMenuItem(value: c.id, child: Text(c.name))],
                  onChanged: (v) => setState(() => _customerId = v),
                ),
                DropdownButtonFormField<String>(
                  initialValue: _interval,
                  decoration: const InputDecoration(labelText: 'Intervall'),
                  items: [for (final e in recurrenceIntervalLabels.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
                  onChanged: (v) => setState(() => _interval = v!),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Nächste Fälligkeit'),
                  subtitle: Text(formatOnlineDate(_nextDue)),
                  trailing: const Icon(Icons.calendar_today_outlined),
                  onTap: () async {
                    final picked = await showDatePicker(context: context, initialDate: _nextDue, firstDate: DateTime(2000), lastDate: DateTime(2100));
                    if (picked != null) setState(() => _nextDue = picked);
                  },
                ),
                TextField(controller: _terms, decoration: const InputDecoration(labelText: 'Zahlungsbedingungen')),
                TextField(controller: _notes, maxLines: 2, decoration: const InputDecoration(labelText: 'Notizen')),
                SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Aktiv'), value: _active, onChanged: (v) => setState(() => _active = v)),
                const SizedBox(height: 8),
                Text('Positionen', style: Theme.of(context).textTheme.titleMedium),
                for (final (index, i) in _items.indexed)
                  Card(
                    child: ListTile(
                      title: Text(i.description),
                      subtitle: Text('${i.quantity.replaceAll('.', ',')} × ${Money.fromCents(i.unitPriceCents)} · ${i.vatRatePercent.toStringAsFixed(0)} %'),
                      trailing: IconButton(
                        tooltip: 'Position entfernen',
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: () => setState(() => _items = [..._items]..removeAt(index)),
                      ),
                    ),
                  ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(onPressed: _addItem, icon: const Icon(Icons.add), label: const Text('Position hinzufügen')),
                ),
                ListTile(title: const Text('Brutto je Rechnung'), trailing: Text(totals.totalGross.toString())),
                Text(
                  'Der Server legt fällige Rechnungen täglich als Entwurf an — je verpasster Periode einer. Finalisiert wird nie automatisch.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
    );
  }
}
