import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/repositories/company_repository.dart';
import '../../domain/models/money.dart';
import '../../domain/services/active_company_service.dart';

/// "Mahnwesen" als eigene Unterseite (Nachtrag 2026-10-18: "Die
/// Einstellungen müssen aufgeräumt werden" — in Unterseiten
/// aufgeteilt). C12 Mahnwesen — Nachbesserung (Kay-Feedback
/// 2026-10-17: "Wo stelle ich die Gebühren und die Fristen ein?").
/// Fristen/Gebühren/Zins sind Kays eigene Werte, siehe ausführlichen
/// Doc-Kommentar bei `DunningConfig` in
/// `domain/services/dunning_service.dart`.
class SettingsDunningScreen extends StatefulWidget {
  const SettingsDunningScreen({super.key});

  @override
  State<SettingsDunningScreen> createState() => _SettingsDunningScreenState();
}

class _SettingsDunningScreenState extends State<SettingsDunningScreen> {
  late final TextEditingController _introCtrl;
  late final TextEditingController _closingCtrl;
  late final TextEditingController _reminder2DaysCtrl;
  late final TextEditingController _reminder3DaysCtrl;
  late final TextEditingController _feeLevel1Ctrl;
  late final TextEditingController _feeLevel2Ctrl;
  late final TextEditingController _feeLevel3Ctrl;
  late final TextEditingController _interestRateCtrl;
  bool _saving = false;

  static String _centsToEuroText(int cents) => (cents / 100).toStringAsFixed(2);

  @override
  void initState() {
    super.initState();
    final company = context.read<ActiveCompanyService>().active;
    _introCtrl = TextEditingController(text: company?.pdfIntroTextDunning);
    _closingCtrl = TextEditingController(text: company?.pdfClosingTextDunning);
    _reminder2DaysCtrl =
        TextEditingController(text: (company?.dunningReminder2AfterDays ?? 14).toString());
    _reminder3DaysCtrl =
        TextEditingController(text: (company?.dunningReminder3AfterDays ?? 28).toString());
    _feeLevel1Ctrl = TextEditingController(text: _centsToEuroText(company?.dunningFeeLevel1Cents ?? 0));
    _feeLevel2Ctrl = TextEditingController(text: _centsToEuroText(company?.dunningFeeLevel2Cents ?? 0));
    _feeLevel3Ctrl = TextEditingController(text: _centsToEuroText(company?.dunningFeeLevel3Cents ?? 0));
    _interestRateCtrl =
        TextEditingController(text: (company?.dunningInterestRatePercent ?? 0).toString());
  }

  @override
  void dispose() {
    _introCtrl.dispose();
    _closingCtrl.dispose();
    _reminder2DaysCtrl.dispose();
    _reminder3DaysCtrl.dispose();
    _feeLevel1Ctrl.dispose();
    _feeLevel2Ctrl.dispose();
    _feeLevel3Ctrl.dispose();
    _interestRateCtrl.dispose();
    super.dispose();
  }

  /// Ungültige Eingaben werden nicht stillschweigend auf 0 gesetzt,
  /// sondern lehnen das Speichern mit einer Fehlermeldung ab — sonst
  /// könnte ein Tippfehler unbemerkt eine Gebühr auf 0 € zurücksetzen.
  Future<void> _save() async {
    final reminder2Days = int.tryParse(_reminder2DaysCtrl.text.trim());
    final reminder3Days = int.tryParse(_reminder3DaysCtrl.text.trim());
    final interestRate = double.tryParse(_interestRateCtrl.text.trim().replaceAll(',', '.'));
    Money? fee1;
    Money? fee2;
    Money? fee3;
    try {
      fee1 = Money.fromEuroString(_feeLevel1Ctrl.text.trim());
      fee2 = Money.fromEuroString(_feeLevel2Ctrl.text.trim());
      fee3 = Money.fromEuroString(_feeLevel3Ctrl.text.trim());
    } catch (_) {
      fee1 = null;
    }
    if (reminder2Days == null ||
        reminder3Days == null ||
        interestRate == null ||
        fee1 == null ||
        fee2 == null ||
        fee3 == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bitte gültige Zahlen für Fristen/Gebühren/Zins eingeben.')),
      );
      return;
    }
    final service = context.read<ActiveCompanyService>();
    final company = service.active;
    if (company == null) return;
    setState(() => _saving = true);
    try {
      await context.read<CompanyRepository>().update(
            company.copyWith(
              dunningReminder2AfterDays: reminder2Days,
              dunningReminder3AfterDays: reminder3Days,
              dunningFeeLevel1Cents: fee1.cents,
              dunningFeeLevel2Cents: fee2.cents,
              dunningFeeLevel3Cents: fee3.cents,
              dunningInterestRatePercent: interestRate,
              pdfIntroTextDunning: Value(_introCtrl.text.trim().isEmpty ? null : _introCtrl.text.trim()),
              pdfClosingTextDunning:
                  Value(_closingCtrl.text.trim().isEmpty ? null : _closingCtrl.text.trim()),
            ),
          );
      await service.refreshActive();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mahnwesen-Einstellungen gespeichert.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mahnwesen')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Eigene Angaben — keine Rechtsprüfung, ob Frist/Gebühr/Zins im '
                    'Einzelfall zulässig sind (siehe Roadmap C12).',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _reminder2DaysCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: '2. Mahnstufe ab (Tage)'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _reminder3DaysCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: '3. Mahnstufe ab (Tage)'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _feeLevel1Ctrl,
                          decoration: const InputDecoration(labelText: 'Mahngebühr 1. Stufe (€)'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _feeLevel2Ctrl,
                          decoration: const InputDecoration(labelText: 'Mahngebühr 2. Stufe (€)'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _feeLevel3Ctrl,
                          decoration: const InputDecoration(labelText: 'Mahngebühr 3. Stufe (€)'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _interestRateCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Verzugszins (% pro Jahr, 0 = ohne Zins)',
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Mahnschreiben', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _introCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Einleitungstext (Mahnschreiben)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _closingCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Schlusstext (Mahnschreiben)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton(
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Speichern'),
                    ),
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
