import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/database/database.dart';
import '../../data/repositories/article_group_repository.dart';
import '../../data/repositories/article_repository.dart';
import '../../data/repositories/supplier_repository.dart';
import '../../domain/models/money.dart';
import '../../domain/services/active_company_service.dart';
import 'article_detail_screen.dart';
import 'article_groups_screen.dart';

/// Artikelliste der aktiven Firma (A1). Tippen auf einen Artikel öffnet
/// die Lieferantenpreis-Verwaltung ([ArticleDetailScreen]).
class ArticlesScreen extends StatefulWidget {
  const ArticlesScreen({super.key});

  @override
  State<ArticlesScreen> createState() => _ArticlesScreenState();
}

class _ArticlesScreenState extends State<ArticlesScreen> {
  late Future<_ArticlesData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_ArticlesData> _load() async {
    final companyId = context.read<ActiveCompanyService>().active!.id;
    final articleRepo = context.read<ArticleRepository>();

    final articles = await articleRepo.listForCompany(companyId);
    final prices = <String, Money?>{};
    for (final article in articles) {
      prices[article.id] = await articleRepo.effectiveSalePrice(
        companyId: companyId,
        articleId: article.id,
      );
    }
    return _ArticlesData(articles: articles, salePrices: prices);
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
    final companyId = context.read<ActiveCompanyService>().active!.id;
    final groups = await context.read<ArticleGroupRepository>().listForCompany(companyId);
    if (!mounted) return;
    final suppliers = await context.read<SupplierRepository>().listForCompany(companyId);
    if (!mounted) return;
    final result = await showDialog<_NewArticleResult>(
      context: context,
      builder: (context) => _NewArticleDialog(groups: groups, suppliers: suppliers),
    );
    if (result == null || !mounted) return;
    await context.read<ArticleRepository>().create(
          companyId: companyId,
          name: result.name,
          unit: result.unit,
          articleGroupId: result.articleGroupId,
          defaultSupplierId: result.defaultSupplierId,
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
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.inventory_2_outlined),
                  title: Text(article.name),
                  subtitle: Text(article.unit ?? ''),
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
  const _ArticlesData({required this.articles, required this.salePrices});
  final List<Article> articles;
  final Map<String, Money?> salePrices;
}

class _NewArticleResult {
  const _NewArticleResult({
    required this.name,
    this.unit,
    this.articleGroupId,
    this.defaultSupplierId,
  });
  final String name;
  final String? unit;
  final String? articleGroupId;
  final String? defaultSupplierId;
}

class _NewArticleDialog extends StatefulWidget {
  const _NewArticleDialog({required this.groups, required this.suppliers});
  final List<ArticleGroup> groups;
  final List<Supplier> suppliers;

  @override
  State<_NewArticleDialog> createState() => _NewArticleDialogState();
}

class _NewArticleDialogState extends State<_NewArticleDialog> {
  final _nameCtrl = TextEditingController();
  final _unitCtrl = TextEditingController(text: 'Stk');
  String? _groupId;
  String? _supplierId;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _unitCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Neuer Artikel'),
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
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
        FilledButton(
          onPressed: () {
            final name = _nameCtrl.text.trim();
            if (name.isEmpty) return;
            Navigator.pop(
              context,
              _NewArticleResult(
                name: name,
                unit: _unitCtrl.text.trim().isEmpty ? null : _unitCtrl.text.trim(),
                articleGroupId: _groupId,
                defaultSupplierId: _supplierId,
              ),
            );
          },
          child: const Text('Anlegen'),
        ),
      ],
    );
  }
}
