import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/database/database.dart';
import '../../data/repositories/article_group_repository.dart';
import '../../data/repositories/article_repository.dart';
import '../../data/repositories/supplier_repository.dart';
import '../../domain/models/money.dart';
import '../../domain/services/active_company_service.dart';
import '../../domain/services/stock_change_notifier.dart';
import 'article_detail_screen.dart';
import 'article_groups_screen.dart';
import 'ecad_material_screen.dart';

/// Artikelliste der aktiven Firma (A1). Tippen auf einen Artikel öffnet
/// die Lieferantenpreis-Verwaltung ([ArticleDetailScreen]).
class ArticlesScreen extends StatefulWidget {
  const ArticlesScreen({super.key});

  @override
  State<ArticlesScreen> createState() => _ArticlesScreenState();
}

class _ArticlesScreenState extends State<ArticlesScreen> {
  late Future<_ArticlesData> _future;

  /// Bugfix 2026-10-19 (Kay: "Wenn ich den Bestand aus einer Bestellung
  /// buche, wird dieser nicht angezeigt") — Ursache: dieser Screen lädt
  /// den Bestand bisher nur einmalig über ein `Future`. Bleibt der
  /// Artikel-Tab im Hintergrund gemountet (IndexedStack, siehe
  /// `home_shell.dart`), während der Bestand anderswo gebucht wird
  /// (Wareneingang, Rechnung finalisieren, Korrektur), zeigt er den
  /// alten Wert bis zur nächsten lokalen Aktion in DIESEM Screen.
  /// [StockChangeNotifier] ist ein gewöhnlicher `ChangeNotifier`
  /// (gleiches, bereits bewährtes Muster wie `ActiveCompanyService`) —
  /// jede bestandsverändernde Stelle pingt ihn an, dieser Screen löst
  /// darauf einen Reload aus. Bewusst **kein** Drift-`.watch()`-Stream
  /// hier: ein erster Versuch damit hat 38 bestehende Widget-Tests mit
  /// "A Timer is still pending even after the widget tree was
  /// disposed" zum Scheitern gebracht (vermutlich internes
  /// Cleanup-Timing von Drifts Stream-Query-Mechanismus im Test-
  /// Binding) — der ChangeNotifier-Weg ist in dieser Codebase bereits
  /// vielfach erprobt und ohne dieses Risiko.
  /// Referenz gemerkt statt in `dispose()` erneut per `context.read()`
  /// zu holen — ein `BuildContext` ist in `dispose()` nicht mehr sicher
  /// für Ancestor-Lookups ("Looking up a deactivated widget's ancestor
  /// is unsafe", per Widget-Test gefunden).
  late StockChangeNotifier _stockChangeNotifier;

  void _onStockChanged() {
    if (mounted) _reload();
  }

  @override
  void initState() {
    super.initState();
    _future = _load();
    _stockChangeNotifier = context.read<StockChangeNotifier>()..addListener(_onStockChanged);
  }

  @override
  void dispose() {
    _stockChangeNotifier.removeListener(_onStockChanged);
    super.dispose();
  }

  Future<_ArticlesData> _load() async {
    final company = context.read<ActiveCompanyService>().active!;
    final articleRepo = context.read<ArticleRepository>();

    final articles = await articleRepo.listForCompany(company.id);
    final prices = <String, Money?>{};
    for (final article in articles) {
      prices[article.id] = await articleRepo.effectiveSalePrice(
        companyId: company.id,
        articleId: article.id,
      );
    }
    return _ArticlesData(
      articles: articles,
      salePrices: prices,
      lagerbestandEnabled: company.lagerbestandEnabled,
    );
  }

  void _reload() => setState(() { _future = _load(); });

  Future<void> _create() async {
    // Frisch laden statt der gecachten Liste aus dem Tab-FutureBuilder:
    // Dieser Screen wird über IndexedStack nie neu initialisiert, eine
    // Artikelgruppe oder ein Lieferant, der NACH dem ersten Öffnen dieses
    // Tabs über den separaten Lieferanten-Tab angelegt wurde, wäre im
    // Dropdown sonst erst nach einem App-Neustart sichtbar (derselbe
    // Fehler, der in invoices_screen.dart über einen Widget-Test gefunden
    // wurde — hier analog ohne erneuten Test repariert, siehe Commit).
    final company = context.read<ActiveCompanyService>().active!;
    final groups = await context.read<ArticleGroupRepository>().listForCompany(company.id);
    if (!mounted) return;
    final suppliers = await context.read<SupplierRepository>().listForCompany(company.id);
    if (!mounted) return;
    final result = await showDialog<ArticleFormResult>(
      context: context,
      builder: (context) => ArticleFormDialog(
        groups: groups,
        suppliers: suppliers,
        lagerbestandEnabled: company.lagerbestandEnabled,
      ),
    );
    if (result == null || !mounted) return;
    await context.read<ArticleRepository>().create(
          companyId: company.id,
          name: result.name,
          unit: result.unit,
          articleGroupId: result.articleGroupId,
          defaultSupplierId: result.defaultSupplierId,
          minimumStock: result.minimumStock,
        );
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Artikel'),
        actions: [
          IconButton(
            tooltip: 'LibreECAD-Materialvorschau',
            icon: const Icon(Icons.electrical_services),
            onPressed: () {
              final company = context.read<ActiveCompanyService>().active!;
              final repo = context.read<ArticleRepository>();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => EcadMaterialScreen(
                    companyId: company.id,
                    companyName: company.name,
                    loadArticles: () async => [
                      for (final a in await repo.listForCompany(company.id))
                        {'id': a.id, 'name': a.name, 'unit': a.unit},
                    ],
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.category_outlined),
            tooltip: 'Artikelgruppen',
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ArticleGroupsScreen()),
              );
              _reload();
            },
          ),
        ],
      ),
      body: FutureBuilder<_ArticlesData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data!;
          if (data.articles.isEmpty) {
            return const Center(child: Text('Noch keine Artikel angelegt.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
            itemCount: data.articles.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final article = data.articles[index];
              final price = data.salePrices[article.id];
              final lowStock = data.lagerbestandEnabled &&
                  article.minimumStock != null &&
                  article.stockQuantity < article.minimumStock!;
              return Card(
                child: ListTile(
                  leading: Icon(
                    Icons.inventory_2_outlined,
                    color: lowStock ? Theme.of(context).colorScheme.error : null,
                  ),
                  title: Text(article.name),
                  subtitle: Text(
                    [
                      if (article.unit != null) article.unit!,
                      if (data.lagerbestandEnabled)
                        'Bestand: ${formatArticleQuantity(article.stockQuantity)}'
                            '${lowStock ? ' (unter Mindestbestand!)' : ''}',
                    ].join(' · '),
                    style: lowStock
                        ? TextStyle(color: Theme.of(context).colorScheme.error)
                        : null,
                  ),
                  trailing: Text(price?.toString() ?? '–'),
                  onTap: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => ArticleDetailScreen(article: article)),
                    );
                    _reload();
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'articles-fab',
        onPressed: _create,
        icon: const Icon(Icons.add),
        label: const Text('Artikel anlegen'),
      ),
    );
  }
}

class _ArticlesData {
  const _ArticlesData({
    required this.articles,
    required this.salePrices,
    required this.lagerbestandEnabled,
  });
  final List<Article> articles;
  final Map<String, Money?> salePrices;
  final bool lagerbestandEnabled;
}

/// C5.1 Lagerbestand — `stockQuantity`/`minimumStock` sind `double`
/// (siehe Doc-Kommentar in `tables.dart`), aber meist ganzzahlige
/// Mengen ("10 Steckdosen") sollen nicht als "10.0" angezeigt werden.
/// Öffentlich, damit `article_detail_screen.dart` dieselbe Formatierung
/// nutzen kann statt sie zu duplizieren.
String formatArticleQuantity(double value) =>
    value == value.roundToDouble() ? value.toStringAsFixed(0) : value.toString();

class ArticleFormResult {
  const ArticleFormResult({
    required this.name,
    this.unit,
    this.articleGroupId,
    this.defaultSupplierId,
    this.minimumStock,
  });
  final String name;
  final String? unit;
  final String? articleGroupId;
  final String? defaultSupplierId;

  /// C5.1 Lagerbestand — `null` = keine Mindestbestand-Überwachung.
  final double? minimumStock;
}

/// Erstellen UND Bearbeiten (Nachtrag 2026-10-18: "Artikel können nicht
/// nachträglich bearbeitet werden") — über [existing] wiederverwendet,
/// gleiches Prinzip wie `_ExpenseFormDialog`. Öffentlich statt privat,
/// weil sowohl `ArticlesScreen` (Neuanlage) als auch
/// `ArticleDetailScreen` (Bearbeiten) ihn brauchen.
class ArticleFormDialog extends StatefulWidget {
  const ArticleFormDialog({
    super.key,
    required this.groups,
    required this.suppliers,
    required this.lagerbestandEnabled,
    this.existing,
  });
  final List<ArticleGroup> groups;
  final List<Supplier> suppliers;

  /// C5.1 Lagerbestand — blendet das Mindestbestand-Feld nur ein,
  /// wenn das Modul aktiv ist.
  final bool lagerbestandEnabled;
  final Article? existing;

  @override
  State<ArticleFormDialog> createState() => _ArticleFormDialogState();
}

class _ArticleFormDialogState extends State<ArticleFormDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _unitCtrl;
  late final TextEditingController _minimumStockCtrl;
  String? _groupId;
  String? _supplierId;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _nameCtrl = TextEditingController(text: existing?.name);
    _unitCtrl = TextEditingController(text: existing?.unit ?? (existing == null ? 'Stk' : null));
    _minimumStockCtrl = TextEditingController(
      text: existing?.minimumStock == null ? '' : formatArticleQuantity(existing!.minimumStock!),
    );
    _groupId = existing?.articleGroupId;
    _supplierId = existing?.defaultSupplierId;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _unitCtrl.dispose();
    _minimumStockCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'Neuer Artikel' : 'Artikel bearbeiten'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameCtrl,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Name *'),
            ),
            TextField(
              controller: _unitCtrl,
              decoration: const InputDecoration(labelText: 'Einheit'),
            ),
            DropdownButtonFormField<String?>(
              isExpanded: true,
              initialValue: _groupId,
              decoration: const InputDecoration(labelText: 'Artikelgruppe (Aufschlag)'),
              items: [
                const DropdownMenuItem<String?>(value: null, child: Text('— keine —')),
                for (final group in widget.groups)
                  DropdownMenuItem(
                    value: group.id,
                    child: Text('${group.name} (+${group.markupPercent.toStringAsFixed(1)} %)'),
                  ),
              ],
              onChanged: (value) => setState(() => _groupId = value),
            ),
            DropdownButtonFormField<String?>(
              isExpanded: true,
              initialValue: _supplierId,
              decoration: const InputDecoration(labelText: 'Standardlieferant'),
              items: [
                const DropdownMenuItem<String?>(value: null, child: Text('— keiner —')),
                for (final supplier in widget.suppliers)
                  DropdownMenuItem(value: supplier.id, child: Text(supplier.name)),
              ],
              onChanged: (value) => setState(() => _supplierId = value),
            ),
            if (widget.lagerbestandEnabled) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _minimumStockCtrl,
                decoration: const InputDecoration(
                  labelText: 'Mindestbestand (optional)',
                  hintText: 'leer = keine Überwachung',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
        FilledButton(
          onPressed: () {
            final name = _nameCtrl.text.trim();
            if (name.isEmpty) return;
            final minimumStockText = _minimumStockCtrl.text.trim().replaceAll(',', '.');
            Navigator.pop(
              context,
              ArticleFormResult(
                name: name,
                unit: _unitCtrl.text.trim().isEmpty ? null : _unitCtrl.text.trim(),
                articleGroupId: _groupId,
                defaultSupplierId: _supplierId,
                minimumStock: minimumStockText.isEmpty ? null : double.tryParse(minimumStockText),
              ),
            );
          },
          child: Text(widget.existing == null ? 'Anlegen' : 'Speichern'),
        ),
      ],
    );
  }
}
