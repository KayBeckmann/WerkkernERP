import 'package:flutter/material.dart';

import '../../data/database/database.dart';
import '../../data/repositories/invoice_repository.dart' show WithdrawalSuggestion;
import '../../data/repositories/stock_ledger.dart';
import '../screens/articles_screen.dart' show formatArticleQuantity;

typedef BinEntry = ({StorageLocation location, StorageBin bin});

/// Auswahl eines Lagerplatzes (C5.4). `''` = „Platz noch nicht
/// zugeordnet“. Optional mit Mengenangabe je Platz ([quantities]).
class StorageBinDropdown extends StatelessWidget {
  const StorageBinDropdown({
    super.key,
    required this.bins,
    required this.value,
    required this.onChanged,
    this.label = 'Lagerplatz',
    this.quantities = const {},
    this.allowUnassigned = true,
    this.unassignedLabel = 'Platz noch nicht zugeordnet',
  });

  final List<BinEntry> bins;
  final String? value;
  final ValueChanged<String?> onChanged;
  final String label;
  final Map<String, double> quantities;
  final bool allowUnassigned;
  final String unassignedLabel;

  String _withQty(String text, String key) =>
      quantities.containsKey(key) ? '$text (${formatArticleQuantity(quantities[key]!)})' : text;

  @override
  Widget build(BuildContext context) {
    final keys = {if (allowUnassigned) unassignedBinKey, for (final e in bins) e.bin.id};
    return DropdownButtonFormField<String>(
      isExpanded: true,
      initialValue: keys.contains(value) ? value : null,
      decoration: InputDecoration(labelText: label),
      items: [
        if (allowUnassigned)
          DropdownMenuItem(value: unassignedBinKey, child: Text(_withQty(unassignedLabel, unassignedBinKey), overflow: TextOverflow.ellipsis)),
        for (final e in bins)
          DropdownMenuItem(
            value: e.bin.id,
            child: Text(_withQty(storageBinLabel(e.bin, locationName: e.location.name), e.bin.id), overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: onChanged,
    );
  }
}

/// Kay (16.11.2026): „Bei Entnahme auch einen Lagerplatz vorschlagen,
/// wenn einer hinterlegt ist.“ Dialog vor dem Finalisieren: je Artikel
/// der vorgeschlagene Platz, änderbar. `null` = abgebrochen.
Future<Map<String, String>?> showWithdrawalBinsDialog(
  BuildContext context, {
  required List<WithdrawalSuggestion> suggestions,
  required List<BinEntry> bins,
}) {
  return showDialog<Map<String, String>>(
    context: context,
    builder: (_) => _WithdrawalDialog(suggestions: suggestions, bins: bins),
  );
}

class _WithdrawalDialog extends StatefulWidget {
  const _WithdrawalDialog({required this.suggestions, required this.bins});
  final List<WithdrawalSuggestion> suggestions;
  final List<BinEntry> bins;

  @override
  State<_WithdrawalDialog> createState() => _WithdrawalDialogState();
}

class _WithdrawalDialogState extends State<_WithdrawalDialog> {
  late final Map<String, String> _choice = {
    for (final s in widget.suggestions) s.article.id: s.suggestedBinKey,
  };

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Entnahme aus Lagerplatz'),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Vorgeschlagen ist der Platz mit dem meisten Bestand, sonst der Standardplatz. '
                'Reicht der Platz nicht, wird der Rest von weiteren Plätzen entnommen.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              for (final s in widget.suggestions)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: StorageBinDropdown(
                    key: Key('withdrawal-bin-${s.article.id}'),
                    bins: widget.bins,
                    value: _choice[s.article.id],
                    label: '${s.article.name}: ${formatArticleQuantity(s.quantity)} entnehmen aus',
                    quantities: {for (final b in s.stocks) b.binKey: b.quantity},
                    onChanged: (v) => setState(() => _choice[s.article.id] = v ?? unassignedBinKey),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
        FilledButton(onPressed: () => Navigator.pop(context, _choice), child: const Text('Weiter')),
      ],
    );
  }
}
