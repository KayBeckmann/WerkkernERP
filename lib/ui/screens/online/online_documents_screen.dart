import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:werkkern_client/werkkern_client.dart';
import 'package:werkkern_core/werkkern_core.dart';

import '../../../domain/services/online_session.dart';
import '../../theme/app_theme.dart';
import 'online_document_screen.dart';

/// Dokumente einer Art ([kind]) der Online-Firma — wie offline
/// (`invoices_screen.dart`) ein eigener Bereich je Dokumentart: Kunde als
/// Titel, Nummer bzw. „Entwurf“ mit Datum oder Mahnstufe, Bruttobetrag;
/// breit Liste und Editor nebeneinander. Zusätzlich online: Suche und
/// der Offline-Bestand.
class OnlineDocumentsScreen extends StatefulWidget {
  const OnlineDocumentsScreen({super.key, required this.session, required this.kind});
  final OnlineSession session;
  final String kind;

  @override
  State<OnlineDocumentsScreen> createState() => _OnlineDocumentsScreenState();
}

class _OnlineDocumentsScreenState extends State<OnlineDocumentsScreen> {
  late Future<List<OnlineDocument>> _future;
  String _query = '';
  DunningConfig? _dunningConfig;

  /// Breit-Layout: im rechten Bereich geöffnetes Dokument; der Zähler
  /// erzwingt nach einer Änderung einen frischen Editor.
  String? _selectedId;
  int _selectionNonce = 0;

  /// Server nicht erreichbar -> Liste zeigt nur den Offline-Bestand.
  bool _showingOffline = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<OnlineDocument>> _load() async {
    final offline = widget.session.offline;
    if (widget.session.offlineOnly && offline != null) return _offlineDocuments(offline);
    try {
      final documents = await widget.session.client.documents(kind: widget.kind, query: _query);
      _showingOffline = false;
      await _loadDunningConfig();
      return documents;
    } on ApiUnreachable {
      if (offline == null || offline.isEmpty) rethrow;
      return _offlineDocuments(offline);
    }
  }

  /// Mahnstufe in der Liste wie offline — Fristen aus den Einstellungen.
  Future<void> _loadDunningConfig() async {
    final session = widget.session;
    if (widget.kind != 'invoice' || !session.modules.contains('dunning') || !session.can('dunning.read')) return;
    try {
      final s = await session.client.dunningSettings();
      _dunningConfig = DunningConfig(
        reminder2AfterDays: s['reminder2AfterDays'] as int? ?? 14,
        reminder3AfterDays: s['reminder3AfterDays'] as int? ?? 28,
        feeLevel1: Money.zero(),
        feeLevel2: Money.zero(),
        feeLevel3: Money.zero(),
        interestRatePercent: 0,
      );
    } on Exception {
      // Ohne Einstellungen eben ohne Mahnstufe in der Liste.
    }
  }

  List<OnlineDocument> _offlineDocuments(OfflineStore offline) {
    _showingOffline = true;
    final q = _query.toLowerCase();
    return [
      for (final d in offline.documents)
        if (d.kind == widget.kind &&
            (q.isEmpty ||
                (d.number ?? '').toLowerCase().contains(q) ||
                (d.displayCustomerName ?? '').toLowerCase().contains(q)))
          d,
    ];
  }

  void _reload() => setState(() {
        _future = _load();
      });

  bool get _isWide => MediaQuery.sizeOf(context).width >= AppMetrics.wideLayoutBreakpoint;

  Future<void> _open(String id) async {
    if (_isWide) {
      setState(() {
        _selectedId = id;
        _selectionNonce++;
      });
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => OnlineDocumentScreen(session: widget.session, documentId: id)),
    );
    if (mounted) _reload();
  }

  /// Wie offline: Kunde mit Suche wählen, dann direkt den Entwurf öffnen
  /// (das Projekt wird im Editor zugeordnet).
  Future<void> _create() async {
    final session = widget.session;
    final List<OnlineCustomer> customers;
    try {
      customers = await session.client.customers();
    } on Exception catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(describeOnlineError(e))));
      return;
    }
    if (!mounted) return;
    if (customers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bitte zuerst einen Kunden anlegen.')));
      return;
    }
    final customer = await showDialog<OnlineCustomer>(
      context: context,
      builder: (_) => OnlinePickCustomerDialog(customers: customers),
    );
    if (customer == null || !mounted) return;
    try {
      final created = await session.client.createDocument(customerId: customer.id, kind: widget.kind);
      if (!mounted) return;
      _reload();
      await _open(created.id);
    } on Exception catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(describeOnlineError(e))));
    }
  }

  Widget _buildList(List<OnlineDocument> documents) {
    final offline = widget.session.offline;
    final theme = Theme.of(context);
    final dateFormat = DateFormat('dd.MM.yyyy');
    if (documents.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _showingOffline
                ? 'Keine offline verfügbaren Dokumente.'
                : _query.isNotEmpty
                    ? 'Keine Dokumente gefunden.'
                    : onlineDocumentEmptyText(widget.kind),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () async => _reload(),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
        itemCount: documents.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final d = documents[index];
          final finalized = !d.isDraft;
          final pending = offline?.pendingFor(d.id).length ?? 0;
          final level = _dunningConfig == null || d.kind != 'invoice'
              ? DunningLevel.none
              : dunningLevelForDue(
                  isFinalized: finalized,
                  isPaid: d.isPaid,
                  dueDate: d.dueDate,
                  now: DateTime.now(),
                  config: _dunningConfig!,
                );
          final status = finalized ? d.number ?? '' : 'Entwurf';
          final selected = _isWide && _selectedId == d.id;
          return Card(
            color: selected ? theme.colorScheme.primaryContainer : null,
            child: ListTile(
              leading: Icon(
                pending > 0
                    ? Icons.sync_problem_outlined
                    : offline?.isPinned(d.id) ?? false
                        ? Icons.offline_pin_outlined
                        : finalized
                            ? Icons.receipt_long
                            : Icons.receipt_long_outlined,
                color: finalized && pending == 0 ? theme.colorScheme.primary : null,
              ),
              title: Text(d.displayCustomerName ?? '(unbekannter Kunde)'),
              subtitle: Text(
                level == DunningLevel.none
                    ? '$status — ${dateFormat.format(d.issueDate)}'
                    : '$status — ${dunningLevelLabel(level)}',
                style: level == DunningLevel.none ? null : TextStyle(color: theme.colorScheme.error),
              ),
              trailing: Text(d.grossCents == null ? '–' : Money.fromCents(d.grossCents!).toString()),
              onTap: () => _open(d.id),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDetailPane() {
    final id = _selectedId;
    if (id == null) {
      return Center(
        child: Text(
          'Dokument auswählen oder "${onlineNewDocumentLabel(widget.kind)}" antippen.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }
    return OnlineDocumentScreen(
      key: ValueKey('$id-$_selectionNonce'),
      session: widget.session,
      documentId: id,
      onChanged: _reload,
      // Gelöscht/umgewandelt: rechts das Folgedokument bzw. nichts zeigen.
      onNavigate: (next) {
        setState(() {
          _selectedId = next;
          _selectionNonce++;
        });
        _reload();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    // Gutschriften entstehen nur aus einer Rechnung (wie offline).
    final canCreate = !session.offlineOnly &&
        widget.kind != 'creditNote' &&
        session.can('invoices.write') &&
        session.can('customers.read');
    final list = Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: TextField(
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Nummer oder Kunde suchen'),
              onSubmitted: (value) {
                _query = value.trim();
                _reload();
              },
            ),
          ),
          Expanded(
            child: FutureBuilder<List<OnlineDocument>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.hasError) return Center(child: Text(describeOnlineError(snapshot.error!)));
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                final list = _buildList(snapshot.data!);
                if (!_showingOffline || session.offlineOnly) return list;
                return Column(
                  children: [
                    const ListTile(
                      leading: Icon(Icons.cloud_off_outlined),
                      title: Text('Server nicht erreichbar — angezeigt werden nur offline verfügbare Dokumente.'),
                    ),
                    Expanded(child: list),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: canCreate
          ? FloatingActionButton.extended(
              heroTag: 'online-documents-fab-${widget.kind}',
              onPressed: _create,
              icon: const Icon(Icons.add),
              label: Text(onlineNewDocumentLabel(widget.kind)),
            )
          : null,
    );
    if (!_isWide) return list;
    // Breit wie offline: Liste links in fester Breite, Editor rechts. Das
    // äußere Scaffold zeigt Hinweise (Snackbars) einmal über beide
    // Bereiche statt je einmal links und rechts.
    return Scaffold(
      body: Row(
        children: [
          SizedBox(width: 360, child: list),
          VerticalDivider(width: 1, color: Theme.of(context).colorScheme.outlineVariant),
          Expanded(child: _buildDetailPane()),
        ],
      ),
    );
  }
}

/// Kunde-wählen-Dialog mit Live-Suche — wie offline beim Anlegen eines
/// Dokuments (bei vielen Kunden ist eine reine Auswahlliste unpraktisch).
class OnlinePickCustomerDialog extends StatefulWidget {
  const OnlinePickCustomerDialog({super.key, required this.customers});
  final List<OnlineCustomer> customers;

  @override
  State<OnlinePickCustomerDialog> createState() => _OnlinePickCustomerDialogState();
}

class _OnlinePickCustomerDialogState extends State<OnlinePickCustomerDialog> {
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
              key: const Key('online-pick-customer-search'),
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
                          ListTile(title: Text(customer.name), onTap: () => Navigator.pop(context, customer)),
                      ],
                    ),
            ),
          ],
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen'))],
    );
  }
}

/// Wie offline `DocumentLabels.newFabLabel`.
String onlineNewDocumentLabel(String? kind) => switch (kind) {
      'invoice' => 'Neue Rechnung',
      'quote' => 'Neues Angebot',
      'order' => 'Neuer Auftrag',
      'deliveryNote' => 'Neuer Lieferschein',
      'proforma' => 'Neue Proforma-Rechnung',
      'creditNote' => 'Neue Gutschrift',
      _ => 'Neues Dokument',
    };

/// Titel des Editors wie offline: „Rechnung R-26001 — Kunde“ bzw.
/// „Rechnung (Entwurf) — Kunde“.
String onlineEditorTitle(OnlineDocument d) {
  final label = onlineDocumentKindLabels[d.kind] ?? d.kind;
  final head = d.number == null ? '$label (Entwurf)' : '$label ${d.number}';
  return d.displayCustomerName == null ? head : '$head — ${d.displayCustomerName}';
}

/// Wie offline `DocumentLabels.emptyListText`.
String onlineDocumentEmptyText(String? kind) => switch (kind) {
      'invoice' => 'Noch keine Rechnungsentwürfe.',
      'quote' => 'Noch keine Angebotsentwürfe.',
      'order' => 'Noch keine Auftragsentwürfe.',
      'deliveryNote' => 'Noch keine Lieferschein-Entwürfe.',
      'proforma' => 'Noch keine Proforma-Entwürfe.',
      'creditNote' => 'Noch keine Gutschriften. Eine Gutschrift wird aus der betreffenden Rechnung heraus '
          'erstellt (Rechnung öffnen → „Gutschrift erstellen").',
      _ => 'Keine Dokumente gefunden.',
    };
