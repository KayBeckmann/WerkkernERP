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

// Buchhaltung der Online-Firma (C14): offene Posten, Belege mit
// DATEV-Export, EÜR-Übersicht, Bankabgleich per CSV — wie offline je ein
// eigener Bereich in der Navigation. Interne Übersicht, **keine
// Steuerberatung**.

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

class OnlineOpenItemsScreen extends StatefulWidget {
  const OnlineOpenItemsScreen({super.key, required this.session});
  final OnlineSession session;

  @override
  State<OnlineOpenItemsScreen> createState() => _OnlineOpenItemsScreenState();
}

class _OnlineOpenItemsScreenState extends State<OnlineOpenItemsScreen> {
  late Future<({int totalCents, List<OnlineOpenItemGroup> customers})> _future = widget.session.client.openItems();

  void _reload() => setState(() {
        _future = widget.session.client.openItems();
      });

  Future<void> _markPaid(String documentId) async {
    if (await runOnline(
      context,
      () => widget.session.client.setPaid(documentId, paid: true),
      success: 'Als bezahlt markiert.',
    )) {
      _reload();
    }
  }

  /// Aufbau wie offline (`open_items_screen.dart`): Gesamtsumme oben, je
  /// Kunde eine aufklappbare Gruppe mit „Bezahlt“ je Rechnung.
  @override
  Widget build(BuildContext context) {
    final canPay = widget.session.can('invoices.payment');
    return FutureBuilder<({int totalCents, List<OnlineOpenItemGroup> customers})>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text(describeOnlineError(snapshot.error!)));
        final data = snapshot.data;
        if (data == null) return const Center(child: CircularProgressIndicator());
        if (data.customers.isEmpty) {
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView(children: const [
              SizedBox(height: 120),
              Center(child: Text('Keine offenen Posten.')),
            ]),
          );
        }
        final today = DateTime.now();
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Gesamt offen', style: TextStyle(fontWeight: FontWeight.w600)),
                  Text(_euro(data.totalCents), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async => _reload(),
                child: ListView(
                  children: [
                    for (final g in data.customers)
                      ExpansionTile(
                        title: Text(g.customerName),
                        subtitle: Text('${g.items.length} offene Rechnung(en)'),
                        trailing: Text(_euro(g.totalCents), style: const TextStyle(fontWeight: FontWeight.bold)),
                        children: [
                          for (final i in g.items)
                            ListTile(
                              title: Text(i.number ?? 'Rechnung'),
                              subtitle: Text(
                                i.dueDate == null
                                    ? 'Ohne Fälligkeitsdatum'
                                    : '${i.dueDate!.isBefore(today) ? 'Überfällig seit' : 'Fällig am'} ${formatOnlineDate(i.dueDate!)}',
                              ),
                              trailing: Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 8,
                                children: [
                                  Text(_euro(i.grossCents)),
                                  if (canPay) TextButton(onPressed: () => _markPaid(i.documentId), child: const Text('Bezahlt')),
                                ],
                              ),
                              // Nur online: Rechnung direkt öffnen.
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
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ---- Belege ----------------------------------------------------------------------

class OnlineExpensesScreen extends StatefulWidget {
  const OnlineExpensesScreen({super.key, required this.session});
  final OnlineSession session;

  @override
  State<OnlineExpensesScreen> createState() => _OnlineExpensesScreenState();
}

class _OnlineExpensesScreenState extends State<OnlineExpensesScreen> {
  _Period _period = _Period(DateTime.now().year, DateTime.now().month);
  late Future<(List<OnlineExpense>, int, List<OnlineExpenseCategory>)> _future = _load();

  WerkkernApiClient get _client => widget.session.client;
  bool get _canWrite => widget.session.can('accounting.write');

  /// Projektnamen für die Listenzeile (wie offline).
  Map<String, String> _projectNames = const {};

  Future<(List<OnlineExpense>, int, List<OnlineExpenseCategory>)> _load() async {
    final categories = await _client.expenseCategories();
    final result = await _client.expenses(from: _period.from, to: _period.to);
    final session = widget.session;
    if (session.modules.contains('projects') && session.can('projects.read')) {
      try {
        _projectNames = {for (final p in await _client.projects(includeArchived: true)) p.id: p.name};
      } on Exception {
        // Ohne Projektliste eben ohne Projektnamen.
      }
    }
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
      title: 'DATEV-Export',
      submitLabel: 'Exportieren',
      fields: [
        // Wie offline frei wählbarer Zeitraum (vorbelegt mit dem angezeigten).
        OnlineField('from', 'Von', type: OnlineFieldType.date, required: true, initial: _period.from),
        OnlineField('to', 'Bis', type: OnlineFieldType.date, required: true, initial: _period.to),
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
      final export = await _client.datevExport(from: values['from'] as DateTime, to: values['to'] as DateTime);
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

  /// Aufbau wie offline (`expenses_screen.dart`): Kategorien, DATEV und
  /// Aktualisieren in der Titelleiste; Zeitraum und Summe nur online.
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<(List<OnlineExpense>, int, List<OnlineExpenseCategory>)>(
      future: _future,
      builder: (context, snapshot) {
        final data = snapshot.data;
        return Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: false,
            title: const Text('Belege/Ausgaben'),
            actions: [
              if (_canWrite)
                IconButton(
                  icon: const Icon(Icons.category_outlined),
                  tooltip: 'Kategorien verwalten',
                  onPressed: data == null ? null : () => _manageCategories(data.$3),
                ),
              IconButton(icon: const Icon(Icons.description_outlined), tooltip: 'DATEV-Export', onPressed: _datev),
              IconButton(icon: const Icon(Icons.refresh_outlined), tooltip: 'Aktualisieren', onPressed: _reload),
            ],
          ),
          floatingActionButton: _canWrite
              ? FloatingActionButton.extended(
                  heroTag: 'online-expense-fab',
                  onPressed: data == null ? null : () => _edit(data.$3),
                  icon: const Icon(Icons.add),
                  label: const Text('Beleg erfassen'),
                )
              : null,
          body: snapshot.hasError
              ? Center(child: Text(describeOnlineError(snapshot.error!)))
              : data == null
                  ? const Center(child: CircularProgressIndicator())
                  : _buildList(data),
        );
      },
    );
  }

  Widget _buildList((List<OnlineExpense>, int, List<OnlineExpenseCategory>) data) {
    final categories = {for (final c in data.$3) c.id: c};
    return ListView(
      padding: const EdgeInsets.only(bottom: 88),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: _PeriodBar(
            period: _period,
            onChanged: (p) {
              _period = p;
              _reload();
            },
          ),
        ),
        ListTile(
          title: Text('Summe ${_period.label}'),
          trailing: Text(_euro(data.$2), style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
        const Divider(height: 1),
        if (data.$1.isEmpty) const Padding(padding: EdgeInsets.all(24), child: Center(child: Text('Keine Belege im Zeitraum.'))),
        for (final e in data.$1)
          ListTile(
            leading: e.purchaseOrderId == null ? null : const Icon(Icons.local_shipping_outlined),
            title: Text(e.description),
            subtitle: Text(
              '${formatOnlineDate(e.date)}'
              '${e.categoryId != null ? ' — ${categories[e.categoryId]?.label ?? 'Kategorie gelöscht'}' : ''}'
              '${e.projectId != null ? ' — ${_projectNames[e.projectId] ?? 'Projekt'}' : ''}',
            ),
            trailing: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 4,
              children: [
                Text(_euro(e.amountGrossCents)),
                if (_canWrite) ...[
                  IconButton(tooltip: 'Bearbeiten', icon: const Icon(Icons.edit_outlined), onPressed: () => _edit(data.$3, e)),
                  IconButton(
                    tooltip: 'Löschen',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () async {
                      if (!await confirmOnline(context, 'Beleg löschen?', e.description)) return;
                      if (mounted && await runOnline(context, () => _client.deleteExpense(e.id))) _reload();
                    },
                  ),
                ],
              ],
            ),
          ),
      ],
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

class OnlineEuerScreen extends StatefulWidget {
  const OnlineEuerScreen({super.key, required this.session});
  final OnlineSession session;

  @override
  State<OnlineEuerScreen> createState() => _OnlineEuerScreenState();
}

class _OnlineEuerScreenState extends State<OnlineEuerScreen> {
  _Period _period = _Period(DateTime.now().year);
  late Future<OnlineEuer> _future = _load();

  Future<OnlineEuer> _load() => widget.session.client.euer(from: _period.from, to: _period.to);

  Widget _row(String label, int cents, {bool bold = false, bool negative = false}) {
    final style = TextStyle(
      fontWeight: bold ? FontWeight.bold : FontWeight.normal,
      color: negative ? Theme.of(context).colorScheme.error : null,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
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
            final theme = Theme.of(context);
            // Aufbau wie offline (`euer_screen.dart`).
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Keine steuerliche Einnahmen-Überschuss-Rechnung — nur eine interne '
                          'Übersicht aus bereits erfassten Rechnungen/Belegen (z. B. ohne '
                          'Abschreibungen). Keine Rechtsprüfung.',
                          style: theme.textTheme.bodySmall,
                        ),
                        const SizedBox(height: 12),
                        _row('Einnahmen', euer.incomeCents),
                        _row('Ausgaben', euer.expensesCents),
                        const Divider(),
                        _row('Überschuss', euer.surplusCents, bold: true, negative: euer.surplusCents < 0),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (euer.expensesByCategory.isNotEmpty) ...[
                  Text('Ausgaben nach Kategorie', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 8),
                  for (final l in euer.expensesByCategory)
                    ListTile(
                      title: Text(l.label),
                      subtitle: l.skr03Account == null ? null : Text('SKR03-Konto ${l.skr03Account}'),
                      trailing: Text(_euro(l.totalCents)),
                    ),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}

// ---- Bank ----------------------------------------------------------------------------

class OnlineBankScreen extends StatefulWidget {
  const OnlineBankScreen({super.key, required this.session});
  final OnlineSession session;

  @override
  State<OnlineBankScreen> createState() => _OnlineBankScreenState();
}

class _OnlineBankScreenState extends State<OnlineBankScreen> {
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

  Future<void> _editMappingAndSave() async {
    final current = (await _client.accountingSettings())['bankCsv']!;
    if (!mounted) return;
    final edited = await _editMapping(current);
    if (edited != null && mounted) {
      await runOnline(context, () => _client.saveAccountingSettings({'bankCsv': edited}), success: 'Zuordnung gespeichert.');
    }
  }

  /// Aufbau wie offline (`bank_reconciliation_screen.dart`): Aktionen in
  /// der Titelleiste, je Umsatz Richtung, Gegenpartei, Betrag und
  /// „Zuordnen“/„Zuordnung lösen“.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Bankabgleich'),
        actions: [
          if (_canWrite) ...[
            IconButton(icon: const Icon(Icons.settings_outlined), tooltip: 'CSV-Spaltenzuordnung', onPressed: _editMappingAndSave),
            IconButton(icon: const Icon(Icons.upload_file_outlined), tooltip: 'CSV importieren', onPressed: _import),
          ],
          IconButton(icon: const Icon(Icons.refresh_outlined), tooltip: 'Aktualisieren', onPressed: _reload),
        ],
      ),
      body: FutureBuilder<List<OnlineBankTransaction>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text(describeOnlineError(snapshot.error!)));
          final transactions = snapshot.data;
          if (transactions == null) return const Center(child: CircularProgressIndicator());
          return ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              // Nur online: Filter auf noch nicht zugeordnete Umsätze.
              SwitchListTile(
                title: const Text('Nur nicht zugeordnete'),
                value: _onlyUnmatched,
                onChanged: (v) {
                  _onlyUnmatched = v;
                  _reload();
                },
              ),
              if (transactions.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Text(_onlyUnmatched ? 'Keine Bankumsätze.' : 'Noch keine Bank-Transaktionen importiert.'),
                  ),
                ),
              for (final t in transactions)
                ListTile(
                  leading: Icon(
                    t.amountCents >= 0 ? Icons.arrow_downward : Icons.arrow_upward,
                    color: t.amountCents >= 0 ? Colors.green : null,
                  ),
                  title: Text(t.counterparty ?? t.purpose ?? 'Ohne Angabe'),
                  subtitle: Text('${formatOnlineDate(t.date)}${t.purpose != null ? ' — ${t.purpose}' : ''}'),
                  trailing: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    children: [
                      Text(_euro(t.amountCents)),
                      if (_canWrite && t.matchedDocumentId == null && t.amountCents > 0)
                        TextButton(onPressed: () => _match(t), child: const Text('Zuordnen')),
                      if (_canWrite && t.matchedDocumentId != null)
                        TextButton(
                          onPressed: () async {
                            if (await runOnline(context, () => _client.matchBankTransaction(t.id, documentId: null))) _reload();
                          },
                          child: const Text('Zuordnung lösen'),
                        ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
