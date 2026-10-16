import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/database/database.dart';
import '../../data/repositories/article_repository.dart';
import '../../data/repositories/supplier_repository.dart';
import '../../domain/models/money.dart';
import '../../domain/services/active_company_service.dart';

/// Lieferanten-Einkaufspreise eines Artikels verwalten (A1:
/// Mehrlieferanten-Preise) und den kalkulierten Verkaufspreis anzeigen.
class ArticleDetailScreen extends StatefulWidget {
  const ArticleDetailScreen({super.key, required this.article});

  final Article article;

  @override
  State<ArticleDetailScreen> createState() => _ArticleDetailScreenState();
}

class _ArticleDetailScreenState extends State<ArticleDetailScreen> {
  late Future<_DetailData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_DetailData> _load() async {
    final companyId = context.read<ActiveCompanyService>().active!.id;
    final articleRepo = context.read<ArticleRepository>();
    final supplierRepo = context.read<SupplierRepository>();
    final prices = await articleRepo.supplierPricesFor(widget.article.id);
    final suppliers = await supplierRepo.listForCompany(companyId);
    final salePrice = await articleRepo.effectiveSalePrice(
      companyId: companyId,
      articleId: widget.article.id,
    );
    return _DetailData(prices: prices, suppliers: suppliers, salePrice: salePrice);
  }

  void _reload() => setState(() { _future = _load(); });

  Future<void> _setPrice(List<Supplier> suppliers, List<ArticleSupplierPrice> existing) async {
    final result = await showDialog<({String supplierId, int cents})>(
      context: context,
      builder: (context) => _SetSupplierPriceDialog(suppliers: suppliers, existing: existing),
    );
    if (result == null || !mounted) return;
    final companyId = context.read<ActiveCompanyService>().active!.id;
    await context.read<ArticleRepository>().setSupplierPrice(
          companyId: companyId,
          articleId: widget.article.id,
          supplierId: result.supplierId,
          purchasePriceCents: result.cents,
        );
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.article.name)),
      body: FutureBuilder<_DetailData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data!;
          final supplierNames = {for (final s in data.suppliers) s.id: s.name};
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  data.salePrice == null
                      ? 'Verkaufspreis: unbekannt (kein Standardlieferant/Einkaufspreis)'
                      : 'Kalkulierter Netto-Verkaufspreis: ${data.salePrice}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: data.prices.isEmpty
                    ? const Center(child: Text('Noch keine Lieferantenpreise hinterlegt.'))
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
                        itemCount: data.prices.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final price = data.prices[index];
                          final isDefault = price.supplierId == widget.article.defaultSupplierId;
                          return Card(
                            child: ListTile(
                              leading: Icon(
                                isDefault ? Icons.star : Icons.local_shipping_outlined,
                                color: isDefault ? Colors.amber[700] : null,
                              ),
                              title: Text(supplierNames[price.supplierId] ?? '(unbekannt)'),
                              subtitle: isDefault ? const Text('Standardlieferant') : null,
                              trailing: Text(Money.fromCents(price.purchasePriceCents).toString()),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FutureBuilder<_DetailData>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const SizedBox.shrink();
          return FloatingActionButton.extended(
            heroTag: 'article-detail-fab',
            onPressed: () => _setPrice(snapshot.data!.suppliers, snapshot.data!.prices),
            icon: const Icon(Icons.add),
            label: const Text('Einkaufspreis setzen'),
          );
        },
      ),
    );
  }
}

class _DetailData {
  const _DetailData({required this.prices, required this.suppliers, required this.salePrice});
  final List<ArticleSupplierPrice> prices;
  final List<Supplier> suppliers;
  final Money? salePrice;
}

class _SetSupplierPriceDialog extends StatefulWidget {
  const _SetSupplierPriceDialog({required this.suppliers, required this.existing});

  final List<Supplier> suppliers;
  final List<ArticleSupplierPrice> existing;

  @override
  State<_SetSupplierPriceDialog> createState() => _SetSupplierPriceDialogState();
}

class _SetSupplierPriceDialogState extends State<_SetSupplierPriceDialog> {
  String? _supplierId;
  final _priceCtrl = TextEditingController();

  @override
  void dispose() {
    _priceCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Einkaufspreis setzen'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: _supplierId,
            decoration: const InputDecoration(labelText: 'Lieferant'),
            items: [
              for (final supplier in widget.suppliers)
                DropdownMenuItem(value: supplier.id, child: Text(supplier.name)),
            ],
            onChanged: (value) => setState(() => _supplierId = value),
          ),
          TextField(
            controller: _priceCtrl,
            decoration: const InputDecoration(labelText: 'Einkaufspreis (€)'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
        FilledButton(
          onPressed: () {
            final supplierId = _supplierId;
            if (supplierId == null || _priceCtrl.text.trim().isEmpty) return;
            final cents = Money.fromEuroString(_priceCtrl.text).cents;
            Navigator.pop(context, (supplierId: supplierId, cents: cents));
          },
          child: const Text('Speichern'),
        ),
      ],
    );
  }
}
