import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/database/database.dart';
import '../../data/database/tables.dart';
import '../../data/repositories/article_repository.dart';
import '../../data/repositories/inventory_repository.dart';
import '../../domain/services/active_company_service.dart';
import '../../domain/services/stock_change_notifier.dart';
import 'articles_screen.dart' show formatArticleQuantity;

/// Ein Inventur-Lauf: Artikel hinzufügen, gezählte Mengen eintragen,
/// abschließen (C5.3, Nachtrag 2026-10-19). Vor dem Abschluss frei
/// bearbeitbar, danach unveränderlich (F3-Prinzip).
class InventoryCountDetailScreen extends StatefulWidget {
  const InventoryCountDetailScreen({super.key, required this.inventoryCountId});
  final String inventoryCountId;

  @override
  State<InventoryCountDetailScreen> createState() => _InventoryCountDetailScreenState();
}

class _InventoryCountDetailScreenState extends State<InventoryCountDetailScreen> {
  late Future<_DetailData> _future;
  bool _busy = false;
  final Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<_DetailData> _load() async {
    final companyId = context.read<ActiveCompanyService>().active!.id;
    final repo = context.read<InventoryRepository>();
    final articleRepo = context.read<ArticleRepository>();
    final count = await repo.findById(companyId: companyId, id: widget.inventoryCountId);
    final items = count == null ? <InventoryCountItem>[] : await repo.itemsFor(count.id);
    final articles = await articleRepo.listForCompany(companyId);
    final articleNames = {for (final article in articles) article.id: article.name};

    for (final item in items) {
      _controllers.putIfAbsent(
        item.id,
        () => TextEditingController(
          text: item.countedQuantity == null ? '' : formatArticleQuantity(item.countedQuantity!),
        ),
      );
    }

    return _DetailData(count: count, items: items, articles: articles, articleNames: articleNames);
  }

  void _reload() => setState(() {
        _future = _load();
      });

  Future<void> _addArticles(List<Article> allArticles, List<InventoryCountItem> existing) async {
    final existingIds = existing.map((i) => i.articleId).toSet();
    final candidates = allArticles.where((a) => !existingIds.contains(a.id)).toList();
    final selected = await showDialog<List<String>>(
      context: context,
      builder: (context) => _AddArticlesDialog(candidates: candidates),
    );
    if (selected == null || selected.isEmpty || !mounted) return;
    final companyId = context.read<ActiveCompanyService>().active!.id;
    await context.read<InventoryRepository>().addArticles(
          companyId: companyId,
          inventoryCountId: widget.inventoryCountId,
          articleIds: selected,
        );
    _reload();
  }

  Future<void> _saveCountedQuantity(String itemId, String text) async {
    final value = double.tryParse(text.trim().replaceAll(',', '.'));
    if (value == null) return;
    await context.read<InventoryRepository>().setCountedQuantity(
          itemId: itemId,
          countedQuantity: value,
        );
  }

  Future<void> _complete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Inventur abschließen?'),
        content: const Text(
          'Alle eingetragenen Abweichungen werden jetzt gebucht und im Bewegungsprotokoll '
          'dokumentiert. Diese Aktion ist nicht umkehrbar.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Abbrechen')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Abschließen')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      final companyId = context.read<ActiveCompanyService>().active!.id;
      await context.read<InventoryRepository>().complete(
            companyId: companyId,
            id: widget.inventoryCountId,
          );
      if (mounted) context.read<StockChangeNotifier>().notifyStockChanged();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Inventur')),
      body: FutureBuilder<_DetailData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data!;
          final count = data.count;
          if (count == null) {
            return const Center(child: Text('Inventur nicht gefunden.'));
          }
          final isDraft = count.status == InventoryCountStatus.draft;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
            children: [
              Text(count.label, style: Theme.of(context).textTheme.headlineSmall),
              Text(isDraft ? 'Entwurf' : 'Abgeschlossen'),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Positionen', style: Theme.of(context).textTheme.titleMedium),
                  if (isDraft)
                    TextButton.icon(
                      onPressed: () => _addArticles(data.articles, data.items),
                      icon: const Icon(Icons.add),
                      label: const Text('Artikel hinzufügen'),
                    ),
                ],
              ),
              if (data.items.isEmpty) const Text('Noch keine Artikel in dieser Inventur.'),
              for (final item in data.items)
                Card(
                  child: ListTile(
                    title: Text(data.articleNames[item.articleId] ?? '(unbekannt)'),
                    subtitle: Text('Soll: ${formatArticleQuantity(item.expectedQuantity)}'),
                    trailing: isDraft
                        ? SizedBox(
                            width: 120,
                            child: TextField(
                              controller: _controllers[item.id],
                              textAlign: TextAlign.right,
                              decoration: const InputDecoration(labelText: 'Ist'),
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              onChanged: (text) => _saveCountedQuantity(item.id, text),
                            ),
                          )
                        : Text(
                            'Ist: ${item.countedQuantity == null ? '–' : formatArticleQuantity(item.countedQuantity!)}',
                          ),
                  ),
                ),
              const SizedBox(height: 24),
              if (isDraft)
                FilledButton(
                  onPressed: _busy || data.items.isEmpty ? null : _complete,
                  child: const Text('Inventur abschließen'),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _DetailData {
  const _DetailData({
    required this.count,
    required this.items,
    required this.articles,
    required this.articleNames,
  });
  final InventoryCount? count;
  final List<InventoryCountItem> items;
  final List<Article> articles;
  final Map<String, String> articleNames;
}

class _AddArticlesDialog extends StatefulWidget {
  const _AddArticlesDialog({required this.candidates});
  final List<Article> candidates;

  @override
  State<_AddArticlesDialog> createState() => _AddArticlesDialogState();
}

class _AddArticlesDialogState extends State<_AddArticlesDialog> {
  final Set<String> _selected = {};

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Artikel hinzufügen'),
      content: SizedBox(
        width: 400,
        height: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => setState(() => _selected
                  ..clear()
                  ..addAll(widget.candidates.map((a) => a.id))),
                child: const Text('Alle auswählen'),
              ),
            ),
            Expanded(
              child: widget.candidates.isEmpty
                  ? const Center(child: Text('Alle Artikel sind bereits in dieser Inventur.'))
                  : ListView(
                      children: [
                        for (final article in widget.candidates)
                          CheckboxListTile(
                            title: Text(article.name),
                            value: _selected.contains(article.id),
                            onChanged: (checked) => setState(() {
                              if (checked ?? false) {
                                _selected.add(article.id);
                              } else {
                                _selected.remove(article.id);
                              }
                            }),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
        FilledButton(
          onPressed: () => Navigator.pop(context, _selected.toList()),
          child: const Text('Hinzufügen'),
        ),
      ],
    );
  }
}
