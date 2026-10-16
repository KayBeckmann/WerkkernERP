import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/database/database.dart';
import '../../data/database/tables.dart';
import '../../data/repositories/customer_repository.dart';
import '../../data/repositories/invoice_repository.dart';
import '../../domain/models/money.dart';
import '../../domain/services/active_company_service.dart';
import 'invoice_editor_screen.dart';

/// Dokumentliste (Entwürfe + finalisiert) der aktiven Firma. Seit A5
/// generisch für alle drei [DocumentKind]s — Rechnung ist über den
/// Default immer verfügbar (A0/A2), Angebot/Auftrag werden nur
/// angezeigt, wenn die Firma das Modul aktiviert hat (Sichtbarkeit
/// regelt `HomeShell`, nicht dieser Screen). Direkte Aktion "Kunde →
/// neues Dokument" ohne Zwischenschritt.
class InvoicesScreen extends StatefulWidget {
  const InvoicesScreen({super.key, this.kind = DocumentKind.invoice});

  final DocumentKind kind;

  @override
  State<InvoicesScreen> createState() => _InvoicesScreenState();
}

/// Beschriftungen je Dokumentart — an einer Stelle gesammelt, damit
/// Liste/Editor/PDF nicht je einzeln abweichen können.
class DocumentLabels {
  const DocumentLabels._();

  static String title(DocumentKind kind) => switch (kind) {
        DocumentKind.invoice => 'Rechnung',
        DocumentKind.quote => 'Angebot',
        DocumentKind.order => 'Auftrag',
        DocumentKind.deliveryNote => 'Lieferschein',
      };

  static String plural(DocumentKind kind) => switch (kind) {
        DocumentKind.invoice => 'Rechnungen',
        DocumentKind.quote => 'Angebote',
        DocumentKind.order => 'Aufträge',
        DocumentKind.deliveryNote => 'Lieferscheine',
      };

  static String emptyListText(DocumentKind kind) => switch (kind) {
        DocumentKind.invoice => 'Noch keine Rechnungsentwürfe.',
        DocumentKind.quote => 'Noch keine Angebotsentwürfe.',
        DocumentKind.order => 'Noch keine Auftragsentwürfe.',
        DocumentKind.deliveryNote => 'Noch keine Lieferschein-Entwürfe.',
      };

  static String newFabLabel(DocumentKind kind) => switch (kind) {
        DocumentKind.invoice => 'Neue Rechnung',
        DocumentKind.quote => 'Neues Angebot',
        DocumentKind.order => 'Neuer Auftrag',
        DocumentKind.deliveryNote => 'Neuer Lieferschein',
      };

  static String editorDraftTitle(DocumentKind kind) => switch (kind) {
        DocumentKind.invoice => 'Rechnung (Entwurf)',
        DocumentKind.quote => 'Angebot (Entwurf)',
        DocumentKind.order => 'Auftrag (Entwurf)',
        DocumentKind.deliveryNote => 'Lieferschein (Entwurf)',
      };

  static String finalizeConfirmSentence(DocumentKind kind) => switch (kind) {
        DocumentKind.invoice =>
          'Die Rechnung erhält jetzt eine endgültige Nummer und kann danach nicht mehr geändert werden.',
        DocumentKind.quote =>
          'Das Angebot erhält jetzt eine endgültige Nummer und kann danach nicht mehr geändert werden.',
        DocumentKind.order =>
          'Der Auftrag erhält jetzt eine endgültige Nummer und kann danach nicht mehr geändert werden.',
        DocumentKind.deliveryNote =>
          'Der Lieferschein erhält jetzt eine endgültige Nummer und kann danach nicht mehr geändert werden.',
      };
}

class _InvoicesScreenState extends State<InvoicesScreen> {
  late Future<_InvoicesData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(InvoicesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.kind != widget.kind) _reload();
  }

  Future<_InvoicesData> _load() async {
    final companyId = context.read<ActiveCompanyService>().active!.id;
    final invoiceRepo = context.read<InvoiceRepository>();
    final customerRepo = context.read<CustomerRepository>();
    final invoices = await invoiceRepo.listAllForCompany(companyId, kind: widget.kind);
    final customers = await customerRepo.listForCompany(companyId);
    final customerById = {for (final c in customers) c.id: c};
    final totalsById = <String, Money>{};
    for (final invoice in invoices) {
      totalsById[invoice.id] = (await invoiceRepo.totalsFor(invoice.id)).totalGross;
    }
    return _InvoicesData(
      invoices: invoices,
      customerById: customerById,
      totalsById: totalsById,
    );
  }

  void _reload() => setState(() {
        _future = _load();
      });

  Future<void> _createNew() async {
    // Frisch laden statt der gecachten Liste aus dem Tab-FutureBuilder:
    // da IndexedStack diesen Screen nie neu initialisiert, wäre ein
    // Kunde, der NACH dem ersten Öffnen dieses Tabs angelegt wurde, in
    // der gecachten Liste sonst erst nach einem App-Neustart sichtbar
    // (gefunden über einen Widget-Test, der genau diesen Ablauf
    // nachstellt — kein theoretischer Fall).
    final companyId = context.read<ActiveCompanyService>().active!.id;
    final customers = await context.read<CustomerRepository>().listForCompany(companyId);
    if (!mounted) return;
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
      MaterialPageRoute(builder: (_) => InvoiceEditorScreen(customer: customer, kind: widget.kind)),
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
            return Center(child: Text(DocumentLabels.emptyListText(widget.kind)));
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
            itemCount: data.invoices.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final invoice = data.invoices[index];
              final customer = data.customerById[invoice.customerId];
              final isFinalized = invoice.status == InvoiceStatus.finalized;
              final statusLabel = isFinalized ? invoice.invoiceNumber! : 'Entwurf';
              return Card(
                child: ListTile(
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
                        builder: (_) => InvoiceEditorScreen(
                          customer: customer,
                          invoice: invoice,
                          kind: widget.kind,
                        ),
                      ),
                    );
                    if (mounted) _reload();
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'invoices-fab-${widget.kind.name}',
        onPressed: _createNew,
        icon: const Icon(Icons.add),
        label: Text(DocumentLabels.newFabLabel(widget.kind)),
      ),
    );
  }
}

class _InvoicesData {
  const _InvoicesData({
    required this.invoices,
    required this.customerById,
    required this.totalsById,
  });
  final List<Invoice> invoices;
  final Map<String, Customer> customerById;
  final Map<String, Money> totalsById;
}

/// Kunde-wählen-Dialog mit Live-Suche (Kay-Nachtrag 2026-10-16: "beim
/// Anlegen eines neuen Dokumentes eine Filter/Suchmaske für Kunden") —
/// bei vielen Kunden war eine reine Scroll-Liste unpraktisch.
class _PickCustomerDialog extends StatefulWidget {
  const _PickCustomerDialog({required this.customers});
  final List<Customer> customers;

  @override
  State<_PickCustomerDialog> createState() => _PickCustomerDialogState();
}

class _PickCustomerDialogState extends State<_PickCustomerDialog> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = _query.trim().toLowerCase();
    final filtered = query.isEmpty
        ? widget.customers
        : widget.customers.where((c) => c.name.toLowerCase().contains(query)).toList();

    return AlertDialog(
      title: const Text('Kunde wählen'),
      content: SizedBox(
        width: 360,
        height: 360,
        child: Column(
          children: [
            TextField(
              controller: _searchCtrl,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Suchen', prefixIcon: Icon(Icons.search)),
              onChanged: (value) => setState(() => _query = value),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: filtered.isEmpty
                  ? const Center(child: Text('Kein Kunde gefunden.'))
                  : ListView(
                      children: [
                        for (final customer in filtered)
                          ListTile(
                            title: Text(customer.name),
                            onTap: () => Navigator.pop(context, customer),
                          ),
                      ],
                    ),
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
