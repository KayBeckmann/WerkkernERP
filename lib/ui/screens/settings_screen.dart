import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/repositories/company_repository.dart';
import '../../domain/services/active_company_service.dart';
import '../../domain/services/theme_preference_service.dart';
import 'backup_screen.dart';

/// Einstellungen der aktiven Firma: Modul-Schalter (A5: Angebot/Auftrag
/// ein-/ausblendbar), anpassbare PDF-Texte (Kay-Nachtrag 2026-10-16)
/// und Backup/Wiederherstellung (A4). Ein Modul-Schalter steuert
/// ausschließlich die Sichtbarkeit in der Navigation — bereits
/// vorhandene Angebots-/Auftragsdaten bleiben beim Deaktivieren
/// unverändert in der Datenbank (Abnahme A5).
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _busy = false;
  bool _textsSaving = false;

  late final _introCtrl =
      TextEditingController(text: context.read<ActiveCompanyService>().active?.pdfIntroText);
  late final _closingCtrl =
      TextEditingController(text: context.read<ActiveCompanyService>().active?.pdfClosingText);
  late final _footerCtrl =
      TextEditingController(text: context.read<ActiveCompanyService>().active?.pdfFooterText);

  @override
  void dispose() {
    _introCtrl.dispose();
    _closingCtrl.dispose();
    _footerCtrl.dispose();
    super.dispose();
  }

  Future<void> _setModule({
    bool? quotesEnabled,
    bool? ordersEnabled,
    bool? deliveryNotesEnabled,
  }) async {
    final service = context.read<ActiveCompanyService>();
    final company = service.active;
    if (company == null) return;
    setState(() => _busy = true);
    try {
      await context.read<CompanyRepository>().setModules(
            companyId: company.id,
            quotesEnabled: quotesEnabled ?? company.quotesEnabled,
            ordersEnabled: ordersEnabled ?? company.ordersEnabled,
            deliveryNotesEnabled: deliveryNotesEnabled ?? company.deliveryNotesEnabled,
          );
      await service.refreshActive();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Speichert alle drei Textfelder (Kay-Nachtrag 2026-10-16:
  /// "Rechtstexte, Fußzeile und Kopfzeile in Dokumenten anpassbar
  /// machen") — gilt für alle Dokumentarten, siehe Doc-Kommentar bei
  /// `Companies.pdfIntroText` in tables.dart.
  Future<void> _saveTexts() async {
    final service = context.read<ActiveCompanyService>();
    final company = service.active;
    if (company == null) return;
    setState(() => _textsSaving = true);
    try {
      await context.read<CompanyRepository>().update(
            company.copyWith(
              pdfIntroText: Value(_introCtrl.text.trim().isEmpty ? null : _introCtrl.text.trim()),
              pdfClosingText: Value(_closingCtrl.text.trim().isEmpty ? null : _closingCtrl.text.trim()),
              pdfFooterText: Value(_footerCtrl.text.trim().isEmpty ? null : _footerCtrl.text.trim()),
            ),
          );
      await service.refreshActive();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dokumenttexte gespeichert.')),
        );
      }
    } finally {
      if (mounted) setState(() => _textsSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final company = context.watch<ActiveCompanyService>().active;
    if (company == null) return const SizedBox.shrink();

    final themePreference = context.watch<ThemePreferenceService>();

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      children: [
        // Design (Kay-Nachtrag 2026-10-16: "Design in den Einstellungen
        // konfigurieren — Hell/Dunkel/System") — bewusst eine Geräte-,
        // keine Firmeneinstellung, siehe Doc-Kommentar bei
        // ThemePreferenceService.
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Design', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 12),
                SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode_outlined), label: Text('Hell')),
                    ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode_outlined), label: Text('Dunkel')),
                    ButtonSegment(
                      value: ThemeMode.system,
                      icon: Icon(Icons.brightness_auto_outlined),
                      label: Text('System'),
                    ),
                  ],
                  selected: {themePreference.mode},
                  onSelectionChanged: (selection) => themePreference.setMode(selection.first),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
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
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Dokumenttexte', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 4),
                Text(
                  'Gelten für Rechnungen, Angebote und Aufträge gleichermaßen.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _introCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Einleitungstext',
                    hintText: 'z. B. „Vielen Dank für Ihren Auftrag."',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _closingCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Schlusstext',
                    hintText: 'z. B. Rechtstext/Hinweis auf AGB',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _footerCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Fußzeile',
                    hintText: 'z. B. Firmenname — Anschrift',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                    onPressed: _textsSaving ? null : _saveTexts,
                    child: _textsSaving
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
        const SizedBox(height: 12),
        const BackupScreen(),
      ],
    );
  }
}
