import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/database/database.dart';
import '../../data/database/tables.dart';
import '../../data/repositories/article_repository.dart';
import '../../domain/models/money.dart';
import '../../domain/services/active_company_service.dart';

/// Dialog zum Hinzufügen einer Rechnungsposition — Artikel, Stunden oder
/// Freitext (A2: alle drei ohne Pflicht auf einen Artikelstamm-Bezug,
/// außer bei der Artikel-Position selbst).
Future<InvoiceItemInputResult?> showInvoiceItemDialog({
  required BuildContext context,
  required List<Article> articles,
}) {
  return showDialog<InvoiceItemInputResult>(
    context: context,
    builder: (context) => _InvoiceItemDialog(articles: articles),
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
  const _InvoiceItemDialog({required this.articles});
  final List<Article> articles;

  @override
  State<_InvoiceItemDialog> createState() => _InvoiceItemDialogState();
}

class _InvoiceItemDialogState extends State<_InvoiceItemDialog> {
  InvoiceItemKind _kind = InvoiceItemKind.text;
  Article? _selectedArticle;
  final _descriptionCtrl = TextEditingController();
  final _quantityCtrl = TextEditingController(text: '1');
  final _priceCtrl = TextEditingController();
  final _groupCtrl = TextEditingController();
  double _vatRate = 19;

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
      title: const Text('Position hinzufügen'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SegmentedButton<InvoiceItemKind>(
                segments: const [
                  ButtonSegment(value: InvoiceItemKind.article, label: Text('Artikel')),
                  ButtonSegment(value: InvoiceItemKind.hours, label: Text('Stunden')),
                  ButtonSegment(value: InvoiceItemKind.text, label: Text('Freitext')),
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
              TextField(
                controller: _groupCtrl,
                decoration: const InputDecoration(
                  labelText: 'Positionsgruppe (optional)',
                  hintText: 'z. B. „Bad", „Küche"',
                ),
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
          child: const Text('Hinzufügen'),
        ),
      ],
    );
  }
}
