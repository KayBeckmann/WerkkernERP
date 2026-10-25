import 'package:flutter/material.dart';
import 'package:werkkern_client/werkkern_client.dart';
import 'package:werkkern_core/werkkern_core.dart';

import '../../../domain/services/online_session.dart';
import 'online_form.dart';

const vehicleCostCategoryLabels = {
  'fuel': 'Tanken',
  'maintenance': 'Wartung',
  'leasing': 'Leasing/Finanzierung',
  'insurance': 'Versicherung',
  'other': 'Sonstiges',
};

/// Fuhrpark der Online-Firma (C6): Fahrzeuge mit TÜV-Termin und
/// Kostenbuchungen. Kosten sind Gemeinkosten; die Projektmarkierung
/// fließt nicht in die Projekt-Ergebnisrechnung.
class OnlineFleetScreen extends StatefulWidget {
  const OnlineFleetScreen({super.key, required this.session});
  final OnlineSession session;

  @override
  State<OnlineFleetScreen> createState() => _OnlineFleetScreenState();
}

class _OnlineFleetScreenState extends State<OnlineFleetScreen> {
  bool _showInactive = false;
  final _listKey = GlobalKey<OnlineListViewState<OnlineVehicle>>();

  Future<bool> _edit(BuildContext context, [OnlineVehicle? existing]) async {
    final values = await showOnlineForm(
      context,
      title: existing == null ? 'Neues Fahrzeug' : 'Fahrzeug bearbeiten',
      fields: [
        OnlineField('name', 'Bezeichnung', required: true, initial: existing?.name),
        OnlineField('licensePlate', 'Kennzeichen', initial: existing?.licensePlate),
        OnlineField('nextInspectionDate', 'Nächster TÜV/HU', type: OnlineFieldType.date, initial: existing?.nextInspectionDate),
        OnlineField('notes', 'Notizen', type: OnlineFieldType.multiline, initial: existing?.notes),
        OnlineField('active', 'Aktiv', type: OnlineFieldType.toggle, initial: existing?.active ?? true),
      ],
    );
    if (values == null || !context.mounted) return false;
    return runOnline(
      context,
      () => widget.session.client.saveVehicle(OnlineVehicle(
        id: existing?.id ?? '',
        name: values['name'] as String,
        licensePlate: values['licensePlate'] as String?,
        nextInspectionDate: values['nextInspectionDate'] as DateTime?,
        notes: values['notes'] as String?,
        active: values['active'] as bool,
      )),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canWrite = widget.session.can('fleet.write');
    final today = DateTime.now();
    return OnlineListView<OnlineVehicle>(
      key: _listKey,
      load: (_) => widget.session.client.vehicles(includeInactive: _showInactive),
      emptyText: 'Keine Fahrzeuge vorhanden.',
      header: (context, items, reload) => SwitchListTile(
        title: const Text('Inaktive anzeigen'),
        value: _showInactive,
        onChanged: (v) {
          setState(() => _showInactive = v);
          reload();
        },
      ),
      itemBuilder: (context, v, reload) {
        final inspection = v.nextInspectionDate;
        final due = inspection != null && inspection.isBefore(today.add(const Duration(days: 30)));
        return Card(
          child: ListTile(
            leading: Icon(Icons.local_shipping_outlined, color: v.active ? null : Theme.of(context).disabledColor),
            title: Text(v.licensePlate == null ? v.name : '${v.name} · ${v.licensePlate}'),
            subtitle: Text([
              if (inspection != null) 'TÜV ${formatOnlineDate(inspection)}${due ? ' — fällig' : ''}',
              if (!v.active) 'inaktiv',
            ].join(' · ')),
            trailing: canWrite
                ? IconButton(
                    tooltip: 'Fahrzeug bearbeiten',
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () async {
                      if (await _edit(context, v)) reload();
                    },
                  )
                : null,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => OnlineVehicleScreen(session: widget.session, vehicle: v)),
            ),
          ),
        );
      },
      floatingActionButton: canWrite
          ? (reload) => Builder(
                builder: (context) => FloatingActionButton.extended(
                  heroTag: 'online-fleet-fab',
                  onPressed: () async {
                    if (await _edit(context)) reload();
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Fahrzeug anlegen'),
                ),
              )
          : null,
    );
  }
}

/// Kosten eines Fahrzeugs je Jahr mit Summen nach Kategorie.
class OnlineVehicleScreen extends StatefulWidget {
  const OnlineVehicleScreen({super.key, required this.session, required this.vehicle});
  final OnlineSession session;
  final OnlineVehicle vehicle;

  @override
  State<OnlineVehicleScreen> createState() => _OnlineVehicleScreenState();
}

class _OnlineVehicleScreenState extends State<OnlineVehicleScreen> {
  int _year = DateTime.now().year;
  late Future<({List<OnlineVehicleCost> costs, OnlineVehicleCostTotals totals})> _future = _load();

  Future<({List<OnlineVehicleCost> costs, OnlineVehicleCostTotals totals})> _load() => widget.session.client.vehicleCosts(
        vehicleId: widget.vehicle.id,
        from: DateTime.utc(_year),
        to: DateTime.utc(_year, 12, 31),
      );

  void _reload() => setState(() {
        _future = _load();
      });

  Future<void> _addCost() async {
    final session = widget.session;
    final projects = session.modules.contains('projects') && session.can('projects.read')
        ? await session.client.projects()
        : const <OnlineProject>[];
    if (!mounted) return;
    final values = await showOnlineForm(
      context,
      title: 'Kosten buchen',
      fields: [
        OnlineField('date', 'Datum', type: OnlineFieldType.date, required: true, initial: DateTime.now()),
        OnlineField('category', 'Kategorie', type: OnlineFieldType.choice, required: true, initial: 'fuel', options: vehicleCostCategoryLabels),
        OnlineField('amount', 'Betrag (brutto)', type: OnlineFieldType.money, required: true),
        OnlineField('description', 'Beschreibung'),
        const OnlineField('principal', 'davon Tilgung', type: OnlineFieldType.money, helper: 'Nur bei Leasing/Finanzierung'),
        const OnlineField('interest', 'davon Zins', type: OnlineFieldType.money),
        if (projects.isNotEmpty)
          OnlineField(
            'projectId',
            'Projekt (nur Markierung)',
            type: OnlineFieldType.choice,
            options: {for (final p in projects) p.id: '${p.displayNumber} · ${p.name}'},
            helper: 'Fuhrpark bleibt Gemeinkosten.',
          ),
      ],
    );
    if (values == null || !mounted) return;
    final date = values['date'] as DateTime;
    if (await runOnline(
      context,
      () => session.client.addVehicleCost(
        vehicleId: widget.vehicle.id,
        date: date,
        amountCents: values['amount'] as int,
        category: values['category'] as String,
        description: values['description'] as String?,
        principalAmountCents: values['principal'] as int?,
        interestAmountCents: values['interest'] as int?,
        projectId: values['projectId'] as String?,
      ),
    )) {
      if (date.year != _year) _year = date.year;
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final canWrite = widget.session.can('fleet.write');
    return Scaffold(
      appBar: AppBar(title: Text(widget.vehicle.name)),
      floatingActionButton: canWrite
          ? FloatingActionButton.extended(
              heroTag: 'online-vehicle-cost-fab',
              onPressed: _addCost,
              icon: const Icon(Icons.add),
              label: const Text('Kosten buchen'),
            )
          : null,
      body: FutureBuilder<({List<OnlineVehicleCost> costs, OnlineVehicleCostTotals totals})>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text(describeOnlineError(snapshot.error!)));
          final data = snapshot.data;
          if (data == null) return const Center(child: CircularProgressIndicator());
          return ListView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
            children: [
              Row(
                children: [
                  IconButton(
                    tooltip: 'Vorjahr',
                    icon: const Icon(Icons.chevron_left),
                    onPressed: () {
                      _year--;
                      _reload();
                    },
                  ),
                  Expanded(child: Center(child: Text('$_year', style: Theme.of(context).textTheme.titleLarge))),
                  IconButton(
                    tooltip: 'Folgejahr',
                    icon: const Icon(Icons.chevron_right),
                    onPressed: () {
                      _year++;
                      _reload();
                    },
                  ),
                ],
              ),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      for (final e in vehicleCostCategoryLabels.entries)
                        if ((data.totals.byCategory[e.key] ?? 0) != 0)
                          _row(e.value, Money.fromCents(data.totals.byCategory[e.key]!).toString()),
                      if (data.totals.principalCents != 0 || data.totals.interestCents != 0) ...[
                        _row('davon Tilgung', Money.fromCents(data.totals.principalCents).toString()),
                        _row('davon Zins', Money.fromCents(data.totals.interestCents).toString()),
                      ],
                      const Divider(),
                      _row('Summe $_year', Money.fromCents(data.totals.totalCents).toString(), bold: true),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              if (data.costs.isEmpty) const Padding(padding: EdgeInsets.all(16), child: Center(child: Text('Keine Kosten in diesem Jahr.'))),
              for (final c in data.costs)
                Card(
                  child: ListTile(
                    title: Text('${vehicleCostCategoryLabels[c.category] ?? c.category} · ${Money.fromCents(c.amountCents)}'),
                    subtitle: Text([
                      formatOnlineDate(c.date),
                      if (c.description != null) c.description!,
                      if (c.principalAmountCents != null) 'Tilgung ${Money.fromCents(c.principalAmountCents!)}',
                      if (c.interestAmountCents != null) 'Zins ${Money.fromCents(c.interestAmountCents!)}',
                    ].join(' · ')),
                    trailing: canWrite
                        ? IconButton(
                            tooltip: 'Buchung löschen',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () async {
                              if (!await confirmOnline(context, 'Buchung löschen?', 'Die Kostenbuchung wird entfernt.')) return;
                              if (context.mounted && await runOnline(context, () => widget.session.client.deleteVehicleCost(c.id))) {
                                _reload();
                              }
                            },
                          )
                        : null,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _row(String label, String value, {bool bold = false}) {
    final style = bold ? const TextStyle(fontWeight: FontWeight.bold) : null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(children: [Expanded(child: Text(label, style: style)), Text(value, style: style)]),
    );
  }
}
