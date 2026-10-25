import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:werkkern_client/werkkern_client.dart';
import 'package:werkkern_core/werkkern_core.dart';

import '../../../domain/services/bank_csv_import_service.dart';
import '../../../domain/services/online_session.dart';
import 'online_document_screen.dart';
import 'online_form.dart';

/// Buchhaltung der Online-Firma (C14): offene Posten, Belege mit
/// DATEV-Export, EÜR-Übersicht, Bankabgleich per CSV. Wie offline eine
/// interne Übersicht, **keine Steuerberatung**.
class OnlineAccountingScreen extends StatelessWidget {
  const OnlineAccountingScreen({super.key, required this.session});
  final OnlineSession session;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Column(
        children: [
          const TabBar(
            isScrollable: true,
            tabs: [Tab(text: 'Offene Posten'), Tab(text: 'Belege'), Tab(text: 'EÜR'), Tab(text: 'Bank')],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _OpenItemsTab(session: session),
                _ExpensesTab(session: session),
                _EuerTab(session: session),
                _BankTab(session: session),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _euro(int cents) => Money.fromCents(cents).toString();

/// Zeitraum: ein Jahr, optional ein Monat daraus.
class _Period {
  const _Period(this.year, [this.month]);
  final int year;
  final int? month;
  DateTime get from => DateTime.utc(year, month ?? 1);
  DateTime get to => month == null ? DateTime.utc(year, 12, 31) : DateTime.utc(year, month! + 1, 0);
  String get label => month == null ? '$year' : '${month.toString().padLeft(2, '0')}/$year';
}

class _PeriodBar extends StatelessWidget {
  const _PeriodBar({required this.period, required this.onChanged});
  final _Period period;
  final ValueChanged<_Period> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          tooltip: 'Zurück',
          icon: const Icon(Icons.chevron_left),
          onPressed: () => onChanged(period.month == null
              ? _Period(period.year - 1)
              : period.month == 1
                  ? _Period(period.year - 1, 12)
                  : _Period(period.year, period.month! - 1)),
        ),
        Expanded(child: Center(child: Text(period.label, style: Theme.of(context).textTheme.titleMedium))),
        IconButton(
          tooltip: 'Weiter',
          icon: const Icon(Icons.chevron_right),
          onPressed: () => onChanged(period.month == null
              ? _Period(period.year + 1)
              : period.month == 12
                  ? _Period(period.year + 1, 1)
                  : _Period(period.year, period.month! + 1)),
        ),
        TextButton(
          onPressed: () => onChanged(period.month == null ? _Period(period.year, DateTime.now().month) : _Period(period.year)),
          child: Text(period.month == null ? 'Monat' : 'Jahr'),
        ),
      ],
    );
  }
}

// ---- Offene Posten -------------------------------------------------------------

class _OpenItemsTab extends StatefulWidget {
  const _OpenItemsTab({required this.session});
  final OnlineSession session;

  @override
  State<_OpenItemsTab> createState() => _OpenItemsTabState();
}

class _OpenItemsTabState extends State<_OpenItemsTab> {
  late Future<({int totalCents, List<OnlineOpenItemGroup> customers})> _future = widget.session.client.openItems();

  void _reload() => setState(() {
        _future = widget.session.client.openItems();
      });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<({int totalCents, List<OnlineOpenItemGroup> customers})>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text(describeOnlineError(snapshot.error!)));
        final data = snapshot.data;
        if (data == null) return const Center(child: CircularProgressIndicator());
        final today = DateTime.now();
        return RefreshIndicator(
          onRefresh: () async => _reload(),
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              Card(
                child: ListTile(
                  title: const Text('Offen gesamt'),
                  trailing: Text(_euro(data.totalCents), style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              if (data.customers.isEmpty)
                const Padding(padding: EdgeInsets.all(24), child: Center(child: Text('Keine offenen Rechnungen.'))),
              for (final g in data.customers)
                Card(
                  child: ExpansionTile(
                    title: Text(g.customerName),
                    trailing: Text(_euro(g.totalCents)),
                    children: [
                      for (final i in g.items)
                        ListTile(
                          dense: true,
                          title: Text(i.number ?? 'Rechnung'),
                          subtitle: Text([
                            'vom ${formatOnlineDate(i.issueDate)}',
                            if (i.dueDate != null)
                              '${i.dueDate!.isBefore(today) ? 'überfällig seit' : 'fällig'} ${formatOnlineDate(i.dueDate!)}',
                          ].join(' · ')),
                          trailing: Text(_euro(i.grossCents)),
                          onTap: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => OnlineDocumentScreen(session: widget.session, documentId: i.documentId),
                              ),
                            );
                            _reload();
                          },
                        ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

// ---- Belege ----------------------------------------------------------------------

class _ExpensesTab extends StatefulWidget {
  const _ExpensesTab({required this.session});
  final OnlineSession session;

  @override
  State<_ExpensesTab> createState() => _ExpensesTabState();
}

class _ExpensesTabState extends State<_ExpensesTab> {
  _Period _period = _Period(DateTime.now().year, DateTime.now().month);
  late Future<(List<OnlineExpense>, int, List<OnlineExpenseCategory>)> _future = _load();

  WerkkernApiClient get _client => widget.session.client;
  bool get _canWrite => widget.session.can('accounting.write');

  Future<(List<OnlineExpense>, int, List<OnlineExpenseCategory>)> _load() async {
    final categories = await _client.expenseCategories();
    final result = await _client.expenses(from: _period.from, to: _period.to);
    return (result.expenses, result.totalGrossCents, categories);
  }

  void _reload() => setState(() {
        _future = _load();
      });

  Future<void> _edit(List<OnlineExpenseCategory> categories, [OnlineExpense? existing]) async {
    final projects = widget.session.modules.contains('projects') && widget.session.can('projects.read')
        ? await _client.projects()
        : const <OnlineProject>[];
    if (!mounted) return;
    final values = await showOnlineForm(
      context,
      title: existing == null ? 'Neuer Beleg' : 'Beleg bearbeiten',
      fields: [
        OnlineField('date', 'Belegdatum', type: OnlineFieldType.date, required: true, initial: existing?.date ?? DateTime.now()),
        OnlineField('description', 'Beschreibung', required: true, initial: existing?.description),
        OnlineField('amount', 'Betrag (brutto)', type: OnlineFieldType.money, required: true, initial: existing?.amountGrossCents),
        OnlineField(
          'vat',
          'Steuersatz',
          type: OnlineFieldType.choice,
          required: true,
          initial: (existing?.vatRatePercent ?? 19).toStringAsFixed(0),
          options: const {'19': '19 %', '7': '7 %', '0': '0 %'},
        ),
        OnlineField(
          'categoryId',
          'Kategorie',
          type: OnlineFieldType.choice,
          initial: existing?.categoryId,
          options: {
            for (final c in categories) c.id: c.skr03Account == null ? c.label : '${c.label} (${c.skr03Account})',
          },
        ),
        OnlineField('supplierReference', 'Belegnummer des Lieferanten', initial: existing?.supplierReference),
        if (projects.isNotEmpty)
          OnlineField(
            'projectId',
            'Projekt',
            type: OnlineFieldType.choice,
            initial: existing?.projectId,
            options: {for (final p in projects) p.id: '${p.displayNumber} · ${p.name}'},
            helper: 'Fließt als Kosten in die Projekt-Ergebnisrechnung ein.',
          ),
      ],
    );
    if (values == null || !mounted) return;
    if (await runOnline(
      context,
      () => _client.saveExpense(OnlineExpense(
        id: existing?.id ?? '',
        date: values['date'] as DateTime,
        description: values['description'] as String,
        amountGrossCents: values['amount'] as int,
        vatRatePercent: double.parse(values['vat'] as String),
        categoryId: values['categoryId'] as String?,
        supplierReference: values['supplierReference'] as String?,
        projectId: values.containsKey('projectId') ? values['projectId'] as String? : existing?.projectId,
      )),
    )) {
      _reload();
    }
  }

  Future<void> _datev() async {
    final settings = await _client.accountingSettings();
    if (!mounted) return;
    final datev = settings['datev']!;
    final values = await showOnlineForm(
      context,
      title: 'DATEV-Export ${_period.label}',
      submitLabel: 'Exportieren',
      fields: [
        OnlineField('beraterNummer', 'Beraternummer', required: true, initial: datev['beraterNummer'] as String?),
        OnlineField('mandantNummer', 'Mandantennummer', required: true, initial: datev['mandantNummer'] as String?),
        OnlineField('bankGegenkonto', 'Bank-Gegenkonto (SKR03)', required: true, initial: datev['bankGegenkonto'] as String?),
        OnlineField('sachkontenlaenge', 'Sachkontenlänge', type: OnlineFieldType.decimal, required: true,
            initial: '${datev['sachkontenlaenge'] ?? 4}'),
      ],
    );
    if (values == null || !mounted) return;
    await runOnline(context, () async {
      await _client.saveAccountingSettings({
        'datev': {
          'beraterNummer': values['beraterNummer'],
          'mandantNummer': values['mandantNummer'],
          'bankGegenkonto': values['bankGegenkonto'],
          'sachkontenlaenge': int.parse(values['sachkontenlaenge'] as String),
        },
      });
      final export = await _client.datevExport(from: _period.from, to: _period.to);
      final saved = await FilePicker.saveFile(
        fileName: export.fileName,
        bytes: Uint8List.fromList(encodeDatevAnsi(export.csv)),
        dialogTitle: 'DATEV-Export speichern',
      );
      if (saved == null || !mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text([
          '${export.exportedCount} Beleg(e) exportiert',
          if (export.skipped.isNotEmpty) '${export.skipped.length} ohne SKR03-Konto übersprungen',
        ].join(', ')),
      ));
    });
  }

  Future<void> _manageCategories(List<OnlineExpenseCategory> categories) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => _CategoriesScreen(session: widget.session)),
    );
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: _canWrite
          ? FutureBuilder<(List<OnlineExpense>, int, List<OnlineExpenseCategory>)>(
              future: _future,
              builder: (context, snapshot) => FloatingActionButton.extended(
                heroTag: 'online-expense-fab',
                onPressed: snapshot.data == null ? null : () => _edit(snapshot.data!.$3),
                icon: const Icon(Icons.add),
                label: const Text('Beleg erfassen'),
              ),
            )
          : null,
      body: FutureBuilder<(List<OnlineExpense>, int, List<OnlineExpenseCategory>)>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text(describeOnlineError(snapshot.error!)));
          final data = snapshot.data;
          if (data == null) return const Center(child: CircularProgressIndicator());
          final categories = {for (final c in data.$3) c.id: c};
          return ListView(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 88),
            children: [
              _PeriodBar(
                period: _period,
                onChanged: (p) {
                  _period = p;
                  _reload();
                },
              ),
              Wrap(
                spacing: 8,
                children: [
                  OutlinedButton.icon(onPressed: _datev, icon: const Icon(Icons.file_download_outlined), label: const Text('DATEV-Export')),
                  if (_canWrite)
                    OutlinedButton.icon(
                      onPressed: () => _manageCategories(data.$3),
                      icon: const Icon(Icons.category_outlined),
                      label: const Text('Kategorien'),
                    ),
                ],
              ),
              Card(
                child: ListTile(
                  title: Text('Summe ${_period.label}'),
                  trailing: Text(_euro(data.$2), style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              if (data.$1.isEmpty) const Padding(padding: EdgeInsets.all(24), child: Center(child: Text('Keine Belege im Zeitraum.'))),
              for (final e in data.$1)
                Card(
                  child: ListTile(
                    leading: Icon(e.purchaseOrderId == null ? Icons.receipt_outlined : Icons.local_shipping_outlined),
                    title: Text(e.description),
                    subtitle: Text([
                      formatOnlineDate(e.date),
                      categories[e.categoryId]?.label ?? 'ohne Kategorie',
                      '${e.vatRatePercent.toStringAsFixed(0)} %',
                      if (e.supplierReference != null) e.supplierReference!,
                    ].join(' · ')),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_euro(e.amountGrossCents)),
                        if (_canWrite)
                          IconButton(
                            tooltip: 'Beleg löschen',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () async {
                              if (!await confirmOnline(context, 'Beleg löschen?', e.description)) return;
                              if (context.mounted && await runOnline(context, () => _client.deleteExpense(e.id))) _reload();
                            },
                          ),
                      ],
                    ),
                    onTap: _canWrite ? () => _edit(data.$3, e) : null,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _CategoriesScreen extends StatelessWidget {
  const _CategoriesScreen({required this.session});
  final OnlineSession session;

  Future<bool> _edit(BuildContext context, [OnlineExpenseCategory? existing]) async {
    final values = await showOnlineForm(
      context,
      title: existing == null ? 'Neue Kategorie' : 'Kategorie bearbeiten',
      fields: [
        OnlineField('label', 'Bezeichnung', required: true, initial: existing?.label),
        OnlineField('skr03Account', 'SKR03-Konto', initial: existing?.skr03Account, helper: 'Ohne Konto wird der Beleg nicht nach DATEV exportiert.'),
      ],
    );
    if (values == null || !context.mounted) return false;
    return runOnline(
      context,
      () => session.client.saveExpenseCategory(
        id: existing?.id,
        label: values['label'] as String,
        skr03Account: values['skr03Account'] as String?,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Beleg-Kategorien')),
      body: OnlineListView<OnlineExpenseCategory>(
        load: (_) => session.client.expenseCategories(),
        emptyText: 'Keine Kategorien.',
        itemBuilder: (context, c, reload) => Card(
          child: ListTile(
            title: Text(c.label),
            subtitle: Text(c.skr03Account == null ? 'kein SKR03-Konto' : 'SKR03 ${c.skr03Account}'),
            trailing: IconButton(
              tooltip: 'Kategorie löschen',
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                if (!await confirmOnline(context, 'Kategorie löschen?', 'Belege bleiben erhalten, nur ohne Kategorie.')) return;
                if (context.mounted && await runOnline(context, () => session.client.deleteExpenseCategory(c.id))) reload();
              },
            ),
            onTap: () async {
              if (await _edit(context, c)) reload();
            },
          ),
        ),
        floatingActionButton: (reload) => Builder(
          builder: (context) => FloatingActionButton.extended(
            heroTag: 'online-category-fab',
            onPressed: () async {
              if (await _edit(context)) reload();
            },
            icon: const Icon(Icons.add),
            label: const Text('Kategorie anlegen'),
          ),
        ),
      ),
    );
  }
}

// ---- EÜR ---------------------------------------------------------------------------

class _EuerTab extends StatefulWidget {
  const _EuerTab({required this.session});
  final OnlineSession session;

  @override
  State<_EuerTab> createState() => _EuerTabState();
}

class _EuerTabState extends State<_EuerTab> {
  _Period _period = _Period(DateTime.now().year);
  late Future<OnlineEuer> _future = _load();

  Future<OnlineEuer> _load() => widget.session.client.euer(from: _period.from, to: _period.to);

  Widget _row(String label, int cents, {bool bold = false}) {
    final style = bold ? const TextStyle(fontWeight: FontWeight.bold) : null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [Expanded(child: Text(label, style: style)), Text(_euro(cents), style: style)]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
      children: [
        _PeriodBar(
          period: _period,
          onChanged: (p) => setState(() {
            _period = p;
            _future = _load();
          }),
        ),
        FutureBuilder<OnlineEuer>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.hasError) return Text(describeOnlineError(snapshot.error!));
            final euer = snapshot.data;
            if (euer == null) return const Center(child: CircularProgressIndicator());
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    _row('Einnahmen (Rechnungen − Gutschriften)', euer.incomeCents),
                    const Divider(),
                    for (final l in euer.expensesByCategory)
                      _row(l.skr03Account == null ? l.label : '${l.label} (${l.skr03Account})', l.totalCents),
                    _row('Ausgaben gesamt', euer.expensesCents),
                    const Divider(),
                    _row('Überschuss', euer.surplusCents, bold: true),
                    const SizedBox(height: 8),
                    Text(
                      'Interne Übersicht nach Rechnungs-/Belegdatum — keine steuerliche EÜR nach § 4 Abs. 3 EStG.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

// ---- Bank ----------------------------------------------------------------------------

class _BankTab extends StatefulWidget {
  const _BankTab({required this.session});
  final OnlineSession session;

  @override
  State<_BankTab> createState() => _BankTabState();
}

class _BankTabState extends State<_BankTab> {
  bool _onlyUnmatched = true;
  late Future<List<OnlineBankTransaction>> _future = _load();

  WerkkernApiClient get _client => widget.session.client;
  bool get _canWrite => widget.session.can('accounting.write');

  Future<List<OnlineBankTransaction>> _load() => _client.bankTransactions(onlyUnmatched: _onlyUnmatched);

  void _reload() => setState(() {
        _future = _load();
      });

  Future<Map<String, Object?>?> _editMapping(Map<String, Object?> current) => showOnlineForm(
        context,
        title: 'CSV-Spaltenzuordnung',
        fields: [
          OnlineField('delimiter', 'Trennzeichen', required: true, initial: current['delimiter'] as String? ?? ';'),
          OnlineField('hasHeaderRow', 'Erste Zeile ist Kopfzeile', type: OnlineFieldType.toggle, initial: current['hasHeaderRow'] as bool? ?? true),
          OnlineField('dateColumn', 'Spalte Datum (Name oder Index)', required: true, initial: current['dateColumn'] as String?),
          OnlineField('amountColumn', 'Spalte Betrag', required: true, initial: current['amountColumn'] as String?),
          OnlineField('purposeColumn', 'Spalte Verwendungszweck', initial: current['purposeColumn'] as String?),
          OnlineField('counterpartyColumn', 'Spalte Auftraggeber/Empfänger', initial: current['counterpartyColumn'] as String?),
          OnlineField('dateFormat', 'Datumsformat', required: true, initial: current['dateFormat'] as String? ?? 'dd.MM.yyyy'),
          OnlineField(
            'decimalSeparator',
            'Dezimaltrenner',
            type: OnlineFieldType.choice,
            required: true,
            initial: current['decimalSeparator'] as String? ?? ',',
            options: const {',': 'Komma (1.234,56)', '.': 'Punkt (1,234.56)'},
          ),
        ],
      );

  Future<void> _import() async {
    var mapping = (await _client.accountingSettings())['bankCsv']!;
    if (!mounted) return;
    if ((mapping['dateColumn'] as String? ?? '').isEmpty || (mapping['amountColumn'] as String? ?? '').isEmpty) {
      final edited = await _editMapping(mapping);
      if (edited == null || !mounted) return;
      if (!await runOnline(context, () => _client.saveAccountingSettings({'bankCsv': edited}))) return;
      mapping = edited;
    }
    final picked = await FilePicker.pickFiles(dialogTitle: 'Bank-CSV wählen');
    if (picked.isEmpty || !mounted) return;
    final bytes = await picked.first.readAsBytes();
    String text;
    try {
      text = utf8.decode(bytes);
    } on FormatException {
      text = latin1.decode(bytes);
    }
    final parsed = parseBankCsv(
      text,
      BankCsvMapping(
        delimiter: mapping['delimiter'] as String? ?? ';',
        hasHeaderRow: mapping['hasHeaderRow'] as bool? ?? true,
        dateColumn: mapping['dateColumn'] as String,
        amountColumn: mapping['amountColumn'] as String,
        purposeColumn: mapping['purposeColumn'] as String?,
        counterpartyColumn: mapping['counterpartyColumn'] as String?,
        dateFormat: mapping['dateFormat'] as String? ?? 'dd.MM.yyyy',
        decimalSeparator: mapping['decimalSeparator'] as String? ?? ',',
      ),
    );
    if (!mounted) return;
    await runOnline(context, () async {
      final result = await _client.importBankTransactions([
        for (final t in parsed.transactions)
          (date: t.date, amountCents: t.amountCents, purpose: t.purpose, counterparty: t.counterparty),
      ]);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text([
          '${result.imported} Umsatz/Umsätze importiert',
          if (result.skippedDuplicates > 0) '${result.skippedDuplicates} bereits vorhanden',
          if (parsed.errors.isNotEmpty) '${parsed.errors.length} Zeile(n) fehlerhaft (z. B. Zeile ${parsed.errors.first.rowNumber}: ${parsed.errors.first.message})',
        ].join(', ')),
        duration: const Duration(seconds: 8),
      ));
    });
    _reload();
  }

  Future<void> _match(OnlineBankTransaction t) async {
    final open = await _client.openItems();
    if (!mounted) return;
    final candidates = [
      for (final g in open.customers)
        for (final i in g.items) (item: i, customer: g.customerName),
    ]..sort((a, b) => (a.item.grossCents - t.amountCents).abs().compareTo((b.item.grossCents - t.amountCents).abs()));
    if (candidates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Keine offenen Rechnungen zum Zuordnen.')));
      return;
    }
    final canMarkPaid = widget.session.can('invoices.payment');
    final values = await showOnlineForm(
      context,
      title: 'Umsatz ${_euro(t.amountCents)} zuordnen',
      submitLabel: 'Zuordnen',
      fields: [
        OnlineField(
          'documentId',
          'Rechnung',
          type: OnlineFieldType.choice,
          required: true,
          initial: candidates.first.item.documentId,
          options: {
            for (final c in candidates)
              c.item.documentId: '${c.item.number ?? 'Rechnung'} · ${c.customer} · ${_euro(c.item.grossCents)}',
          },
        ),
        if (canMarkPaid)
          const OnlineField('markPaid', 'Als bezahlt markieren', type: OnlineFieldType.toggle, initial: true),
      ],
    );
    if (values == null || !mounted) return;
    if (await runOnline(
      context,
      () => _client.matchBankTransaction(t.id, documentId: values['documentId'] as String, markPaid: values['markPaid'] == true),
    )) {
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: _canWrite
          ? FloatingActionButton.extended(
              heroTag: 'online-bank-fab',
              onPressed: _import,
              icon: const Icon(Icons.upload_file_outlined),
              label: const Text('CSV importieren'),
            )
          : null,
      body: FutureBuilder<List<OnlineBankTransaction>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text(describeOnlineError(snapshot.error!)));
          final transactions = snapshot.data;
          if (transactions == null) return const Center(child: CircularProgressIndicator());
          return ListView(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 88),
            children: [
              SwitchListTile(
                title: const Text('Nur nicht zugeordnete'),
                value: _onlyUnmatched,
                onChanged: (v) {
                  _onlyUnmatched = v;
                  _reload();
                },
              ),
              if (_canWrite)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () async {
                      final current = (await _client.accountingSettings())['bankCsv']!;
                      if (!context.mounted) return;
                      final edited = await _editMapping(current);
                      if (edited != null && context.mounted) {
                        await runOnline(context, () => _client.saveAccountingSettings({'bankCsv': edited}), success: 'Zuordnung gespeichert.');
                      }
                    },
                    icon: const Icon(Icons.tune),
                    label: const Text('CSV-Spaltenzuordnung'),
                  ),
                ),
              if (transactions.isEmpty) const Padding(padding: EdgeInsets.all(24), child: Center(child: Text('Keine Bankumsätze.'))),
              for (final t in transactions)
                Card(
                  child: ListTile(
                    leading: Icon(t.matchedDocumentId == null ? Icons.link_off : Icons.link),
                    title: Text('${_euro(t.amountCents)} · ${formatOnlineDate(t.date)}'),
                    subtitle: Text([if (t.counterparty != null) t.counterparty!, if (t.purpose != null) t.purpose!].join(' · ')),
                    trailing: !_canWrite
                        ? null
                        : t.matchedDocumentId == null
                            ? (t.amountCents > 0
                                ? TextButton(onPressed: () => _match(t), child: const Text('Zuordnen'))
                                : null)
                            : TextButton(
                                onPressed: () async {
                                  if (await runOnline(context, () => _client.matchBankTransaction(t.id, documentId: null))) _reload();
                                },
                                child: const Text('Lösen'),
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
