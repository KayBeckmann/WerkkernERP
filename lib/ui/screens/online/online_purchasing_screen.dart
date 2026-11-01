import 'dart:typed_data';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:werkkern_client/werkkern_client.dart';
import 'package:werkkern_core/werkkern_core.dart';

import '../../../domain/services/online_session.dart';
import '../../../pdf/purchase_order_pdf_builder.dart';
import 'online_articles_screen.dart' show formatQuantity;
import 'online_form.dart';
import 'online_mail.dart';

/// Wie offline (`purchase_orders_screen.dart`).
const purchaseOrderStatusLabels = {
  'draft': 'Entwurf',
  'finalized': 'Finalisiert',
  'partiallyReceived': 'Teilweise erhalten',
  'fullyReceived': 'Vollständig erhalten',
};

/// Bestellungen an Lieferanten (C5.2) — Aufbau wie offline
/// (`purchase_orders_screen.dart`): Liste mit Nummer, Lieferant und
/// Status; „Mindestbestand“ und „Neue Bestellung“ unten.
class OnlinePurchasingScreen extends StatelessWidget {
  const OnlinePurchasingScreen({super.key, required this.session});
  final OnlineSession session;

  Future<void> _open(BuildContext context, String id) => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => OnlinePurchaseOrderScreen(session: session, purchaseOrderId: id)),
      );

  Future<void> _create(BuildContext context, VoidCallback reload) async {
    final suppliers = await session.client.suppliers();
    if (!context.mounted) return;
    if (suppliers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bitte zuerst einen Lieferanten anlegen.')));
      return;
    }
    final supplier = await showDialog<OnlineSupplier>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Lieferant wählen'),
        children: [
          for (final s in suppliers)
            SimpleDialogOption(onPressed: () => Navigator.pop(context, s), child: Text(s.name)),
        ],
      ),
    );
    if (supplier == null || !context.mounted) return;
    OnlinePurchaseOrder? created;
    await runOnline(context, () async {
      created = await session.client.createPurchaseOrder(supplierId: supplier.id);
    });
    if (created != null && context.mounted) await _open(context, created!.id);
    reload();
  }

  Future<void> _suggestions(BuildContext context, VoidCallback reload) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => _SuggestionsScreen(session: session)));
    reload();
  }

  @override
  Widget build(BuildContext context) {
    final canWrite = session.can('purchaseOrders.write');
    return OnlineListView<OnlinePurchaseOrder>(
      load: (_) => session.client.purchaseOrders(),
      emptyText: 'Noch keine Bestellungen angelegt.',
      itemBuilder: (context, o, reload) => Card(
        child: ListTile(
          leading: const Icon(Icons.shopping_cart_outlined),
          title: Text(o.number ?? 'Entwurf'),
          subtitle: Text('${o.supplierName ?? ''} · ${purchaseOrderStatusLabels[o.status] ?? o.status}'.trim()),
          trailing: const Icon(Icons.chevron_right),
          onTap: () async {
            await _open(context, o.id);
            reload();
          },
        ),
      ),
      floatingActionButton: (reload) => Builder(
        builder: (context) => Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            FloatingActionButton.extended(
              heroTag: 'online-purchasing-low-stock-fab',
              onPressed: () => _suggestions(context, reload),
              icon: const Icon(Icons.warning_amber_outlined),
              label: const Text('Mindestbestand'),
            ),
            if (canWrite) ...[
              const SizedBox(width: 12),
              FloatingActionButton.extended(
                heroTag: 'online-purchasing-fab',
                onPressed: () => _create(context, reload),
                icon: const Icon(Icons.add),
                label: const Text('Neue Bestellung'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Mindestbestand-Meldungen wie offline (`low_stock_suggestions_screen.dart`):
/// je Lieferant ein Vorschlag, bei nicht erreichter Mindestbestellmenge
/// Rückfrage vor dem Anlegen.
class _SuggestionsScreen extends StatefulWidget {
  const _SuggestionsScreen({required this.session});
  final OnlineSession session;

  @override
  State<_SuggestionsScreen> createState() => _SuggestionsScreenState();
}

class _SuggestionsScreenState extends State<_SuggestionsScreen> {
  late Future<({List<OnlinePurchaseSuggestion> suggestions, List<String> unassignable})> _future =
      widget.session.client.purchaseSuggestions();

  Future<void> _createDraft(OnlinePurchaseSuggestion s) async {
    if (!s.meetsMinimumOrderQuantity) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Mindestbestellmenge nicht erreicht'),
          content: Text(
            'Die zusammengefasste Menge (${formatQuantity(s.totalQuantity)}) erreicht nicht '
            'die Mindestbestellmenge von ${s.supplierName} '
            '(${formatQuantity(s.minimumOrderQuantity!)}). Der Entwurf lässt sich trotzdem '
            'anlegen und vor dem Finalisieren noch anpassen.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Abbrechen')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Trotzdem anlegen')),
          ],
        ),
      );
      if (proceed != true || !mounted) return;
    }
    OnlinePurchaseOrder? created;
    await runOnline(context, () async {
      created = await widget.session.client.purchaseOrderFromSuggestion(s.supplierId);
    });
    if (created == null || !mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => OnlinePurchaseOrderScreen(session: widget.session, purchaseOrderId: created!.id),
      ),
    );
    if (mounted) {
      setState(() {
        _future = widget.session.client.purchaseSuggestions();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Mindestbestand-Meldungen')),
      body: FutureBuilder<({List<OnlinePurchaseSuggestion> suggestions, List<String> unassignable})>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text(describeOnlineError(snapshot.error!)));
          final data = snapshot.data;
          if (data == null) return const Center(child: CircularProgressIndicator());
          if (data.suggestions.isEmpty && data.unassignable.isEmpty) {
            return const Center(child: Text('Aktuell kein Artikel unter Mindestbestand.'));
          }
          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              for (final s in data.suggestions)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.supplierName, style: theme.textTheme.titleMedium),
                        for (final i in s.items) Text('${i.description}: ${formatQuantity(i.quantity)}'),
                        if (!s.meetsMinimumOrderQuantity)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'Unter Mindestbestellmenge (${formatQuantity(s.minimumOrderQuantity!)}) — wird noch nicht erreicht.',
                              style: TextStyle(color: theme.colorScheme.error),
                            ),
                          ),
                        if (widget.session.can('purchaseOrders.write')) ...[
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: FilledButton(onPressed: () => _createDraft(s), child: const Text('Entwurf anlegen')),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              if (data.unassignable.isNotEmpty)
                Card(
                  color: theme.colorScheme.errorContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Nicht zuordenbar (kein Standardlieferant/Preis bekannt):'),
                        for (final name in data.unassignable) Text(name),
                      ],
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

/// Eine Bestellung: Entwurf bearbeiten, finalisieren, Ware annehmen, PDF.
class OnlinePurchaseOrderScreen extends StatefulWidget {
  const OnlinePurchaseOrderScreen({super.key, required this.session, required this.purchaseOrderId});
  final OnlineSession session;
  final String purchaseOrderId;

  @override
  State<OnlinePurchaseOrderScreen> createState() => _OnlinePurchaseOrderScreenState();
}

class _OnlinePurchaseOrderScreenState extends State<OnlinePurchaseOrderScreen> {
  OnlinePurchaseOrder? _order;
  Object? _error;

  /// Für die Zuordnungszeile im Kopf (wie offline).
  String? _projectName;
  String? _categoryLabel;

  WerkkernApiClient get _client => widget.session.client;
  bool get _canWrite => widget.session.can('purchaseOrders.write');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final order = await _client.purchaseOrder(widget.purchaseOrderId);
      await _loadAssignmentNames(order);
      if (mounted) setState(() => _order = order);
    } on Exception catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _loadAssignmentNames(OnlinePurchaseOrder order) async {
    final session = widget.session;
    try {
      _projectName = order.projectId == null || !session.can('projects.read')
          ? null
          : (await _client.projects()).where((p) => p.id == order.projectId).firstOrNull?.name;
      _categoryLabel = order.expenseCategoryId == null || !session.can('accounting.read')
          ? null
          : (await _client.expenseCategories()).where((c) => c.id == order.expenseCategoryId).firstOrNull?.label;
    } on Exception {
      // Nur Anzeige — ohne Namen bleibt die Zuordnung trotzdem gespeichert.
    }
  }

  Future<void> _apply(OnlinePurchaseOrder updated) async {
    await _loadAssignmentNames(updated);
    if (mounted) setState(() => _order = updated);
  }

  Future<void> _saveItems(List<OnlinePurchaseOrderItem> items) async {
    final order = _order!;
    await runOnline(context, () async {
      final updated = await _client.updatePurchaseOrder(
        order,
        items: items,
        notes: order.notes,
        projectId: order.projectId,
        expenseCategoryId: order.expenseCategoryId,
      );
      await _apply(updated);
    });
  }

  Future<void> _addItem() async {
    final order = _order!;
    final articles = widget.session.can('articles.read') ? await _client.articles() : const <OnlineArticle>[];
    if (!mounted) return;
    final values = await showOnlineForm(
      context,
      title: 'Position',
      submitLabel: 'Übernehmen',
      fields: [
        if (articles.isNotEmpty)
          OnlineField('articleId', 'Artikel aus Stamm (optional)', type: OnlineFieldType.choice, options: {for (final a in articles) a.id: a.name}),
        const OnlineField('description', 'Beschreibung', helper: 'Leer = Artikelname'),
        const OnlineField('quantity', 'Menge', type: OnlineFieldType.decimal, required: true, initial: '1'),
        const OnlineField('price', 'Einkaufspreis je Einheit (netto)', type: OnlineFieldType.money, helper: 'Leer = Preis dieses Lieferanten'),
      ],
    );
    if (values == null || !mounted) return;
    final articleId = values['articleId'] as String?;
    var price = values['price'] as int?;
    var description = values['description'] as String?;
    if (articleId != null) {
      description ??= articles.firstWhere((a) => a.id == articleId).name;
      price ??= (await _client.articlePrices(articleId)).where((p) => p.supplierId == order.supplierId).firstOrNull?.purchasePriceCents;
    }
    if (description == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Beschreibung oder Artikel ist Pflicht.')));
      return;
    }
    await _saveItems([
      ...order.items,
      OnlinePurchaseOrderItem(articleId: articleId, description: description, quantity: values['quantity'] as String, purchasePriceCents: price),
    ]);
  }

  /// Nur online: Lieferant und Hinweis an den Lieferanten ändern.
  Future<void> _editHeader() async {
    final order = _order!;
    final suppliers = await _client.suppliers();
    if (!mounted) return;
    final values = await showOnlineForm(
      context,
      title: 'Bestellung',
      fields: [
        OnlineField('supplierId', 'Lieferant', type: OnlineFieldType.choice, required: true, initial: order.supplierId,
            options: {for (final s in suppliers) s.id: s.name}),
        OnlineField('notes', 'Hinweis an den Lieferanten', type: OnlineFieldType.multiline, initial: order.notes),
      ],
    );
    if (values == null || !mounted) return;
    await runOnline(context, () async {
      await _apply(await _client.updatePurchaseOrder(
        order,
        items: order.items,
        supplierId: values['supplierId'] as String,
        notes: values['notes'] as String?,
        projectId: order.projectId,
        expenseCategoryId: order.expenseCategoryId,
      ));
    });
  }

  /// Wie offline: Projekt, Beleg-Kategorie und Auftrag/Rechnung in einem
  /// Dialog, alle optional — ohne jede Zuordnung gilt die Bestellung als
  /// Lagerbestellung.
  Future<void> _editAssignment() async {
    final order = _order!;
    final session = widget.session;
    var projects = const <OnlineProject>[];
    var categories = const <OnlineExpenseCategory>[];
    var documents = const <OnlineDocument>[];
    final loaded = await runOnline(context, () async {
      if (session.modules.contains('projects') && session.can('projects.read')) projects = await _client.projects();
      if (session.modules.contains('buchhaltung') && session.can('accounting.read')) {
        categories = await _client.expenseCategories();
      }
      if (session.can('invoices.read')) {
        documents = [
          if (session.modules.contains('orders')) ...await _client.documents(kind: 'order', status: 'finalized'),
          ...await _client.documents(kind: 'invoice', status: 'finalized'),
        ];
      }
    });
    if (!loaded || !mounted) return;
    if (projects.isEmpty && categories.isEmpty && documents.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Keine Projekte, Beleg-Kategorien oder finalisierten Dokumente vorhanden.')),
      );
      return;
    }
    final values = await showOnlineForm(
      context,
      title: 'Zuordnung',
      fields: [
        if (projects.isNotEmpty)
          OnlineField('projectId', 'Projekt', type: OnlineFieldType.choice, initial: order.projectId,
              options: {null: '— keines —', for (final p in projects) p.id: p.name}),
        if (categories.isNotEmpty)
          OnlineField('expenseCategoryId', 'Beleg-Kategorie (SKR03)', type: OnlineFieldType.choice, initial: order.expenseCategoryId,
              options: {null: '— ohne Kategorie —', for (final c in categories) c.id: c.label}),
        if (documents.isNotEmpty)
          OnlineField('sourceOrderId', 'Auftrag/Rechnung', type: OnlineFieldType.choice,
              initial: documents.any((d) => d.id == order.sourceOrderId) ? order.sourceOrderId : null,
              options: {
                null: '— keines —',
                for (final d in documents) d.id: '${d.number ?? d.id}${d.displayCustomerName == null ? '' : ' · ${d.displayCustomerName}'}',
              }),
      ],
    );
    if (values == null || !mounted) return;
    await runOnline(context, () async {
      await _apply(await _client.updatePurchaseOrder(
        order,
        items: order.items,
        notes: order.notes,
        projectId: values.containsKey('projectId') ? values['projectId'] as String? : order.projectId,
        expenseCategoryId: values.containsKey('expenseCategoryId') ? values['expenseCategoryId'] as String? : order.expenseCategoryId,
        sourceOrderId: values.containsKey('sourceOrderId') ? () => values['sourceOrderId'] as String? : null,
      ));
    });
  }

  Future<void> _finalize() async {
    if (!await confirmOnline(
      context,
      'Bestellung finalisieren?',
      'Vergibt die nächste Bestellnummer und macht die Bestellung unveränderlich.',
      confirm: 'Finalisieren',
    )) {
      return;
    }
    if (!mounted) return;
    await runOnline(context, () async {
      final updated = await _client.finalizePurchaseOrder(_order!);
      await _apply(updated);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Finalisiert als ${updated.number}.')));
      }
    });
  }

  /// Wie offline: je offener Position die **zusätzlich** eingegangene
  /// Menge, leer = nichts gebucht.
  Future<void> _receive() async {
    final order = _order!;
    String open(OnlinePurchaseOrderItem i) => (Decimal.parse(i.quantity) - Decimal.parse(i.receivedQuantity)).toString();
    final values = await showOnlineForm(
      context,
      title: 'Wareneingang erfassen',
      submitLabel: 'Buchen',
      fields: [
        for (final i in order.items)
          if (Decimal.parse(i.quantity) > Decimal.parse(i.receivedQuantity))
            OnlineField(i.id!, i.description, type: OnlineFieldType.decimal, helper: 'offen: ${formatQuantity(open(i))}'),
      ],
    );
    if (values == null || !mounted) return;
    final receipts = <String, String>{
      for (final e in values.entries)
        if (e.value != null && Decimal.parse(e.value as String) > Decimal.zero) e.key: e.value as String,
    };
    if (receipts.isEmpty) return;
    await runOnline(context, () async {
      await _apply(await _client.receivePurchaseOrder(order.id, receipts));
    }, success: 'Wareneingang gebucht.');
  }

  Future<Uint8List> _buildPdf(OnlinePurchaseOrder order, OnlineCompanyProfile company) =>
      buildPurchaseOrderPdfFromData(PurchaseOrderPdfData(
              number: order.number!,
              issueDate: order.issueDate,
              notes: order.notes,
              supplierName: order.supplierName ?? '',
              supplierAddress: order.supplierAddress,
              companyName: widget.session.companyName,
              companyAddress: company.address,
              companyEmail: company.email,
              companyPhone: company.phone,
              items: [
                for (final i in order.items)
                  (description: i.description, quantity: Decimal.parse(i.quantity), purchasePriceCents: i.purchasePriceCents),
              ],
            ));

  Future<void> _pdf() async {
    final order = _order!;
    final company = await _client.companyProfile();
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(title: Text(order.number!)),
          body: PdfPreview(
            canChangeOrientation: false,
            canChangePageFormat: false,
            pdfFileName: '${order.number}.pdf',
            build: (_) => _buildPdf(order, company),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final order = _order;
    final editable = order != null && order.isDraft && _canWrite;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bestellung'),
        actions: [
          // Nur online: Mailversand, Lieferant/Hinweis ändern, Entwurf löschen.
          if (order != null && !order.isDraft && _canWrite && canSendMail(widget.session))
            IconButton(
              tooltip: 'Per E-Mail senden',
              icon: const Icon(Icons.mail_outline),
              onPressed: () => sendPdfByMail(
                context,
                session: widget.session,
                title: 'Bestellung ${order.number} senden',
                defaultRecipientHint: 'Leer = E-Mail des Lieferanten',
                buildPdf: () async => _buildPdf(order, await _client.companyProfile()),
                send: (pdf, {to, subject, body}) => _client.sendPurchaseOrderMail(order.id, pdf, to: to),
              ),
            ),
          if (editable) IconButton(tooltip: 'Lieferant/Hinweis ändern', icon: const Icon(Icons.edit_outlined), onPressed: _editHeader),
          if (editable)
            IconButton(
              tooltip: 'Entwurf löschen',
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                if (!await confirmOnline(context, 'Entwurf löschen?', 'Die Bestellung wird entfernt.')) return;
                if (!context.mounted) return;
                if (await runOnline(context, () => _client.deletePurchaseOrder(order.id)) && context.mounted) {
                  Navigator.of(context).pop();
                }
              },
            ),
        ],
      ),
      body: _error != null
          ? Center(child: Text(describeOnlineError(_error!)))
          : order == null
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
                  children: [
                    Text(order.number ?? 'Entwurf', style: theme.textTheme.headlineSmall),
                    Text('${order.supplierName ?? ''} · ${purchaseOrderStatusLabels[order.status] ?? order.status}'),
                    if (order.notes != null) Text(order.notes!, style: theme.textTheme.bodySmall),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            () {
                              final parts = [
                                if (_projectName != null) 'Projekt: $_projectName',
                                if (_categoryLabel != null) 'Kategorie: $_categoryLabel',
                                if (order.sourceOrderId != null) 'Dokument: ${order.sourceOrderNumber ?? '–'}',
                              ];
                              return parts.isEmpty ? 'Keine Zuordnung (Lagerbestellung)' : parts.join(' · ');
                            }(),
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                        if (editable) TextButton(onPressed: _editAssignment, child: const Text('Zuordnung bearbeiten')),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Positionen', style: theme.textTheme.titleMedium),
                        if (editable)
                          TextButton.icon(onPressed: _addItem, icon: const Icon(Icons.add), label: const Text('Position hinzufügen')),
                      ],
                    ),
                    if (order.items.isEmpty) const Text('Noch keine Positionen.'),
                    for (final (index, i) in order.items.indexed)
                      Card(
                        child: ListTile(
                          title: Text(i.description),
                          subtitle: Text([
                            order.isDraft
                                ? 'Menge: ${formatQuantity(i.quantity)}'
                                : 'Menge: ${formatQuantity(i.quantity)} · erhalten: ${formatQuantity(i.receivedQuantity)}',
                            if (i.purchasePriceCents != null) 'je ${Money.fromCents(i.purchasePriceCents!)}',
                          ].join(' · ')),
                          trailing: editable
                              ? IconButton(
                                  tooltip: 'Position entfernen',
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: () => _saveItems([...order.items]..removeAt(index)),
                                )
                              : null,
                        ),
                      ),
                    if (order.items.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4, right: 8),
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Text('Summe netto: ${Money.fromCents(order.totalNetCents)}', style: theme.textTheme.bodySmall),
                        ),
                      ),
                    const SizedBox(height: 24),
                    if (order.isDraft && _canWrite)
                      FilledButton(onPressed: order.items.isEmpty ? null : _finalize, child: const Text('Finalisieren')),
                    if (!order.isDraft) ...[
                      OutlinedButton.icon(
                        onPressed: _pdf,
                        icon: const Icon(Icons.picture_as_pdf_outlined),
                        label: const Text('PDF teilen'),
                      ),
                      const SizedBox(height: 8),
                      if (order.canReceive && _canWrite)
                        OutlinedButton.icon(
                          onPressed: _receive,
                          icon: const Icon(Icons.inventory_outlined),
                          label: const Text('Wareneingang erfassen'),
                        ),
                    ],
                  ],
                ),
    );
  }
}

/// Aus einem finalisierten Auftrag Bestellentwürfe erzeugen (Dialog im
/// Dokument-Screen).
Future<void> createPurchaseOrdersFromDocument(BuildContext context, OnlineSession session, String documentId) async {
  final suppliers = await session.client.suppliers();
  if (!context.mounted) return;
  final values = await showOnlineForm(
    context,
    title: 'Bestellungen erzeugen',
    submitLabel: 'Erzeugen',
    fields: [
      const OnlineField(
        'mode',
        'Verfahren',
        type: OnlineFieldType.choice,
        required: true,
        initial: 'cheapest',
        options: {'cheapest': 'Je Artikel günstigster Lieferant', 'oneSupplier': 'Alles über einen Lieferanten'},
      ),
      OnlineField('supplierId', 'Lieferant (nur „alles über einen“)', type: OnlineFieldType.choice, options: {for (final s in suppliers) s.id: s.name}),
    ],
  );
  if (values == null || !context.mounted) return;
  await runOnline(context, () async {
    final result = await session.client.purchaseOrdersFromDocument(
      documentId,
      mode: values['mode'] as String,
      supplierId: values['supplierId'] as String?,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text([
        '${result.ids.length} Bestellentwurf/-entwürfe angelegt',
        if (result.unassignable.isNotEmpty) 'ohne Einkaufspreis: ${result.unassignable.join(', ')}',
      ].join(' · ')),
      duration: const Duration(seconds: 6),
    ));
  });
}
