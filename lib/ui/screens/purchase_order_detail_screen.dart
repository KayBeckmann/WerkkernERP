import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../../data/database/database.dart';
import '../../data/database/tables.dart';
import '../../data/repositories/article_repository.dart';
import '../../data/repositories/purchase_order_repository.dart';
import '../../domain/services/active_company_service.dart';
import '../../pdf/purchase_order_pdf_builder.dart';

/// Bestellungsdetail (C5.2 Bestellwesen, Nachtrag 2026-10-19) —
/// Positionen bearbeiten (nur im Entwurf), Finalisieren, PDF teilen und
/// Wareneingang erfassen (auch als Teillieferung).
class PurchaseOrderDetailScreen extends StatefulWidget {
  const PurchaseOrderDetailScreen({super.key, required this.purchaseOrderId});
  final String purchaseOrderId;

  @override
  State<PurchaseOrderDetailScreen> createState() => _PurchaseOrderDetailScreenState();
}

class _PurchaseOrderDetailScreenState extends State<PurchaseOrderDetailScreen> {
  late Future<_DetailData> _future;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_DetailData> _load() async {
    final companyId = context.read<ActiveCompanyService>().active!.id;
    final repo = context.read<PurchaseOrderRepository>();
    final order = await repo.findById(companyId: companyId, id: widget.purchaseOrderId);
    final items = order == null ? <PurchaseOrderItem>[] : await repo.itemsFor(order.id);
    return _DetailData(order: order, items: items);
  }

  void _reload() => setState(() => _future = _load());

  Future<void> _editItems(PurchaseOrder order, List<PurchaseOrderItem> items) async {
    final companyId = context.read<ActiveCompanyService>().active!.id;
    final articles = await context.read<ArticleRepository>().listForCompany(companyId);
    if (!mounted) return;
    final result = await showDialog<List<PurchaseOrderItemInput>>(
      context: context,
      builder: (context) => _PurchaseOrderItemsEditorDialog(
        articles: articles,
        articleRepository: context.read<ArticleRepository>(),
        supplierId: order.supplierId,
        initialItems: [
          for (final item in items)
            PurchaseOrderItemInput(
              id: item.id,
              articleId: item.articleId,
              description: item.description,
              quantity: item.quantity,
              purchasePriceCents: item.purchasePriceCents,
            ),
        ],
      ),
    );
    if (result == null || !mounted) return;
    await context.read<PurchaseOrderRepository>().updateDraft(
          companyId: companyId,
          id: order.id,
          items: result,
        );
    _reload();
  }

  Future<void> _finalize(PurchaseOrder order) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Bestellung finalisieren?'),
        content: const Text(
          'Die Bestellung bekommt eine Nummer und ist danach nicht mehr änderbar. Diese Aktion ist '
          'nicht umkehrbar.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Abbrechen')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Finalisieren')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      final companyId = context.read<ActiveCompanyService>().active!.id;
      final finalized = await context
          .read<PurchaseOrderRepository>()
          .finalize(companyId: companyId, id: order.id);
      if (!mounted) return;
      if (finalized == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Finalisierung nicht möglich (bereits finalisiert?).')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Finalisiert als ${finalized.orderNumber}.')),
        );
      }
    } on StateError catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
      _reload();
    }
  }

  Future<void> _sharePdf(PurchaseOrder order, List<PurchaseOrderItem> items) async {
    try {
      final company = context.read<ActiveCompanyService>().active!;
      final bytes = await buildPurchaseOrderPdf(order: order, items: items, company: company);
      await Printing.sharePdf(bytes: bytes, filename: '${order.orderNumber}.pdf');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PDF konnte nicht erstellt/geteilt werden. Bitte erneut versuchen.')),
        );
      }
    }
  }

  Future<void> _receiveGoods(PurchaseOrder order, List<PurchaseOrderItem> items) async {
    final receipts = await showDialog<Map<String, double>>(
      context: context,
      builder: (context) => _ReceiveGoodsDialog(items: items),
    );
    if (receipts == null || receipts.isEmpty || !mounted) return;
    try {
      final companyId = context.read<ActiveCompanyService>().active!.id;
      await context
          .read<PurchaseOrderRepository>()
          .receiveGoods(companyId: companyId, id: order.id, receipts: receipts);
    } on StateError catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
    _reload();
  }

  String _statusLabel(PurchaseOrderStatus status) => switch (status) {
        PurchaseOrderStatus.draft => 'Entwurf',
        PurchaseOrderStatus.finalized => 'Finalisiert',
        PurchaseOrderStatus.partiallyReceived => 'Teilweise erhalten',
        PurchaseOrderStatus.fullyReceived => 'Vollständig erhalten',
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bestellung')),
      body: FutureBuilder<_DetailData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final order = snapshot.data!.order;
          if (order == null) {
            return const Center(child: Text('Bestellung nicht gefunden.'));
          }
          final items = snapshot.data!.items;
          final isDraft = order.status == PurchaseOrderStatus.draft;
          final canReceiveGoods = order.status == PurchaseOrderStatus.finalized ||
              order.status == PurchaseOrderStatus.partiallyReceived;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
            children: [
              Text(
                order.orderNumber ?? 'Entwurf',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              Text('${order.supplierSnapshotName ?? ''} · ${_statusLabel(order.status)}'),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Positionen', style: Theme.of(context).textTheme.titleMedium),
                  if (isDraft)
                    TextButton.icon(
                      onPressed: () => _editItems(order, items),
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Bearbeiten'),
                    ),
                ],
              ),
              if (items.isEmpty) const Text('Noch keine Positionen.'),
              for (final item in items)
                Card(
                  child: ListTile(
                    title: Text(item.description),
                    subtitle: Text(
                      isDraft
                          ? 'Menge: ${_formatQuantity(item.quantity)}'
                          : 'Menge: ${_formatQuantity(item.quantity)} · erhalten: '
                              '${_formatQuantity(item.receivedQuantity)}',
                    ),
                  ),
                ),
              const SizedBox(height: 24),
              if (isDraft)
                FilledButton(
                  onPressed: _busy || items.isEmpty ? null : () => _finalize(order),
                  child: const Text('Finalisieren'),
                ),
              if (!isDraft) ...[
                OutlinedButton.icon(
                  onPressed: () => _sharePdf(order, items),
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: const Text('PDF teilen'),
                ),
                const SizedBox(height: 8),
                if (canReceiveGoods)
                  OutlinedButton.icon(
                    onPressed: () => _receiveGoods(order, items),
                    icon: const Icon(Icons.inventory_outlined),
                    label: const Text('Wareneingang erfassen'),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}

String _formatQuantity(double value) =>
    value == value.roundToDouble() ? value.toStringAsFixed(0) : value.toString();

class _DetailData {
  const _DetailData({required this.order, required this.items});
  final PurchaseOrder? order;
  final List<PurchaseOrderItem> items;
}

/// Dialog zum Erfassen eines Wareneingangs — ein Eingabefeld je Position
/// für die **zusätzlich** eingegangene Menge (additiv, siehe Doc-
/// Kommentar bei `PurchaseOrderRepository.receiveGoods`), vorausgefüllt
/// mit der noch offenen Restmenge als Platzhalter.
class _ReceiveGoodsDialog extends StatefulWidget {
  const _ReceiveGoodsDialog({required this.items});
  final List<PurchaseOrderItem> items;

  @override
  State<_ReceiveGoodsDialog> createState() => _ReceiveGoodsDialogState();
}

class _ReceiveGoodsDialogState extends State<_ReceiveGoodsDialog> {
  late final Map<String, TextEditingController> _controllers = {
    for (final item in widget.items) item.id: TextEditingController(),
  };

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Wareneingang erfassen'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final item in widget.items)
                if (item.receivedQuantity < item.quantity)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: TextField(
                      controller: _controllers[item.id],
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: item.description,
                        hintText: 'offen: ${_formatQuantity(item.quantity - item.receivedQuantity)}',
                      ),
                    ),
                  ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
        FilledButton(
          onPressed: () {
            final receipts = <String, double>{};
            for (final entry in _controllers.entries) {
              final text = entry.value.text.trim().replaceAll(',', '.');
              if (text.isEmpty) continue;
              final value = double.tryParse(text);
              if (value != null && value > 0) receipts[entry.key] = value;
            }
            Navigator.pop(context, receipts);
          },
          child: const Text('Buchen'),
        ),
      ],
    );
  }
}

/// Positionen-Editor eines Bestellungsentwurfs — ähnliches Muster wie
/// `ArticleFormDialog`, aber für eine ganze Liste statt eines einzelnen
/// Datensatzes. Ein Artikel aus der Dropdown-Auswahl füllt Beschreibung
/// und (falls beim gewählten Lieferanten hinterlegt) den Einkaufspreis
/// automatisch vor — beides danach frei editierbar.
class _PurchaseOrderItemsEditorDialog extends StatefulWidget {
  const _PurchaseOrderItemsEditorDialog({
    required this.articles,
    required this.articleRepository,
    required this.supplierId,
    required this.initialItems,
  });
  final List<Article> articles;
  final ArticleRepository articleRepository;
  final String supplierId;
  final List<PurchaseOrderItemInput> initialItems;

  @override
  State<_PurchaseOrderItemsEditorDialog> createState() => _PurchaseOrderItemsEditorDialogState();
}

class _PurchaseOrderItemsEditorDialogState extends State<_PurchaseOrderItemsEditorDialog> {
  late List<PurchaseOrderItemInput> _items = List.of(widget.initialItems);

  Future<void> _addItem() async {
    final input = await showDialog<PurchaseOrderItemInput>(
      context: context,
      builder: (context) => _PurchaseOrderItemDialog(
        articles: widget.articles,
        articleRepository: widget.articleRepository,
        supplierId: widget.supplierId,
      ),
    );
    if (input == null) return;
    setState(() => _items = [..._items, input]);
  }

  void _removeAt(int index) => setState(() {
        final next = List.of(_items);
        next.removeAt(index);
        _items = next;
      });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Positionen'),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 300,
              child: _items.isEmpty
                  ? const Center(child: Text('Noch keine Positionen.'))
                  : ListView.builder(
                      itemCount: _items.length,
                      itemBuilder: (context, index) {
                        final item = _items[index];
                        return ListTile(
                          title: Text(item.description),
                          subtitle: Text(
                            'Menge: ${_formatQuantity(item.quantity)}'
                            '${item.purchasePriceCents == null ? '' : ' · ${(item.purchasePriceCents! / 100).toStringAsFixed(2)} €'}',
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => _removeAt(index),
                          ),
                        );
                      },
                    ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _addItem,
                icon: const Icon(Icons.add),
                label: const Text('Position hinzufügen'),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
        FilledButton(
          onPressed: () => Navigator.pop(context, _items),
          child: const Text('Speichern'),
        ),
      ],
    );
  }
}

class _PurchaseOrderItemDialog extends StatefulWidget {
  const _PurchaseOrderItemDialog({
    required this.articles,
    required this.articleRepository,
    required this.supplierId,
  });
  final List<Article> articles;
  final ArticleRepository articleRepository;
  final String supplierId;

  @override
  State<_PurchaseOrderItemDialog> createState() => _PurchaseOrderItemDialogState();
}

class _PurchaseOrderItemDialogState extends State<_PurchaseOrderItemDialog> {
  Article? _article;
  final _descriptionCtrl = TextEditingController();
  final _quantityCtrl = TextEditingController(text: '1');
  final _priceCtrl = TextEditingController();

  @override
  void dispose() {
    _descriptionCtrl.dispose();
    _quantityCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  Future<void> _onArticleSelected(Article? article) async {
    setState(() => _article = article);
    if (article == null) return;
    _descriptionCtrl.text = article.name;
    final prices = await widget.articleRepository.supplierPricesFor(article.id);
    final match = prices.where((p) => p.supplierId == widget.supplierId).toList();
    if (match.isNotEmpty && mounted) {
      setState(() => _priceCtrl.text = (match.first.purchasePriceCents / 100).toStringAsFixed(2));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Position hinzufügen'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<Article?>(
              isExpanded: true,
              initialValue: _article,
              decoration: const InputDecoration(labelText: 'Artikel (optional)'),
              items: [
                const DropdownMenuItem<Article?>(value: null, child: Text('— frei —')),
                for (final article in widget.articles)
                  DropdownMenuItem(value: article, child: Text(article.name)),
              ],
              onChanged: _onArticleSelected,
            ),
            TextField(
              controller: _descriptionCtrl,
              decoration: const InputDecoration(labelText: 'Beschreibung *'),
            ),
            TextField(
              controller: _quantityCtrl,
              decoration: const InputDecoration(labelText: 'Menge *'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            TextField(
              controller: _priceCtrl,
              decoration: const InputDecoration(labelText: 'Einkaufspreis je Einheit (€)'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
        FilledButton(
          onPressed: () {
            final description = _descriptionCtrl.text.trim();
            final quantity = double.tryParse(_quantityCtrl.text.trim().replaceAll(',', '.'));
            if (description.isEmpty || quantity == null || quantity <= 0) return;
            final priceText = _priceCtrl.text.trim().replaceAll(',', '.');
            final priceEuro = priceText.isEmpty ? null : double.tryParse(priceText);
            Navigator.pop(
              context,
              PurchaseOrderItemInput(
                articleId: _article?.id,
                description: description,
                quantity: quantity,
                purchasePriceCents: priceEuro == null ? null : (priceEuro * 100).round(),
              ),
            );
          },
          child: const Text('Hinzufügen'),
        ),
      ],
    );
  }
}
