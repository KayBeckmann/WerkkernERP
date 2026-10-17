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
    this.unit,
    this.discountPercent = 0,
    this.groupLabel,
  });

  final InvoiceItemKind kind;
  final String? articleId;
  final String description;
  final Decimal quantity;
  final int unitPriceCents;
  final double vatRatePercent;

  /// Einheit (z. B. "Stk", "h", "m") — Kay-Nachtrag 2026-10-16: "Es
  /// fehlen Details" beim Vergleich mit RechnungsFee.
  final String? unit;

  /// Rabatt in Prozent auf diese Position — Kay-Nachtrag 2026-10-16.
  final double discountPercent;
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
  late final _unitCtrl = TextEditingController(text: widget.existing?.unit);
  late final _discountCtrl = TextEditingController(
    text: (widget.existing?.discountPercent ?? 0) == 0
        ? ''
        : widget.existing!.discountPercent.toString(),
  );
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
    _unitCtrl.dispose();
    _discountCtrl.dispose();
    super.dispose();
  }

  Future<void> _applyArticleDefaults(Article article) async {
    final companyId = context.read<ActiveCompanyService>().active!.id;
    final price = await context.read<ArticleRepository>().effectiveSalePrice(
          companyId: companyId,
          articleId: article.id,
        );
    // Dialog kann waehrend des Preis-Lookups bereits geschlossen worden
    // sein (z. B. schnelles Abbrechen) — ohne diesen Check wuerden
    // setState() UND der Zugriff auf die (dann schon dispose()ten)
    // Controller darunter einen Absturz auslösen (siehe gleiche
    // Fehlerklasse in email_send_dialog.dart/settings_screen.dart).
    if (!mounted) return;
    setState(() {
      _selectedArticle = article;
      _descriptionCtrl.text = article.name;
      if (price != null) _priceCtrl.text = price.formatEuro();
      // Einheit vom Artikelstamm übernehmen (Kay-Nachtrag 2026-10-16) —
      // bisher trug Article.unit zwar den Stammdaten-Wert, wurde aber
      // nie tatsächlich in eine Position übernommen.
      if (article.unit != null) _unitCtrl.text = article.unit!;
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
                    flex: 2,
                    child: TextField(
                      controller: _quantityCtrl,
                      decoration: InputDecoration(
                        labelText: _kind == InvoiceItemKind.hours ? 'Stunden' : 'Menge',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Einheit (Kay-Nachtrag 2026-10-16: "Es fehlen Details"
                  // im Vergleich mit RechnungsFee) — bisher gab es gar
                  // kein Feld dafür, nur "10 × 2,50 €" ohne Angabe, ob
                  // das Stück, Meter oder Stunden sind.
                  Expanded(
                    child: TextField(
                      controller: _unitCtrl,
                      decoration: const InputDecoration(labelText: 'Einheit', hintText: 'Stk'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _priceCtrl,
                decoration: const InputDecoration(labelText: 'Einzelpreis (€) *'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<double>(
                      isExpanded: true,
                      initialValue: _vatRate,
                      decoration: const InputDecoration(labelText: 'MwSt.'),
                      items: const [
                        DropdownMenuItem(value: 19.0, child: Text('19 %')),
                        DropdownMenuItem(value: 7.0, child: Text('7 %')),
                        DropdownMenuItem(value: 0.0, child: Text('0 %')),
                      ],
                      onChanged: (value) => setState(() => _vatRate = value ?? 19),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Rabatt pro Position (Kay-Nachtrag 2026-10-16, analog
                  // zu RechnungsFees Positionsrabatt) — wirkt auf den
                  // Netto-Betrag vor der Steuerberechnung, siehe
                  // InvoiceLineInput.lineNet.
                  Expanded(
                    child: TextField(
                      controller: _discountCtrl,
                      decoration: const InputDecoration(labelText: 'Rabatt %', hintText: '0'),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                ],
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
            final discount = double.tryParse(_discountCtrl.text.trim().replaceAll(',', '.')) ?? 0;
            Navigator.pop(
              context,
              InvoiceItemInputResult(
                kind: _kind,
                articleId: _kind == InvoiceItemKind.article ? _selectedArticle?.id : null,
                description: description,
                quantity: quantity,
                unitPriceCents: price.cents,
                vatRatePercent: _vatRate,
                unit: _unitCtrl.text.trim().isEmpty ? null : _unitCtrl.text.trim(),
                discountPercent: discount.clamp(0, 100),
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
