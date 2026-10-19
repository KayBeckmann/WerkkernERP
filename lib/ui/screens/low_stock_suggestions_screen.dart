import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/repositories/purchase_order_repository.dart';
import '../../domain/services/active_company_service.dart';
import 'purchase_order_detail_screen.dart';

/// Mindestbestand-Meldungen, nach Lieferant gruppiert (C5.2 Bestellwesen,
/// Weg (b) der Roadmap) — live berechnet bei jedem Öffnen, kein eigenes
/// persistiertes Meldungs-Objekt (siehe Doc-Kommentar bei
/// `PurchaseOrderRepository.suggestFromLowStock`).
class LowStockSuggestionsScreen extends StatefulWidget {
  const LowStockSuggestionsScreen({super.key});

  @override
  State<LowStockSuggestionsScreen> createState() => _LowStockSuggestionsScreenState();
}

class _LowStockSuggestionsScreenState extends State<LowStockSuggestionsScreen> {
  late Future<LowStockSuggestions> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<LowStockSuggestions> _load() {
    final companyId = context.read<ActiveCompanyService>().active!.id;
    return context.read<PurchaseOrderRepository>().suggestFromLowStock(companyId);
  }

  String _formatQuantity(double value) =>
      value == value.roundToDouble() ? value.toStringAsFixed(0) : value.toString();

  Future<void> _createDraft(SupplierPurchaseSuggestion suggestion) async {
    if (!suggestion.meetsMinimumOrderQuantity) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Mindestbestellmenge nicht erreicht'),
          content: Text(
            'Die zusammengefasste Menge (${_formatQuantity(suggestion.totalQuantity)}) erreicht nicht '
            'die Mindestbestellmenge von ${suggestion.supplierName} '
            '(${_formatQuantity(suggestion.minimumOrderQuantity!)}). Der Entwurf lässt sich trotzdem '
            'anlegen und vor dem Finalisieren noch anpassen.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Abbrechen')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Trotzdem anlegen')),
          ],
        ),
      );
      if (proceed != true || !mounted) return;
    }
    final companyId = context.read<ActiveCompanyService>().active!.id;
    final draft = await context.read<PurchaseOrderRepository>().createDraftFromSuggestion(
          companyId: companyId,
          suggestion: suggestion,
        );
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PurchaseOrderDetailScreen(purchaseOrderId: draft.id)),
    );
    if (mounted) setState(() => _future = _load());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mindestbestand-Meldungen')),
      body: FutureBuilder<LowStockSuggestions>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data!;
          if (data.bySupplier.isEmpty && data.unassignable.isEmpty) {
            return const Center(child: Text('Aktuell kein Artikel unter Mindestbestand.'));
          }
          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              for (final suggestion in data.bySupplier)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(suggestion.supplierName, style: Theme.of(context).textTheme.titleMedium),
                        for (final item in suggestion.items)
                          Text('${item.description}: ${_formatQuantity(item.quantity)}'),
                        if (!suggestion.meetsMinimumOrderQuantity)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'Unter Mindestbestellmenge (${_formatQuantity(suggestion.minimumOrderQuantity!)})'
                              ' — wird noch nicht erreicht.',
                              style: TextStyle(color: Theme.of(context).colorScheme.error),
                            ),
                          ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: FilledButton(
                            onPressed: () => _createDraft(suggestion),
                            child: const Text('Entwurf anlegen'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              if (data.unassignable.isNotEmpty)
                Card(
                  color: Theme.of(context).colorScheme.errorContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Nicht zuordenbar (kein Standardlieferant/Preis bekannt):'),
                        for (final article in data.unassignable)
                          Text('${article.articleName}: ${_formatQuantity(article.quantity)}'),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
