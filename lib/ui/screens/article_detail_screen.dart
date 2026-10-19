import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/database/database.dart';
import '../../data/database/tables.dart';
import '../../data/repositories/article_group_repository.dart';
import '../../data/repositories/article_repository.dart';
import '../../data/repositories/inventory_repository.dart';
import '../../data/repositories/supplier_repository.dart';
import '../../domain/models/money.dart';
import '../../domain/services/active_company_service.dart';
import '../../domain/services/stock_change_notifier.dart';
import 'articles_screen.dart' show ArticleFormDialog, ArticleFormResult, formatArticleQuantity;

/// Lieferanten-Einkaufspreise eines Artikels verwalten (A1:
/// Mehrlieferanten-Preise), den kalkulierten Verkaufspreis anzeigen —
/// und seit dem Nachtrag 2026-10-18 ("Artikel können nicht nachträglich
/// bearbeitet werden") auch die Artikelstammdaten selbst bearbeiten
/// bzw. den Artikel deaktivieren/reaktivieren.
class ArticleDetailScreen extends StatefulWidget {
  const ArticleDetailScreen({super.key, required this.article});

  final Article article;

  @override
  State<ArticleDetailScreen> createState() => _ArticleDetailScreenState();
}

class _ArticleDetailScreenState extends State<ArticleDetailScreen> {
  late Article _article;
  late Future<_DetailData> _future;
  bool _busy = false;
  bool _lagerbestandEnabled = false;

  /// Bugfix 2026-10-19 (Kay: "Wenn ich den Bestand aus einer Bestellung
  /// buche, wird dieser nicht angezeigt") — siehe ausführlicher Doc-
  /// Kommentar bei `_ArticlesScreenState._onStockChanged` für die
  /// Begründung (ChangeNotifier statt Drift-`.watch()`-Stream). Lädt
  /// [_article] hier per einmaligem `findById()` neu statt reaktiv zu
  /// streamen — reicht aus, weil der Ping ohnehin erst NACH der
  /// abgeschlossenen Buchung ausgelöst wird.
  Future<void> _onStockChanged() async {
    final companyId = context.read<ActiveCompanyService>().active!.id;
    final reloaded = await context.read<ArticleRepository>().findById(
          companyId: companyId,
          id: _article.id,
        );
    if (mounted && reloaded != null) setState(() => _article = reloaded);
  }

  /// Referenz gemerkt statt in `dispose()` erneut per `context.read()`
  /// zu holen — siehe gleichlautende Doc-Notiz bei
  /// `_ArticlesScreenState._stockChangeNotifier`.
  late StockChangeNotifier _stockChangeNotifier;

  @override
  void initState() {
    super.initState();
    _article = widget.article;
    _lagerbestandEnabled = context.read<ActiveCompanyService>().active!.lagerbestandEnabled;
    _future = _load();
    _stockChangeNotifier = context.read<StockChangeNotifier>()..addListener(_onStockChanged);
  }

  @override
  void dispose() {
    _stockChangeNotifier.removeListener(_onStockChanged);
    super.dispose();
  }

  Future<_DetailData> _load() async {
    final companyId = context.read<ActiveCompanyService>().active!.id;
    final articleRepo = context.read<ArticleRepository>();
    final supplierRepo = context.read<SupplierRepository>();
    final groupRepo = context.read<ArticleGroupRepository>();
    final prices = await articleRepo.supplierPricesFor(_article.id);
    final suppliers = await supplierRepo.listForCompany(companyId);
    final groups = await groupRepo.listForCompany(companyId);
    final salePrice = await articleRepo.effectiveSalePrice(
      companyId: companyId,
      articleId: _article.id,
    );
    return _DetailData(prices: prices, suppliers: suppliers, groups: groups, salePrice: salePrice);
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
          articleId: _article.id,
          supplierId: result.supplierId,
          purchasePriceCents: result.cents,
        );
    _reload();
  }

  Future<void> _edit(List<ArticleGroup> groups, List<Supplier> suppliers) async {
    final result = await showDialog<ArticleFormResult>(
      context: context,
      builder: (context) => ArticleFormDialog(
        groups: groups,
        suppliers: suppliers,
        lagerbestandEnabled: _lagerbestandEnabled,
        existing: _article,
      ),
    );
    if (result == null || !mounted) return;
    final companyId = context.read<ActiveCompanyService>().active!.id;
    final updated = await context.read<ArticleRepository>().update(
          companyId: companyId,
          id: _article.id,
          name: result.name,
          unit: Value(result.unit),
          articleGroupId: Value(result.articleGroupId),
          defaultSupplierId: Value(result.defaultSupplierId),
          minimumStock: Value(result.minimumStock),
        );
    if (updated == null || !mounted) return;
    setState(() => _article = updated);
    _reload();
  }

  /// C5.1 Lagerbestand (Nachtrag 2026-10-19) — Bestandskorrektur
  /// (Inventur, Anfangsbestand) als eigener, expliziter Vorgang,
  /// getrennt vom normalen Bearbeiten-Dialog. Seit C5.3 (Nachtrag
  /// 2026-10-19: "Das muss alles dokumentiert werden, damit es dem
  /// Finanzamt sauber gezeigt werden kann") läuft das **nicht** mehr
  /// über das grundlose `ArticleRepository.setStock()`, sondern über
  /// `InventoryRepository.correctSingleArticleStock()` — ein Ein-
  /// Artikel-Inventurlauf mit Pflicht-Grund, der eine unveränderliche
  /// [StockMovement]-Zeile erzeugt (siehe Doc-Kommentar dort).
  Future<void> _correctStock() async {
    final result = await showDialog<_StockCorrectionResult>(
      context: context,
      builder: (context) => _StockCorrectionDialog(currentQuantity: _article.stockQuantity),
    );
    if (result == null || !mounted) return;
    final companyId = context.read<ActiveCompanyService>().active!.id;
    final updated = await context.read<InventoryRepository>().correctSingleArticleStock(
          companyId: companyId,
          articleId: _article.id,
          newQuantity: result.quantity,
          reason: result.reason,
        );
    if (updated == null || !mounted) return;
    setState(() => _article = updated);
    context.read<StockChangeNotifier>().notifyStockChanged();
  }

  /// C5.3 (Nachtrag 2026-10-19) — zeigt das Bewegungsprotokoll dieses
  /// Artikels (siehe `InventoryRepository.movementsForArticle()`), rein
  /// lesend.
  Future<void> _showMovements() async {
    final companyId = context.read<ActiveCompanyService>().active!.id;
    final movements = await context.read<InventoryRepository>().movementsForArticle(
          companyId: companyId,
          articleId: _article.id,
        );
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => _StockMovementsDialog(articleName: _article.name, movements: movements),
    );
  }

  Future<void> _toggleActive() async {
    setState(() => _busy = true);
    try {
      final companyId = context.read<ActiveCompanyService>().active!.id;
      final nextActive = !_article.active;
      await context.read<ArticleRepository>().setActive(
            companyId: companyId,
            id: _article.id,
            active: nextActive,
          );
      if (mounted) setState(() => _article = _article.copyWith(active: nextActive));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_article.active ? _article.name : '${_article.name} (deaktiviert)'),
        actions: [
          FutureBuilder<_DetailData>(
            future: _future,
            builder: (context, snapshot) => IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Bearbeiten',
              onPressed: snapshot.hasData
                  ? () => _edit(snapshot.data!.groups, snapshot.data!.suppliers)
                  : null,
            ),
          ),
          IconButton(
            icon: Icon(_article.active ? Icons.block_outlined : Icons.check_circle_outline),
            tooltip: _article.active ? 'Deaktivieren' : 'Aktivieren',
            onPressed: _busy ? null : _toggleActive,
          ),
        ],
      ),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.salePrice == null
                          ? 'Verkaufspreis: unbekannt (kein Standardlieferant/Einkaufspreis)'
                          : 'Kalkulierter Netto-Verkaufspreis: ${data.salePrice}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (_lagerbestandEnabled) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Lagerbestand: ${formatArticleQuantity(_article.stockQuantity)}'
                              '${_article.minimumStock == null ? '' : ' (Mindestbestand: ${formatArticleQuantity(_article.minimumStock!)})'}',
                              style: TextStyle(
                                color: _article.minimumStock != null &&
                                        _article.stockQuantity < _article.minimumStock!
                                    ? Theme.of(context).colorScheme.error
                                    : null,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: _showMovements,
                            child: const Text('Bewegungen'),
                          ),
                          TextButton(
                            onPressed: _correctStock,
                            child: const Text('Bestand korrigieren'),
                          ),
                        ],
                      ),
                    ],
                  ],
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
                          final isDefault = price.supplierId == _article.defaultSupplierId;
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
  const _DetailData({
    required this.prices,
    required this.suppliers,
    required this.groups,
    required this.salePrice,
  });
  final List<ArticleSupplierPrice> prices;
  final List<Supplier> suppliers;
  final List<ArticleGroup> groups;
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

class _StockCorrectionResult {
  const _StockCorrectionResult({required this.quantity, required this.reason});
  final double quantity;
  final String reason;
}

/// C5.1 Lagerbestand (Nachtrag 2026-10-19) — setzt den Lagerbestand
/// absolut neu (Inventur, Anfangsbestand). Seit C5.3 (Nachtrag
/// 2026-10-19: "Das muss alles dokumentiert werden") mit **Pflicht-
/// Grund** — läuft über `InventoryRepository.
/// correctSingleArticleStock()`, siehe Doc-Kommentar dort.
class _StockCorrectionDialog extends StatefulWidget {
  const _StockCorrectionDialog({required this.currentQuantity});
  final double currentQuantity;

  @override
  State<_StockCorrectionDialog> createState() => _StockCorrectionDialogState();
}

class _StockCorrectionDialogState extends State<_StockCorrectionDialog> {
  late final TextEditingController _quantityCtrl;
  final _reasonCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _quantityCtrl = TextEditingController(text: formatArticleQuantity(widget.currentQuantity));
  }

  @override
  void dispose() {
    _quantityCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Bestand korrigieren'),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Setzt den Lagerbestand auf den eingegebenen Wert (für Inventur, Anfangsbestand '
              'oder eine Korrektur außerhalb von Bestellungen/Dokumenten). Wird mit Grund im '
              'Bewegungsprotokoll dokumentiert.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _quantityCtrl,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Neuer Lagerbestand *'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
            ),
            TextField(
              controller: _reasonCtrl,
              decoration: const InputDecoration(labelText: 'Grund *', hintText: 'z. B. "Inventur 10/2026"'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
        FilledButton(
          onPressed: () {
            final value = double.tryParse(_quantityCtrl.text.trim().replaceAll(',', '.'));
            final reason = _reasonCtrl.text.trim();
            if (value == null || reason.isEmpty) return;
            Navigator.pop(context, _StockCorrectionResult(quantity: value, reason: reason));
          },
          child: const Text('Speichern'),
        ),
      ],
    );
  }
}

/// C5.3 (Nachtrag 2026-10-19) — rein lesende Anzeige des
/// Bewegungsprotokolls eines Artikels.
class _StockMovementsDialog extends StatelessWidget {
  const _StockMovementsDialog({required this.articleName, required this.movements});
  final String articleName;
  final List<StockMovement> movements;

  String _typeLabel(StockMovementType type) => switch (type) {
        StockMovementType.documentBooking => 'Dokument',
        StockMovementType.purchaseOrderReceipt => 'Wareneingang',
        StockMovementType.inventoryCorrection => 'Inventur',
      };

  String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Bewegungen: $articleName'),
      content: SizedBox(
        width: 420,
        height: 400,
        child: movements.isEmpty
            ? const Center(child: Text('Noch keine Bewegungen.'))
            : ListView.separated(
                itemCount: movements.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final movement = movements[index];
                  final sign = movement.quantityDelta >= 0 ? '+' : '';
                  return ListTile(
                    dense: true,
                    title: Text(
                      '$sign${formatArticleQuantity(movement.quantityDelta)} '
                      '(${_typeLabel(movement.type)})',
                    ),
                    subtitle: Text(
                      [
                        _formatDate(movement.createdAt),
                        if (movement.referenceLabel != null) movement.referenceLabel!,
                        'Bestand danach: ${formatArticleQuantity(movement.resultingQuantity)}',
                      ].join(' · '),
                    ),
                  );
                },
              ),
      ),
      actions: [FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Schließen'))],
    );
  }
}
