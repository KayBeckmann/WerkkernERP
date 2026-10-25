import 'package:flutter/material.dart';
import 'package:werkkern_client/werkkern_client.dart';
import 'package:werkkern_core/werkkern_core.dart';

import '../../../domain/services/online_session.dart';
import 'online_form.dart';

/// Artikelbereich der Online-Firma: Artikel, Lieferanten, Artikelgruppen
/// (wie offline A1). Lesen mit `articles.read`, Pflege mit `articles.write`.
class OnlineArticlesScreen extends StatelessWidget {
  const OnlineArticlesScreen({super.key, required this.session});
  final OnlineSession session;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          const TabBar(tabs: [Tab(text: 'Artikel'), Tab(text: 'Lieferanten'), Tab(text: 'Gruppen')]),
          Expanded(
            child: TabBarView(
              children: [
                _ArticleList(session: session),
                _SupplierList(session: session),
                _GroupList(session: session),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _price(int? cents) => cents == null ? 'kein Preis' : '${Money.fromCents(cents)} netto';

Future<OnlineArticle?> editOnlineArticle(BuildContext context, OnlineSession session, [OnlineArticle? existing]) async {
  final client = session.client;
  final groups = await client.articleGroups();
  final suppliers = await client.suppliers();
  if (!context.mounted) return null;
  final values = await showOnlineForm(
    context,
    title: existing == null ? 'Neuer Artikel' : 'Artikel bearbeiten',
    fields: [
      OnlineField('name', 'Bezeichnung', required: true, initial: existing?.name),
      OnlineField('unit', 'Einheit', initial: existing?.unit),
      OnlineField(
        'articleGroupId',
        'Artikelgruppe',
        type: OnlineFieldType.choice,
        initial: existing?.articleGroupId,
        options: {for (final g in groups) g.id: '${g.name} (+${g.markupPercent.toStringAsFixed(1).replaceAll('.', ',')} %)'},
      ),
      OnlineField(
        'defaultSupplierId',
        'Standardlieferant',
        type: OnlineFieldType.choice,
        initial: existing?.defaultSupplierId,
        options: {for (final s in suppliers) s.id: s.name},
        helper: 'Sein Einkaufspreis × Gruppenaufschlag ergibt den Verkaufspreis.',
      ),
      OnlineField(
        'salePriceCents',
        'Manueller Verkaufspreis (netto)',
        type: OnlineFieldType.money,
        initial: existing?.salePriceCents,
        helper: 'Leer lassen, um zu kalkulieren.',
      ),
      OnlineField('active', 'Aktiv', type: OnlineFieldType.toggle, initial: existing?.active ?? true),
    ],
  );
  if (values == null || !context.mounted) return null;
  OnlineArticle? saved;
  await runOnline(context, () async {
    saved = await client.saveArticle(OnlineArticle(
      id: existing?.id ?? '',
      name: values['name'] as String,
      unit: values['unit'] as String?,
      salePriceCents: values['salePriceCents'] as int?,
      active: values['active'] as bool,
      articleGroupId: values['articleGroupId'] as String?,
      defaultSupplierId: values['defaultSupplierId'] as String?,
    ));
  });
  return saved;
}

class _ArticleList extends StatelessWidget {
  const _ArticleList({required this.session});
  final OnlineSession session;

  @override
  Widget build(BuildContext context) {
    final canWrite = session.can('articles.write');
    return OnlineListView<OnlineArticle>(
      load: (q) => session.client.articles(query: q),
      emptyText: 'Keine Artikel vorhanden.',
      searchHint: 'Artikel suchen',
      itemBuilder: (context, a, reload) => Card(
        child: ListTile(
          leading: const Icon(Icons.inventory_2_outlined),
          title: Text(a.name),
          subtitle: Text([
            a.unit == null ? _price(a.effectiveSalePriceCents) : '${_price(a.effectiveSalePriceCents)} / ${a.unit}',
            if (a.salePriceCents != null) 'manuell',
            if (a.articleGroupName != null) a.articleGroupName!,
          ].join(' · ')),
          trailing: const Icon(Icons.chevron_right),
          onTap: () async {
            await Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => OnlineArticleDetailScreen(session: session, articleId: a.id)),
            );
            reload();
          },
        ),
      ),
      floatingActionButton: canWrite
          ? (reload) => Builder(
                builder: (context) => FloatingActionButton.extended(
                  heroTag: 'online-articles-fab',
                  onPressed: () async {
                    if (await editOnlineArticle(context, session) != null) reload();
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Artikel anlegen'),
                ),
              )
          : null,
    );
  }
}

/// Artikel mit Einkaufspreisen je Lieferant und Kalkulation.
class OnlineArticleDetailScreen extends StatefulWidget {
  const OnlineArticleDetailScreen({super.key, required this.session, required this.articleId});
  final OnlineSession session;
  final String articleId;

  @override
  State<OnlineArticleDetailScreen> createState() => _OnlineArticleDetailScreenState();
}

class _OnlineArticleDetailScreenState extends State<OnlineArticleDetailScreen> {
  late Future<(OnlineArticle, List<OnlineArticlePrice>, List<OnlineSupplier>)> _future = _load();

  Future<(OnlineArticle, List<OnlineArticlePrice>, List<OnlineSupplier>)> _load() async {
    final client = widget.session.client;
    return (
      await client.article(widget.articleId),
      await client.articlePrices(widget.articleId),
      await client.suppliers(),
    );
  }

  void _reload() => setState(() {
        _future = _load();
      });

  Future<void> _editPrice(List<OnlineSupplier> suppliers, [OnlineArticlePrice? existing]) async {
    final values = await showOnlineForm(
      context,
      title: existing == null ? 'Einkaufspreis hinzufügen' : 'Einkaufspreis ändern',
      fields: [
        OnlineField(
          'supplierId',
          'Lieferant',
          type: OnlineFieldType.choice,
          required: true,
          initial: existing?.supplierId,
          options: {for (final s in suppliers) s.id: s.name},
        ),
        OnlineField(
          'price',
          'Einkaufspreis (netto)',
          type: OnlineFieldType.money,
          required: true,
          initial: existing?.purchasePriceCents,
        ),
      ],
    );
    if (values == null || !mounted) return;
    if (await runOnline(
      context,
      () => widget.session.client.setArticlePrice(widget.articleId, values['supplierId'] as String, values['price'] as int),
    )) {
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final canWrite = widget.session.can('articles.write');
    return FutureBuilder<(OnlineArticle, List<OnlineArticlePrice>, List<OnlineSupplier>)>(
      future: _future,
      builder: (context, snapshot) {
        final data = snapshot.data;
        return Scaffold(
          appBar: AppBar(
            title: Text(data?.$1.name ?? 'Artikel'),
            actions: [
              if (canWrite && data != null)
                IconButton(
                  tooltip: 'Bearbeiten',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () async {
                    if (await editOnlineArticle(context, widget.session, data.$1) != null) _reload();
                  },
                ),
            ],
          ),
          body: snapshot.hasError
              ? Center(child: Text(describeOnlineError(snapshot.error!)))
              : data == null
                  ? const Center(child: CircularProgressIndicator())
                  : _body(data.$1, data.$2, data.$3, canWrite),
        );
      },
    );
  }

  Widget _body(OnlineArticle article, List<OnlineArticlePrice> prices, List<OnlineSupplier> suppliers, bool canWrite) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Card(
          child: Column(
            children: [
              ListTile(
                title: const Text('Verkaufspreis (wirksam)'),
                trailing: Text(_price(article.effectiveSalePriceCents), style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
              ListTile(
                dense: true,
                title: const Text('Kalkuliert'),
                subtitle: Text(article.articleGroupName == null ? 'ohne Gruppe: 0 % Aufschlag' : 'Gruppe ${article.articleGroupName}'),
                trailing: Text(_price(article.calculatedSalePriceCents)),
              ),
              if (article.salePriceCents != null)
                ListTile(dense: true, title: const Text('Manuell (vorrangig)'), trailing: Text(_price(article.salePriceCents))),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text('Einkaufspreise', style: Theme.of(context).textTheme.titleMedium),
        if (prices.isEmpty) const Padding(padding: EdgeInsets.all(8), child: Text('Noch keine Einkaufspreise.')),
        for (final p in prices)
          Card(
            child: ListTile(
              leading: Icon(p.supplierId == article.defaultSupplierId ? Icons.star : Icons.local_shipping_outlined),
              title: Text(p.supplierName ?? 'Lieferant'),
              subtitle: p.supplierId == article.defaultSupplierId ? const Text('Standardlieferant') : null,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(Money.fromCents(p.purchasePriceCents).toString()),
                  if (canWrite)
                    IconButton(
                      tooltip: 'Preis entfernen',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () async {
                        if (await runOnline(
                          context,
                          () => widget.session.client.removeArticlePrice(article.id, p.supplierId),
                        )) {
                          _reload();
                        }
                      },
                    ),
                ],
              ),
              onTap: canWrite ? () => _editPrice(suppliers, p) : null,
            ),
          ),
        if (canWrite)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: suppliers.isEmpty ? null : () => _editPrice(suppliers),
              icon: const Icon(Icons.add),
              label: Text(suppliers.isEmpty ? 'Erst einen Lieferanten anlegen' : 'Einkaufspreis hinzufügen'),
            ),
          ),
      ],
    );
  }
}

class _SupplierList extends StatelessWidget {
  const _SupplierList({required this.session});
  final OnlineSession session;

  Future<bool> _edit(BuildContext context, [OnlineSupplier? existing]) async {
    final values = await showOnlineForm(
      context,
      title: existing == null ? 'Neuer Lieferant' : 'Lieferant bearbeiten',
      fields: [
        OnlineField('name', 'Name', required: true, initial: existing?.name),
        OnlineField('address', 'Anschrift', type: OnlineFieldType.multiline, initial: existing?.address),
        OnlineField('contactPerson', 'Ansprechpartner', initial: existing?.contactPerson),
        OnlineField('email', 'E-Mail', initial: existing?.email),
        OnlineField('phone', 'Telefon', initial: existing?.phone),
        OnlineField('vatId', 'USt-IdNr.', initial: existing?.vatId),
        OnlineField('minimumOrderQuantity', 'Mindestbestellmenge', type: OnlineFieldType.decimal, initial: existing?.minimumOrderQuantity),
        OnlineField('deliveryTerms', 'Lieferbedingungen', initial: existing?.deliveryTerms),
        OnlineField('notes', 'Notizen', type: OnlineFieldType.multiline, initial: existing?.notes),
      ],
    );
    if (values == null || !context.mounted) return false;
    return runOnline(
      context,
      () => session.client.saveSupplier(OnlineSupplier(
        id: existing?.id ?? '',
        name: values['name'] as String,
        address: values['address'] as String?,
        contactPerson: values['contactPerson'] as String?,
        email: values['email'] as String?,
        phone: values['phone'] as String?,
        vatId: values['vatId'] as String?,
        minimumOrderQuantity: values['minimumOrderQuantity'] as String?,
        deliveryTerms: values['deliveryTerms'] as String?,
        notes: values['notes'] as String?,
      )),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canWrite = session.can('articles.write');
    return OnlineListView<OnlineSupplier>(
      load: (q) => session.client.suppliers(query: q),
      emptyText: 'Keine Lieferanten vorhanden.',
      searchHint: 'Lieferanten suchen',
      itemBuilder: (context, s, reload) => Card(
        child: ListTile(
          leading: const Icon(Icons.local_shipping_outlined),
          title: Text(s.name),
          subtitle: Text([
            if (s.contactPerson != null) s.contactPerson!,
            if (s.email != null) s.email!,
            if (s.minimumOrderQuantity != null) 'Mindestmenge ${s.minimumOrderQuantity!.replaceAll('.', ',')}',
          ].join(' · ')),
          trailing: canWrite
              ? IconButton(
                  tooltip: 'Lieferant löschen',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    if (!await confirmOnline(
                      context,
                      'Lieferant löschen?',
                      'Seine Einkaufspreise werden entfernt; Artikel verlieren ihn als Standardlieferanten.',
                    )) {
                      return;
                    }
                    if (context.mounted && await runOnline(context, () => session.client.deleteSupplier(s.id))) reload();
                  },
                )
              : null,
          onTap: canWrite
              ? () async {
                  if (await _edit(context, s)) reload();
                }
              : null,
        ),
      ),
      floatingActionButton: canWrite
          ? (reload) => Builder(
                builder: (context) => FloatingActionButton.extended(
                  heroTag: 'online-suppliers-fab',
                  onPressed: () async {
                    if (await _edit(context)) reload();
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Lieferant anlegen'),
                ),
              )
          : null,
    );
  }
}

class _GroupList extends StatelessWidget {
  const _GroupList({required this.session});
  final OnlineSession session;

  Future<bool> _edit(BuildContext context, [OnlineArticleGroup? existing]) async {
    final values = await showOnlineForm(
      context,
      title: existing == null ? 'Neue Artikelgruppe' : 'Artikelgruppe bearbeiten',
      fields: [
        OnlineField('name', 'Name', required: true, initial: existing?.name),
        OnlineField(
          'markup',
          'Aufschlag in %',
          type: OnlineFieldType.decimal,
          required: true,
          initial: existing?.markupPercent.toString(),
        ),
      ],
    );
    if (values == null || !context.mounted) return false;
    return runOnline(
      context,
      () => session.client.saveArticleGroup(
        id: existing?.id,
        name: values['name'] as String,
        markupPercent: double.parse(values['markup'] as String),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canWrite = session.can('articles.write');
    return OnlineListView<OnlineArticleGroup>(
      load: (_) => session.client.articleGroups(),
      emptyText: 'Keine Artikelgruppen vorhanden.',
      itemBuilder: (context, g, reload) => Card(
        child: ListTile(
          leading: const Icon(Icons.category_outlined),
          title: Text(g.name),
          subtitle: Text('Aufschlag ${g.markupPercent.toString().replaceAll('.', ',')} %'),
          trailing: canWrite
              ? IconButton(
                  tooltip: 'Gruppe löschen',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    if (!await confirmOnline(context, 'Artikelgruppe löschen?', 'Die Artikel bleiben erhalten, nur ohne Gruppe.')) {
                      return;
                    }
                    if (context.mounted && await runOnline(context, () => session.client.deleteArticleGroup(g.id))) reload();
                  },
                )
              : null,
          onTap: canWrite
              ? () async {
                  if (await _edit(context, g)) reload();
                }
              : null,
        ),
      ),
      floatingActionButton: canWrite
          ? (reload) => Builder(
                builder: (context) => FloatingActionButton.extended(
                  heroTag: 'online-groups-fab',
                  onPressed: () async {
                    if (await _edit(context)) reload();
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Gruppe anlegen'),
                ),
              )
          : null,
    );
  }
}
