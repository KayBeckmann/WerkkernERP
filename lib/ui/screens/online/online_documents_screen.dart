import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:werkkern_client/werkkern_client.dart';
import 'package:werkkern_core/werkkern_core.dart';

import '../../../domain/services/online_session.dart';
import 'online_document_screen.dart';

/// Dokumente der Online-Firma — Liste mit Suche und Status, neuer
/// Entwurf mit `invoices.write`. Dokumentarten erscheinen nur bei
/// aktivem Modul (wie offline).
class OnlineDocumentsScreen extends StatefulWidget {
  const OnlineDocumentsScreen({super.key, required this.session});
  final OnlineSession session;

  @override
  State<OnlineDocumentsScreen> createState() => _OnlineDocumentsScreenState();
}

class _OnlineDocumentsScreenState extends State<OnlineDocumentsScreen> {
  late Future<List<OnlineDocument>> _future;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<OnlineDocument>> _load() => widget.session.client.documents(query: _query);

  void _reload() => setState(() {
        _future = _load();
      });

  Future<void> _open(String id) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => OnlineDocumentScreen(session: widget.session, documentId: id)),
    );
    if (mounted) _reload();
  }

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
    final kinds = [
      for (final entry in onlineDocumentKindModules.entries)
        // Gutschriften entstehen offline nur aus einer Rechnung — hier
        // ebenso wenig "aus dem Nichts" anbieten.
        if (entry.key != 'creditNote' && (entry.value == null || session.modules.contains(entry.value))) entry.key,
    ];
    final choice = await showDialog<({String kind, String customerId})>(
      context: context,
      builder: (_) => _NewDocumentDialog(customers: customers, kinds: kinds),
    );
    if (choice == null || !mounted) return;
    try {
      final created = await session.client.createDocument(customerId: choice.customerId, kind: choice.kind);
      if (mounted) await _open(created.id);
    } on Exception catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(describeOnlineError(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd.MM.yyyy');
    return Scaffold(
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
                final documents = snapshot.data!;
                if (documents.isEmpty) return const Center(child: Text('Keine Dokumente gefunden.'));
                return RefreshIndicator(
                  onRefresh: () async => _reload(),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
                    itemCount: documents.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final d = documents[index];
                      final label = onlineDocumentKindLabels[d.kind] ?? d.kind;
                      return Card(
                        child: ListTile(
                          leading: Icon(d.isDraft ? Icons.edit_note : Icons.lock_outline),
                          title: Text(d.number ?? '$label (Entwurf)'),
                          subtitle: Text(
                            [label, ?d.displayCustomerName, dateFormat.format(d.issueDate)].join(' · '),
                          ),
                          trailing: Text(d.grossCents == null ? '' : Money.fromCents(d.grossCents!).toString()),
                          onTap: () => _open(d.id),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: widget.session.can('invoices.write') && widget.session.can('customers.read')
          ? FloatingActionButton.extended(
              heroTag: 'online-documents-fab',
              onPressed: _create,
              icon: const Icon(Icons.add),
              label: const Text('Neues Dokument'),
            )
          : null,
    );
  }
}

class _NewDocumentDialog extends StatefulWidget {
  const _NewDocumentDialog({required this.customers, required this.kinds});
  final List<OnlineCustomer> customers;
  final List<String> kinds;

  @override
  State<_NewDocumentDialog> createState() => _NewDocumentDialogState();
}

class _NewDocumentDialogState extends State<_NewDocumentDialog> {
  late String _kind = widget.kinds.first;
  String? _customerId;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Neues Dokument'),
      content: widget.customers.isEmpty
          ? const Text('Bitte zuerst einen Kunden anlegen.')
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _kind,
                  decoration: const InputDecoration(labelText: 'Dokumentart'),
                  items: [
                    for (final k in widget.kinds) DropdownMenuItem(value: k, child: Text(onlineDocumentKindLabels[k] ?? k)),
                  ],
                  onChanged: (v) => setState(() => _kind = v!),
                ),
                DropdownButtonFormField<String>(
                  key: const Key('online-new-document-customer'),
                  initialValue: _customerId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Kunde'),
                  items: [
                    for (final c in widget.customers)
                      DropdownMenuItem(value: c.id, child: Text(c.name, overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged: (v) => setState(() => _customerId = v),
                ),
              ],
            ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
        FilledButton(
          onPressed: _customerId == null ? null : () => Navigator.pop(context, (kind: _kind, customerId: _customerId!)),
          child: const Text('Anlegen'),
        ),
      ],
    );
  }
}
