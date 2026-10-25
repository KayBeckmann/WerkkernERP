import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/database/database.dart';
import '../../data/repositories/customer_repository.dart';
import '../../data/repositories/invoice_repository.dart';
import '../../domain/services/active_company_service.dart';
import '../../domain/services/open_items_service.dart';

/// C14.1 Offene-Posten-Übersicht (Kay-Priorisierungsentscheidung
/// 2026-10-18, erster Baustein der vollen Buchhaltung). Zeigt alle noch
/// offenen, finalisierten Rechnungen gruppiert nach Kunde — reine
/// Aggregation bereits vorhandener Daten, keine neue Buchungsart, kein
/// neues rechtliches Risiko (siehe Doc-Kommentar in
/// `open_items_service.dart`).
class OpenItemsScreen extends StatefulWidget {
  const OpenItemsScreen({super.key});

  @override
  State<OpenItemsScreen> createState() => _OpenItemsScreenState();
}

class _OpenItemsScreenState extends State<OpenItemsScreen> {
  late Future<List<CustomerOpenItems>> _future;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<CustomerOpenItems>> _load() async {
    final companyId = context.read<ActiveCompanyService>().active!.id;
    final invoiceRepo = context.read<InvoiceRepository>();
    final customerRepo = context.read<CustomerRepository>();

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
    return groupOpenItemsByCustomer(openItems);
  }

  // Bewusst ein Block-Body, nicht `setState(() => _future = _load())` —
  // siehe dieselbe Begründung in dashboard_screen.dart/projects_screen.dart.
  void _reload() => setState(() {
        _future = _load();
      });

  Future<void> _markPaid(Invoice invoice) async {
    setState(() => _busy = true);
    try {
      final companyId = context.read<ActiveCompanyService>().active!.id;
      await context.read<InvoiceRepository>().markPaid(companyId: companyId, id: invoice.id);
      if (mounted) _reload();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  static String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';

  @override
  Widget build(BuildContext context) {
    final company = context.watch<ActiveCompanyService>().active;
    if (company == null) return const SizedBox.shrink();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Offene Posten'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            tooltip: 'Aktualisieren',
            onPressed: _reload,
          ),
        ],
      ),
      body: FutureBuilder<List<CustomerOpenItems>>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final groups = snapshot.data!;
          final grandTotal = totalOpenAmount([for (final g in groups) ...g.items]);

          if (groups.isEmpty) {
            return const Center(child: Text('Keine offenen Posten.'));
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Gesamt offen', style: TextStyle(fontWeight: FontWeight.w600)),
                    Text(
                      grandTotal.toString(),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  children: [
                    for (final group in groups)
                      ExpansionTile(
                        title: Text(group.customerName),
                        subtitle: Text('${group.items.length} offene Rechnung(en)'),
                        trailing: Text(
                          group.total.toString(),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        children: [
                          for (final item in group.items)
                            ListTile(
                              title: Text(item.invoice.invoiceNumber ?? ''),
                              subtitle: Text(
                                item.invoice.dueDate == null
                                    ? 'Ohne Fälligkeitsdatum'
                                    : 'Fällig am ${_formatDate(item.invoice.dueDate!)}',
                              ),
                              trailing: Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 8,
                                children: [
                                  Text(item.gross.toString()),
                                  TextButton(
                                    onPressed: _busy ? null : () => _markPaid(item.invoice),
                                    child: const Text('Bezahlt'),
                                  ),
                                ],
                              ),
                            ),
                        ],
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
