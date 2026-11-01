import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:werkkern_client/werkkern_client.dart';
import 'package:werkkern_core/werkkern_core.dart';

import '../../../domain/services/online_session.dart';
import 'online_form.dart';

/// Artikel der Online-Firma (wie offline A1): Liste mit Knopf
/// „Artikelgruppen“; Lieferanten haben wie offline einen eigenen Bereich
/// ([OnlineSuppliersScreen]). Lesen mit `articles.read`, Pflege mit
/// `articles.write`.
class OnlineArticlesScreen extends StatelessWidget {
  const OnlineArticlesScreen({super.key, required this.session});
  final OnlineSession session;

  @override
  Widget build(BuildContext context) => _ArticleList(session: session);
}

/// Lieferanten der Online-Firma — eigener Bereich wie offline.
class OnlineSuppliersScreen extends StatelessWidget {
  const OnlineSuppliersScreen({super.key, required this.session});
  final OnlineSession session;

  @override
  Widget build(BuildContext context) => _SupplierList(session: session);
}

/// Artikelgruppen mit Aufschlag — wie offline eine Unterseite des
/// Artikelbereichs.
class OnlineArticleGroupsScreen extends StatelessWidget {
  const OnlineArticleGroupsScreen({super.key, required this.session});
  final OnlineSession session;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Artikelgruppen')),
        body: _GroupList(session: session),
      );
}

String _price(int? cents) => cents == null ? 'kein Preis' : '${Money.fromCents(cents)} netto';

/// Bestand unter dem Mindestbestand (Mengen als Dezimaltext).
bool isBelowMinimum(OnlineArticle a) =>
    a.minimumStock != null && Decimal.parse(a.stockQuantity) < Decimal.parse(a.minimumStock!);

/// Dezimaltext ("2.5") in deutscher Schreibweise.
String formatQuantity(String value) => value.replaceAll('.', ',');

const stockMovementTypeLabels = {
  'documentBooking': 'Dokument',
  'purchaseOrderReceipt': 'Wareneingang',
  'inventoryCorrection': 'Inventur/Korrektur',
  'creditNoteReturn': 'Gutschrift-Rückbuchung',
};

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
      if (session.modules.contains('lagerbestand'))
        OnlineField('minimumStock', 'Mindestbestand', type: OnlineFieldType.decimal, initial: existing?.minimumStock),
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
      // Ohne Lagermodul bleibt ein gesetzter Mindestbestand erhalten.
      minimumStock: values.containsKey('minimumStock') ? values['minimumStock'] as String? : existing?.minimumStock,
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
    final showStock = session.modules.contains('lagerbestand');
    return OnlineListView<OnlineArticle>(
      load: (q) => session.client.articles(query: q),
      emptyText: 'Noch keine Artikel angelegt.',
      appBar: (context, reload) => AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Artikel'),
        actions: [
          IconButton(
            icon: const Icon(Icons.category_outlined),
            tooltip: 'Artikelgruppen',
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => OnlineArticleGroupsScreen(session: session)),
              );
              reload();
            },
          ),
        ],
      ),
      searchHint: 'Artikel suchen',
      itemBuilder: (context, a, reload) {
        // Wie offline: Artikel unter Mindestbestand rot markieren.
        final lowStock = showStock && isBelowMinimum(a);
        final error = Theme.of(context).colorScheme.error;
        return Card(
          child: ListTile(
            leading: Icon(Icons.inventory_2_outlined, color: lowStock ? error : null),
            title: Text(a.name),
            subtitle: Text(
              [
                ?a.unit,
                if (a.articleGroupName != null) a.articleGroupName!,
                if (showStock) 'Bestand: ${formatQuantity(a.stockQuantity)}${lowStock ? ' (unter Mindestbestand!)' : ''}',
              ].join(' · '),
              style: lowStock ? TextStyle(color: error) : null,
            ),
            trailing: Text(a.effectiveSalePriceCents == null ? '–' : Money.fromCents(a.effectiveSalePriceCents!).toString()),
            onTap: () async {
              await Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => OnlineArticleDetailScreen(session: session, articleId: a.id)),
              );
              reload();
            },
          ),
        );
      },
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

  bool get _showStock => widget.session.modules.contains('lagerbestand') && widget.session.can('stock.read');

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

  Future<void> _correctStock(OnlineArticle article) async {
    final values = await showOnlineForm(
      context,
      title: 'Bestand korrigieren',
      submitLabel: 'Buchen',
      fields: [
        OnlineField('counted', 'Gezählter Bestand', type: OnlineFieldType.decimal, required: true, initial: article.stockQuantity),
        const OnlineField('reason', 'Grund', required: true, helper: 'Wird als Inventur dokumentiert.'),
      ],
    );
    if (values == null || !mounted) return;
    if (await runOnline(
      context,
      () => widget.session.client.correctStock(
        article.id,
        countedQuantity: values['counted'] as String,
        reason: values['reason'] as String,
      ),
      success: 'Bestand gebucht.',
    )) {
      _reload();
    }
  }

  Future<void> _editPrice(List<OnlineSupplier> suppliers, [OnlineArticlePrice? existing]) async {
    final values = await showOnlineForm(
      context,
      title: 'Einkaufspreis setzen',
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

  Future<void> _toggleActive(OnlineArticle a) async {
    if (await runOnline(
      context,
      () => widget.session.client.saveArticle(OnlineArticle(
        id: a.id,
        name: a.name,
        unit: a.unit,
        salePriceCents: a.salePriceCents,
        active: !a.active,
        articleGroupId: a.articleGroupId,
        defaultSupplierId: a.defaultSupplierId,
        minimumStock: a.minimumStock,
      )),
    )) {
      _reload();
    }
  }

  /// Bestandsbewegungen als Dialog wie offline (Knopf „Bewegungen“).
  Future<void> _showMovements(OnlineArticle article) async {
    List<OnlineStockMovement>? movements;
    if (!await runOnline(context, () async => movements = await widget.session.client.stockMovements(articleId: article.id))) {
      return;
    }
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Bewegungen: ${article.name}'),
        content: SizedBox(
          width: 420,
          child: movements!.isEmpty
              ? const Text('Noch keine Bestandsbewegungen.')
              : ListView(
                  shrinkWrap: true,
                  children: [
                    for (final m in movements!)
                      ListTile(
                        dense: true,
                        title: Text('${m.quantityDelta.startsWith('-') ? '' : '+'}${formatQuantity(m.quantityDelta)} → '
                            '${formatQuantity(m.resultingQuantity)}'),
                        subtitle: Text([
                          stockMovementTypeLabels[m.type] ?? m.type,
                          if (m.referenceLabel != null) m.referenceLabel!,
                          if (m.note != null) m.note!,
                          formatOnlineDate(m.createdAt.toLocal()),
                        ].join(' · ')),
                      ),
                  ],
                ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Schließen'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canWrite = widget.session.can('articles.write');
    return FutureBuilder<(OnlineArticle, List<OnlineArticlePrice>, List<OnlineSupplier>)>(
      future: _future,
      builder: (context, snapshot) {
        final data = snapshot.data;
        final article = data?.$1;
        return Scaffold(
          appBar: AppBar(
            title: Text(article == null ? 'Artikel' : article.active ? article.name : '${article.name} (deaktiviert)'),
            actions: [
              if (canWrite && article != null) ...[
                IconButton(
                  tooltip: 'Bearbeiten',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () async {
                    if (await editOnlineArticle(context, widget.session, article) != null) _reload();
                  },
                ),
                IconButton(
                  icon: Icon(article.active ? Icons.block_outlined : Icons.check_circle_outline),
                  tooltip: article.active ? 'Deaktivieren' : 'Aktivieren',
                  onPressed: () => _toggleActive(article),
                ),
              ],
            ],
          ),
          body: snapshot.hasError
              ? Center(child: Text(describeOnlineError(snapshot.error!)))
              : data == null
                  ? const Center(child: CircularProgressIndicator())
                  : _body(data.$1, data.$2, data.$3, canWrite),
          floatingActionButton: canWrite && data != null && data.$3.isNotEmpty
              ? FloatingActionButton.extended(
                  heroTag: 'online-article-detail-fab',
                  onPressed: () => _editPrice(data.$3),
                  icon: const Icon(Icons.add),
                  label: const Text('Einkaufspreis setzen'),
                )
              : null,
        );
      },
    );
  }

  /// Aufbau wie offline (`article_detail_screen.dart`): Verkaufspreis,
  /// Lagerbestand mit „Bewegungen“/„Bestand korrigieren“, darunter die
  /// Einkaufspreise je Lieferant (Stern = Standardlieferant).
  Widget _body(OnlineArticle article, List<OnlineArticlePrice> prices, List<OnlineSupplier> suppliers, bool canWrite) {
    final theme = Theme.of(context);
    final low = isBelowMinimum(article);
    return ListView(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 88),
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                article.effectiveSalePriceCents == null
                    ? 'Verkaufspreis: unbekannt (kein Standardlieferant/Einkaufspreis)'
                    : article.salePriceCents != null
                        ? 'Netto-Verkaufspreis (manuell): ${Money.fromCents(article.salePriceCents!)}'
                        : 'Kalkulierter Netto-Verkaufspreis: ${Money.fromCents(article.effectiveSalePriceCents!)}',
                style: theme.textTheme.titleMedium,
              ),
              // Nur online: manueller Preis überschreibt die Kalkulation.
              if (article.salePriceCents != null)
                Text(
                  'Kalkuliert: ${_price(article.calculatedSalePriceCents)}'
                  '${article.articleGroupName == null ? '' : ' (Gruppe ${article.articleGroupName})'}',
                  style: theme.textTheme.bodySmall,
                ),
              if (_showStock) ...[
                const SizedBox(height: 8),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'Lagerbestand: ${formatQuantity(article.stockQuantity)}'
                      '${article.unit == null ? '' : ' ${article.unit}'}'
                      '${article.minimumStock == null ? '' : ' (Mindestbestand: ${formatQuantity(article.minimumStock!)})'}',
                      style: TextStyle(color: low ? theme.colorScheme.error : null, fontWeight: FontWeight.w600),
                    ),
                    TextButton(onPressed: () => _showMovements(article), child: const Text('Bewegungen')),
                    if (widget.session.can('stock.write'))
                      TextButton(onPressed: () => _correctStock(article), child: const Text('Bestand korrigieren')),
                  ],
                ),
              ],
            ],
          ),
        ),
        const Divider(height: 1),
        if (prices.isEmpty)
          const Padding(padding: EdgeInsets.all(24), child: Center(child: Text('Noch keine Lieferantenpreise hinterlegt.'))),
        for (final p in prices)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Card(
              child: ListTile(
                leading: Icon(
                  p.supplierId == article.defaultSupplierId ? Icons.star : Icons.local_shipping_outlined,
                  color: p.supplierId == article.defaultSupplierId ? Colors.amber[700] : null,
                ),
                title: Text(p.supplierName ?? '(unbekannt)'),
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
          ),
        if (canWrite && suppliers.isEmpty)
          const Padding(padding: EdgeInsets.all(16), child: Text('Für Einkaufspreise erst einen Lieferanten anlegen.')),
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
      emptyText: 'Noch keine Lieferanten angelegt.',
      searchHint: 'Lieferanten suchen',
      itemBuilder: (context, s, reload) => Card(
        child: ListTile(
          leading: const Icon(Icons.local_shipping_outlined),
          title: Text(s.name),
          // Wie offline: Anschrift als Untertitel.
          subtitle: s.address == null ? null : Text(s.address!),
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
      emptyText: 'Noch keine Artikelgruppen angelegt.',
      itemBuilder: (context, g, reload) => Card(
        child: ListTile(
          leading: const Icon(Icons.category_outlined),
          title: Text(g.name),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('+${g.markupPercent.toStringAsFixed(1).replaceAll('.', ',')} %'),
              if (canWrite)
                IconButton(
                  tooltip: 'Gruppe löschen',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    if (!await confirmOnline(context, 'Artikelgruppe löschen?', 'Die Artikel bleiben erhalten, nur ohne Gruppe.')) {
                      return;
                    }
                    if (context.mounted && await runOnline(context, () => session.client.deleteArticleGroup(g.id))) reload();
                  },
                )
            ],
          ),
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
