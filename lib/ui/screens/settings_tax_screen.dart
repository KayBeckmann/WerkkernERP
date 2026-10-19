import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/repositories/company_repository.dart';
import '../../domain/services/active_company_service.dart';

/// "Umsatzsteuer" als eigene Unterseite (Nachtrag 2026-10-18: "Die
/// Einstellungen müssen aufgeräumt werden" — in Unterseiten
/// aufgeteilt). Bewusst getrennt von "Module": Kleinunternehmer ist
/// keine Dokumentart, sondern eine Steuer-Arbeitsvorgabe quer durch
/// alle Dokumentarten (siehe `invoice_item_dialog.dart`/
/// `invoice_pdf_builder.dart`).
class SettingsTaxScreen extends StatefulWidget {
  const SettingsTaxScreen({super.key});

  @override
  State<SettingsTaxScreen> createState() => _SettingsTaxScreenState();
}

class _SettingsTaxScreenState extends State<SettingsTaxScreen> {
  bool _busy = false;

  Future<void> _setSmallBusinessExempt(bool value) async {
    final service = context.read<ActiveCompanyService>();
    final company = service.active;
    if (company == null) return;
    setState(() => _busy = true);
    try {
      await context.read<CompanyRepository>().update(
            company.copyWith(isSmallBusinessExempt: value),
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
      appBar: AppBar(title: const Text('Umsatzsteuer')),
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
                    'Arbeitsvorgabe, keine Steuerberatung (F1) — bitte mit deinem '
                    'Steuerberater bestätigen, dass die Kleinunternehmerregelung tatsächlich '
                    'zutrifft, bevor du diesen Schalter aktivierst.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Kleinunternehmer nach § 19 UStG'),
                    subtitle: const Text(
                      'Neue Positionen erhalten automatisch 0 % USt, das PDF zeigt den '
                      'gesetzlichen Hinweis.',
                    ),
                    value: company.isSmallBusinessExempt,
                    onChanged: _busy ? null : _setSmallBusinessExempt,
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
