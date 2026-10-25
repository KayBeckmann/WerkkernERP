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

const purchaseOrderStatusLabels = {
  'draft': 'Entwurf',
  'finalized': 'bestellt',
  'partiallyReceived': 'teilweise geliefert',
  'fullyReceived': 'vollständig geliefert',
};

/// Bestellungen an Lieferanten (C5.2): Entwürfe, Bestellvorschläge aus
/// dem Unterbestand, Finalisieren mit Nummer, Wareneingang, PDF.
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erst einen Lieferanten anlegen (Artikel → Lieferanten).')));
      return;
    }
    final values = await showOnlineForm(
      context,
      title: 'Neue Bestellung',
      submitLabel: 'Anlegen',
      fields: [
        OnlineField('supplierId', 'Lieferant', type: OnlineFieldType.choice, required: true, options: {for (final s in suppliers) s.id: s.name}),
      ],
    );
    if (values == null || !context.mounted) return;
    OnlinePurchaseOrder? created;
    await runOnline(context, () async {
      created = await session.client.createPurchaseOrder(supplierId: values['supplierId'] as String);
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
      emptyText: 'Noch keine Bestellungen.',
      header: (context, items, reload) => Align(
        alignment: Alignment.centerLeft,
        child: OutlinedButton.icon(
          onPressed: () => _suggestions(context, reload),
          icon: const Icon(Icons.lightbulb_outline),
          label: const Text('Bestellvorschläge'),
        ),
      ),
      itemBuilder: (context, o, reload) => Card(
        child: ListTile(
          leading: Icon(o.isDraft ? Icons.edit_note : Icons.local_shipping_outlined),
          title: Text('${o.number ?? 'Entwurf'} · ${o.supplierName ?? ''}'),
          subtitle: Text('${formatOnlineDate(o.issueDate)} · ${purchaseOrderStatusLabels[o.status] ?? o.status}'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () async {
            await _open(context, o.id);
            reload();
          },
        ),
      ),
      floatingActionButton: canWrite
          ? (reload) => Builder(
                builder: (context) => FloatingActionButton.extended(
                  heroTag: 'online-purchasing-fab',
                  onPressed: () => _create(context, reload),
                  icon: const Icon(Icons.add),
                  label: const Text('Bestellung anlegen'),
                ),
              )
          : null,
    );
  }
}

class _SuggestionsScreen extends StatelessWidget {
  const _SuggestionsScreen({required this.session});
  final OnlineSession session;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bestellvorschläge')),
      body: FutureBuilder<({List<OnlinePurchaseSuggestion> suggestions, List<String> unassignable})>(
        future: session.client.purchaseSuggestions(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text(describeOnlineError(snapshot.error!)));
          final data = snapshot.data;
          if (data == null) return const Center(child: CircularProgressIndicator());
          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              if (data.suggestions.isEmpty) const Padding(padding: EdgeInsets.all(24), child: Center(child: Text('Kein Artikel unter Mindestbestand.'))),
              for (final s in data.suggestions)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.supplierName, style: Theme.of(context).textTheme.titleMedium),
                        for (final i in s.items) Text('${formatQuantity(i.quantity)} × ${i.description}'),
                        if (!s.meetsMinimumOrderQuantity)
                          Text(
                            'Mindestbestellmenge ${formatQuantity(s.minimumOrderQuantity!)} nicht erreicht '
                            '(${formatQuantity(s.totalQuantity)}) — vor dem Finalisieren ergänzen.',
                            style: TextStyle(color: Theme.of(context).colorScheme.error),
                          ),
                        if (session.can('purchaseOrders.write'))
                          Align(
                            alignment: Alignment.centerRight,
                            child: FilledButton(
                              onPressed: () async {
                                OnlinePurchaseOrder? created;
                                await runOnline(context, () async {
                                  created = await session.client.purchaseOrderFromSuggestion(s.supplierId);
                                });
                                if (created != null && context.mounted) {
                                  await Navigator.of(context).pushReplacement(
                                    MaterialPageRoute<void>(
                                      builder: (_) => OnlinePurchaseOrderScreen(session: session, purchaseOrderId: created!.id),
                                    ),
                                  );
                                }
                              },
                              child: const Text('Als Entwurf übernehmen'),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              if (data.unassignable.isNotEmpty)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.help_outline),
                    title: const Text('Nicht zuordenbar (kein Einkaufspreis)'),
                    subtitle: Text(data.unassignable.join(', ')),
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
      if (mounted) setState(() => _order = order);
    } on Exception catch (e) {
      if (mounted) setState(() => _error = e);
    }
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
      if (mounted) setState(() => _order = updated);
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

  Future<void> _editHeader() async {
    final order = _order!;
    final session = widget.session;
    final suppliers = await _client.suppliers();
    final projects = session.modules.contains('projects') && session.can('projects.read') ? await _client.projects() : const <OnlineProject>[];
    final categories = session.modules.contains('buchhaltung') && session.can('accounting.read')
        ? await _client.expenseCategories()
        : const <OnlineExpenseCategory>[];
    if (!mounted) return;
    final values = await showOnlineForm(
      context,
      title: 'Bestellung',
      fields: [
        OnlineField('supplierId', 'Lieferant', type: OnlineFieldType.choice, required: true, initial: order.supplierId,
            options: {for (final s in suppliers) s.id: s.name}),
        if (projects.isNotEmpty)
          OnlineField('projectId', 'Projekt', type: OnlineFieldType.choice, initial: order.projectId,
              options: {for (final p in projects) p.id: '${p.displayNumber} · ${p.name}'},
              helper: 'Der Wareneingangs-Beleg zählt als Projektkosten.'),
        if (categories.isNotEmpty)
          OnlineField('expenseCategoryId', 'Beleg-Kategorie', type: OnlineFieldType.choice, initial: order.expenseCategoryId,
              options: {for (final c in categories) c.id: c.label}),
        OnlineField('notes', 'Hinweis an den Lieferanten', type: OnlineFieldType.multiline, initial: order.notes),
      ],
    );
    if (values == null || !mounted) return;
    await runOnline(context, () async {
      final updated = await _client.updatePurchaseOrder(
        order,
        items: order.items,
        supplierId: values['supplierId'] as String,
        notes: values['notes'] as String?,
        projectId: values.containsKey('projectId') ? values['projectId'] as String? : order.projectId,
        expenseCategoryId: values.containsKey('expenseCategoryId') ? values['expenseCategoryId'] as String? : order.expenseCategoryId,
      );
      if (mounted) setState(() => _order = updated);
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
      if (mounted) setState(() => _order = updated);
    }, success: 'Bestellung finalisiert.');
  }

  Future<void> _receive() async {
    final order = _order!;
    final open = [
      for (final i in order.items)
        if (Decimal.parse(i.quantity) > Decimal.parse(i.receivedQuantity)) i,
    ];
    final values = await showOnlineForm(
      context,
      title: 'Wareneingang',
      submitLabel: 'Buchen',
      fields: [
        for (final i in open)
          OnlineField(
            i.id!,
            '${i.description} (offen ${formatQuantity((Decimal.parse(i.quantity) - Decimal.parse(i.receivedQuantity)).toString())})',
            type: OnlineFieldType.decimal,
            initial: (Decimal.parse(i.quantity) - Decimal.parse(i.receivedQuantity)).toString(),
          ),
      ],
    );
    if (values == null || !mounted) return;
    final receipts = <String, String>{
      for (final e in values.entries)
        if (e.value != null && Decimal.parse(e.value as String) > Decimal.zero) e.key: e.value as String,
    };
    if (receipts.isEmpty) return;
    await runOnline(context, () async {
      final updated = await _client.receivePurchaseOrder(order.id, receipts);
      if (mounted) setState(() => _order = updated);
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
    return Scaffold(
      appBar: AppBar(
        title: Text(order == null ? 'Bestellung' : (order.number ?? 'Bestellentwurf')),
        actions: [
          if (order != null && !order.isDraft) IconButton(tooltip: 'PDF', icon: const Icon(Icons.picture_as_pdf_outlined), onPressed: _pdf),
          if (order != null && !order.isDraft && _canWrite && canSendMail(widget.session))
            IconButton(
              tooltip: 'Per E-Mail senden',
              icon: const Icon(Icons.send_outlined),
              onPressed: () => sendPdfByMail(
                context,
                session: widget.session,
                title: 'Bestellung ${order.number} senden',
                defaultRecipientHint: 'Leer = E-Mail des Lieferanten',
                buildPdf: () async => _buildPdf(order, await _client.companyProfile()),
                send: (pdf, {to, subject, body}) => _client.sendPurchaseOrderMail(order.id, pdf, to: to),
              ),
            ),
          if (editable) IconButton(tooltip: 'Bestellung bearbeiten', icon: const Icon(Icons.edit_outlined), onPressed: _editHeader),
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
      bottomNavigationBar: order == null || !_canWrite
          ? null
          : order.isDraft
              ? SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: FilledButton(onPressed: order.items.isEmpty ? null : _finalize, child: const Text('Finalisieren')),
                  ),
                )
              : order.canReceive
                  ? SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: FilledButton.icon(onPressed: _receive, icon: const Icon(Icons.move_to_inbox), label: const Text('Wareneingang buchen')),
                      ),
                    )
                  : null,
      body: _error != null
          ? Center(child: Text(describeOnlineError(_error!)))
          : order == null
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    Card(
                      child: ListTile(
                        title: Text(order.supplierName ?? 'Lieferant'),
                        subtitle: Text([
                          formatOnlineDate(order.issueDate),
                          purchaseOrderStatusLabels[order.status] ?? order.status,
                          if (order.notes != null) order.notes!,
                        ].join(' · ')),
                        trailing: Text('${Money.fromCents(order.totalNetCents)} netto'),
                      ),
                    ),
                    Text('Positionen', style: Theme.of(context).textTheme.titleMedium),
                    if (order.items.isEmpty) const Padding(padding: EdgeInsets.all(8), child: Text('Noch keine Positionen.')),
                    for (final (index, i) in order.items.indexed)
                      Card(
                        child: ListTile(
                          title: Text(i.description),
                          subtitle: Text([
                            '${formatQuantity(i.quantity)} × ${i.purchasePriceCents == null ? '–' : Money.fromCents(i.purchasePriceCents!)}',
                            if (!order.isDraft) 'geliefert ${formatQuantity(i.receivedQuantity)}',
                          ].join(' · ')),
                          trailing: editable
                              ? IconButton(
                                  tooltip: 'Position entfernen',
                                  icon: const Icon(Icons.remove_circle_outline),
                                  onPressed: () => _saveItems([...order.items]..removeAt(index)),
                                )
                              : null,
                        ),
                      ),
                    if (editable)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(onPressed: _addItem, icon: const Icon(Icons.add), label: const Text('Position hinzufügen')),
                      ),
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
