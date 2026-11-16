import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/database/database.dart';
import '../../data/repositories/article_group_repository.dart';
import '../../domain/services/active_company_service.dart';
import '../widgets/article_group_delete_dialog.dart';

/// Artikelgruppen-Verwaltung (prozentualer Aufschlag) — erreichbar aus
/// dem Artikel-Screen heraus, kein eigener Hauptnavigationspunkt (A1:
/// "Artikelgruppe ≠ Positionsgruppe im Dokument", bewusst unauffällig
/// platziert, um Verwechslung zu vermeiden).
class ArticleGroupsScreen extends StatefulWidget {
  const ArticleGroupsScreen({super.key});

  @override
  State<ArticleGroupsScreen> createState() => _ArticleGroupsScreenState();
}

class _ArticleGroupsScreenState extends State<ArticleGroupsScreen> {
  late Future<List<ArticleGroup>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<ArticleGroup>> _load() {
    final companyId = context.read<ActiveCompanyService>().active!.id;
    return context.read<ArticleGroupRepository>().listForCompany(companyId);
  }

  void _reload() => setState(() { _future = _load(); });

  Future<void> _create() async {
    final result = await showDialog<({String name, double markup})>(
      context: context,
      builder: (context) => const _NewArticleGroupDialog(),
    );
    if (result == null || !mounted) return;
    final companyId = context.read<ActiveCompanyService>().active!.id;
    await context.read<ArticleGroupRepository>().create(
          companyId: companyId,
          name: result.name,
          markupPercent: result.markup,
        );
    _reload();
  }

  Future<void> _edit(ArticleGroup group) async {
    final result = await showDialog<({String name, double markup})>(
      context: context, builder: (context) => _NewArticleGroupDialog(existing: group),
    );
    if (result == null || !mounted) return;
    final companyId = context.read<ActiveCompanyService>().active!.id;
    await context.read<ArticleGroupRepository>().update(companyId: companyId, id: group.id,
        name: result.name, markupPercent: result.markup);
    if (mounted) _reload();
  }

  Future<void> _delete(ArticleGroup group) async {
    final companyId = context.read<ActiveCompanyService>().active!.id;
    final repo = context.read<ArticleGroupRepository>();
    final count = await repo.countArticles(companyId: companyId, id: group.id);
    if (count == null || !mounted) { if (mounted) _reload(); return; }
    final choice = await showArticleGroupDeleteDialog(context, group.name, count);
    if (choice == null || !mounted) return;
    try {
      await repo.delete(companyId: companyId, id: group.id,
          deleteArticles: choice == DeleteGroupChoice.deleteArticles, expectedCount: count);
      if (mounted) _reload();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text(
          'Artikelgruppe konnte nicht gelöscht werden. Anzahl oder historische Verweise prüfen.')));
        _reload();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Artikelgruppen')),
      body: FutureBuilder<List<ArticleGroup>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) return Center(child: Text('Artikelgruppen konnten nicht geladen werden: ${snapshot.error}'));
          final groups = snapshot.data!;
          if (groups.isEmpty) {
            return const Center(child: Text('Noch keine Artikelgruppen angelegt.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
            itemCount: groups.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final group = groups[index];
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.category_outlined),
                  title: Text(group.name),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text('+${group.markupPercent.toStringAsFixed(1)} %'),
                    IconButton(tooltip: 'Gruppe bearbeiten', icon: const Icon(Icons.edit_outlined), onPressed: () => _edit(group)),
                    IconButton(tooltip: 'Gruppe löschen', icon: const Icon(Icons.delete_outline), onPressed: () => _delete(group)),
                  ]),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'article-groups-fab',
        onPressed: _create,
        icon: const Icon(Icons.add),
        label: const Text('Gruppe anlegen'),
      ),
    );
  }
}

class _NewArticleGroupDialog extends StatefulWidget {
  const _NewArticleGroupDialog({this.existing});
  final ArticleGroup? existing;

  @override
  State<_NewArticleGroupDialog> createState() => _NewArticleGroupDialogState();
}

class _NewArticleGroupDialogState extends State<_NewArticleGroupDialog> {
  final _nameCtrl = TextEditingController();
  final _markupCtrl = TextEditingController(text: '0');

  @override
  void initState() {
    super.initState();
    _nameCtrl.text = widget.existing?.name ?? '';
    _markupCtrl.text = widget.existing?.markupPercent.toString() ?? '0';
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _markupCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'Neue Artikelgruppe' : 'Artikelgruppe bearbeiten'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameCtrl,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          TextField(
            controller: _markupCtrl,
            decoration: const InputDecoration(labelText: 'Aufschlag (%)'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
        FilledButton(
          onPressed: () {
            final name = _nameCtrl.text.trim();
            final markup = double.tryParse(_markupCtrl.text.replaceAll(',', '.'));
            if (name.isEmpty || markup == null || !markup.isFinite || markup < 0) return;
            Navigator.pop(context, (name: name, markup: markup));
          },
          child: Text(widget.existing == null ? 'Anlegen' : 'Speichern'),
        ),
      ],
    );
  }
}
