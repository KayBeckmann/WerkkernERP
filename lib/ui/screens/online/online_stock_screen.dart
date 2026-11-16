import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:werkkern_client/werkkern_client.dart';

import '../../../domain/services/online_session.dart';
import 'online_articles_screen.dart';
import 'online_form.dart';
import 'online_storage_screen.dart';

/// Inventur der Online-Firma (C5.3) — Bereich „Inventur“ wie offline.
/// Unterbestand und das unveränderliche Bewegungsprotokoll (nur online)
/// liegen als Unterseiten in der Titelleiste.
class OnlineStockScreen extends StatelessWidget {
  const OnlineStockScreen({super.key, required this.session});
  final OnlineSession session;

  @override
  Widget build(BuildContext context) => _InventoryList(session: session);
}

/// Artikel unter Mindestbestand mit Fehlmenge.
class OnlineLowStockScreen extends StatelessWidget {
  const OnlineLowStockScreen({super.key, required this.session});
  final OnlineSession session;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Unterbestand')),
    body: OnlineListView<({OnlineArticle article, String shortfall})>(
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
  );
}

/// Unveränderliches Bewegungsprotokoll aller Artikel.
class OnlineStockMovementsScreen extends StatelessWidget {
  const OnlineStockMovementsScreen({super.key, required this.session});
  final OnlineSession session;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Bestandsbewegungen')),
    body: OnlineListView<OnlineStockMovement>(
      load: (_) => session.client.stockMovements(),
      emptyText: 'Noch keine Bestandsbewegungen.',
      itemBuilder: (context, m, reload) => Card(
        child: ListTile(
          title: Text(
            '${m.articleName ?? 'Artikel'}: ${m.quantityDelta.startsWith('-') ? '' : '+'}'
            '${formatQuantity(m.quantityDelta)} → ${formatQuantity(m.resultingQuantity)}',
          ),
          subtitle: Text(
            [
              stockMovementTypeLabels[m.type] ?? m.type,
              if (m.referenceLabel != null) m.referenceLabel!,
              if (m.note != null) m.note!,
              formatOnlineDate(m.createdAt.toLocal()),
            ].join(' · '),
          ),
        ),
      ),
    ),
  );
}

class _InventoryList extends StatelessWidget {
  const _InventoryList({required this.session});
  final OnlineSession session;

  @override
  Widget build(BuildContext context) {
    final canWrite = session.can('stock.write');
    return OnlineListView<OnlineInventoryCount>(
      load: (_) => session.client.inventoryCounts(),
      emptyText: 'Noch keine Inventur durchgeführt.',
      appBar: (context, reload) => AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Inventur'),
        actions: [
          IconButton(
            key: const Key('online-open-storage'),
            tooltip: 'Lagerorte & Plätze',
            icon: const Icon(Icons.warehouse_outlined),
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute<void>(builder: (_) => OnlineStorageLocationsScreen(session: session))),
          ),
          IconButton(
            tooltip: 'Unterbestand',
            icon: const Icon(Icons.warning_amber_outlined),
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute<void>(builder: (_) => OnlineLowStockScreen(session: session))),
          ),
          IconButton(
            tooltip: 'Bestandsbewegungen',
            icon: const Icon(Icons.history),
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute<void>(builder: (_) => OnlineStockMovementsScreen(session: session))),
          ),
        ],
      ),
      itemBuilder: (context, c, reload) => Card(
        child: ListTile(
          leading: Icon(c.isDraft ? Icons.edit_note_outlined : Icons.fact_check_outlined),
          title: Text(c.label),
          subtitle: Text('${c.isDraft ? 'Entwurf' : 'Abgeschlossen'} · Stichtag ${formatOnlineDate(c.date)}'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () async {
            await Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => OnlineInventoryScreen(session: session, countId: c.id),
              ),
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
                  // C5.4: Lagerorte für „Platz für Platz“ zählen.
                  var locations = const <OnlineStorageLocation>[];
                  try {
                    locations = (await session.client.storageLocations()).locations;
                  } on Exception {
                    // Ohne Lagerorte bleibt die artikelweise Inventur.
                  }
                  if (!context.mounted) return;
                  final values = await showOnlineForm(
                    context,
                    title: 'Neue Inventur',
                    submitLabel: 'Anlegen',
                    fields: [
                      OnlineField('label', 'Bezeichnung', required: true, initial: 'Inventur ${DateTime.now().year}'),
                      OnlineField(
                        'date',
                        'Stichtag',
                        type: OnlineFieldType.date,
                        required: true,
                        initial: DateTime.now(),
                      ),
                      if (locations.isNotEmpty)
                        OnlineField(
                          'location',
                          'Zählen nach',
                          type: OnlineFieldType.choice,
                          options: {
                            null: 'Artikeln',
                            for (final l in locations) l.id: 'Lagerort ${l.name} (Platz für Platz)',
                          },
                        ),
                      OnlineField(
                        'all',
                        'Alle aktiven Artikel aufnehmen',
                        type: OnlineFieldType.toggle,
                        initial: true,
                        visibleWhen: (v) => v['location'] == null,
                      ),
                    ],
                  );
                  if (values == null || !context.mounted) return;
                  OnlineInventoryCount? created;
                  await runOnline(context, () async {
                    created = await session.client.createInventoryCount(
                      values['label'] as String,
                      date: values['date'] as DateTime,
                      allArticles: (values['all'] as bool?) ?? false,
                      locationId: values['location'] as String?,
                    );
                  });
                  if (created != null && context.mounted) {
                    await Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => OnlineInventoryScreen(session: session, countId: created!.id),
                      ),
                    );
                  }
                  reload();
                },
                icon: const Icon(Icons.add),
                label: const Text('Neue Inventur'),
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
  bool _busy = false;

  /// Ist-Mengen direkt in der Liste wie offline; gespeichert wird kurz
  /// nach dem Tippen (nicht bei jedem Zeichen ein Serveraufruf).
  final _controllers = <String, TextEditingController>{};
  final _pending = <String, Timer>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final t in _pending.values) {
      t.cancel();
    }
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final count = await widget.session.client.inventoryCount(widget.countId);
      if (mounted) setState(() => _apply(count));
    } on Exception catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  void _apply(OnlineInventoryCount count) {
    _count = count;
    for (final i in count.items) {
      // Laufende Eingaben nicht vom Serverstand überschreiben.
      _controllers.putIfAbsent(
        i.id,
        () => TextEditingController(text: i.countedQuantity == null ? '' : formatQuantity(i.countedQuantity!)),
      );
    }
  }

  void _countedChanged(OnlineInventoryItem item, String text) {
    _pending[item.id]?.cancel();
    _pending[item.id] = Timer(const Duration(milliseconds: 600), () => _saveCounted(item.id));
  }

  Future<void> _saveCounted(String itemId) async {
    _pending.remove(itemId)?.cancel();
    final text = _controllers[itemId]!.text.trim().replaceAll(',', '.');
    if (text.isNotEmpty && Decimal.tryParse(text) == null) return;
    try {
      final updated = await widget.session.client.setInventoryCounted(widget.countId, itemId, text.isEmpty ? null : text);
      if (mounted) setState(() => _apply(updated));
    } on Exception catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(describeOnlineError(e))));
    }
  }

  /// Wie offline: Mehrfachauswahl mit „Alle auswählen“.
  Future<void> _addArticles() async {
    final present = {for (final i in _count!.items) i.articleId};
    final List<OnlineArticle> candidates;
    try {
      candidates = (await widget.session.client.articles()).where((a) => !present.contains(a.id)).toList();
    } on Exception catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(describeOnlineError(e))));
      return;
    }
    if (!mounted) return;
    final selected = await showDialog<List<String>>(
      context: context,
      builder: (_) => _AddArticlesDialog(candidates: candidates),
    );
    if (selected == null || selected.isEmpty || !mounted) return;
    await runOnline(context, () async {
      final updated = await widget.session.client.addInventoryArticles(widget.countId, selected);
      if (mounted) setState(() => _apply(updated));
    });
  }

  /// C5.4: Fund an einem Platz (auch leerer Platz) nachtragen.
  Future<void> _addFound(String binKey) async {
    final List<OnlineArticle> candidates;
    try {
      candidates = await widget.session.client.articles();
    } on Exception catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(describeOnlineError(e))));
      return;
    }
    if (!mounted) return;
    final selected = await showDialog<List<String>>(
      context: context,
      builder: (_) => _AddArticlesDialog(candidates: candidates),
    );
    if (selected == null || selected.isEmpty || !mounted) return;
    await runOnline(context, () async {
      OnlineInventoryCount? updated;
      for (final articleId in selected) {
        updated = await widget.session.client.addInventoryFound(widget.countId, articleId: articleId, binKey: binKey);
      }
      if (mounted && updated != null) setState(() => _apply(updated!));
    });
  }

  Widget _itemCard(OnlineInventoryItem i, bool editable) => Card(
        child: ListTile(
          title: Text(i.articleName ?? '(unbekannt)'),
          subtitle: Text('Soll: ${formatQuantity(i.expectedQuantity)}${i.unit == null ? '' : ' ${i.unit}'}'),
          trailing: editable
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 120,
                      child: TextField(
                        key: Key('online-inventory-counted-${i.articleName}${i.binKey == null ? '' : '-${i.binLabel}'}'),
                        controller: _controllers[i.id],
                        textAlign: TextAlign.right,
                        decoration: const InputDecoration(labelText: 'Ist'),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        onChanged: (text) => _countedChanged(i, text),
                        onSubmitted: (_) => _saveCounted(i.id),
                      ),
                    ),
                    // Nur online: Artikel wieder aus der Inventur nehmen.
                    IconButton(
                      tooltip: 'Aus Inventur entfernen',
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: () async {
                        await runOnline(context, () => widget.session.client.removeInventoryItem(widget.countId, i.id));
                        await _load();
                      },
                    ),
                  ],
                )
              : Text('Ist: ${i.countedQuantity == null ? '–' : formatQuantity(i.countedQuantity!)}'),
        ),
      );

  /// Platz-Inventur: je Platz eine Überschrift (auch leere Plätze), dann
  /// die Klärfälle ohne Platz.
  List<Widget> _locationSections(OnlineInventoryCount count, bool editable) {
    Widget header(String text, String binKey, {bool empty = false}) => Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 4),
          child: Row(
            children: [
              Expanded(child: Text(empty ? '$text — leer' : text, style: Theme.of(context).textTheme.titleSmall)),
              if (editable)
                TextButton.icon(
                  onPressed: () => _addFound(binKey),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Fund'),
                ),
            ],
          ),
        );
    final widgets = <Widget>[];
    for (final bin in count.bins) {
      final here = count.items.where((i) => i.binKey == bin.id).toList();
      widgets.add(header(bin.label, bin.id, empty: here.isEmpty));
      widgets.addAll(here.map((i) => _itemCard(i, editable)));
    }
    final known = {for (final b in count.bins) b.id};
    final rest = count.items.where((i) => !known.contains(i.binKey)).toList();
    if (rest.isNotEmpty) {
      widgets.add(header('Platz noch nicht zugeordnet (Klärfälle)', ''));
      widgets.addAll(rest.map((i) => _itemCard(i, editable)));
    }
    return widgets;
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
    // Noch nicht übertragene Eingaben zuerst speichern.
    for (final id in [..._pending.keys]) {
      await _saveCounted(id);
    }
    if (!mounted) return;
    await runOnline(context, () async {
      final updated = await widget.session.client.completeInventoryCount(widget.countId);
      if (mounted) setState(() => _apply(updated));
    }, success: 'Inventur abgeschlossen, Abweichungen gebucht.');
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final count = _count;
    final editable = count != null && count.isDraft && widget.session.can('stock.write');
    return Scaffold(
      appBar: AppBar(title: const Text('Inventur')),
      body: _error != null
          ? Center(child: Text(describeOnlineError(_error!)))
          : count == null
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
                  children: [
                    Text(count.label, style: Theme.of(context).textTheme.headlineSmall),
                    Text('${count.isDraft ? 'Entwurf' : 'Abgeschlossen'} · Stichtag ${formatOnlineDate(count.date)}'),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Positionen', style: Theme.of(context).textTheme.titleMedium),
                        if (editable && count.locationId == null)
                          TextButton.icon(onPressed: _addArticles, icon: const Icon(Icons.add), label: const Text('Artikel hinzufügen')),
                      ],
                    ),
                    if (count.locationId != null)
                      ..._locationSections(count, editable)
                    else ...[
                      if (count.items.isEmpty) const Text('Noch keine Artikel in dieser Inventur.'),
                      for (final i in count.items) _itemCard(i, editable),
                    ],
                    const SizedBox(height: 24),
                    if (editable)
                      FilledButton(
                        onPressed: _busy || count.items.isEmpty ? null : _complete,
                        child: const Text('Inventur abschließen'),
                      ),
                  ],
                ),
    );
  }
}

class _AddArticlesDialog extends StatefulWidget {
  const _AddArticlesDialog({required this.candidates});
  final List<OnlineArticle> candidates;

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
        FilledButton(onPressed: () => Navigator.pop(context, _selected.toList()), child: const Text('Hinzufügen')),
      ],
    );
  }
}
