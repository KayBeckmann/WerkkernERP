import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/database/database.dart';
import '../../data/database/tables.dart';
import '../../data/repositories/article_group_repository.dart';
import '../../data/repositories/article_repository.dart';
import '../../data/repositories/inventory_repository.dart';
import '../../data/repositories/stock_ledger.dart';
import '../../data/repositories/storage_repository.dart';
import '../../data/repositories/supplier_repository.dart';
import '../../domain/models/money.dart';
import '../../domain/services/active_company_service.dart';
import '../../domain/services/stock_change_notifier.dart';
import '../widgets/storage_bin_picker.dart';
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
  bool _isSmallBusinessExempt = false;

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
    if (mounted && reloaded != null) {
      setState(() {
        _article = reloaded;
        _future = _load();
      });
    }
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
    _isSmallBusinessExempt = context.read<ActiveCompanyService>().active!.isSmallBusinessExempt;
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
    final ledger = context.read<StockLedger>();
    final prices = await articleRepo.supplierPricesFor(_article.id);
    final suppliers = await supplierRepo.listForCompany(companyId);
    final groups = await groupRepo.listForCompany(companyId);
    final salePrice = await articleRepo.effectiveSalePrice(
      companyId: companyId,
      articleId: _article.id,
    );
    // C5.4: Platzbestände nur mit aktivem Lagermodul.
    final bins = _lagerbestandEnabled ? await ledger.binsWithLocation(companyId) : <BinEntry>[];
    final binStocks = _lagerbestandEnabled
        ? await ledger.stocksFor(companyId: companyId, articleId: _article.id)
        : <BinStock>[];
    return _DetailData(
      prices: prices,
      suppliers: suppliers,
      groups: groups,
      salePrice: salePrice,
      bins: bins,
      binStocks: binStocks,
    );
  }

  void _reload() => setState(() { _future = _load(); });

  Future<void> _setPrice(List<Supplier> suppliers, List<ArticleSupplierPrice> existing, {String? supplierId}) async {
    final result = await showDialog<({String supplierId, int cents, String number})>(
      context: context,
      builder: (context) => _SetSupplierPriceDialog(suppliers: suppliers, existing: existing, initialSupplierId: supplierId),
    );
    if (result == null || !mounted) return;
    final companyId = context.read<ActiveCompanyService>().active!.id;
    await context.read<ArticleRepository>().setSupplierPrice(
          companyId: companyId,
          articleId: _article.id,
          supplierId: result.supplierId,
          purchasePriceCents: result.cents,
          supplierArticleNumber: Value(result.number),
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
    final Article? updated;
    try {
      updated = await context.read<ArticleRepository>().update(
            companyId: companyId,
            id: _article.id,
            name: result.name,
            unit: Value(result.unit),
            articleGroupId: Value(result.articleGroupId),
            defaultSupplierId: Value(result.defaultSupplierId),
            minimumStock: Value(result.minimumStock),
            barcode: Value(result.barcode),
          );
    } on BarcodeInUseException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      return;
    }
    if (updated == null || !mounted) return;
    final saved = updated;
    setState(() => _article = saved);
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

  /// C5.4: Standardplatz wählen (Vorschlag für Wareneingang/Entnahme).
  Future<void> _chooseDefaultBin(List<BinEntry> bins) async {
    String? choice = _article.defaultBinId ?? unassignedBinKey;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Standardplatz'),
        content: StatefulBuilder(
          builder: (ctx, setLocal) => StorageBinDropdown(
            key: const Key('default-bin'),
            bins: bins,
            value: choice,
            label: 'Standardplatz',
            unassignedLabel: 'Kein Standardplatz',
            onChanged: (v) => setLocal(() => choice = v),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Abbrechen')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Speichern')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final companyId = context.read<ActiveCompanyService>().active!.id;
    final binId = (choice == null || choice == unassignedBinKey) ? null : choice;
    await context.read<StorageRepository>().setDefaultBin(companyId: companyId, articleId: _article.id, binId: binId);
    if (!mounted) return;
    setState(() => _article = _article.copyWith(defaultBinId: Value(binId)));
    _reload();
  }

  /// C5.4: Menge zwischen zwei Plätzen umlagern (Gesamtbestand bleibt).
  Future<void> _transfer(List<BinEntry> bins, List<BinStock> stocks) async {
    final result = await showDialog<({String from, String to, double quantity})>(
      context: context,
      builder: (_) => _TransferDialog(
        bins: bins,
        quantities: {for (final s in stocks) s.binKey: s.quantity},
        from: stocks.where((s) => s.quantity > 0).firstOrNull?.binKey ?? unassignedBinKey,
        to: _article.defaultBinId ?? bins.firstOrNull?.bin.id,
      ),
    );
    if (result == null || !mounted) return;
    final companyId = context.read<ActiveCompanyService>().active!.id;
    await context.read<StockLedger>().transfer(
          companyId: companyId,
          articleId: _article.id,
          fromBinKey: result.from,
          toBinKey: result.to,
          quantity: result.quantity,
        );
    if (!mounted) return;
    context.read<StockChangeNotifier>().notifyStockChanged();
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
                          : _isSmallBusinessExempt
                              ? 'Kalkulierter Verkaufspreis (brutto): ${data.salePrice}'
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
                      if (data.bins.isNotEmpty) ...[
                        for (final s in data.binStocks)
                          Padding(
                            padding: const EdgeInsets.only(left: 8, top: 2),
                            child: Text(
                              '${s.label}: ${formatArticleQuantity(s.quantity)}'
                              '${s.binKey == _article.defaultBinId ? ' (Standardplatz)' : ''}',
                              style: TextStyle(
                                color: s.isUnassigned ? Theme.of(context).colorScheme.tertiary : null,
                              ),
                            ),
                          ),
                        Wrap(
                          spacing: 8,
                          children: [
                            TextButton.icon(
                              key: const Key('article-default-bin'),
                              onPressed: () => _chooseDefaultBin(data.bins),
                              icon: const Icon(Icons.push_pin_outlined, size: 18),
                              label: const Text('Standardplatz'),
                            ),
                            TextButton.icon(
                              key: const Key('article-transfer'),
                              onPressed: () => _transfer(data.bins, data.binStocks),
                              icon: const Icon(Icons.swap_horiz, size: 18),
                              label: const Text('Umlagern'),
                            ),
                          ],
                        ),
                      ],
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
                              subtitle: isDefault || price.supplierArticleNumber != null
                                  ? Text([
                                      if (isDefault) 'Standardlieferant',
                                      if (price.supplierArticleNumber != null) 'Art.-Nr. ${price.supplierArticleNumber}',
                                    ].join(' · '))
                                  : null,
                              onTap: () => _setPrice(data.suppliers, data.prices, supplierId: price.supplierId),
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
    this.bins = const [],
    this.binStocks = const [],
  });
  final List<BinEntry> bins;
  final List<BinStock> binStocks;
  final List<ArticleSupplierPrice> prices;
  final List<Supplier> suppliers;
  final List<ArticleGroup> groups;
  final Money? salePrice;
}

class _SetSupplierPriceDialog extends StatefulWidget {
  const _SetSupplierPriceDialog({required this.suppliers, required this.existing, this.initialSupplierId});

  final List<Supplier> suppliers;
  final List<ArticleSupplierPrice> existing;
  final String? initialSupplierId;

  @override
  State<_SetSupplierPriceDialog> createState() => _SetSupplierPriceDialogState();
}

class _SetSupplierPriceDialogState extends State<_SetSupplierPriceDialog> {
  String? _supplierId;
  final _priceCtrl = TextEditingController();
  final _numberCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.initialSupplierId != null) _select(widget.initialSupplierId);
  }

  /// Vorhandene Zuordnung vorbelegen (Preis und Lieferantenartikelnummer).
  void _select(String? supplierId) {
    _supplierId = supplierId;
    final existing = widget.existing.where((p) => p.supplierId == supplierId).firstOrNull;
    if (existing != null) {
      _priceCtrl.text = Money.fromCents(existing.purchasePriceCents).toString().replaceAll(RegExp(r'[^0-9,.-]'), '');
      _numberCtrl.text = existing.supplierArticleNumber ?? '';
    }
  }

  @override
  void dispose() {
    _priceCtrl.dispose();
    _numberCtrl.dispose();
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
            onChanged: (value) => setState(() => _select(value)),
          ),
          TextField(
            controller: _priceCtrl,
            decoration: const InputDecoration(labelText: 'Einkaufspreis (€)'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          TextField(
            key: const Key('supplier-article-number'),
            controller: _numberCtrl,
            decoration: const InputDecoration(
              labelText: 'Lieferantenartikelnummer',
              helperText: 'Nur für Bestellungen bei diesem Lieferanten, nie auf Kundenbelegen.',
              helperMaxLines: 2,
            ),
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
            Navigator.pop(context, (supplierId: supplierId, cents: cents, number: _numberCtrl.text));
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
        StockMovementType.creditNoteReturn => 'Gutschrift (Rückbuchung)',
        StockMovementType.transfer => 'Umlagerung',
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

/// C5.4: Umlagerung zwischen zwei Plätzen.
class _TransferDialog extends StatefulWidget {
  const _TransferDialog({required this.bins, required this.quantities, required this.from, required this.to});
  final List<BinEntry> bins;
  final Map<String, double> quantities;
  final String? from;
  final String? to;

  @override
  State<_TransferDialog> createState() => _TransferDialogState();
}

class _TransferDialogState extends State<_TransferDialog> {
  late String? _from = widget.from;
  late String? _to = widget.to;
  final _qty = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _qty.dispose();
    super.dispose();
  }

  void _submit() {
    final amount = double.tryParse(_qty.text.trim().replaceAll(',', '.'));
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Menge größer 0 eingeben.');
      return;
    }
    if (_from == null || _to == null || _from == _to) {
      setState(() => _error = 'Zwei verschiedene Plätze wählen.');
      return;
    }
    Navigator.pop(context, (from: _from!, to: _to!, quantity: amount));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Umlagern'),
      content: SizedBox(
        width: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            StorageBinDropdown(
              key: const Key('transfer-from'),
              bins: widget.bins,
              value: _from,
              label: 'Von',
              quantities: widget.quantities,
              onChanged: (v) => setState(() => _from = v),
            ),
            StorageBinDropdown(
              key: const Key('transfer-to'),
              bins: widget.bins,
              value: _to,
              label: 'Nach',
              quantities: widget.quantities,
              onChanged: (v) => setState(() => _to = v),
            ),
            TextField(
              key: const Key('transfer-quantity'),
              controller: _qty,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: 'Menge *', errorText: _error),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
        FilledButton(onPressed: _submit, child: const Text('Umlagern')),
      ],
    );
  }
}
