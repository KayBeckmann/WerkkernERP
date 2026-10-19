import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/database/database.dart';
import '../../data/database/tables.dart';
import '../../data/repositories/inventory_repository.dart';
import '../../domain/services/active_company_service.dart';
import 'inventory_count_detail_screen.dart';

/// Inventur-Läufe der aktiven Firma (C5.3 Bestandsbuchhaltung, Nachtrag
/// 2026-10-19: "Wir müssen auch Inventur vorsehen" — Kay-Entscheidung
/// auf Rückfrage: "Volle Inventur-Sitzung"). Gleiches Listen-Muster wie
/// `PurchaseOrdersScreen`.
class InventoryCountsScreen extends StatefulWidget {
  const InventoryCountsScreen({super.key});

  @override
  State<InventoryCountsScreen> createState() => _InventoryCountsScreenState();
}

class _InventoryCountsScreenState extends State<InventoryCountsScreen> {
  late Future<List<InventoryCount>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<InventoryCount>> _load() {
    final companyId = context.read<ActiveCompanyService>().active!.id;
    return context.read<InventoryRepository>().listForCompany(companyId);
  }

  void _reload() => setState(() {
        _future = _load();
      });

  Future<void> _startCount() async {
    final label = await showDialog<String>(
      context: context,
      builder: (context) => const _StartCountDialog(),
    );
    if (label == null || !mounted) return;
    final companyId = context.read<ActiveCompanyService>().active!.id;
    final count = await context.read<InventoryRepository>().startCount(
          companyId: companyId,
          label: label,
        );
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => InventoryCountDetailScreen(inventoryCountId: count.id)),
    );
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<List<InventoryCount>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final counts = snapshot.data!;
          if (counts.isEmpty) {
            return const Center(child: Text('Noch keine Inventur durchgeführt.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
            itemCount: counts.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final count = counts[index];
              return Card(
                child: ListTile(
                  leading: Icon(
                    count.status == InventoryCountStatus.completed
                        ? Icons.fact_check_outlined
                        : Icons.edit_note_outlined,
                  ),
                  title: Text(count.label),
                  subtitle: Text(
                    count.status == InventoryCountStatus.completed ? 'Abgeschlossen' : 'Entwurf',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => InventoryCountDetailScreen(inventoryCountId: count.id),
                      ),
                    );
                    _reload();
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'inventory-counts-fab',
        onPressed: _startCount,
        icon: const Icon(Icons.add),
        label: const Text('Neue Inventur'),
      ),
    );
  }
}

class _StartCountDialog extends StatefulWidget {
  const _StartCountDialog();

  @override
  State<_StartCountDialog> createState() => _StartCountDialogState();
}

class _StartCountDialogState extends State<_StartCountDialog> {
  final _labelCtrl = TextEditingController();

  @override
  void dispose() {
    _labelCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Neue Inventur'),
      content: TextField(
        controller: _labelCtrl,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: 'Bezeichnung *',
          hintText: 'z. B. "Jahresinventur 2026"',
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
        FilledButton(
          onPressed: () {
            final label = _labelCtrl.text.trim();
            if (label.isEmpty) return;
            Navigator.pop(context, label);
          },
          child: const Text('Starten'),
        ),
      ],
    );
  }
}
