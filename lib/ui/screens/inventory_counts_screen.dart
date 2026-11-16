import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/database/database.dart';
import '../../data/database/tables.dart';
import '../../data/repositories/inventory_repository.dart';
import '../../data/repositories/storage_repository.dart';
import '../../domain/services/active_company_service.dart';
import 'inventory_count_detail_screen.dart';
import 'storage_locations_screen.dart';

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
    final companyId = context.read<ActiveCompanyService>().active!.id;
    final locations = await context.read<StorageRepository>().locations(companyId);
    if (!mounted) return;
    final result = await showDialog<(String, String?)>(
      context: context,
      builder: (context) => _StartCountDialog(locations: locations),
    );
    if (result == null || !mounted) return;
    final (label, locationId) = result;
    final repo = context.read<InventoryRepository>();
    // C5.4: Inventur nach Lagerort — Positionen je Platz in Laufreihenfolge.
    final count = locationId == null
        ? await repo.startCount(companyId: companyId, label: label)
        : await repo.startLocationCount(companyId: companyId, label: label, locationId: locationId);
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
          final header = Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              key: const Key('open-storage-locations'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const StorageLocationsScreen()),
              ),
              icon: const Icon(Icons.warehouse_outlined),
              label: const Text('Lagerorte & Plätze'),
            ),
          );
          if (counts.isEmpty) {
            return Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [header, const Expanded(child: Center(child: Text('Noch keine Inventur durchgeführt.')))],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
            itemCount: counts.length + 1,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              if (index == 0) return header;
              final count = counts[index - 1];
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
  const _StartCountDialog({this.locations = const []});
  final List<StorageLocation> locations;

  @override
  State<_StartCountDialog> createState() => _StartCountDialogState();
}

class _StartCountDialogState extends State<_StartCountDialog> {
  final _labelCtrl = TextEditingController();
  String? _locationId;

  @override
  void dispose() {
    _labelCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Neue Inventur'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _labelCtrl,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Bezeichnung *',
              hintText: 'z. B. "Jahresinventur 2026"',
            ),
          ),
          if (widget.locations.isNotEmpty)
            DropdownButtonFormField<String?>(
              key: const Key('inventory-location'),
              isExpanded: true,
              initialValue: _locationId,
              decoration: const InputDecoration(labelText: 'Zählen nach'),
              items: [
                const DropdownMenuItem<String?>(value: null, child: Text('Artikeln (frei auswählen)')),
                for (final l in widget.locations)
                  DropdownMenuItem<String?>(value: l.id, child: Text('Lagerort ${l.name} (Platz für Platz)')),
              ],
              onChanged: (v) => setState(() => _locationId = v),
            ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
        FilledButton(
          onPressed: () {
            final label = _labelCtrl.text.trim();
            if (label.isEmpty) return;
            Navigator.pop(context, (label, _locationId));
          },
          child: const Text('Starten'),
        ),
      ],
    );
  }
}
