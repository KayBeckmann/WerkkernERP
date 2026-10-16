import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/database/database.dart';
import '../../data/database/tables.dart';
import '../../data/repositories/customer_repository.dart';
import '../../data/repositories/invoice_repository.dart';
import '../../domain/models/money.dart';
import '../../domain/services/active_company_service.dart';
import 'invoice_editor_screen.dart';

/// Rechnungsliste (Entwürfe) der aktiven Firma (A2). Direkte Aktion
/// "Kunde → neue Rechnung" ohne Angebot/Auftrag-Zwischenschritt.
class InvoicesScreen extends StatefulWidget {
  const InvoicesScreen({super.key});

  @override
  State<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends State<InvoicesScreen> {
  late Future<_InvoicesData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_InvoicesData> _load() async {
    final companyId = context.read<ActiveCompanyService>().active!.id;
    final invoiceRepo = context.read<InvoiceRepository>();
    final customerRepo = context.read<CustomerRepository>();
    final invoices = await invoiceRepo.listAllForCompany(companyId);
    final customers = await customerRepo.listForCompany(companyId);
    final customerById = {for (final c in customers) c.id: c};
    final totalsById = <String, Money>{};
    for (final invoice in invoices) {
      totalsById[invoice.id] = (await invoiceRepo.totalsFor(invoice.id)).totalGross;
    }
    return _InvoicesData(
      invoices: invoices,
      customerById: customerById,
      allCustomers: customers,
      totalsById: totalsById,
    );
  }

  void _reload() => setState(() => _future = _load());

  Future<void> _createNew(List<Customer> customers) async {
    if (customers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bitte zuerst einen Kunden anlegen.')),
      );
      return;
    }
    final customer = await showDialog<Customer>(
      context: context,
      builder: (context) => _PickCustomerDialog(customers: customers),
    );
    if (customer == null || !mounted) return;
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => InvoiceEditorScreen(customer: customer)),
    );
    if (mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<_InvoicesData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data!;
          if (data.invoices.isEmpty) {
            return const Center(child: Text('Noch keine Rechnungsentwürfe.'));
          }
          return ListView.separated(
            itemCount: data.invoices.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final invoice = data.invoices[index];
              final customer = data.customerById[invoice.customerId];
              final isFinalized = invoice.status == InvoiceStatus.finalized;
              final statusLabel = isFinalized ? invoice.invoiceNumber! : 'Entwurf';
              return ListTile(
                leading: Icon(
                  isFinalized ? Icons.receipt_long : Icons.receipt_long_outlined,
                  color: isFinalized ? Theme.of(context).colorScheme.primary : null,
                ),
                title: Text(customer?.name ?? '(unbekannter Kunde)'),
                subtitle: Text(
                  '$statusLabel — ${invoice.issueDate.toLocal().toString().split(' ').first}',
                ),
                trailing: Text(data.totalsById[invoice.id]?.toString() ?? '–'),
                onTap: () async {
                  if (customer == null) return;
                  await Navigator.of(context).push<bool>(
                    MaterialPageRoute(
                      builder: (_) => InvoiceEditorScreen(customer: customer, invoice: invoice),
                    ),
                  );
                  if (mounted) _reload();
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FutureBuilder<_InvoicesData>(
        future: _future,
        builder: (context, snapshot) {
          return FloatingActionButton.extended(
            heroTag: 'invoices-fab',
            onPressed: () => _createNew(snapshot.data?.allCustomers ?? []),
            icon: const Icon(Icons.add),
            label: const Text('Neue Rechnung'),
          );
        },
      ),
    );
  }
}

class _InvoicesData {
  const _InvoicesData({
    required this.invoices,
    required this.customerById,
    required this.allCustomers,
    required this.totalsById,
  });
  final List<Invoice> invoices;
  final Map<String, Customer> customerById;
  final List<Customer> allCustomers;
  final Map<String, Money> totalsById;
}

class _PickCustomerDialog extends StatelessWidget {
  const _PickCustomerDialog({required this.customers});
  final List<Customer> customers;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Kunde wählen'),
      content: SizedBox(
        width: 360,
        height: 320,
        child: ListView(
          children: [
            for (final customer in customers)
              ListTile(
                title: Text(customer.name),
                onTap: () => Navigator.pop(context, customer),
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
