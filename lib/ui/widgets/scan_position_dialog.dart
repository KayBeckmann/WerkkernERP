import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

/// C5.5-Nachtrag (Kay, 16.11.2026): Ergebnis nach dem Scan eines Artikels.
class ScannedPositionResult {
  const ScannedPositionResult({required this.quantity, this.groupLabel, required this.addToExisting});

  /// Tatsächlich verbaute Menge — vom Monteur eingegeben, nie aus dem Code.
  final Decimal quantity;
  final String? groupLabel;

  /// `true` = Menge zur vorhandenen Position desselben Artikels in
  /// derselben Gruppe addieren; `false` = eigene Position.
  final bool addToExisting;
}

/// Dialog nach dem Scan: erkannter Artikel mit Einheit, Pflichtfeld Menge,
/// Positionsgruppe (Kay-Entscheidung 2026-11-16: derselbe Artikel darf in
/// verschiedenen Gruppen stehen). Steht der Artikel in der gewählten Gruppe
/// schon im Beleg, entscheidet der Monteur ausdrücklich zwischen
/// „addieren“ und „neue Position“ — nie unbemerkt doppelt.
Future<ScannedPositionResult?> showScannedArticleDialog(
  BuildContext context, {
  required String articleName,
  String? unit,
  required List<String> groupLabels,
  required Decimal? Function(String? groupLabel) existingQuantityInGroup,
}) =>
    showDialog<ScannedPositionResult>(
      context: context,
      builder: (_) => _ScannedArticleDialog(
        articleName: articleName,
        unit: unit,
        groupLabels: groupLabels,
        existingQuantityInGroup: existingQuantityInGroup,
      ),
    );

class _ScannedArticleDialog extends StatefulWidget {
  const _ScannedArticleDialog({
    required this.articleName,
    required this.unit,
    required this.groupLabels,
    required this.existingQuantityInGroup,
  });
  final String articleName;
  final String? unit;
  final List<String> groupLabels;
  final Decimal? Function(String? groupLabel) existingQuantityInGroup;

  @override
  State<_ScannedArticleDialog> createState() => _ScannedArticleDialogState();
}

class _ScannedArticleDialogState extends State<_ScannedArticleDialog> {
  final _quantity = TextEditingController();
  final _group = TextEditingController();
  final _groupFocus = FocusNode();
  String? _error;

  @override
  void dispose() {
    _quantity.dispose();
    _group.dispose();
    _groupFocus.dispose();
    super.dispose();
  }

  String? get _groupLabel => _group.text.trim().isEmpty ? null : _group.text.trim();

  void _submit({required bool addToExisting}) {
    final parsed = Decimal.tryParse(_quantity.text.trim().replaceAll(',', '.'));
    if (parsed == null || parsed <= Decimal.zero) {
      setState(() => _error = 'Bitte die verbaute Menge eingeben (größer 0).');
      return;
    }
    Navigator.pop(context, ScannedPositionResult(quantity: parsed, groupLabel: _groupLabel, addToExisting: addToExisting));
  }

  @override
  Widget build(BuildContext context) {
    final existing = widget.existingQuantityInGroup(_groupLabel);
    final unit = widget.unit == null ? '' : ' ${widget.unit}';
    return AlertDialog(
      title: const Text('Artikel erkannt'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.articleName, style: Theme.of(context).textTheme.titleMedium),
            if (widget.unit != null) Text('Einheit: ${widget.unit}'),
            const SizedBox(height: 8),
            TextField(
              key: const Key('scan-quantity'),
              controller: _quantity,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: 'Verbaute Menge *', suffixText: widget.unit, errorText: _error),
            ),
            Autocomplete<String>(
              textEditingController: _group,
              focusNode: _groupFocus,
              optionsBuilder: (value) => widget.groupLabels
                  .where((g) => g.toLowerCase().contains(value.text.toLowerCase())),
              onSelected: (_) => setState(() {}),
              fieldViewBuilder: (context, controller, focusNode, onSubmit) => TextField(
                key: const Key('scan-group'),
                controller: controller,
                focusNode: focusNode,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(labelText: 'Positionsgruppe (optional)'),
              ),
            ),
            if (existing != null) ...[
              const SizedBox(height: 12),
              Text(
                'Dieser Artikel steht in ${_groupLabel == null ? 'der Liste ohne Gruppe' : 'der Gruppe „$_groupLabel“'} '
                'bereits mit $existing$unit. Menge addieren oder als eigene Position anlegen?',
                style: TextStyle(color: Theme.of(context).colorScheme.tertiary),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
        if (existing != null) ...[
          TextButton(onPressed: () => _submit(addToExisting: false), child: const Text('Als neue Position')),
          FilledButton(onPressed: () => _submit(addToExisting: true), child: const Text('Zur Position addieren')),
        ] else
          FilledButton(onPressed: () => _submit(addToExisting: false), child: const Text('Hinzufügen')),
      ],
    );
  }
}
