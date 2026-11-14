import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:werkkern_client/werkkern_client.dart';
import 'package:werkkern_core/werkkern_core.dart';

/// Position hinzufügen **oder bearbeiten** — gleicher Dialog wie offline
/// (`invoice_item_dialog.dart`): Artikel/Stunden/Freitext, Einheit,
/// Rabatt, Positionsgruppe mit Vorschlägen aus dem Dokument. Für
/// Dokumente und wiederkehrende Vorlagen.
Future<OnlineDocumentItem?> showOnlineItemDialog(
  BuildContext context, {
  required List<OnlineArticle> articles,
  List<String> existingGroupLabels = const [],
  OnlineDocumentItem? existing,
  // Lieferscheine enthalten keine Stunden (wie offline).
  bool allowHours = true,
  // Kleinunternehmerregelung (§ 19 UStG): USt fest 0 % (der Server
  // erzwingt es ohnehin).
  bool forceZeroVat = false,
  // C3.4: Rollen für Stunden-Positionen; leer = keine Rollenauswahl.
  List<OnlineStaffRole> staffRoles = const [],
}) {
  return showDialog<OnlineDocumentItem>(
    context: context,
    builder: (_) => _OnlineItemDialog(
      articles: articles,
      existingGroupLabels: existingGroupLabels,
      existing: existing,
      allowHours: allowHours,
      forceZeroVat: forceZeroVat,
      staffRoles: staffRoles,
    ),
  );
}

/// Bereits im Dokument verwendete Positionsgruppen, sortiert.
List<String> onlineGroupLabels(Iterable<OnlineDocumentItem> items) =>
    {for (final item in items) ?item.groupLabel}.toList()..sort();

class _OnlineItemDialog extends StatefulWidget {
  const _OnlineItemDialog({
    required this.articles,
    required this.existingGroupLabels,
    this.existing,
    required this.allowHours,
    required this.forceZeroVat,
    required this.staffRoles,
  });
  final List<OnlineArticle> articles;
  final List<String> existingGroupLabels;
  final OnlineDocumentItem? existing;
  final bool allowHours;
  final bool forceZeroVat;
  final List<OnlineStaffRole> staffRoles;

  bool get isEdit => existing != null;

  @override
  State<_OnlineItemDialog> createState() => _OnlineItemDialogState();
}

class _OnlineItemDialogState extends State<_OnlineItemDialog> {
  late OnlineItemKind _kind = widget.existing?.kind ?? OnlineItemKind.text;
  OnlineArticle? _article;
  late final _description = TextEditingController(text: widget.existing?.description);
  late final _quantity = TextEditingController(text: widget.existing?.quantity.replaceAll('.', ',') ?? '1');
  late final _price = TextEditingController(
    text: widget.existing == null ? null : Money.fromCents(widget.existing!.unitPriceCents).formatEuro(),
  );
  late final _unit = TextEditingController(text: widget.existing?.unit);
  late final _discount = TextEditingController(
    text: (widget.existing?.discountPercent ?? 0) == 0 ? '' : _formatPercent(widget.existing!.discountPercent),
  );
  late final _group = TextEditingController(text: widget.existing?.groupLabel);
  late double _vat = widget.forceZeroVat ? 0 : (widget.existing?.vatRatePercent ?? 19);
  String? _error;

  /// Gelöschte Rolle → „ohne Rolle“, damit das Dropdown einen gültigen
  /// Wert hat.
  late String? _staffRoleId = widget.staffRoles.any((r) => r.id == widget.existing?.staffRoleId)
      ? widget.existing!.staffRoleId
      : null;

  /// Zuletzt aus der Rolle vorbelegte Werte — nur diese werden bei einem
  /// Rollenwechsel ersetzt (wie offline).
  String? _autoPrice;
  String? _autoDescription;

  OnlineStaffRole? get _selectedRole => widget.staffRoles.where((r) => r.id == _staffRoleId).firstOrNull;

  void _selectKind(OnlineItemKind kind) {
    setState(() {
      // C3.4: Stunden haben die Einheit „h“ vorbelegt.
      if (kind == OnlineItemKind.hours && _unit.text.trim().isEmpty) _unit.text = hoursUnit;
      if (kind != OnlineItemKind.hours && _kind == OnlineItemKind.hours && _unit.text.trim() == hoursUnit) _unit.clear();
      _kind = kind;
    });
  }

  /// Rolle gewählt: Preis = Verrechnungssatz, Beschreibung = Rollenname,
  /// solange leer bzw. noch der letzte Vorschlag; ohne Satz bleibt der
  /// Preis leer (Kay 2026-11-03).
  void _selectRole(String? roleId) {
    setState(() {
      _staffRoleId = roleId;
      final role = _selectedRole;
      if (role == null) return;
      final price = _price.text.trim();
      if (price.isEmpty || price == _autoPrice) {
        final rate = resolveHourlyBillingRateCents(roleBillingRateCents: role.hourlyBillingCents);
        _autoPrice = rate == null ? '' : Money.fromCents(rate).formatEuro();
        _price.text = _autoPrice!;
      }
      final description = _description.text.trim();
      if (description.isEmpty || description == _autoDescription) {
        _autoDescription = role.name;
        _description.text = role.name;
      }
    });
  }

  static String _formatPercent(double value) =>
      (value == value.roundToDouble() ? value.toStringAsFixed(0) : value.toString()).replaceAll('.', ',');

  List<OnlineArticle> get _articleChoices => [
        for (final a in widget.articles)
          if (a.active || a.id == widget.existing?.articleId) a,
      ];

  @override
  void initState() {
    super.initState();
    final articleId = widget.existing?.articleId;
    if (articleId != null) _article = widget.articles.where((a) => a.id == articleId).firstOrNull;
  }

  @override
  void dispose() {
    for (final c in [_description, _quantity, _price, _unit, _discount, _group]) {
      c.dispose();
    }
    super.dispose();
  }

  void _pickArticle(OnlineArticle article) {
    setState(() {
      _article = article;
      _description.text = article.name;
      if (article.unit != null) _unit.text = article.unit!;
      if (article.effectiveSalePriceCents != null) _price.text = Money.fromCents(article.effectiveSalePriceCents!).formatEuro();
    });
  }

  void _submit() {
    final description = _description.text.trim();
    final quantity = Decimal.tryParse(_quantity.text.trim().replaceAll(',', '.'));
    if (description.isEmpty || quantity == null || _price.text.trim().isEmpty) {
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
    final discount = double.tryParse(_discount.text.trim().replaceAll(',', '.')) ?? 0;
    Navigator.pop(
      context,
      OnlineDocumentItem(
        kind: _kind,
        articleId: _kind == OnlineItemKind.article ? _article?.id : null,
        description: description,
        quantity: quantity.toString(),
        unitPriceCents: price.cents,
        vatRatePercent: _vat,
        unit: _unit.text.trim().isEmpty ? null : _unit.text.trim(),
        discountPercent: discount.clamp(0, 100).toDouble(),
        groupLabel: _group.text.trim().isEmpty ? null : _group.text.trim(),
        staffRoleId: _kind == OnlineItemKind.hours ? _staffRoleId : null,
      ),
    );
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
              SegmentedButton<OnlineItemKind>(
                segments: [
                  const ButtonSegment(value: OnlineItemKind.article, label: Text('Artikel')),
                  if (widget.allowHours || _kind == OnlineItemKind.hours)
                    const ButtonSegment(value: OnlineItemKind.hours, label: Text('Stunden')),
                  const ButtonSegment(value: OnlineItemKind.text, label: Text('Freitext')),
                ],
                selected: {_kind},
                onSelectionChanged: (selection) => _selectKind(selection.first),
              ),
              const SizedBox(height: 12),
              if (_kind == OnlineItemKind.hours && widget.staffRoles.isNotEmpty)
                DropdownButtonFormField<String?>(
                  key: const Key('online-item-role'),
                  isExpanded: true,
                  initialValue: _staffRoleId,
                  decoration: InputDecoration(
                    labelText: 'Rolle',
                    helperText: _selectedRole != null && _selectedRole!.hourlyBillingCents == 0
                        ? 'Kein Verrechnungssatz hinterlegt — Preis bitte eingeben.'
                        : null,
                  ),
                  items: [
                    const DropdownMenuItem<String?>(value: null, child: Text('ohne Rolle')),
                    for (final role in widget.staffRoles)
                      DropdownMenuItem<String?>(
                        value: role.id,
                        child: Text(
                          role.hourlyBillingCents == 0
                              ? role.name
                              : '${role.name} · ${Money.fromCents(role.hourlyBillingCents)}/h',
                        ),
                      ),
                  ],
                  onChanged: _selectRole,
                ),
              if (_kind == OnlineItemKind.article && _articleChoices.isNotEmpty)
                DropdownButtonFormField<OnlineArticle>(
                  key: const Key('online-item-article'),
                  isExpanded: true,
                  initialValue: _article,
                  decoration: const InputDecoration(labelText: 'Artikel'),
                  items: [
                    for (final a in _articleChoices)
                      DropdownMenuItem(value: a, child: Text(a.name, overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged: (article) {
                    if (article != null) _pickArticle(article);
                  },
                ),
              TextField(
                key: const Key('online-item-description'),
                controller: _description,
                decoration: const InputDecoration(labelText: 'Beschreibung *'),
              ),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      key: const Key('online-item-quantity'),
                      controller: _quantity,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(labelText: _kind == OnlineItemKind.hours ? 'Stunden' : 'Menge'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _unit,
                      decoration: const InputDecoration(labelText: 'Einheit', hintText: 'Stk'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                key: const Key('online-item-price'),
                controller: _price,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                    labelText: widget.forceZeroVat ? 'Einzelpreis brutto (€) *' : 'Einzelpreis (€) *'),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (!widget.forceZeroVat) Expanded(
                    child: DropdownButtonFormField<double>(
                            isExpanded: true,
                            initialValue: _vat,
                            decoration: const InputDecoration(labelText: 'MwSt.'),
                            items: const [
                              DropdownMenuItem(value: 19.0, child: Text('19 %')),
                              DropdownMenuItem(value: 7.0, child: Text('7 %')),
                              DropdownMenuItem(value: 0.0, child: Text('0 %')),
                            ],
                            onChanged: (value) => setState(() => _vat = value ?? 19),
                          ),
                  ),
                  if (!widget.forceZeroVat) const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      key: const Key('online-item-discount'),
                      controller: _discount,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Rabatt %', hintText: '0'),
                    ),
                  ),
                ],
              ),
              if (widget.forceZeroVat)
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text('Kleinunternehmerregelung (§ 19 UStG): keine Umsatzsteuer.', style: TextStyle(fontSize: 12)),
                ),
              // Vorschläge aus den Gruppen dieses Dokuments, neue Gruppe
              // weiterhin frei eintippbar.
              Autocomplete<String>(
                initialValue: TextEditingValue(text: _group.text),
                optionsBuilder: (value) {
                  if (value.text.isEmpty) return widget.existingGroupLabels;
                  final query = value.text.toLowerCase();
                  return widget.existingGroupLabels.where((label) => label.toLowerCase().contains(query));
                },
                onSelected: (value) => _group.text = value,
                fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                  controller.addListener(() => _group.text = controller.text);
                  return TextField(
                    key: const Key('online-item-group'),
                    controller: controller,
                    focusNode: focusNode,
                    decoration: const InputDecoration(
                      labelText: 'Positionsgruppe (optional)',
                      hintText: 'z. B. „Bad", „Küche"',
                    ),
                    onSubmitted: (_) => onFieldSubmitted(),
                  );
                },
              ),
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
        FilledButton(onPressed: _submit, child: Text(widget.isEdit ? 'Speichern' : 'Hinzufügen')),
      ],
    );
  }
}
