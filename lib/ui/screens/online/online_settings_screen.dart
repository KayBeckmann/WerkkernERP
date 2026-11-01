import 'package:flutter/material.dart';
import 'package:werkkern_client/werkkern_client.dart';
import 'package:werkkern_core/werkkern_core.dart' show Money;

import '../../../domain/services/online_session.dart';
import '../settings_appearance_screen.dart';
import 'online_admin_screen.dart';

/// Einstellungen der Online-Firma — dieselbe Menüseite wie offline
/// (`settings_screen.dart`). Firmenweite Punkte nur für Firmen-Admins
/// bzw. mit dem passenden Recht; dazu die Mehrbenutzer-Verwaltung, die es
/// offline nicht gibt. Lokale Sicherung und Datenbank-Verschlüsselung
/// entfallen online (Daten liegen auf dem Server).
class OnlineSettingsScreen extends StatelessWidget {
  const OnlineSettingsScreen({super.key, required this.session});
  final OnlineSession session;

  @override
  Widget build(BuildContext context) {
    final admin = session.isAdmin;
    final modules = session.modules;
    Widget adminTile(OnlineAdminSection section, IconData icon, String subtitle) => _MenuTile(
          icon: icon,
          title: section.title,
          subtitle: subtitle,
          onTap: () => _push(context, OnlineAdminPage(session: session, section: section)),
        );
    return ListView(
      children: [
        if (session.permissions.isEmpty)
          const Card(
            margin: EdgeInsets.all(12),
            child: ListTile(
              leading: Icon(Icons.info_outline),
              title: Text('Dir sind in dieser Firma noch keine Rechte zugewiesen.'),
              subtitle: Text('Als Admin vergibst du sie unter „Gruppen & Rechte“ bzw. bei „Mitglieder“.'),
            ),
          ),
        _MenuTile(
          icon: Icons.palette_outlined,
          title: 'Darstellung',
          subtitle: 'Hell/Dunkel/System',
          onTap: () => _push(context, const SettingsAppearanceScreen()),
        ),
        if (admin) ...[
          adminTile(OnlineAdminSection.modules, Icons.extension_outlined, 'Angebote, Aufträge, Buchhaltung, Gutschriften …'),
          adminTile(OnlineAdminSection.company, Icons.business_outlined, 'Anschrift, Steuernummer, IBAN, Kontakt'),
          adminTile(OnlineAdminSection.tax, Icons.receipt_long_outlined, 'Kleinunternehmer nach § 19 UStG'),
          adminTile(OnlineAdminSection.documentTexts, Icons.description_outlined, 'Einleitung/Schluss je Dokumentart, Fußzeile'),
        ],
        if (modules.contains('dunning') && session.can('dunning.write'))
          _MenuTile(
            icon: Icons.notifications_active_outlined,
            title: 'Mahnwesen',
            subtitle: 'Fristen, Gebühren, Zins, Mahnschreiben',
            onTap: () => _push(context, OnlineDunningSettingsScreen(session: session)),
          ),
        if (admin && modules.contains('smtp'))
          adminTile(OnlineAdminSection.mail, Icons.outgoing_mail, 'Server, Zugangsdaten, E-Mail-Vorlagen'),
        if (admin) ...[
          const Divider(),
          const _SectionHeader('Benutzer & Zugriff'),
          adminTile(OnlineAdminSection.members, Icons.people_outline, 'Mitglieder, Gruppe, Ausnahmen, Stundensatz'),
          adminTile(OnlineAdminSection.groups, Icons.admin_panel_settings_outlined, 'Rechte je Gruppe'),
          adminTile(OnlineAdminSection.invitations, Icons.mail_outline, 'Neue Mitglieder einladen'),
          adminTile(OnlineAdminSection.audit, Icons.history, 'Wer hat wann was geändert'),
        ],
      ],
    );
  }

  void _push(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        child: Text(text, style: Theme.of(context).textTheme.titleSmall),
      );
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({required this.icon, required this.title, required this.subtitle, required this.onTap});

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

/// Mahnwesen-Einstellungen — gleiche Seite wie offline
/// (`settings_dunning_screen.dart`), gespeichert auf dem Server.
class OnlineDunningSettingsScreen extends StatefulWidget {
  const OnlineDunningSettingsScreen({super.key, required this.session});
  final OnlineSession session;

  @override
  State<OnlineDunningSettingsScreen> createState() => _OnlineDunningSettingsScreenState();
}

class _OnlineDunningSettingsScreenState extends State<OnlineDunningSettingsScreen> {
  final _introCtrl = TextEditingController();
  final _closingCtrl = TextEditingController();
  final _reminder2DaysCtrl = TextEditingController();
  final _reminder3DaysCtrl = TextEditingController();
  final _feeLevel1Ctrl = TextEditingController();
  final _feeLevel2Ctrl = TextEditingController();
  final _feeLevel3Ctrl = TextEditingController();
  final _interestRateCtrl = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  Object? _error;

  static String _centsToEuroText(int cents) => (cents / 100).toStringAsFixed(2);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [
      _introCtrl,
      _closingCtrl,
      _reminder2DaysCtrl,
      _reminder3DaysCtrl,
      _feeLevel1Ctrl,
      _feeLevel2Ctrl,
      _feeLevel3Ctrl,
      _interestRateCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final s = await widget.session.client.dunningSettings();
      if (!mounted) return;
      _reminder2DaysCtrl.text = '${s['reminder2AfterDays'] ?? 14}';
      _reminder3DaysCtrl.text = '${s['reminder3AfterDays'] ?? 28}';
      _feeLevel1Ctrl.text = _centsToEuroText(s['feeLevel1Cents'] as int? ?? 0);
      _feeLevel2Ctrl.text = _centsToEuroText(s['feeLevel2Cents'] as int? ?? 0);
      _feeLevel3Ctrl.text = _centsToEuroText(s['feeLevel3Cents'] as int? ?? 0);
      _interestRateCtrl.text = '${s['interestRatePercent'] ?? 0}';
      _introCtrl.text = s['introText'] as String? ?? '';
      _closingCtrl.text = s['closingText'] as String? ?? '';
    } on Exception catch (e) {
      _error = e;
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Ungültige Eingaben lehnen das Speichern ab (wie offline) — sonst
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
    String? text(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();
    setState(() => _saving = true);
    try {
      await widget.session.client.saveDunningSettings({
        'reminder2AfterDays': reminder2Days,
        'reminder3AfterDays': reminder3Days,
        'feeLevel1Cents': fee1.cents,
        'feeLevel2Cents': fee2.cents,
        'feeLevel3Cents': fee3.cents,
        'interestRatePercent': interestRate,
        'introText': text(_introCtrl),
        'closingText': text(_closingCtrl),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mahnwesen-Einstellungen gespeichert.')),
        );
      }
    } on Exception catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(describeOnlineError(e))));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mahnwesen')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(describeOnlineError(_error!))))
          : ListView(
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
                                key: const Key('online-dunning-reminder2'),
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
                                key: const Key('online-dunning-fee1'),
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
                          decoration: const InputDecoration(labelText: 'Verzugszins (% pro Jahr, 0 = ohne Zins)'),
                        ),
                        const SizedBox(height: 16),
                        const Text('Mahnschreiben', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
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
                                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
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
