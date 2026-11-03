import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/database/database.dart';
import '../../data/repositories/staff_role_repository.dart';
import '../../domain/models/money.dart';
import '../../domain/services/active_company_service.dart';

/// "Rollen & Stundensätze" als eigene Settings-Unterseite (C3
/// Zeiterfassung, Nachtrag 2026-10-20) — siehe ausführlichen Doc-
/// Kommentar bei `StaffRoles` in tables.dart: eine Rolle ist eine frei
/// benennbare Stundensatz-Kategorie (Monteur/Meister/Projektleiter),
/// **keine** Mitarbeiter-Stammdaten mit Namen.
class SettingsStaffRolesScreen extends StatefulWidget {
  const SettingsStaffRolesScreen({super.key});

  @override
  State<SettingsStaffRolesScreen> createState() => _SettingsStaffRolesScreenState();
}

class _SettingsStaffRolesScreenState extends State<SettingsStaffRolesScreen> {
  late Future<List<StaffRole>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<StaffRole>> _load() async {
    final companyId = context.read<ActiveCompanyService>().active!.id;
    final repo = context.read<StaffRoleRepository>();
    await repo.seedDefaultsIfNeverSeeded(companyId);
    return repo.listForCompany(companyId);
  }

  void _reload() => setState(() {
        _future = _load();
      });

  Future<void> _create() async {
    final result = await showDialog<_StaffRoleFormResult>(
      context: context,
      builder: (context) => const _StaffRoleFormDialog(),
    );
    if (result == null || !mounted) return;
    final companyId = context.read<ActiveCompanyService>().active!.id;
    await context.read<StaffRoleRepository>().create(
          companyId: companyId,
          name: result.name,
          hourlyCostRateCents: result.hourlyCostRateCents,
          hourlyBillingRateCents: result.hourlyBillingRateCents,
        );
    _reload();
  }

  Future<void> _edit(StaffRole role) async {
    final result = await showDialog<_StaffRoleFormResult>(
      context: context,
      builder: (context) => _StaffRoleFormDialog(existing: role),
    );
    if (result == null || !mounted) return;
    final companyId = context.read<ActiveCompanyService>().active!.id;
    await context.read<StaffRoleRepository>().update(
          companyId: companyId,
          id: role.id,
          name: result.name,
          hourlyCostRateCents: result.hourlyCostRateCents,
          hourlyBillingRateCents: result.hourlyBillingRateCents,
        );
    _reload();
  }

  Future<void> _delete(StaffRole role) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rolle löschen?'),
        content: Text(
          '"${role.name}" löschen? Bereits gebuchte Zeiten mit dieser Rolle bleiben erhalten, '
          'verlieren aber ihren Stundenkostensatz-Bezug. Positionen in Dokumenten behalten '
          'ihren Preis und Text.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Abbrechen')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Löschen')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final companyId = context.read<ActiveCompanyService>().active!.id;
    await context.read<StaffRoleRepository>().delete(companyId: companyId, id: role.id);
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rollen & Stundensätze')),
      body: FutureBuilder<List<StaffRole>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final roles = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                child: Text(
                  'Rollen sind reine Stundensatz-Kategorien (kein Login/Mehrbenutzer-Konzept). '
                  'Der Verrechnungssatz ist der Preis je Stunde für den Kunden: er wird in '
                  'Stunden-Positionen vorgeschlagen und beim Abrechnen gebuchter Zeiten genutzt. '
                  'Der Kostensatz (was dich die Stunde kostet) fließt in die '
                  'Projekt-Ergebnisrechnung ein. Sobald es Rollen gibt, braucht jede '
                  'Zeitbuchung eine Rolle.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              for (final role in roles)
                Card(
                  child: ListTile(
                    title: Text(role.name),
                    subtitle: Text(
                      'Verrechnung: ${role.hourlyBillingRateCents == 0 ? 'nicht hinterlegt' : '${Money.fromCents(role.hourlyBillingRateCents)} / Std.'}'
                      ' · Kosten: ${Money.fromCents(role.hourlyCostRateCents)} / Std.',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit_outlined),
                          onPressed: () => _edit(role),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _delete(role),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'staff-roles-fab',
        onPressed: _create,
        icon: const Icon(Icons.add),
        label: const Text('Rolle anlegen'),
      ),
    );
  }
}

class _StaffRoleFormResult {
  const _StaffRoleFormResult({
    required this.name,
    required this.hourlyCostRateCents,
    required this.hourlyBillingRateCents,
  });
  final String name;
  final int hourlyCostRateCents;
  final int hourlyBillingRateCents;
}

class _StaffRoleFormDialog extends StatefulWidget {
  const _StaffRoleFormDialog({this.existing});
  final StaffRole? existing;

  @override
  State<_StaffRoleFormDialog> createState() => _StaffRoleFormDialogState();
}

class _StaffRoleFormDialogState extends State<_StaffRoleFormDialog> {
  late final _nameCtrl = TextEditingController(text: widget.existing?.name);
  late final _rateCtrl = TextEditingController(
    text: widget.existing == null ? null : Money.fromCents(widget.existing!.hourlyCostRateCents).formatEuro(),
  );
  late final _billingCtrl = TextEditingController(
    text: widget.existing == null || widget.existing!.hourlyBillingRateCents == 0
        ? null
        : Money.fromCents(widget.existing!.hourlyBillingRateCents).formatEuro(),
  );

  bool get _isEdit => widget.existing != null;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _rateCtrl.dispose();
    _billingCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEdit ? 'Rolle bearbeiten' : 'Neue Rolle'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameCtrl,
            autofocus: !_isEdit,
            decoration: const InputDecoration(labelText: 'Name *'),
          ),
          TextField(
            key: const Key('staff-role-billing'),
            controller: _billingCtrl,
            decoration: const InputDecoration(
              labelText: 'Verrechnungssatz (€/h)',
              helperText: 'Preis je Stunde für den Kunden',
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          TextField(
            controller: _rateCtrl,
            decoration: const InputDecoration(
              labelText: 'Kostensatz (€/h)',
              helperText: 'Was dich die Stunde kostet (Projekt-Ergebnis)',
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
        FilledButton(
          onPressed: () {
            final name = _nameCtrl.text.trim();
            if (name.isEmpty) return;
            int cents(TextEditingController c) => c.text.trim().isEmpty ? 0 : Money.fromEuroString(c.text.trim()).cents;
            Navigator.pop(
              context,
              _StaffRoleFormResult(
                name: name,
                hourlyCostRateCents: cents(_rateCtrl),
                hourlyBillingRateCents: cents(_billingCtrl),
              ),
            );
          },
          child: Text(_isEdit ? 'Speichern' : 'Anlegen'),
        ),
      ],
    );
  }
}
