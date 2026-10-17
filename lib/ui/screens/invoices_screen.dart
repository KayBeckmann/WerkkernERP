import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/database/database.dart';
import '../../data/database/tables.dart';
import '../../data/repositories/customer_repository.dart';
import '../../data/repositories/invoice_repository.dart';
import '../../data/repositories/recurring_invoice_template_repository.dart';
import '../../domain/models/money.dart';
import '../../domain/services/active_company_service.dart';
import '../theme/app_theme.dart';
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
        DocumentKind.proforma => 'Proforma-Rechnung',
      };

  static String plural(DocumentKind kind) => switch (kind) {
        DocumentKind.invoice => 'Rechnungen',
        DocumentKind.quote => 'Angebote',
        DocumentKind.order => 'Aufträge',
        DocumentKind.deliveryNote => 'Lieferscheine',
        DocumentKind.proforma => 'Proforma-Rechnungen',
      };

  static String emptyListText(DocumentKind kind) => switch (kind) {
        DocumentKind.invoice => 'Noch keine Rechnungsentwürfe.',
        DocumentKind.quote => 'Noch keine Angebotsentwürfe.',
        DocumentKind.order => 'Noch keine Auftragsentwürfe.',
        DocumentKind.deliveryNote => 'Noch keine Lieferschein-Entwürfe.',
        DocumentKind.proforma => 'Noch keine Proforma-Entwürfe.',
      };

  static String newFabLabel(DocumentKind kind) => switch (kind) {
        DocumentKind.invoice => 'Neue Rechnung',
        DocumentKind.quote => 'Neues Angebot',
        DocumentKind.order => 'Neuer Auftrag',
        DocumentKind.deliveryNote => 'Neuer Lieferschein',
        DocumentKind.proforma => 'Neue Proforma-Rechnung',
      };

  static String editorDraftTitle(DocumentKind kind) => switch (kind) {
        DocumentKind.invoice => 'Rechnung (Entwurf)',
        DocumentKind.quote => 'Angebot (Entwurf)',
        DocumentKind.order => 'Auftrag (Entwurf)',
        DocumentKind.deliveryNote => 'Lieferschein (Entwurf)',
        DocumentKind.proforma => 'Proforma-Rechnung (Entwurf)',
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
        DocumentKind.proforma =>
          'Die Proforma-Rechnung erhält jetzt eine endgültige Nummer (eigener Nummernkreis, keine '
              'umsatzsteuerliche Rechnungsnummer) und kann danach nicht mehr geändert werden.',
      };
}

class _InvoicesScreenState extends State<InvoicesScreen> {
  late Future<_InvoicesData> _future;

  // Audit-Befund 2026-10-17 (Abweichungen.md Abschnitt 3): auf breiten
  // Bildschirmen zeigt RechnungsFee Liste und Detail/Formular
  // **gleichzeitig** nebeneinander statt per Navigation zu wechseln.
  // Diese Auswahl ist nur für den breiten Pfad relevant — der schmale
  // Pfad (Smartphone) bleibt bei Push-Navigation, siehe `_isWideLayout`.
  Invoice? _selectedInvoice;
  Customer? _selectedCustomer;
  bool _creatingNew = false;
  // Erzwingt einen frischen `InvoiceEditorScreen`-Zustand auch dann, wenn
  // zweimal hintereinander "Neu" für denselben Kunden gewählt wird (ohne
  // das wäre der Key sonst identisch, siehe `_detailKey`).
  int _newDraftNonce = 0;

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

  /// C11 (Kay-Priorisierungsentscheidung 2026-10-17): ohne Server/
  /// Hintergrunddienst kann die Fälligkeitsprüfung wiederkehrender
  /// Vorlagen nur laufen, wenn diese Liste tatsächlich **gelesen** wird —
  /// bewusst in [_load] statt nur in `initState`: `HomeShell` hält alle
  /// Tab-Screens dauerhaft in einem `IndexedStack` lebend, ein einmal
  /// gemountetes `InvoicesScreen` bekommt beim erneuten Antippen des
  /// Tabs **kein** neues `initState()` mehr (gefunden über einen Widget-
  /// Test: ein Modul, das erst NACH dem ersten Mount aktiviert wurde,
  /// hätte seine fällige Vorlage sonst nie generiert). `generateDueDrafts`
  /// ist für wiederholte Aufrufe unschädlich — nach der Generierung
  /// liegt `nextDueDate` in der Zukunft, ein erneuter Aufruf findet
  /// nichts mehr zu tun. Nur für `kind == invoice` relevant, da Vorlagen
  /// ausschließlich Rechnungsentwürfe erzeugen.
  Future<void> _checkDueTemplates(String companyId) async {
    if (widget.kind != DocumentKind.invoice) return;
    final company = context.read<ActiveCompanyService>().active!;
    if (!company.recurringInvoicesEnabled) return;
    final created = await context
        .read<RecurringInvoiceTemplateRepository>()
        .generateDueDrafts(companyId: companyId);
    if (created.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${created.length} Rechnungsentwurf/-entwürfe aus wiederkehrenden Vorlagen erstellt.',
              ),
            ),
          );
        }
      });
    }
  }

  Future<_InvoicesData> _load() async {
    final companyId = context.read<ActiveCompanyService>().active!.id;
    final invoiceRepo = context.read<InvoiceRepository>();
    final customerRepo = context.read<CustomerRepository>();
    await _checkDueTemplates(companyId);
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

  /// Liefert `null`, wenn kein Kunde vorhanden ist (Snackbar bereits
  /// gezeigt) oder der Auswahldialog abgebrochen wurde.
  Future<Customer?> _pickCustomerForNew() async {
    // Frisch laden statt der gecachten Liste aus dem Tab-FutureBuilder:
    // da IndexedStack diesen Screen nie neu initialisiert, wäre ein
    // Kunde, der NACH dem ersten Öffnen dieses Tabs angelegt wurde, in
    // der gecachten Liste sonst erst nach einem App-Neustart sichtbar
    // (gefunden über einen Widget-Test, der genau diesen Ablauf
    // nachstellt — kein theoretischer Fall).
    final companyId = context.read<ActiveCompanyService>().active!.id;
    final customers = await context.read<CustomerRepository>().listForCompany(companyId);
    if (!mounted) return null;
    if (customers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bitte zuerst einen Kunden anlegen.')),
      );
      return null;
    }
    return showDialog<Customer>(
      context: context,
      builder: (context) => _PickCustomerDialog(customers: customers),
    );
  }

  /// Schmaler Pfad (Smartphone): wie bisher per Push-Navigation.
  Future<void> _createNewNarrow() async {
    final customer = await _pickCustomerForNew();
    if (customer == null || !mounted) return;
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => InvoiceEditorScreen(customer: customer, kind: widget.kind)),
    );
    if (mounted) _reload();
  }

  /// Breiter Pfad (Audit-Befund 2026-10-17, Abschnitt 3): kein Push —
  /// der Editor erscheint direkt eingebettet im rechten Bereich.
  Future<void> _createNewWide() async {
    final customer = await _pickCustomerForNew();
    if (customer == null || !mounted) return;
    setState(() {
      _selectedCustomer = customer;
      _selectedInvoice = null;
      _creatingNew = true;
      _newDraftNonce++;
    });
  }

  Future<void> _openNarrow(Invoice invoice, Customer customer) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => InvoiceEditorScreen(customer: customer, invoice: invoice, kind: widget.kind),
      ),
    );
    if (mounted) _reload();
  }

  void _selectWide(Invoice invoice, Customer customer) {
    setState(() {
      _selectedInvoice = invoice;
      _selectedCustomer = customer;
      _creatingNew = false;
    });
  }

  /// Nach Speichern/Finalisieren im eingebetteten Editor (Breit-Layout):
  /// die Liste neu laden UND das übergebene Dokument gleich als Auswahl
  /// übernehmen — sonst bliebe ein frisch gespeicherter Entwurf in der
  /// Liste unmarkiert, während er im Detailbereich sichtbar bearbeitet
  /// wird (siehe Doc-Kommentar bei `InvoiceEditorScreen.onChanged`).
  void _handleEditorChanged(Invoice updated) {
    setState(() {
      _selectedInvoice = updated;
      _creatingNew = false;
    });
    _reload();
  }

  Widget _buildList(_InvoicesData data, {required bool isWide}) {
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
        final selected = isWide && !_creatingNew && _selectedInvoice?.id == invoice.id;
        return Card(
          color: selected ? Theme.of(context).colorScheme.primaryContainer : null,
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
            onTap: customer == null
                ? null
                : () => isWide ? _selectWide(invoice, customer) : _openNarrow(invoice, customer),
          ),
        );
      },
    );
  }

  Widget _buildDetailPane() {
    if (_creatingNew && _selectedCustomer != null) {
      return InvoiceEditorScreen(
        key: ValueKey('new-${_selectedCustomer!.id}-$_newDraftNonce'),
        customer: _selectedCustomer!,
        kind: widget.kind,
        onChanged: _handleEditorChanged,
      );
    }
    if (_selectedInvoice != null && _selectedCustomer != null) {
      return InvoiceEditorScreen(
        key: ValueKey(_selectedInvoice!.id),
        customer: _selectedCustomer!,
        invoice: _selectedInvoice,
        kind: widget.kind,
        onChanged: _handleEditorChanged,
      );
    }
    return Center(
      child: Text(
        'Dokument auswählen oder "${DocumentLabels.newFabLabel(widget.kind)}" antippen.',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= AppMetrics.wideLayoutBreakpoint;

    return FutureBuilder<_InvoicesData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = snapshot.data!;

        if (!isWide) {
          return Scaffold(
            body: _buildList(data, isWide: false),
            floatingActionButton: FloatingActionButton.extended(
              heroTag: 'invoices-fab-${widget.kind.name}',
              onPressed: _createNewNarrow,
              icon: const Icon(Icons.add),
              label: Text(DocumentLabels.newFabLabel(widget.kind)),
            ),
          );
        }

        // Breit-Layout (Audit-Befund 2026-10-17, Abschnitt 3): Liste
        // links in fester Breite, Detail/Editor rechts eingebettet statt
        // per Navigator.push — beide gleichzeitig sichtbar, wie bei
        // RechnungsFees Arbeitsansicht beschrieben (eigenständig in
        // Flutter nachgebaut, kein Code/Asset von dort).
        return Row(
          children: [
            SizedBox(
              width: 360,
              child: Scaffold(
                body: _buildList(data, isWide: true),
                floatingActionButton: FloatingActionButton.extended(
                  heroTag: 'invoices-fab-${widget.kind.name}',
                  onPressed: _createNewWide,
                  icon: const Icon(Icons.add),
                  label: Text(DocumentLabels.newFabLabel(widget.kind)),
                ),
              ),
            ),
            VerticalDivider(width: 1, color: Theme.of(context).colorScheme.outlineVariant),
            Expanded(child: _buildDetailPane()),
          ],
        );
      },
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
