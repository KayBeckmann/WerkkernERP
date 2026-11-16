import 'package:flutter/material.dart';
import 'package:werkkern_client/werkkern_client.dart';

import '../../../domain/services/online_session.dart';
import 'online_articles_screen.dart' show formatQuantity;
import 'online_form.dart';

/// Auswahlliste aller Plätze (`''` = „Platz noch nicht zugeordnet“), optional
/// mit Menge je Platz.
Map<String?, String> onlineBinOptions(
  List<OnlineStorageLocation> locations, {
  Map<String, String> quantities = const {},
  String unassignedLabel = 'Platz noch nicht zugeordnet',
}) {
  String withQty(String label, String key) =>
      quantities.containsKey(key) ? '$label (${formatQuantity(quantities[key]!)})' : label;
  return {
    '': withQty(unassignedLabel, ''),
    for (final l in locations)
      for (final b in l.bins) b.id: withQty('${l.name} · ${b.label}', b.id),
  };
}

/// Kay (16.11.2026): „Bei Entnahme auch einen Lagerplatz vorschlagen,
/// wenn einer hinterlegt ist.“ Je Artikel der Vorschlag, änderbar.
/// `null` = abgebrochen.
Future<Map<String, String>?> askOnlineWithdrawalBins(
  BuildContext context,
  List<OnlineWithdrawal> withdrawals,
  List<OnlineStorageLocation> locations,
) async {
  final values = await showOnlineForm(
    context,
    title: 'Entnahme aus Lagerplatz',
    submitLabel: 'Weiter',
    fields: [
      for (final w in withdrawals)
        OnlineField(
          'bin-${w.articleId}',
          '${w.articleName}: ${formatQuantity(w.quantity)} entnehmen aus',
          type: OnlineFieldType.choice,
          required: true,
          initial: w.binStock.suggestedBinKey,
          options: onlineBinOptions(locations, quantities: {for (final s in w.binStock.stocks) s.binKey: s.quantity}),
          helper: 'Reicht der Platz nicht, wird der Rest von weiteren Plätzen entnommen.',
        ),
    ],
  );
  if (values == null) return null;
  return {for (final w in withdrawals) w.articleId: (values['bin-${w.articleId}'] as String?) ?? ''};
}

/// C5.4-Nachtrag (Kay, 16.11.2026) online: Lagerorte und Plätze
/// (Reihe → Regal → Fach) — wie offline.
class OnlineStorageLocationsScreen extends StatefulWidget {
  const OnlineStorageLocationsScreen({super.key, required this.session});
  final OnlineSession session;

  @override
  State<OnlineStorageLocationsScreen> createState() => _OnlineStorageLocationsScreenState();
}

class _OnlineStorageLocationsScreenState extends State<OnlineStorageLocationsScreen> {
  WerkkernApiClient get _client => widget.session.client;
  late Future<List<OnlineStorageLocation>> _future = _load();

  Future<List<OnlineStorageLocation>> _load() async => (await _client.storageLocations()).locations;

  void _reload() {
    if (!mounted) return;
    setState(() {
      _future = _load();
    });
  }

  bool get _canWrite => widget.session.can('stock.write');

  Future<void> _editLocation([OnlineStorageLocation? existing]) async {
    final values = await showOnlineForm(
      context,
      title: existing == null ? 'Neuer Lagerort' : 'Lagerort umbenennen',
      fields: [
        OnlineField('name', 'Name', required: true, initial: existing?.name, helper: 'z. B. Lager, Halle, Fahrzeug 1'),
      ],
    );
    if (values == null || !mounted) return;
    if (await runOnline(context, () => _client.saveStorageLocation(values['name'] as String, id: existing?.id))) _reload();
  }

  Future<void> _editBin(OnlineStorageLocation location, [OnlineStorageBin? existing]) async {
    final values = await showOnlineForm(
      context,
      title: existing == null ? 'Neuer Platz in ${location.name}' : 'Platz bearbeiten',
      fields: [
        OnlineField('row', 'Reihe', initial: existing?.row),
        OnlineField('shelf', 'Regal', initial: existing?.shelf),
        OnlineField(
          'compartment',
          'Fach',
          initial: existing?.compartment,
          helper: 'Mindestens ein Feld ausfüllen. Die Inventur läuft Reihe → Regal → Fach ab.',
        ),
      ],
    );
    if (values == null || !mounted) return;
    String v(String key) => (values[key] as String?)?.trim() ?? '';
    if (v('row').isEmpty && v('shelf').isEmpty && v('compartment').isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Mindestens Reihe, Regal oder Fach angeben.')));
      return;
    }
    if (await runOnline(
      context,
      () => _client.saveStorageBin(
        locationId: location.id,
        id: existing?.id,
        row: v('row'),
        shelf: v('shelf'),
        compartment: v('compartment'),
      ),
    )) {
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lagerorte & Plätze')),
      floatingActionButton: _canWrite
          ? FloatingActionButton.extended(
              heroTag: 'online-storage-fab',
              onPressed: _editLocation,
              icon: const Icon(Icons.add),
              label: const Text('Lagerort anlegen'),
            )
          : null,
      body: FutureBuilder<List<OnlineStorageLocation>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text(describeOnlineError(snapshot.error!)));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final locations = snapshot.data!;
          if (locations.isEmpty) {
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
              for (final location in locations)
                Card(
                  child: ExpansionTile(
                    key: PageStorageKey(location.id),
                    initiallyExpanded: true,
                    leading: const Icon(Icons.warehouse_outlined),
                    title: Text(location.name),
                    subtitle: Text(location.bins.length == 1 ? '1 Platz' : '${location.bins.length} Plätze'),
                    trailing: _canWrite
                        ? PopupMenuButton<String>(
                            onSelected: (v) async {
                              switch (v) {
                                case 'bin':
                                  await _editBin(location);
                                case 'rename':
                                  await _editLocation(location);
                                case 'delete':
                                  if (await runOnline(context, () => _client.deleteStorageLocation(location.id))) _reload();
                              }
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(value: 'bin', child: Text('Platz anlegen')),
                              PopupMenuItem(value: 'rename', child: Text('Umbenennen')),
                              PopupMenuItem(value: 'delete', child: Text('Löschen')),
                            ],
                          )
                        : null,
                    children: [
                      for (final bin in location.bins)
                        ListTile(
                          dense: true,
                          leading: const Icon(Icons.shelves),
                          title: Text(bin.label),
                          onTap: _canWrite ? () => _editBin(location, bin) : null,
                          trailing: _canWrite
                              ? IconButton(
                                  tooltip: 'Platz löschen',
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: () async {
                                    if (await runOnline(context, () => _client.deleteStorageBin(bin.id))) _reload();
                                  },
                                )
                              : null,
                        ),
                      if (_canWrite)
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
