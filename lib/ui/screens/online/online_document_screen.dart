import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:werkkern_client/werkkern_client.dart';
import 'package:werkkern_core/werkkern_core.dart';

import '../../../domain/services/online_session.dart';
import '../../../pdf/online_document_pdf.dart';

/// Detail/Bearbeitung eines Online-Dokuments. Lokale Änderungen werden
/// erst mit "Speichern" übertragen — immer mit der zuletzt gelesenen
/// Version. Hat ein anderes Gerät inzwischen gespeichert, lehnt der
/// Server ab (409) und die App fragt nach, statt still zu überschreiben
/// (B2-Vorgabe "kein last write wins").
class OnlineDocumentScreen extends StatefulWidget {
  const OnlineDocumentScreen({super.key, required this.session, required this.documentId});
  final OnlineSession session;
  final String documentId;

  @override
  State<OnlineDocumentScreen> createState() => _OnlineDocumentScreenState();
}

class _OnlineDocumentScreenState extends State<OnlineDocumentScreen> {
  OnlineDocument? _document;
  List<OnlineDocumentItem> _items = [];
  late final _notes = TextEditingController();
  bool _dirty = false;
  bool _busy = true;
  String? _error;

  WerkkernApiClient get _client => widget.session.client;
  bool get _editable =>
      (_document?.isDraft ?? false) && widget.session.can('invoices.write');

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final document = await _client.document(widget.documentId);
      if (!mounted) return;
      setState(() => _apply(document));
    } on Exception catch (e) {
      if (mounted) setState(() => _error = describeOnlineError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _apply(OnlineDocument document) {
    _document = document;
    _items = [...document.items];
    _notes.text = document.notes ?? '';
    _dirty = false;
  }

  void _snack(String message) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  /// 409 -> Nutzer entscheidet ausdrücklich; nichts wird überschrieben.
  Future<void> _handleConflict(ApiException e) async {
    final reload = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Zwischenzeitlich geändert'),
        content: Text(
          '${e.message}\n\nDeine Änderungen wurden NICHT gespeichert. Neu laden zeigt den aktuellen Stand vom '
          'Server und verwirft deine lokalen Änderungen.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Abbrechen')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Neu laden')),
        ],
      ),
    );
    if (reload == true) await _reload();
  }

  Future<void> _run(Future<OnlineDocument> Function() action, String success) async {
    setState(() => _busy = true);
    Object? failure;
    try {
      final document = await action();
      if (!mounted) return;
      setState(() => _apply(document));
      _snack(success);
    } on Exception catch (e) {
      failure = e;
    } finally {
      // Vor einem Konflikt-Dialog beenden — sonst läuft der Ladebalken
      // hinter dem Dialog endlos weiter.
      if (mounted) setState(() => _busy = false);
    }
    if (failure == null || !mounted) return;
    if (failure is ApiException && failure.isConflict) {
      await _handleConflict(failure);
    } else {
      _snack(describeOnlineError(failure));
    }
  }

  Future<void> _save() => _run(
        () => _client.updateDocument(
          id: widget.documentId,
          version: _document!.version,
          items: _items,
          notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        ),
        'Gespeichert.',
      );

  Future<void> _finalize() async {
    final label = onlineDocumentKindLabels[_document!.kind] ?? 'Dokument';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$label finalisieren?'),
        content: const Text(
          'Vergibt die nächste Nummer und macht das Dokument unveränderlich. Kunden- und Firmendaten werden '
          'zum jetzigen Stand eingefroren.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Abbrechen')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Finalisieren')),
        ],
      ),
    );
    if (confirmed != true) return;
    await _run(() => _client.finalizeDocument(widget.documentId, version: _document!.version), 'Finalisiert.');
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Entwurf löschen?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Abbrechen')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Löschen')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _client.deleteDocument(widget.documentId);
      if (mounted) Navigator.of(context).pop();
    } on Exception catch (e) {
      if (mounted) _snack(describeOnlineError(e));
    }
  }

  /// PDF aus dem gespeicherten Serverstand. Finalisierte Dokumente
  /// dürfen geteilt/gedruckt werden, Entwürfe nur angesehen (wie
  /// offline: kein unfertiges Dokument verschicken).
  Future<void> _showPdf() async {
    final document = _document!;
    OnlineCompanyProfile? company;
    OnlineCustomer? customer;
    if (document.isDraft) {
      try {
        company = await _client.companyProfile();
        if (widget.session.can('customers.read')) {
          customer = (await _client.customers()).where((c) => c.id == document.customerId).firstOrNull;
        }
      } on Exception catch (e) {
        if (mounted) _snack(describeOnlineError(e));
        return;
      }
    }
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(title: Text(document.isDraft ? 'Vorschau (Entwurf, nicht final)' : document.number!)),
          body: PdfPreview(
            build: (_) => buildOnlineDocumentPdf(document, liveCompany: company, liveCustomer: customer),
            canChangeOrientation: false,
            canChangePageFormat: false,
            allowSharing: !document.isDraft,
            allowPrinting: !document.isDraft,
            pdfFileName: '${document.number ?? 'entwurf'}.pdf',
          ),
        ),
      ),
    );
  }

  Future<void> _addItem() async {
    List<OnlineArticle> articles = const [];
    if (widget.session.can('articles.read')) {
      try {
        articles = await _client.articles();
      } on Exception {
        // Ohne Artikelliste bleiben Stunden/Freitext/manuelle Artikel möglich.
      }
    }
    if (!mounted) return;
    final item = await showDialog<OnlineDocumentItem>(
      context: context,
      builder: (_) => _ItemDialog(articles: articles),
    );
    if (item == null) return;
    setState(() {
      _items = [..._items, item];
      _dirty = true;
    });
  }

  InvoiceTotals get _totals => calculateInvoiceTotals([
        for (final i in _items)
          InvoiceLineInput(
            quantity: Decimal.parse(i.quantity),
            unitPriceCents: i.unitPriceCents,
            vatRatePercent: i.vatRatePercent,
            discountPercent: i.discountPercent,
          ),
      ]);

  @override
  Widget build(BuildContext context) {
    final document = _document;
    final label = document == null ? 'Dokument' : (onlineDocumentKindLabels[document.kind] ?? document.kind);
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final discard = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Ungespeicherte Änderungen verwerfen?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Weiter bearbeiten')),
              FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Verwerfen')),
            ],
          ),
        );
        if (discard == true && context.mounted) {
          setState(() => _dirty = false);
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(document?.number ?? '$label (Entwurf)'),
          actions: [
            if (document != null && !_dirty)
              IconButton(
                tooltip: document.isDraft ? 'PDF-Vorschau (Entwurf)' : 'PDF',
                icon: const Icon(Icons.picture_as_pdf_outlined),
                onPressed: _busy ? null : _showPdf,
              ),
            if (_editable)
              IconButton(tooltip: 'Entwurf löschen', icon: const Icon(Icons.delete_outline), onPressed: _busy ? null : _delete),
          ],
        ),
        body: _error != null
            ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!)))
            : document == null
                ? const Center(child: CircularProgressIndicator())
                : _buildBody(document, label),
        bottomNavigationBar: document == null ? null : _buildActions(document),
      ),
    );
  }

  Widget _buildBody(OnlineDocument document, String label) {
    final totals = _totals;
    final dateFormat = DateFormat('dd.MM.yyyy');
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        if (_busy) const LinearProgressIndicator(),
        Card(
          child: ListTile(
            title: Text(document.isDraft ? '$label · Entwurf' : '$label · finalisiert'),
            subtitle: Text(
              [
                'Datum ${dateFormat.format(document.issueDate)}',
                if (document.displayCustomerName != null) 'Kunde ${document.displayCustomerName}',
                'Version ${document.version}',
              ].join(' · '),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text('Positionen', style: Theme.of(context).textTheme.titleMedium),
        if (_items.isEmpty) const Padding(padding: EdgeInsets.all(8), child: Text('Noch keine Positionen.')),
        for (final (index, item) in _items.indexed)
          Card(
            child: ListTile(
              title: Text(item.description),
              subtitle: Text(
                '${item.quantity.replaceAll('.', ',')} ${item.unit ?? ''} × ${Money.fromCents(item.unitPriceCents)}'
                ' · ${item.vatRatePercent.toStringAsFixed(0)} %${item.groupLabel != null ? ' · ${item.groupLabel}' : ''}',
              ),
              trailing: _editable
                  ? IconButton(
                      tooltip: 'Position entfernen',
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: () => setState(() {
                        _items = [..._items]..removeAt(index);
                        _dirty = true;
                      }),
                    )
                  : null,
            ),
          ),
        if (_editable)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(onPressed: _addItem, icon: const Icon(Icons.add), label: const Text('Position hinzufügen')),
          ),
        const SizedBox(height: 8),
        TextField(
          controller: _notes,
          enabled: _editable,
          maxLines: 2,
          decoration: const InputDecoration(labelText: 'Notizen'),
          onChanged: (_) => setState(() => _dirty = true),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                for (final rate in totals.sortedRates)
                  _row('Netto ${rate.toStringAsFixed(0)} % / USt', '${totals.netByRate[rate]} / ${totals.taxByRate[rate]}'),
                const Divider(),
                _row('Netto', totals.totalNet.toString()),
                _row('USt', totals.totalTax.toString()),
                _row('Brutto', totals.totalGross.toString(), bold: true),
              ],
            ),
          ),
        ),
        if (_dirty)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('Ungespeicherte Änderungen — erst nach "Speichern" auf dem Server.'),
          ),
      ],
    );
  }

  Widget _row(String label, String value, {bool bold = false}) {
    final style = bold ? const TextStyle(fontWeight: FontWeight.bold) : null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(children: [Expanded(child: Text(label, style: style)), Text(value, style: style)]),
    );
  }

  Widget? _buildActions(OnlineDocument document) {
    if (!document.isDraft) return null;
    final canFinalize = widget.session.can('invoices.finalize');
    if (!_editable && !canFinalize) return null;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            if (_editable)
              Expanded(
                child: OutlinedButton(onPressed: _busy || !_dirty ? null : _save, child: const Text('Speichern')),
              ),
            if (_editable && canFinalize) const SizedBox(width: 12),
            if (canFinalize)
              Expanded(
                child: FilledButton(
                  // Erst speichern, dann finalisieren — finalisiert wird
                  // genau der Stand, den der Server kennt.
                  onPressed: _busy || _dirty || _items.isEmpty ? null : _finalize,
                  child: const Text('Finalisieren'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ItemDialog extends StatefulWidget {
  const _ItemDialog({required this.articles});
  final List<OnlineArticle> articles;

  @override
  State<_ItemDialog> createState() => _ItemDialogState();
}

class _ItemDialogState extends State<_ItemDialog> {
  OnlineItemKind _kind = OnlineItemKind.hours;
  OnlineArticle? _article;
  final _description = TextEditingController();
  final _quantity = TextEditingController(text: '1');
  final _price = TextEditingController();
  final _unit = TextEditingController();
  final _group = TextEditingController();
  double _vat = 19;
  String? _error;

  @override
  void dispose() {
    for (final c in [_description, _quantity, _price, _unit, _group]) {
      c.dispose();
    }
    super.dispose();
  }

  void _pickArticle(OnlineArticle? article) {
    setState(() {
      _article = article;
      if (article != null) {
        _description.text = article.name;
        _unit.text = article.unit ?? '';
        if (article.salePriceCents != null) _price.text = Money.fromCents(article.salePriceCents!).formatEuro();
      }
    });
  }

  void _submit() {
    final quantity = Decimal.tryParse(_quantity.text.trim().replaceAll(',', '.'));
    if (_description.text.trim().isEmpty || quantity == null || _price.text.trim().isEmpty) {
      setState(() => _error = 'Beschreibung, Menge und Einzelpreis sind Pflicht.');
      return;
    }
    final Money price;
    try {
      price = Money.fromEuroString(_price.text);
    } on FormatException {
      setState(() => _error = 'Einzelpreis ist keine gültige Zahl.');
      return;
    }
    Navigator.pop(
      context,
      OnlineDocumentItem(
        kind: _kind,
        articleId: _kind == OnlineItemKind.article ? _article?.id : null,
        description: _description.text.trim(),
        quantity: quantity.toString(),
        unitPriceCents: price.cents,
        vatRatePercent: _vat,
        unit: _unit.text.trim().isEmpty ? null : _unit.text.trim(),
        groupLabel: _group.text.trim().isEmpty ? null : _group.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Position'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SegmentedButton<OnlineItemKind>(
                segments: const [
                  ButtonSegment(value: OnlineItemKind.article, label: Text('Artikel')),
                  ButtonSegment(value: OnlineItemKind.hours, label: Text('Stunden')),
                  ButtonSegment(value: OnlineItemKind.text, label: Text('Freitext')),
                ],
                selected: {_kind},
                onSelectionChanged: (s) => setState(() => _kind = s.first),
              ),
              if (_kind == OnlineItemKind.article && widget.articles.isNotEmpty)
                DropdownButtonFormField<OnlineArticle>(
                  initialValue: _article,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Artikel aus Stamm (optional)'),
                  items: [
                    for (final a in widget.articles.where((a) => a.active))
                      DropdownMenuItem(value: a, child: Text(a.name, overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged: _pickArticle,
                ),
              TextField(key: const Key('online-item-description'), controller: _description, decoration: const InputDecoration(labelText: 'Beschreibung *')),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('online-item-quantity'),
                      controller: _quantity,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Menge *'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: TextField(controller: _unit, decoration: const InputDecoration(labelText: 'Einheit'))),
                ],
              ),
              TextField(
                key: const Key('online-item-price'),
                controller: _price,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Einzelpreis netto (€) *'),
              ),
              DropdownButtonFormField<double>(
                initialValue: _vat,
                decoration: const InputDecoration(labelText: 'USt-Satz'),
                items: const [
                  DropdownMenuItem(value: 19, child: Text('19 %')),
                  DropdownMenuItem(value: 7, child: Text('7 %')),
                  DropdownMenuItem(value: 0, child: Text('0 %')),
                ],
                onChanged: (v) => setState(() => _vat = v!),
              ),
              TextField(controller: _group, decoration: const InputDecoration(labelText: 'Positionsgruppe (optional)')),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
        FilledButton(onPressed: _submit, child: const Text('Übernehmen')),
      ],
    );
  }
}
