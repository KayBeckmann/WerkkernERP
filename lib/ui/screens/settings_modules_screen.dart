import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/repositories/company_repository.dart';
import '../../domain/services/active_company_service.dart';

/// "Module" als eigene Unterseite (Nachtrag 2026-10-18: "Die
/// Einstellungen müssen aufgeräumt werden" — in Unterseiten
/// aufgeteilt). Pro Firma ein-/ausblendbare Dokumentarten/Bereiche.
class SettingsModulesScreen extends StatefulWidget {
  const SettingsModulesScreen({super.key});

  @override
  State<SettingsModulesScreen> createState() => _SettingsModulesScreenState();
}

class _SettingsModulesScreenState extends State<SettingsModulesScreen> {
  bool _busy = false;

  Future<void> _setModule({
    bool? quotesEnabled,
    bool? ordersEnabled,
    bool? deliveryNotesEnabled,
    bool? proformaEnabled,
    bool? projectsEnabled,
    bool? fleetEnabled,
    bool? recurringInvoicesEnabled,
    bool? advancePaymentInvoicesEnabled,
    bool? dunningEnabled,
    bool? smtpEnabled,
    bool? buchhaltungEnabled,
    bool? creditNotesEnabled,
    bool? lagerbestandEnabled,
    bool? bestellwesenEnabled,
  }) async {
    final service = context.read<ActiveCompanyService>();
    final company = service.active;
    if (company == null) return;
    final newLagerbestandEnabled = lagerbestandEnabled ?? company.lagerbestandEnabled;
    setState(() => _busy = true);
    try {
      await context.read<CompanyRepository>().setModules(
            companyId: company.id,
            quotesEnabled: quotesEnabled ?? company.quotesEnabled,
            ordersEnabled: ordersEnabled ?? company.ordersEnabled,
            deliveryNotesEnabled: deliveryNotesEnabled ?? company.deliveryNotesEnabled,
            proformaEnabled: proformaEnabled ?? company.proformaEnabled,
            projectsEnabled: projectsEnabled ?? company.projectsEnabled,
            fleetEnabled: fleetEnabled ?? company.fleetEnabled,
            recurringInvoicesEnabled: recurringInvoicesEnabled ?? company.recurringInvoicesEnabled,
            advancePaymentInvoicesEnabled:
                advancePaymentInvoicesEnabled ?? company.advancePaymentInvoicesEnabled,
            dunningEnabled: dunningEnabled ?? company.dunningEnabled,
            smtpEnabled: smtpEnabled ?? company.smtpEnabled,
            buchhaltungEnabled: buchhaltungEnabled ?? company.buchhaltungEnabled,
            creditNotesEnabled: creditNotesEnabled ?? company.creditNotesEnabled,
            lagerbestandEnabled: newLagerbestandEnabled,
            // C5.2 Bestellwesen setzt Lagerbestand voraus (Roadmap: "nur
            // sichtbar/nutzbar wenn lagerbestandEnabled ebenfalls aktiv
            // ist") — wird Lagerbestand hier ausgeschaltet, kann
            // Bestellwesen nicht aktiviert bleiben.
            bestellwesenEnabled:
                newLagerbestandEnabled ? (bestellwesenEnabled ?? company.bestellwesenEnabled) : false,
          );
      await service.refreshActive();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final company = context.watch<ActiveCompanyService>().active;
    if (company == null) return const Scaffold(body: SizedBox.shrink());

    return Scaffold(
      appBar: AppBar(title: const Text('Module')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pro Firma ein-/ausblendbar. Bereits vorhandene Daten bleiben beim '
                    'Deaktivieren erhalten.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Angebote'),
                    value: company.quotesEnabled,
                    onChanged: _busy ? null : (value) => _setModule(quotesEnabled: value),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Aufträge'),
                    value: company.ordersEnabled,
                    onChanged: _busy ? null : (value) => _setModule(ordersEnabled: value),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Lieferscheine'),
                    value: company.deliveryNotesEnabled,
                    onChanged: _busy ? null : (value) => _setModule(deliveryNotesEnabled: value),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Proforma-Rechnungen'),
                    value: company.proformaEnabled,
                    onChanged: _busy ? null : (value) => _setModule(proformaEnabled: value),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Projekte'),
                    value: company.projectsEnabled,
                    onChanged: _busy ? null : (value) => _setModule(projectsEnabled: value),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Fuhrpark'),
                    value: company.fleetEnabled,
                    onChanged: _busy ? null : (value) => _setModule(fleetEnabled: value),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Wiederkehrende Rechnungen'),
                    value: company.recurringInvoicesEnabled,
                    onChanged: _busy ? null : (value) => _setModule(recurringInvoicesEnabled: value),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Abschlagsrechnungen'),
                    value: company.advancePaymentInvoicesEnabled,
                    onChanged: _busy
                        ? null
                        : (value) => _setModule(advancePaymentInvoicesEnabled: value),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Mahnwesen'),
                    value: company.dunningEnabled,
                    onChanged: _busy ? null : (value) => _setModule(dunningEnabled: value),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Versand (SMTP)'),
                    value: company.smtpEnabled,
                    onChanged: _busy ? null : (value) => _setModule(smtpEnabled: value),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Buchhaltung'),
                    value: company.buchhaltungEnabled,
                    onChanged: _busy ? null : (value) => _setModule(buchhaltungEnabled: value),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Gutschriften'),
                    value: company.creditNotesEnabled,
                    onChanged: _busy ? null : (value) => _setModule(creditNotesEnabled: value),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Lagerbestand'),
                    value: company.lagerbestandEnabled,
                    onChanged: _busy ? null : (value) => _setModule(lagerbestandEnabled: value),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Bestellwesen'),
                    subtitle: company.lagerbestandEnabled
                        ? null
                        : const Text('Setzt Lagerbestand voraus'),
                    value: company.bestellwesenEnabled,
                    onChanged: !_busy && company.lagerbestandEnabled
                        ? (value) => _setModule(bestellwesenEnabled: value)
                        : null,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
