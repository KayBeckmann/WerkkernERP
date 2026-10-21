import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/database/database.dart';
import '../../data/database/tables.dart';
import '../../data/repositories/vehicle_repository.dart';
import '../../domain/models/money.dart';
import '../../domain/services/active_company_service.dart';

/// Fahrzeugliste der aktiven Firma (C6-Kern, Kay-Priorisierungs-
/// entscheidung 2026-10-17). Zeigt nur aktive Fahrzeuge — deaktivierte
/// bleiben samt Kostenhistorie erhalten (gleiches Prinzip wie Projekte/
/// Modul-Schalter).
class VehiclesScreen extends StatefulWidget {
  const VehiclesScreen({super.key});

  @override
  State<VehiclesScreen> createState() => _VehiclesScreenState();
}

class _VehiclesScreenState extends State<VehiclesScreen> {
  late Future<List<Vehicle>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Vehicle>> _load() {
    final companyId = context.read<ActiveCompanyService>().active!.id;
    return context.read<VehicleRepository>().listForCompany(companyId);
  }

  // Bewusst ein Block-Body, nicht `setState(() => _future = _load())` —
  // eine Zuweisung als Ausdruck liefert ihren Wert (hier ein `Future`)
  // zurück, und Flutter wirft im Debug-Modus bei jedem `setState()`,
  // dessen Callback ein `Future` zurückgibt (bereits einmal in A5 so
  // gefunden).
  void _reload() => setState(() {
        _future = _load();
      });

  Future<void> _create() async {
    final result = await showDialog<_VehicleFormResult>(
      context: context,
      builder: (context) => const _VehicleFormDialog(),
    );
    if (result == null || !mounted) return;
    final companyId = context.read<ActiveCompanyService>().active!.id;
    await context.read<VehicleRepository>().create(
          companyId: companyId,
          name: result.name,
          licensePlate: result.licensePlate,
          notes: result.notes,
          nextInspectionDate: result.nextInspectionDate,
        );
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<List<Vehicle>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final vehicles = snapshot.data!;
          if (vehicles.isEmpty) {
            return const Center(child: Text('Noch keine Fahrzeuge angelegt.'));
          }
          final now = DateTime.now();
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
            itemCount: vehicles.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final vehicle = vehicles[index];
              final dueSoon = vehicle.nextInspectionDate != null &&
                  vehicle.nextInspectionDate!.difference(now).inDays < 30;
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.directions_car_outlined),
                  title: Text(vehicle.name),
                  subtitle: Text([
                    if (vehicle.licensePlate != null) vehicle.licensePlate!,
                    if (vehicle.nextInspectionDate != null)
                      'TÜV: ${_formatDate(vehicle.nextInspectionDate!)}',
                  ].join(' · ')),
                  trailing: dueSoon
                      ? Icon(Icons.warning_amber_outlined, color: Theme.of(context).colorScheme.error)
                      : const Icon(Icons.chevron_right),
                  onTap: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => VehicleDetailScreen(vehicle: vehicle)),
                    );
                    if (mounted) _reload();
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'vehicles-fab',
        onPressed: _create,
        icon: const Icon(Icons.add),
        label: const Text('Fahrzeug anlegen'),
      ),
    );
  }
}

String _formatDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';

class _VehicleFormResult {
  const _VehicleFormResult({
    required this.name,
    this.licensePlate,
    this.notes,
    this.nextInspectionDate,
  });
  final String name;
  final String? licensePlate;
  final String? notes;
  final DateTime? nextInspectionDate;
}

class _VehicleFormDialog extends StatefulWidget {
  const _VehicleFormDialog();

  @override
  State<_VehicleFormDialog> createState() => _VehicleFormDialogState();
}

class _VehicleFormDialogState extends State<_VehicleFormDialog> {
  final _nameCtrl = TextEditingController();
  final _plateCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  DateTime? _nextInspectionDate;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _plateCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _nextInspectionDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _nextInspectionDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Neues Fahrzeug'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nameCtrl,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Name/Bezeichnung *'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _plateCtrl,
                decoration: const InputDecoration(labelText: 'Kennzeichen'),
              ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  _nextInspectionDate == null
                      ? 'TÜV-Termin (optional)'
                      : 'TÜV: ${_formatDate(_nextInspectionDate!)}',
                ),
                trailing: const Icon(Icons.calendar_today_outlined),
                onTap: _pickDate,
              ),
              TextField(
                controller: _notesCtrl,
                decoration: const InputDecoration(labelText: 'Notizen'),
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
        FilledButton(
          onPressed: () {
            if (_nameCtrl.text.trim().isEmpty) return;
            Navigator.pop(
              context,
              _VehicleFormResult(
                name: _nameCtrl.text.trim(),
                licensePlate: _plateCtrl.text.trim().isEmpty ? null : _plateCtrl.text.trim(),
                notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
                nextInspectionDate: _nextInspectionDate,
              ),
            );
          },
          child: const Text('Anlegen'),
        ),
      ],
    );
  }
}

/// Fahrzeugdetail: Stammdaten + Kostenbuchungen (Tanken, Wartung,
/// Leasing, Versicherung, Sonstiges). **Keine Summierung in eine
/// Projekt-Ergebnisrechnung** — siehe Doc-Kommentar bei [Vehicles] in
/// tables.dart. Die optionale Projektzuordnung je Buchung ist hier
/// bewusst nur eine Markierung, kein berechneter Wert.
class VehicleDetailScreen extends StatefulWidget {
  const VehicleDetailScreen({super.key, required this.vehicle});
  final Vehicle vehicle;

  @override
  State<VehicleDetailScreen> createState() => _VehicleDetailScreenState();
}

class _VehicleDetailScreenState extends State<VehicleDetailScreen> {
  late Future<List<VehicleCostEntry>> _future;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<VehicleCostEntry>> _load() {
    final companyId = context.read<ActiveCompanyService>().active!.id;
    return context.read<VehicleRepository>().listCostsForVehicle(
          companyId: companyId,
          vehicleId: widget.vehicle.id,
        );
  }

  void _reload() => setState(() {
        _future = _load();
      });

  Future<void> _deactivate() async {
    setState(() => _busy = true);
    try {
      final companyId = context.read<ActiveCompanyService>().active!.id;
      await context.read<VehicleRepository>().setActive(
            companyId: companyId,
            id: widget.vehicle.id,
            active: false,
          );
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addCost() async {
    final result = await showDialog<_CostFormResult>(
      context: context,
      builder: (context) => const _CostFormDialog(),
    );
    if (result == null || !mounted) return;
    final companyId = context.read<ActiveCompanyService>().active!.id;
    await context.read<VehicleRepository>().addCostEntry(
          companyId: companyId,
          vehicleId: widget.vehicle.id,
          date: result.date,
          amountCents: result.amountCents,
          category: result.category,
          description: result.description,
          principalAmountCents: result.principalAmountCents,
          interestAmountCents: result.interestAmountCents,
        );
    _reload();
  }

  static String _categoryLabel(VehicleCostCategory category) => switch (category) {
        VehicleCostCategory.fuel => 'Tanken',
        VehicleCostCategory.maintenance => 'Wartung',
        VehicleCostCategory.leasing => 'Leasing/Kredit',
        VehicleCostCategory.insurance => 'Versicherung',
        VehicleCostCategory.other => 'Sonstiges',
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.vehicle.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.block_outlined),
            tooltip: 'Deaktivieren',
            onPressed: _busy ? null : _deactivate,
          ),
        ],
      ),
      body: FutureBuilder<List<VehicleCostEntry>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final costs = snapshot.data!;
          final sum = costs.fold<Money>(
            Money.zero(),
            (acc, c) => acc + Money.fromCents(c.amountCents),
          );
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (widget.vehicle.licensePlate != null) Text(widget.vehicle.licensePlate!),
              if (widget.vehicle.nextInspectionDate != null)
                Text('Nächster TÜV: ${_formatDate(widget.vehicle.nextInspectionDate!)}'),
              if (widget.vehicle.notes != null) ...[
                const SizedBox(height: 8),
                Text(widget.vehicle.notes!, style: Theme.of(context).textTheme.bodySmall),
              ],
              const SizedBox(height: 16),
              Card(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Summe aller Buchungen: $sum', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text(
                        'Reine Belegsumme, keine Projektumlage oder Ergebnisrechnung. Tilgung/Zins '
                        'bei Leasing/Kredit lassen sich seit dem C6-Nachtrag (2026-10-21) je Buchung '
                        'aufschlüsseln, fließen aber weiterhin nicht automatisch in eine '
                        'Ergebnisrechnung ein.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('Kostenbuchungen', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              if (costs.isEmpty) const Text('Noch keine Kosten erfasst.'),
              for (final cost in costs)
                Card(
                  child: ListTile(
                    title: Text(_categoryLabel(cost.category)),
                    subtitle: Text(
                      '${_formatDate(cost.date)}'
                      '${cost.description != null ? ' · ${cost.description}' : ''}'
                      '${cost.principalAmountCents != null || cost.interestAmountCents != null ? ' · Tilgung ${Money.fromCents(cost.principalAmountCents ?? 0)} / Zins ${Money.fromCents(cost.interestAmountCents ?? 0)}' : ''}',
                    ),
                    trailing: Text(Money.fromCents(cost.amountCents).toString()),
                  ),
                ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'vehicle-cost-fab',
        onPressed: _addCost,
        icon: const Icon(Icons.add),
        label: const Text('Kosten erfassen'),
      ),
    );
  }
}

class _CostFormResult {
  const _CostFormResult({
    required this.date,
    required this.amountCents,
    required this.category,
    this.description,
    this.principalAmountCents,
    this.interestAmountCents,
  });
  final DateTime date;
  final int amountCents;
  final VehicleCostCategory category;
  final String? description;

  /// C6-Nachtrag 2026-10-21 — nur bei [VehicleCostCategory.leasing]
  /// über die UI befüllbar.
  final int? principalAmountCents;
  final int? interestAmountCents;
}

class _CostFormDialog extends StatefulWidget {
  const _CostFormDialog();

  @override
  State<_CostFormDialog> createState() => _CostFormDialogState();
}

class _CostFormDialogState extends State<_CostFormDialog> {
  final _amountCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _principalCtrl = TextEditingController();
  final _interestCtrl = TextEditingController();
  DateTime _date = DateTime.now();
  VehicleCostCategory _category = VehicleCostCategory.fuel;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _descriptionCtrl.dispose();
    _principalCtrl.dispose();
    _interestCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Kosten erfassen'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Datum: ${_formatDate(_date)}'),
                trailing: const Icon(Icons.calendar_today_outlined),
                onTap: _pickDate,
              ),
              DropdownButtonFormField<VehicleCostCategory>(
                isExpanded: true,
                initialValue: _category,
                decoration: const InputDecoration(labelText: 'Kategorie'),
                items: [
                  for (final category in VehicleCostCategory.values)
                    DropdownMenuItem(
                      value: category,
                      child: Text(_VehicleDetailScreenState._categoryLabel(category)),
                    ),
                ],
                onChanged: (value) => setState(() => _category = value!),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _amountCtrl,
                decoration: const InputDecoration(labelText: 'Betrag (€) *'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _descriptionCtrl,
                decoration: const InputDecoration(labelText: 'Beschreibung'),
              ),
              if (_category == VehicleCostCategory.leasing) ...[
                const SizedBox(height: 8),
                Text(
                  'Optionale Aufschlüsselung der Rate (C6-Nachtrag):',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 4),
                TextField(
                  controller: _principalCtrl,
                  decoration: const InputDecoration(labelText: 'Tilgungsanteil (€)'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _interestCtrl,
                  decoration: const InputDecoration(labelText: 'Zinsanteil (€)'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
        FilledButton(
          onPressed: () {
            Money amount;
            try {
              amount = Money.fromEuroString(_amountCtrl.text.trim());
            } catch (_) {
              return;
            }
            if (_amountCtrl.text.trim().isEmpty) return;
            int? principalCents;
            int? interestCents;
            if (_category == VehicleCostCategory.leasing) {
              if (_principalCtrl.text.trim().isNotEmpty) {
                try {
                  principalCents = Money.fromEuroString(_principalCtrl.text.trim()).cents;
                } catch (_) {
                  return;
                }
              }
              if (_interestCtrl.text.trim().isNotEmpty) {
                try {
                  interestCents = Money.fromEuroString(_interestCtrl.text.trim()).cents;
                } catch (_) {
                  return;
                }
              }
            }
            Navigator.pop(
              context,
              _CostFormResult(
                date: _date,
                amountCents: amount.cents,
                category: _category,
                description: _descriptionCtrl.text.trim().isEmpty ? null : _descriptionCtrl.text.trim(),
                principalAmountCents: principalCents,
                interestAmountCents: interestCents,
              ),
            );
          },
          child: const Text('Speichern'),
        ),
      ],
    );
  }
}
