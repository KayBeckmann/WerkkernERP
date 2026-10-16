import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/database/database.dart';
import '../../data/database/tables.dart';
import '../../data/repositories/article_repository.dart';
import '../../domain/models/money.dart';
import '../../domain/services/active_company_service.dart';

/// Dialog zum Hinzufügen **oder Bearbeiten** einer Rechnungsposition —
/// Artikel, Stunden oder Freitext (A2: alle drei ohne Pflicht auf einen
/// Artikelstamm-Bezug, außer bei der Artikel-Position selbst).
///
/// Bearbeiten-Unterstützung (Kay-Nachtrag 2026-10-16: "Positionen ...
/// nachträglich noch bearbeiten können") — vorher ließ sich eine
/// bestehende Position nur löschen und neu anlegen.
Future<InvoiceItemInputResult?> showInvoiceItemDialog({
  required BuildContext context,
  required List<Article> articles,
  List<String> existingGroupLabels = const [],
  InvoiceItemInputResult? existing,
  bool allowHours = true,
}) {
  return showDialog<InvoiceItemInputResult>(
    context: context,
    builder: (context) => _InvoiceItemDialog(
      articles: articles,
      existingGroupLabels: existingGroupLabels,
      existing: existing,
      allowHours: allowHours,
    ),
  );
}

class InvoiceItemInputResult {
  const InvoiceItemInputResult({
    required this.kind,
    this.articleId,
    required this.description,
    required this.quantity,
    required this.unitPriceCents,
    required this.vatRatePercent,
    this.groupLabel,
  });

  final InvoiceItemKind kind;
  final String? articleId;
  final String description;
  final Decimal quantity;
  final int unitPriceCents;
  final double vatRatePercent;
  final String? groupLabel;
}

class _InvoiceItemDialog extends StatefulWidget {
  const _InvoiceItemDialog({
    required this.articles,
    required this.existingGroupLabels,
    this.existing,
    this.allowHours = true,
  });
  final List<Article> articles;
  final List<String> existingGroupLabels;
  final InvoiceItemInputResult? existing;

  /// `false` für Lieferscheine (Kay: "Lieferscheine sollen KEINE
  /// Stunden enthalten!!!") — blendet das Segment aus statt nur die
  /// Auswahl im Nachhinein abzulehnen.
  final bool allowHours;

  bool get isEdit => existing != null;

  @override
  State<_InvoiceItemDialog> createState() => _InvoiceItemDialogState();
}

class _InvoiceItemDialogState extends State<_InvoiceItemDialog> {
  late InvoiceItemKind _kind = widget.existing?.kind ?? InvoiceItemKind.text;
  Article? _selectedArticle;
  late final _descriptionCtrl = TextEditingController(text: widget.existing?.description);
  late final _quantityCtrl =
      TextEditingController(text: widget.existing?.quantity.toString() ?? '1');
  late final _priceCtrl = TextEditingController(
    text: widget.existing == null ? null : Money.fromCents(widget.existing!.unitPriceCents).formatEuro(),
  );
  late final _groupCtrl = TextEditingController(text: widget.existing?.groupLabel);
  late double _vatRate = widget.existing?.vatRatePercent ?? 19;

  @override
  void initState() {
    super.initState();
    final articleId = widget.existing?.articleId;
    if (articleId != null) {
      _selectedArticle = widget.articles.where((a) => a.id == articleId).firstOrNull;
    }
  }

  @override
  void dispose() {
    _descriptionCtrl.dispose();
    _quantityCtrl.dispose();
    _priceCtrl.dispose();
    _groupCtrl.dispose();
    super.dispose();
  }

  Future<void> _applyArticleDefaults(Article article) async {
    final companyId = context.read<ActiveCompanyService>().active!.id;
    final price = await context.read<ArticleRepository>().effectiveSalePrice(
          companyId: companyId,
          articleId: article.id,
        );
    setState(() {
      _selectedArticle = article;
      _descriptionCtrl.text = article.name;
      if (price != null) _priceCtrl.text = price.formatEuro();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.isEdit ? 'Position bearbeiten' : 'Position hinzufügen'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SegmentedButton<InvoiceItemKind>(
                segments: [
                  const ButtonSegment(value: InvoiceItemKind.article, label: Text('Artikel')),
                  if (widget.allowHours)
                    const ButtonSegment(value: InvoiceItemKind.hours, label: Text('Stunden')),
                  const ButtonSegment(value: InvoiceItemKind.text, label: Text('Freitext')),
                ],
                selected: {_kind},
                onSelectionChanged: (selection) => setState(() => _kind = selection.first),
              ),
              const SizedBox(height: 12),
              if (_kind == InvoiceItemKind.article)
                DropdownButtonFormField<Article>(
                  isExpanded: true,
                  initialValue: _selectedArticle,
                  decoration: const InputDecoration(labelText: 'Artikel'),
                  items: [
                    for (final article in widget.articles)
                      DropdownMenuItem(value: article, child: Text(article.name)),
                  ],
                  onChanged: (article) {
                    if (article != null) _applyArticleDefaults(article);
                  },
                ),
              TextField(
                controller: _descriptionCtrl,
                decoration: const InputDecoration(labelText: 'Beschreibung *'),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _quantityCtrl,
                      decoration: InputDecoration(
                        labelText: _kind == InvoiceItemKind.hours ? 'Stunden' : 'Menge',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _priceCtrl,
                      decoration: const InputDecoration(labelText: 'Einzelpreis (€) *'),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                ],
              ),
              DropdownButtonFormField<double>(
                isExpanded: true,
                initialValue: _vatRate,
                decoration: const InputDecoration(labelText: 'MwSt.'),
                items: const [
                  DropdownMenuItem(value: 19.0, child: Text('19 % (Standard)')),
                  DropdownMenuItem(value: 7.0, child: Text('7 % (ermäßigt)')),
                  DropdownMenuItem(value: 0.0, child: Text('0 % (ohne Steuerbetrag)')),
                ],
                onChanged: (value) => setState(() => _vatRate = value ?? 19),
              ),
              // Autocomplete statt reinem Freitext (Kay-Nachtrag
              // 2026-10-16: "Dropdown für Positionsgruppen, die es schon
              // gibt") — schlägt bereits im Dokument verwendete Gruppen
              // vor (vermeidet Tippfehler-Dubletten wie "Bad"/"bad"),
              // lässt aber weiterhin eine neue Gruppe frei eintippen.
              Autocomplete<String>(
                initialValue: TextEditingValue(text: _groupCtrl.text),
                optionsBuilder: (value) {
                  if (value.text.isEmpty) return widget.existingGroupLabels;
                  final query = value.text.toLowerCase();
                  return widget.existingGroupLabels
                      .where((label) => label.toLowerCase().contains(query));
                },
                onSelected: (value) => _groupCtrl.text = value,
                fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                  // Eigenen Controller mit `_groupCtrl` synchron halten,
                  // damit der Wert auch ohne explizite Options-Auswahl
                  // (reine Freitext-Eingabe) beim Speichern ankommt.
                  controller.addListener(() => _groupCtrl.text = controller.text);
                  return TextField(
                    controller: controller,
                    focusNode: focusNode,
                    decoration: const InputDecoration(
                      labelText: 'Positionsgruppe (optional)',
                      hintText: 'z. B. „Bad", „Küche"',
                    ),
                    // Ohne das schließt z.B. die Eingabetaste/"Fertig" auf
                    // der Tastatur das Options-Overlay nicht richtig.
                    onSubmitted: (_) => onFieldSubmitted(),
                  );
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
        FilledButton(
          onPressed: () {
            final description = _descriptionCtrl.text.trim();
            final quantity = Decimal.tryParse(_quantityCtrl.text.trim().replaceAll(',', '.'));
            if (description.isEmpty || quantity == null || _priceCtrl.text.trim().isEmpty) return;
            final price = Money.fromEuroString(_priceCtrl.text);
            Navigator.pop(
              context,
              InvoiceItemInputResult(
                kind: _kind,
                articleId: _kind == InvoiceItemKind.article ? _selectedArticle?.id : null,
                description: description,
                quantity: quantity,
                unitPriceCents: price.cents,
                vatRatePercent: _vatRate,
                groupLabel: _groupCtrl.text.trim().isEmpty ? null : _groupCtrl.text.trim(),
              ),
            );
          },
          child: Text(widget.isEdit ? 'Speichern' : 'Hinzufügen'),
        ),
      ],
    );
  }
}
