import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/database/database.dart';
import '../../data/database/tables.dart';
import '../../data/repositories/expense_category_repository.dart';
import '../../data/repositories/expense_repository.dart';
import '../../data/repositories/invoice_repository.dart';
import '../../domain/services/active_company_service.dart';
import '../../domain/services/dashboard_service.dart' show InvoiceWithGross;
import '../../domain/services/euer_service.dart';

/// C14.3 EÜR-Übersicht (Kay-Priorisierungsentscheidung 2026-10-18,
/// dritter Baustein der vollen Buchhaltung). Siehe ausführlichen
/// Disclaimer in `euer_service.dart` — **keine steuerliche EÜR**, nur
/// eine interne Übersicht aus den bereits erfassten Einnahmen/Ausgaben.
class EuerScreen extends StatefulWidget {
  const EuerScreen({super.key});

  @override
  State<EuerScreen> createState() => _EuerScreenState();
}

enum _Period { thisMonth, thisYear }

class _EuerData {
  const _EuerData({required this.invoices, required this.expenses, required this.categoryById});
  final List<InvoiceWithGross> invoices;
  final List<Expense> expenses;
  final Map<String, ExpenseCategory> categoryById;
}

class _EuerScreenState extends State<EuerScreen> {
  late Future<_EuerData> _future;
  _Period _period = _Period.thisMonth;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_EuerData> _load() async {
    // Provider-Zugriffe VOR dem ersten await — siehe dieselbe
    // Begründung in dashboard_screen.dart.
    final companyId = context.read<ActiveCompanyService>().active!.id;
    final invoiceRepo = context.read<InvoiceRepository>();
    final expenseRepo = context.read<ExpenseRepository>();
    final categoryRepo = context.read<ExpenseCategoryRepository>();

    final allInvoices = await invoiceRepo.listAllForCompany(companyId);
    final finalized = allInvoices.where((i) => i.status == InvoiceStatus.finalized).toList();
    final withGross = <InvoiceWithGross>[];
    for (final invoice in finalized) {
      final totals = await invoiceRepo.totalsFor(invoice.id);
      withGross.add(InvoiceWithGross(invoice: invoice, gross: totals.totalGross));
    }

    final expenses = await expenseRepo.listForCompany(companyId);
    final categories = await categoryRepo.listForCompany(companyId);

    return _EuerData(
      invoices: withGross,
      expenses: expenses,
      categoryById: {for (final c in categories) c.id: c},
    );
  }

  void _reload() => setState(() {
        _future = _load();
      });

  ({DateTime start, DateTime end}) _periodBounds(_Period period) {
    final now = DateTime.now();
    switch (period) {
      case _Period.thisMonth:
        final start = DateTime(now.year, now.month, 1);
        final end = DateTime(now.year, now.month + 1, 1).subtract(const Duration(days: 1));
        return (start: start, end: end);
      case _Period.thisYear:
        return (start: DateTime(now.year, 1, 1), end: DateTime(now.year, 12, 31));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('EÜR-Übersicht'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            tooltip: 'Aktualisieren',
            onPressed: _reload,
          ),
        ],
      ),
      body: FutureBuilder<_EuerData>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final data = snapshot.data!;
          final bounds = _periodBounds(_period);
          final summary = computeEuerSummary(
            allFinalizedInvoices: data.invoices,
            allExpenses: data.expenses,
            categoryById: data.categoryById,
            periodStart: bounds.start,
            periodEnd: bounds.end,
          );

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              SegmentedButton<_Period>(
                segments: const [
                  ButtonSegment(value: _Period.thisMonth, label: Text('Dieser Monat')),
                  ButtonSegment(value: _Period.thisYear, label: Text('Dieses Jahr')),
                ],
                selected: {_period},
                onSelectionChanged: (selection) => setState(() => _period = selection.first),
              ),
              const SizedBox(height: 16),
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
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 12),
                      _row(context, 'Einnahmen', summary.totalIncome.toString()),
                      _row(context, 'Ausgaben', summary.totalExpenses.toString()),
                      const Divider(),
                      _row(
                        context,
                        'Überschuss',
                        summary.surplus.toString(),
                        bold: true,
                        negative: summary.surplus.cents < 0,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (summary.expensesByCategory.isNotEmpty) ...[
                Text('Ausgaben nach Kategorie', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                for (final category in summary.expensesByCategory)
                  ListTile(
                    title: Text(category.categoryLabel),
                    subtitle: category.skr03Account == null
                        ? null
                        : Text('SKR03-Konto ${category.skr03Account}'),
                    trailing: Text(category.total.toString()),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value, {bool bold = false, bool negative = false}) {
    final style = TextStyle(
      fontWeight: bold ? FontWeight.bold : FontWeight.normal,
      color: negative ? Theme.of(context).colorScheme.error : null,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text(label, style: style), Text(value, style: style)],
      ),
    );
  }
}
