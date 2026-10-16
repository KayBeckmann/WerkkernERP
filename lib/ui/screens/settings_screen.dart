import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/repositories/company_repository.dart';
import '../../domain/services/active_company_service.dart';
import 'backup_screen.dart';

/// Einstellungen der aktiven Firma: Modul-Schalter (A5: Angebot/Auftrag
/// ein-/ausblendbar) und Backup/Wiederherstellung (A4). Ein Schalter
/// steuert ausschließlich die Sichtbarkeit in der Navigation — bereits
/// vorhandene Angebots-/Auftragsdaten bleiben beim Deaktivieren
/// unverändert in der Datenbank (Abnahme A5).
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _busy = false;

  Future<void> _setModule({required bool? quotesEnabled, required bool? ordersEnabled}) async {
    final service = context.read<ActiveCompanyService>();
    final company = service.active;
    if (company == null) return;
    setState(() => _busy = true);
    try {
      await context.read<CompanyRepository>().setModules(
            companyId: company.id,
            quotesEnabled: quotesEnabled ?? company.quotesEnabled,
            ordersEnabled: ordersEnabled ?? company.ordersEnabled,
          );
      await service.refreshActive();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final company = context.watch<ActiveCompanyService>().active;
    if (company == null) return const SizedBox.shrink();

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Module', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 4),
                Text(
                  'Pro Firma ein-/ausblendbar. Bereits vorhandene Daten bleiben beim '
                  'Deaktivieren erhalten.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Angebote'),
                  value: company.quotesEnabled,
                  onChanged: _busy ? null : (value) => _setModule(quotesEnabled: value, ordersEnabled: null),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Aufträge'),
                  value: company.ordersEnabled,
                  onChanged: _busy ? null : (value) => _setModule(quotesEnabled: null, ordersEnabled: value),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        const BackupScreen(),
      ],
    );
  }
}
