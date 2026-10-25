import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/database/database.dart';
import '../../data/database/tables.dart';
import '../../data/repositories/bank_transaction_repository.dart';
import '../../data/repositories/company_repository.dart';
import '../../data/repositories/customer_repository.dart';
import '../../data/repositories/invoice_repository.dart';
import '../../domain/models/money.dart';
import '../../domain/services/active_company_service.dart';
import '../../domain/services/bank_csv_import_service.dart';
import '../../domain/services/open_items_service.dart';

/// C14.4 Bankabgleich per CSV (Kay-Priorisierungsentscheidung
/// 2026-10-18, vierter Baustein der vollen Buchhaltung). **Nie
/// automatisches Buchen** — jede Zuordnung einer importierten
/// Transaktion zu einer offenen Rechnung braucht Kays ausdrückliche
/// Bestätigung im "Zuordnen"-Dialog, siehe Doc-Kommentar bei
/// [BankTransactions] in tables.dart.
class BankReconciliationScreen extends StatefulWidget {
  const BankReconciliationScreen({super.key});

  @override
  State<BankReconciliationScreen> createState() => _BankReconciliationScreenState();
}

class _BankData {
  const _BankData({required this.transactions, required this.openItems});
  final List<BankTransaction> transactions;
  final List<OpenItem> openItems;
}

class _BankReconciliationScreenState extends State<BankReconciliationScreen> {
  late Future<_BankData> _future;
  bool _importing = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_BankData> _load() async {
    // Provider-Zugriffe VOR dem ersten await — siehe dieselbe Begründung
    // in dashboard_screen.dart.
    final companyId = context.read<ActiveCompanyService>().active!.id;
    final bankRepo = context.read<BankTransactionRepository>();
    final invoiceRepo = context.read<InvoiceRepository>();
    final customerRepo = context.read<CustomerRepository>();

    final transactions = await bankRepo.listForCompany(companyId);

    final allInvoices = await invoiceRepo.listAllForCompany(companyId);
    final customers = await customerRepo.listForCompany(companyId);
    final customerNameById = {for (final c in customers) c.id: c.name};

    final openItems = <OpenItem>[];
    for (final invoice in allInvoices) {
      if (!isOpenItem(invoice)) continue;
      final totals = await invoiceRepo.totalsFor(invoice.id);
      openItems.add(
        OpenItem(
          invoice: invoice,
          gross: totals.totalGross,
          customerName: customerNameById[invoice.customerId] ?? 'Unbekannter Kunde',
        ),
      );
    }

    return _BankData(transactions: transactions, openItems: openItems);
  }

  void _reload() => setState(() {
        _future = _load();
      });

  Future<void> _editMapping() async {
    await showDialog<void>(context: context, builder: (context) => const _CsvMappingDialog());
  }

  Future<void> _importCsv() async {
    final company = context.read<ActiveCompanyService>().active!;
    final mapping = BankCsvMapping.fromCompany(company);
    if (!mapping.isComplete) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bitte zuerst die CSV-Spaltenzuordnung einstellen (Zahnrad oben).'),
        ),
      );
      return;
    }

    final result = await FilePicker.pickFiles(dialogTitle: 'Bank-CSV wählen');
    if (result.isEmpty || !mounted) return;

    setState(() => _importing = true);
    try {
      final bytes = await result.first.readAsBytes();
      // Deutsche Bank-Exporte sind oft Windows-1252/ISO-8859-1 statt
      // UTF-8 (Umlaute würden sonst als Mojibake/Fehler auftauchen) —
      // erst UTF-8 versuchen, bei ungültiger Byte-Sequenz auf Latin-1
      // zurückfallen statt mit einem kryptischen Fehler abzubrechen.
      String csvText;
      try {
        csvText = utf8.decode(bytes);
      } catch (_) {
        csvText = latin1.decode(bytes);
      }
      final parsed = parseBankCsv(csvText, mapping);
      if (!mounted) return;
      final importResult = await context.read<BankTransactionRepository>().importParsed(
            companyId: company.id,
            transactions: parsed.transactions,
          );
      if (!mounted) return;
      _reload();
      final messages = <String>[
        '${importResult.imported} Transaktion(en) importiert',
        if (importResult.skippedDuplicates > 0) '${importResult.skippedDuplicates} bereits vorhanden',
        if (parsed.errors.isNotEmpty) '${parsed.errors.length} Zeile(n) mit Fehlern übersprungen',
      ];
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(messages.join(', '))));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('CSV konnte nicht gelesen werden: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _assign(BankTransaction transaction, List<OpenItem> openItems) async {
    final candidates = openItems.where((o) => o.gross.cents == transaction.amountCents.abs()).toList();
    final selected = await showDialog<OpenItem?>(
      context: context,
      builder: (context) => _MatchDialog(transaction: transaction, candidates: candidates),
    );
    if (selected == null || !mounted) return;
    final companyId = context.read<ActiveCompanyService>().active!.id;
    final bankRepo = context.read<BankTransactionRepository>();
    final invoiceRepo = context.read<InvoiceRepository>();
    await bankRepo.setMatchedInvoice(
      companyId: companyId,
      id: transaction.id,
      invoiceId: selected.invoice.id,
    );
    await invoiceRepo.markPaid(companyId: companyId, id: selected.invoice.id);
    if (mounted) _reload();
  }

  Future<void> _unassign(BankTransaction transaction) async {
    final companyId = context.read<ActiveCompanyService>().active!.id;
    await context.read<BankTransactionRepository>().setMatchedInvoice(
          companyId: companyId,
          id: transaction.id,
          invoiceId: null,
        );
    if (mounted) _reload();
  }

  static String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bankabgleich'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'CSV-Spaltenzuordnung',
            onPressed: _editMapping,
          ),
          IconButton(
            icon: _importing
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.upload_file_outlined),
            tooltip: 'CSV importieren',
            onPressed: _importing ? null : _importCsv,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            tooltip: 'Aktualisieren',
            onPressed: _reload,
          ),
        ],
      ),
      body: FutureBuilder<_BankData>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final data = snapshot.data!;
          if (data.transactions.isEmpty) {
            return const Center(
              child: Text('Noch keine Bank-Transaktionen importiert.'),
            );
          }
          return ListView(
            children: [
              for (final transaction in data.transactions)
                ListTile(
                  leading: Icon(
                    transaction.amountCents >= 0 ? Icons.arrow_downward : Icons.arrow_upward,
                    color: transaction.amountCents >= 0 ? Colors.green : null,
                  ),
                  title: Text(transaction.counterparty ?? transaction.purpose ?? 'Ohne Angabe'),
                  subtitle: Text(
                    '${_formatDate(transaction.date)}'
                    '${transaction.purpose != null ? ' — ${transaction.purpose}' : ''}',
                  ),
                  trailing: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    children: [
                      Text(Money.fromCents(transaction.amountCents).toString()),
                      if (transaction.matchedInvoiceId == null)
                        TextButton(
                          onPressed: () => _assign(transaction, data.openItems),
                          child: const Text('Zuordnen'),
                        )
                      else
                        TextButton(
                          onPressed: () => _unassign(transaction),
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

class _MatchDialog extends StatelessWidget {
  const _MatchDialog({required this.transaction, required this.candidates});
  final BankTransaction transaction;
  final List<OpenItem> candidates;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Rechnung zuordnen'),
      content: SizedBox(
        width: 420,
        child: candidates.isEmpty
            ? const Text(
                'Keine offene Rechnung mit demselben Betrag gefunden. Prüfe die Offene-Posten-'
                'Übersicht oder lass diese Transaktion unzugeordnet.',
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final candidate in candidates)
                    ListTile(
                      title: Text('${candidate.invoice.invoiceNumber} — ${candidate.customerName}'),
                      subtitle: Text(candidate.gross.toString()),
                      onTap: () => Navigator.pop(context, candidate),
                    ),
                ],
              ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
      ],
    );
  }
}

class _CsvMappingDialog extends StatefulWidget {
  const _CsvMappingDialog();

  @override
  State<_CsvMappingDialog> createState() => _CsvMappingDialogState();
}

class _CsvMappingDialogState extends State<_CsvMappingDialog> {
  late final TextEditingController _delimiterCtrl;
  late final TextEditingController _dateColumnCtrl;
  late final TextEditingController _amountColumnCtrl;
  late final TextEditingController _purposeColumnCtrl;
  late final TextEditingController _counterpartyColumnCtrl;
  late final TextEditingController _dateFormatCtrl;
  late bool _hasHeaderRow;
  late String _decimalSeparator;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final company = context.read<ActiveCompanyService>().active!;
    _delimiterCtrl = TextEditingController(text: company.bankCsvDelimiter);
    _dateColumnCtrl = TextEditingController(text: company.bankCsvDateColumn);
    _amountColumnCtrl = TextEditingController(text: company.bankCsvAmountColumn);
    _purposeColumnCtrl = TextEditingController(text: company.bankCsvPurposeColumn);
    _counterpartyColumnCtrl = TextEditingController(text: company.bankCsvCounterpartyColumn);
    _dateFormatCtrl = TextEditingController(text: company.bankCsvDateFormat);
    _hasHeaderRow = company.bankCsvHasHeaderRow;
    _decimalSeparator = company.bankCsvDecimalSeparator;
  }

  @override
  void dispose() {
    _delimiterCtrl.dispose();
    _dateColumnCtrl.dispose();
    _amountColumnCtrl.dispose();
    _purposeColumnCtrl.dispose();
    _counterpartyColumnCtrl.dispose();
    _dateFormatCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final service = context.read<ActiveCompanyService>();
      final company = service.active!;
      await context.read<CompanyRepository>().update(
            company.copyWith(
              bankCsvDelimiter: _delimiterCtrl.text.trim().isEmpty ? ';' : _delimiterCtrl.text.trim(),
              bankCsvHasHeaderRow: _hasHeaderRow,
              bankCsvDateColumn: Value(_textOrNull(_dateColumnCtrl)),
              bankCsvAmountColumn: Value(_textOrNull(_amountColumnCtrl)),
              bankCsvPurposeColumn: Value(_textOrNull(_purposeColumnCtrl)),
              bankCsvCounterpartyColumn: Value(_textOrNull(_counterpartyColumnCtrl)),
              bankCsvDateFormat: _dateFormatCtrl.text.trim().isEmpty ? 'dd.MM.yyyy' : _dateFormatCtrl.text.trim(),
              bankCsvDecimalSeparator: _decimalSeparator,
            ),
          );
      await service.refreshActive();
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _textOrNull(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('CSV-Spaltenzuordnung'),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Jede Bank hat ein eigenes CSV-Format — hier die Spalten deiner Bank eintragen. '
                'Spaltennamen (bei Kopfzeile) oder nullbasierte Indizes (z. B. "0" für die erste '
                'Spalte).',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Erste Zeile ist eine Kopfzeile'),
                value: _hasHeaderRow,
                onChanged: (value) => setState(() => _hasHeaderRow = value),
              ),
              TextField(
                controller: _delimiterCtrl,
                decoration: const InputDecoration(labelText: 'Spaltentrennzeichen (meist ";")'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _dateColumnCtrl,
                decoration: const InputDecoration(labelText: 'Datumsspalte *'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _dateFormatCtrl,
                decoration: const InputDecoration(labelText: 'Datumsformat (z. B. dd.MM.yyyy)'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _amountColumnCtrl,
                decoration: const InputDecoration(labelText: 'Betragsspalte *'),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _decimalSeparator,
                decoration: const InputDecoration(labelText: 'Dezimaltrenner im Betrag'),
                items: const [
                  DropdownMenuItem(value: ',', child: Text('Komma (1.234,56)')),
                  DropdownMenuItem(value: '.', child: Text('Punkt (1,234.56)')),
                ],
                onChanged: (value) => setState(() => _decimalSeparator = value ?? ','),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _purposeColumnCtrl,
                decoration: const InputDecoration(labelText: 'Verwendungszweck-Spalte (optional)'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _counterpartyColumnCtrl,
                decoration: const InputDecoration(labelText: 'Auftraggeber/Empfänger-Spalte (optional)'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Speichern'),
        ),
      ],
    );
  }
}
