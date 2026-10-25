import 'package:flutter/material.dart';
import 'package:werkkern_client/werkkern_client.dart';

import '../../../domain/services/online_session.dart';
import 'online_articles_screen.dart';
import 'online_form.dart';

/// Lager der Online-Firma (C5.1/C5.3): Unterbestand, Inventurläufe und
/// das unveränderliche Bewegungsprotokoll.
class OnlineStockScreen extends StatelessWidget {
  const OnlineStockScreen({super.key, required this.session});
  final OnlineSession session;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          const TabBar(tabs: [Tab(text: 'Unterbestand'), Tab(text: 'Inventur'), Tab(text: 'Bewegungen')]),
          Expanded(
            child: TabBarView(
              children: [
                OnlineListView<({OnlineArticle article, String shortfall})>(
                  load: (_) => session.client.lowStock(),
                  emptyText: 'Kein Artikel unter Mindestbestand.',
                  itemBuilder: (context, e, reload) => Card(
                    child: ListTile(
                      leading: const Icon(Icons.warning_amber_outlined),
                      title: Text(e.article.name),
                      subtitle: Text(
                        'Bestand ${formatQuantity(e.article.stockQuantity)} · Mindestbestand '
                        '${formatQuantity(e.article.minimumStock ?? '0')} · fehlen ${formatQuantity(e.shortfall)}',
                      ),
                    ),
                  ),
                ),
                _InventoryList(session: session),
                OnlineListView<OnlineStockMovement>(
                  load: (_) => session.client.stockMovements(),
                  emptyText: 'Noch keine Bestandsbewegungen.',
                  itemBuilder: (context, m, reload) => Card(
                    child: ListTile(
                      title: Text('${m.articleName ?? 'Artikel'}: ${m.quantityDelta.startsWith('-') ? '' : '+'}'
                          '${formatQuantity(m.quantityDelta)} → ${formatQuantity(m.resultingQuantity)}'),
                      subtitle: Text([
                        stockMovementTypeLabels[m.type] ?? m.type,
                        if (m.referenceLabel != null) m.referenceLabel!,
                        if (m.note != null) m.note!,
                        formatOnlineDate(m.createdAt.toLocal()),
                      ].join(' · ')),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InventoryList extends StatelessWidget {
  const _InventoryList({required this.session});
  final OnlineSession session;

  @override
  Widget build(BuildContext context) {
    final canWrite = session.can('stock.write');
    return OnlineListView<OnlineInventoryCount>(
      load: (_) => session.client.inventoryCounts(),
      emptyText: 'Noch keine Inventur.',
      itemBuilder: (context, c, reload) => Card(
        child: ListTile(
          leading: Icon(c.isDraft ? Icons.fact_check_outlined : Icons.lock_outline),
          title: Text(c.label),
          subtitle: Text('${formatOnlineDate(c.date)} · ${c.isDraft ? 'offen' : 'abgeschlossen'}'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () async {
            await Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => OnlineInventoryScreen(session: session, countId: c.id)),
            );
            reload();
          },
        ),
      ),
      floatingActionButton: canWrite
          ? (reload) => Builder(
                builder: (context) => FloatingActionButton.extended(
                  heroTag: 'online-inventory-fab',
                  onPressed: () async {
                    final values = await showOnlineForm(
                      context,
                      title: 'Neue Inventur',
                      submitLabel: 'Anlegen',
                      fields: [
                        OnlineField('label', 'Bezeichnung', required: true, initial: 'Inventur ${DateTime.now().year}'),
                        OnlineField('date', 'Stichtag', type: OnlineFieldType.date, required: true, initial: DateTime.now()),
                        const OnlineField('all', 'Alle aktiven Artikel aufnehmen', type: OnlineFieldType.toggle, initial: true),
                      ],
                    );
                    if (values == null || !context.mounted) return;
                    OnlineInventoryCount? created;
                    await runOnline(context, () async {
                      created = await session.client.createInventoryCount(
                        values['label'] as String,
                        date: values['date'] as DateTime,
                        allArticles: values['all'] as bool,
                      );
                    });
                    if (created != null && context.mounted) {
                      await Navigator.of(context).push(
                        MaterialPageRoute<void>(builder: (_) => OnlineInventoryScreen(session: session, countId: created!.id)),
                      );
                    }
                    reload();
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Inventur starten'),
                ),
              )
          : null,
    );
  }
}

/// Ein Inventurlauf: Soll (beim Aufnehmen eingefroren), Zählmenge,
/// Abschluss bucht alle Abweichungen auf einmal.
class OnlineInventoryScreen extends StatefulWidget {
  const OnlineInventoryScreen({super.key, required this.session, required this.countId});
  final OnlineSession session;
  final String countId;

  @override
  State<OnlineInventoryScreen> createState() => _OnlineInventoryScreenState();
}

class _OnlineInventoryScreenState extends State<OnlineInventoryScreen> {
  OnlineInventoryCount? _count;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final count = await widget.session.client.inventoryCount(widget.countId);
      if (mounted) setState(() => _count = count);
    } on Exception catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _enterCount(OnlineInventoryItem item) async {
    final values = await showOnlineForm(
      context,
      title: item.articleName ?? 'Artikel',
      submitLabel: 'Übernehmen',
      fields: [
        OnlineField('counted', 'Gezählte Menge', type: OnlineFieldType.decimal, initial: item.countedQuantity ?? item.expectedQuantity),
      ],
    );
    if (values == null || !mounted) return;
    await runOnline(context, () async {
      final updated = await widget.session.client.setInventoryCounted(widget.countId, item.id, values['counted'] as String?);
      if (mounted) setState(() => _count = updated);
    });
  }

  Future<void> _addArticles() async {
    final present = {for (final i in _count!.items) i.articleId};
    final articles = (await widget.session.client.articles()).where((a) => !present.contains(a.id)).toList();
    if (!mounted) return;
    if (articles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Alle aktiven Artikel sind bereits enthalten.')));
      return;
    }
    final values = await showOnlineForm(
      context,
      title: 'Artikel aufnehmen',
      submitLabel: 'Aufnehmen',
      fields: [
        OnlineField('articleId', 'Artikel', type: OnlineFieldType.choice, required: true, options: {for (final a in articles) a.id: a.name}),
      ],
    );
    if (values == null || !mounted) return;
    await runOnline(context, () async {
      final updated = await widget.session.client.addInventoryArticles(widget.countId, [values['articleId'] as String]);
      if (mounted) setState(() => _count = updated);
    });
  }

  Future<void> _complete() async {
    if (!await confirmOnline(
      context,
      'Inventur abschließen?',
      'Jede gezählte Abweichung zum aktuellen Bestand wird gebucht. Danach ist die Inventur unveränderlich.',
      confirm: 'Abschließen',
    )) {
      return;
    }
    if (!mounted) return;
    await runOnline(context, () async {
      final updated = await widget.session.client.completeInventoryCount(widget.countId);
      if (mounted) setState(() => _count = updated);
    }, success: 'Inventur abgeschlossen, Abweichungen gebucht.');
  }

  @override
  Widget build(BuildContext context) {
    final count = _count;
    final editable = count != null && count.isDraft && widget.session.can('stock.write');
    return Scaffold(
      appBar: AppBar(
        title: Text(count?.label ?? 'Inventur'),
        actions: [
          if (editable) IconButton(tooltip: 'Artikel aufnehmen', icon: const Icon(Icons.playlist_add), onPressed: _addArticles),
        ],
      ),
      bottomNavigationBar: editable
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: FilledButton(onPressed: _complete, child: const Text('Inventur abschließen')),
              ),
            )
          : null,
      body: _error != null
          ? Center(child: Text(describeOnlineError(_error!)))
          : count == null
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    Text('${formatOnlineDate(count.date)} · ${count.isDraft ? 'offen' : 'abgeschlossen'}'),
                    const SizedBox(height: 8),
                    if (count.items.isEmpty) const Padding(padding: EdgeInsets.all(16), child: Text('Noch keine Artikel aufgenommen.')),
                    for (final i in count.items)
                      Card(
                        child: ListTile(
                          title: Text(i.articleName ?? 'Artikel'),
                          subtitle: Text(
                            'Soll ${formatQuantity(i.expectedQuantity)}${i.unit == null ? '' : ' ${i.unit}'}'
                            '${i.countedQuantity == null ? ' · noch nicht gezählt' : ' · gezählt ${formatQuantity(i.countedQuantity!)}'}',
                          ),
                          trailing: editable
                              ? IconButton(
                                  tooltip: 'Aus Inventur entfernen',
                                  icon: const Icon(Icons.remove_circle_outline),
                                  onPressed: () async {
                                    await runOnline(context, () => widget.session.client.removeInventoryItem(widget.countId, i.id));
                                    await _load();
                                  },
                                )
                              : null,
                          onTap: editable ? () => _enterCount(i) : null,
                        ),
                      ),
                  ],
                ),
    );
  }
}
