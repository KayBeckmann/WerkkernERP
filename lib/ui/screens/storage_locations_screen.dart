import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/database/database.dart';
import '../../data/repositories/stock_ledger.dart';
import '../../data/repositories/storage_repository.dart';
import '../../domain/services/active_company_service.dart';

/// C5.4-Nachtrag (Kay, 16.11.2026): Lagerorte (frei benannt, z. B.
/// Lager, Halle, Fahrzeug) und Plätze darin (Reihe → Regal → Fach). Die
/// Reihenfolge der Plätze ist die Laufreihenfolge der Inventur.
class StorageLocationsScreen extends StatefulWidget {
  const StorageLocationsScreen({super.key});

  @override
  State<StorageLocationsScreen> createState() => _StorageLocationsScreenState();
}

class _StorageLocationsScreenState extends State<StorageLocationsScreen> {
  late Future<List<(StorageLocation, List<StorageBin>)>> _future = _load();

  String get _companyId => context.read<ActiveCompanyService>().active!.id;
  StorageRepository get _repo => context.read<StorageRepository>();

  Future<List<(StorageLocation, List<StorageBin>)>> _load() async {
    final repo = _repo;
    final companyId = _companyId;
    return [
      for (final l in await repo.locations(companyId)) (l, await repo.binsOf(companyId: companyId, locationId: l.id)),
    ];
  }

  void _reload() {
    if (!mounted) return;
    setState(() {
      _future = _load();
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
    } on StorageBinInUseException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } on ArgumentError catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${e.message}')));
    }
    _reload();
  }

  Future<void> _editLocation([StorageLocation? existing]) async {
    final name = await _askText(
      title: existing == null ? 'Neuer Lagerort' : 'Lagerort umbenennen',
      label: 'Name *',
      hint: 'z. B. Lager, Halle, Fahrzeug 1',
      initial: existing?.name,
    );
    if (name == null) return;
    await _run(() async {
      if (existing == null) {
        await _repo.createLocation(companyId: _companyId, name: name);
      } else {
        await _repo.renameLocation(companyId: _companyId, id: existing.id, name: name);
      }
    });
  }

  Future<String?> _askText({required String title, required String label, String? hint, String? initial}) async {
    final values = await showDialog<List<String>>(
      context: context,
      builder: (_) => _FieldsDialog(
        title: title,
        fields: [(key: 'storage-location-name', label: label, hint: hint, initial: initial ?? '')],
        requireAny: true,
      ),
    );
    return values?.first;
  }

  Future<void> _editBin(StorageLocation location, [StorageBin? existing]) async {
    final values = await showDialog<List<String>>(
      context: context,
      builder: (_) => _FieldsDialog(
        title: existing == null ? 'Neuer Platz in ${location.name}' : 'Platz bearbeiten',
        fields: [
          (key: 'bin-row', label: 'Reihe', hint: null, initial: existing?.row ?? ''),
          (key: 'bin-shelf', label: 'Regal', hint: null, initial: existing?.shelf ?? ''),
          (key: 'bin-compartment', label: 'Fach', hint: null, initial: existing?.compartment ?? ''),
        ],
        note: 'Mindestens ein Feld ausfüllen. Die Inventur läuft Reihe → Regal → Fach ab.',
        requireAny: true,
      ),
    );
    if (values == null) return;
    await _run(() => _repo.saveBin(
          companyId: _companyId,
          locationId: location.id,
          id: existing?.id,
          row: values[0],
          shelf: values[1],
          compartment: values[2],
        ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lagerorte & Plätze')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'storage-locations-fab',
        onPressed: _editLocation,
        icon: const Icon(Icons.add),
        label: const Text('Lagerort anlegen'),
      ),
      body: FutureBuilder<List<(StorageLocation, List<StorageBin>)>>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final data = snapshot.data!;
          if (data.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Noch keine Lagerorte. Bestand ohne Platz erscheint als „Platz noch nicht zugeordnet“.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
            children: [
              for (final (location, bins) in data)
                Card(
                  child: ExpansionTile(
                    key: PageStorageKey(location.id),
                    initiallyExpanded: true,
                    leading: const Icon(Icons.warehouse_outlined),
                    title: Text(location.name),
                    subtitle: Text(bins.length == 1 ? '1 Platz' : '${bins.length} Plätze'),
                    trailing: PopupMenuButton<String>(
                      onSelected: (v) async {
                        switch (v) {
                          case 'bin':
                            await _editBin(location);
                          case 'rename':
                            await _editLocation(location);
                          case 'delete':
                            await _run(() => _repo.deleteLocation(companyId: _companyId, id: location.id));
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'bin', child: Text('Platz anlegen')),
                        PopupMenuItem(value: 'rename', child: Text('Umbenennen')),
                        PopupMenuItem(value: 'delete', child: Text('Löschen')),
                      ],
                    ),
                    children: [
                      for (final bin in bins)
                        ListTile(
                          dense: true,
                          leading: const Icon(Icons.shelves),
                          title: Text(storageBinLabel(bin)),
                          onTap: () => _editBin(location, bin),
                          trailing: IconButton(
                            tooltip: 'Platz löschen',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => _run(() => _repo.deleteBin(companyId: _companyId, id: bin.id)),
                          ),
                        ),
                      ListTile(
                        dense: true,
                        leading: const Icon(Icons.add),
                        title: const Text('Platz anlegen'),
                        onTap: () => _editBin(location),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

typedef _FieldSpec = ({String key, String label, String? hint, String initial});

/// Kleiner Formulardialog; besitzt seine Controller selbst (sonst würden
/// sie während der Schließ-Animation schon entsorgt).
class _FieldsDialog extends StatefulWidget {
  const _FieldsDialog({required this.title, required this.fields, this.note, this.requireAny = false});
  final String title;
  final List<_FieldSpec> fields;
  final String? note;
  final bool requireAny;

  @override
  State<_FieldsDialog> createState() => _FieldsDialogState();
}

class _FieldsDialogState extends State<_FieldsDialog> {
  late final List<TextEditingController> _ctrls = [
    for (final f in widget.fields) TextEditingController(text: f.initial),
  ];

  @override
  void dispose() {
    for (final c in _ctrls) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < widget.fields.length; i++)
            TextField(
              key: Key(widget.fields[i].key),
              controller: _ctrls[i],
              autofocus: i == 0,
              decoration: InputDecoration(labelText: widget.fields[i].label, hintText: widget.fields[i].hint),
            ),
          if (widget.note != null) ...[
            const SizedBox(height: 8),
            Text(widget.note!, style: const TextStyle(fontSize: 12)),
          ],
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
        FilledButton(
          onPressed: () {
            final values = [for (final c in _ctrls) c.text.trim()];
            if (widget.requireAny && values.every((v) => v.isEmpty)) return;
            Navigator.pop(context, values);
          },
          child: const Text('Speichern'),
        ),
      ],
    );
  }
}
