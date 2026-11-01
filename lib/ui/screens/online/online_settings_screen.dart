import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
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
        if (admin && modules.contains('timeTracking'))
          _MenuTile(
            icon: Icons.badge_outlined,
            title: 'Rollen & Stundensätze',
            subtitle: 'Monteur, Meister, Projektleiter …',
            onTap: () => _push(context, OnlineStaffRolesScreen(session: session)),
          ),
        if (admin)
          _MenuTile(
            icon: Icons.save_outlined,
            title: 'Daten & Sicherung',
            subtitle: 'Alle Firmendaten exportieren',
            onTap: () => _push(context, OnlineDataExportScreen(session: session)),
          ),
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

/// Rollen & Stundensätze wie offline (`settings_staff_roles_screen.dart`).
/// Online gilt zusätzlich der Stundensatz je Mitglied, wenn eine Buchung
/// keine Rolle trägt.
class OnlineStaffRolesScreen extends StatefulWidget {
  const OnlineStaffRolesScreen({super.key, required this.session});
  final OnlineSession session;

  @override
  State<OnlineStaffRolesScreen> createState() => _OnlineStaffRolesScreenState();
}

class _OnlineStaffRolesScreenState extends State<OnlineStaffRolesScreen> {
  late Future<List<OnlineStaffRole>> _future = widget.session.client.staffRoles();

  void _reload() => setState(() {
        _future = widget.session.client.staffRoles();
      });

  Future<void> _edit([OnlineStaffRole? existing]) async {
    final result = await showDialog<({String name, int cents})>(
      context: context,
      builder: (_) => _StaffRoleFormDialog(existing: existing),
    );
    if (result == null || !mounted) return;
    try {
      await widget.session.client.saveStaffRole(id: existing?.id, name: result.name, hourlyCostCents: result.cents);
      _reload();
    } on Exception catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(describeOnlineError(e))));
    }
  }

  Future<void> _delete(OnlineStaffRole role) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rolle löschen?'),
        content: Text(
          '"${role.name}" löschen? Bereits gebuchte Zeiten mit dieser Rolle behalten ihren '
          'eingefrorenen Stundensatz, verlieren aber den Rollenbezug.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Abbrechen')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Löschen')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await widget.session.client.deleteStaffRole(role.id);
      _reload();
    } on Exception catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(describeOnlineError(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Rollen & Stundensätze')),
      body: FutureBuilder<List<OnlineStaffRole>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text(describeOnlineError(snapshot.error!)));
          if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          final roles = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                child: Text(
                  'Rollen sind Stundensatz-Kategorien — eine Zeitbuchung kann optional eine Rolle wählen, deren '
                  'Stundenkostensatz in die Projekt-Ergebnisrechnung einfließt. Ohne Rolle gilt der Stundensatz '
                  'des Mitglieds (Einstellungen › Mitglieder).',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              for (final role in roles)
                Card(
                  child: ListTile(
                    title: Text(role.name),
                    subtitle: Text('${Money.fromCents(role.hourlyCostCents)} / Std.'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(tooltip: 'Bearbeiten', icon: const Icon(Icons.edit_outlined), onPressed: () => _edit(role)),
                        IconButton(tooltip: 'Löschen', icon: const Icon(Icons.delete_outline), onPressed: () => _delete(role)),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'online-staff-roles-fab',
        onPressed: _edit,
        icon: const Icon(Icons.add),
        label: const Text('Rolle anlegen'),
      ),
    );
  }
}

class _StaffRoleFormDialog extends StatefulWidget {
  const _StaffRoleFormDialog({this.existing});
  final OnlineStaffRole? existing;

  @override
  State<_StaffRoleFormDialog> createState() => _StaffRoleFormDialogState();
}

class _StaffRoleFormDialogState extends State<_StaffRoleFormDialog> {
  late final _nameCtrl = TextEditingController(text: widget.existing?.name);
  late final _rateCtrl = TextEditingController(
    text: widget.existing == null ? null : Money.fromCents(widget.existing!.hourlyCostCents).formatEuro(),
  );
  String? _error;

  bool get _isEdit => widget.existing != null;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _rateCtrl.dispose();
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
            key: const Key('online-role-name'),
            controller: _nameCtrl,
            autofocus: !_isEdit,
            decoration: const InputDecoration(labelText: 'Name *'),
          ),
          TextField(
            key: const Key('online-role-rate'),
            controller: _rateCtrl,
            decoration: InputDecoration(labelText: 'Stundenkostensatz (€)', errorText: _error),
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
            final rateText = _rateCtrl.text.trim();
            final int cents;
            try {
              cents = rateText.isEmpty ? 0 : Money.fromEuroString(rateText).cents;
            } on FormatException {
              setState(() => _error = 'Bitte einen Betrag eingeben.');
              return;
            }
            Navigator.pop(context, (name: name, cents: cents));
          },
          child: Text(_isEdit ? 'Speichern' : 'Anlegen'),
        ),
      ],
    );
  }
}

/// „Daten & Sicherung“ online: Die Datenbank sichert der Betreiber; hier
/// lädt der Admin alle Firmendaten als JSON herunter (z. B. für den
/// Steuerberater oder einen Anbieterwechsel). Ohne Passwörter/Zugangsdaten.
class OnlineDataExportScreen extends StatefulWidget {
  const OnlineDataExportScreen({super.key, required this.session});
  final OnlineSession session;

  @override
  State<OnlineDataExportScreen> createState() => _OnlineDataExportScreenState();
}

class _OnlineDataExportScreenState extends State<OnlineDataExportScreen> {
  bool _busy = false;

  /// Dateiname `werkkernerp-firma-JJJJ-MM-TT.json` ohne Sonderzeichen.
  String _fileName() {
    final now = DateTime.now();
    final slug = widget.session.companyName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9äöüß]+'), '-').replaceAll(RegExp(r'^-|-$'), '');
    final date = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    return 'werkkernerp-${slug.isEmpty ? 'firma' : slug}-$date.json';
  }

  Future<void> _export() async {
    setState(() => _busy = true);
    try {
      final data = await widget.session.client.exportCompanyData();
      final bytes = Uint8List.fromList(utf8.encode(const JsonEncoder.withIndent('  ').convert(data)));
      final saved = await FilePicker.saveFile(fileName: _fileName(), bytes: bytes, dialogTitle: 'Datenexport speichern');
      if (saved != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Datenexport gespeichert.')));
      }
    } on Exception catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(describeOnlineError(e))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Daten & Sicherung')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Sicherung', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 4),
                  const Text(
                    'Die Daten liegen auf dem Server und werden vom Betreiber verschlüsselt gesichert. '
                    'Eine eigene Sicherung auf dem Gerät ist online nicht nötig.',
                  ),
                ],
              ),
            ),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Datenexport', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 4),
                  const Text(
                    'Lädt alle Daten dieser Firma als JSON-Datei herunter: Kunden, Artikel, Lieferanten, '
                    'Dokumente mit Positionen, Projekte, Zeiten, Stundenzettel, Fuhrpark, Lager, Bestellungen, '
                    'Buchhaltung und Einstellungen. Passwörter und Zugangsdaten sind nicht enthalten.',
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      key: const Key('online-export-start'),
                      onPressed: _busy ? null : _export,
                      icon: _busy
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.download_outlined),
                      label: const Text('Datenexport erstellen'),
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
