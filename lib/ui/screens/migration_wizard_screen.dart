import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:werkkern_client/werkkern_client.dart';

import '../../data/backup/backup_io.dart';
import '../../data/backup/backup_service.dart';
import '../../data/database/database.dart';
import '../../data/migration/migration_package_builder.dart';
import '../../data/repositories/company_repository.dart';
import '../../domain/services/active_company_service.dart';
import '../../domain/services/online_accounts.dart';
import '../../domain/services/online_session.dart';
import 'company_switcher_screen.dart';
import 'online/online_login_screen.dart';

/// B4 Umzug Einzelplatz → Online-Firma (Selbstbedienung, Kay
/// 2026-11-02): Warnhinweis „kein Zurück“, Konto + neue leere
/// Online-Firma, Rollen den Mitgliedern zuordnen, Probelauf, Sicherung,
/// Umzug. Danach ist die lokale Firma nur noch Archiv.
class MigrationWizardScreen extends StatefulWidget {
  const MigrationWizardScreen({
    super.key,
    required this.company,
    this.clientFactory,
    this.accountStore,
    this.offlineStoreFactory,
  });

  final Company company;
  final WerkkernApiClient Function(Uri baseUrl)? clientFactory;
  final OnlineAccountStore? accountStore;
  final OfflineStore? Function()? offlineStoreFactory;

  @override
  State<MigrationWizardScreen> createState() => _MigrationWizardScreenState();
}

enum _Step { warning, account, roles, check, done }

class _MigrationWizardScreenState extends State<MigrationWizardScreen> {
  _Step _step = _Step.warning;
  bool _acknowledged = false;
  bool _busy = false;
  String? _error;

  final _serverCtrl = TextEditingController(text: defaultOnlineServerUrl());
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  late final _companyNameCtrl = TextEditingController(text: widget.company.name);
  late final OnlineAccountStore _accounts = widget.accountStore ?? defaultOnlineAccountStore();

  Uri? _serverUrl;
  WerkkernApiClient? _client;
  OnlineLogin? _login;
  String? _onlineCompanyId;
  DateTime? _expiresAt;
  Map<String, Object?>? _package;
  CompanyImportResult? _preview;
  List<OnlineMember> _members = const [];
  List<OnlineGroup> _groups = const [];
  final Map<String, String> _assignments = {};
  String? _backupPath;

  @override
  void dispose() {
    _serverCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _companyNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on Exception catch (e) {
      if (mounted) setState(() => _error = describeOnlineError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  WerkkernApiClient _newClient(Uri url) => (widget.clientFactory ?? (u) => WerkkernApiClient(baseUrl: u))(url);

  bool _readAccountFields() {
    final raw = _serverCtrl.text.trim();
    final url = Uri.tryParse(raw.contains('://') ? raw : 'https://$raw');
    if (url == null || url.host.isEmpty) {
      setState(() => _error = 'Bitte eine gültige Server-Adresse eingeben.');
      return false;
    }
    if (_emailCtrl.text.trim().isEmpty || _passwordCtrl.text.length < 8) {
      setState(() => _error = 'E-Mail und Passwort (mind. 8 Zeichen) eingeben.');
      return false;
    }
    _serverUrl = url;
    return true;
  }

  Future<void> _signIn({bool register = false}) async {
    if (!_readAccountFields()) return;
    await _run(() async {
      final client = _newClient(_serverUrl!);
      if (register) await client.register(_emailCtrl.text.trim(), _passwordCtrl.text);
      final login = await client.login(_emailCtrl.text.trim(), _passwordCtrl.text);
      setState(() {
        _client = client;
        _login = login;
      });
    });
  }

  /// Neue, leere Online-Firma mit dem Konto als Admin, dann direkt in sie
  /// wechseln (das Login-Zwischentoken ist danach verbraucht → neu
  /// anmelden).
  Future<void> _createOnlineCompany() async {
    final name = _companyNameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Bitte einen Firmennamen eingeben.');
      return;
    }
    final builder = MigrationPackageBuilder(context.read<AppDatabase>());
    await _run(() async {
      final client = _client!;
      final companyId = await client.createCompany(_login!.identityToken, name);
      final login = await client.login(_emailCtrl.text.trim(), _passwordCtrl.text);
      _expiresAt = await client.selectCompany(login.identityToken, companyId);
      _login = login;
      _onlineCompanyId = companyId;
      _package ??= await builder.build(widget.company.id);
      await _loadMembersAndPreview();
      if (mounted) setState(() => _step = _Step.roles);
    });
  }

  Future<void> _loadMembersAndPreview() async {
    final client = _client!;
    final members = (await client.members()).where((m) => m.active).toList();
    final groups = await client.groups();
    final preview = await client.importCompany(_package!, dryRun: true);
    final me = members.firstWhere((m) => m.email == _emailCtrl.text.trim(), orElse: () => members.first);
    if (!mounted) return;
    setState(() {
      _members = members;
      _groups = groups;
      _preview = preview;
      for (final role in preview.roles) {
        final current = _assignments[role.id];
        if (current == null || !members.any((m) => m.id == current)) _assignments[role.id] = me.id;
      }
    });
  }

  Future<void> _invite() async {
    final result = await showDialog<(String, String)>(
      context: context,
      builder: (_) => _InviteDialog(groups: _groups),
    );
    if (result == null) return;
    await _run(() async {
      final code = await _client!.createInvitation(result.$1, result.$2);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Einladung erstellt'),
          content: SelectableText(
            'Code für ${result.$1}:\n\n$code\n\nDer Code wird nur jetzt angezeigt. Die Person meldet sich in der App '
            'unter „Online anmelden“ → „Einladung einlösen“ an. Danach hier „Mitglieder aktualisieren“.',
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
        ),
      );
    });
  }

  Future<void> _check() => _run(() async {
        final preview = await _client!.importCompany(_package!, roleAssignments: _assignments, dryRun: true);
        if (mounted) {
          setState(() {
            _preview = preview;
            _step = _Step.check;
          });
        }
      });

  Future<void> _migrate() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Endgültig umziehen?'),
        content: Text(
          'Es gibt kein Zurück zur Offline-Variante. „${widget.company.name}“ ist danach auf diesem Gerät nur noch '
          'lesbar; weitergearbeitet wird online in „${_companyNameCtrl.text.trim()}“.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Abbrechen')),
          FilledButton(
            key: const Key('migration-confirm'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Jetzt umziehen'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final backups = context.read<BackupService>();
    final companies = context.read<CompanyRepository>();
    final active = context.read<ActiveCompanyService>();
    await _run(() async {
      if (backups.isSupported) {
        final stamp = DateTime.now().toIso8601String().replaceAll(RegExp('[:.]'), '-');
        _backupPath = await writeMigrationBackupFile('vor-umzug-$stamp.wkbackup', await backups.createBackup());
      }
      await _client!.importCompany(_package!, roleAssignments: _assignments);
      await companies.markMigrated(
        widget.company.id,
        server: _serverUrl.toString(),
        companyName: _companyNameCtrl.text.trim(),
      );
      await active.loadCompanies();
      await _accounts.save(
        SavedOnlineAccount(
          serverUrl: _serverUrl.toString(),
          email: _emailCtrl.text.trim(),
          memberships: (await _client!.login(_emailCtrl.text.trim(), _passwordCtrl.text)).memberships,
        ).withSession(token: _client!.token, companyId: _onlineCompanyId, expiresAt: _expiresAt),
      );
      if (mounted) setState(() => _step = _Step.done);
    });
  }

  /// Startseite neu aufbauen (die Offline-Firma ist jetzt Archiv) und
  /// direkt mit der gemerkten Sitzung in die Online-Firma.
  Future<void> _openOnline() async {
    final account = (await _accounts.load())
        .where((a) => a.serverUrl == _serverUrl.toString() && a.email == _emailCtrl.text.trim())
        .firstOrNull;
    if (!mounted) return;
    final navigator = Navigator.of(context);
    unawaited(navigator.pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => CompanySwitcherScreen(
          accountStore: _accounts,
          onlineClientFactory: widget.clientFactory,
          offlineStoreFactory: widget.offlineStoreFactory,
        ),
      ),
      (_) => false,
    ));
    unawaited(navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => OnlineLoginScreen(
          clientFactory: widget.clientFactory,
          offlineStoreFactory: widget.offlineStoreFactory,
          accountStore: _accounts,
          account: account,
          targetCompanyId: _onlineCompanyId,
        ),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Auf Server umziehen'),
        automaticallyImplyLeading: _step != _Step.done,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ..._content(context),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                    ],
                    if (_busy) const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator())),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _content(BuildContext context) {
    final theme = Theme.of(context);
    switch (_step) {
      case _Step.warning:
        return [
          Card(
            color: theme.colorScheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: theme.colorScheme.onErrorContainer),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Es gibt kein Zurück zur Offline-Variante',
                          style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onErrorContainer),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Alle Daten von „${widget.company.name}“ ziehen einmalig in eine neue Online-Firma um — Kunden, '
                    'Artikel, alle Dokumente mit ihren Nummern, Projekte, Zeiten, Lager, Buchhaltung und Einstellungen. '
                    'Danach wird nur noch online gearbeitet; die Firma auf diesem Gerät bleibt als schreibgeschütztes '
                    'Archiv (lesen, PDF, Sicherung). Ein Zurückholen der Online-Daten in die Offline-App ist nicht '
                    'vorgesehen.',
                    style: TextStyle(color: theme.colorScheme.onErrorContainer),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text('Vor dem Umzug legt die App automatisch eine lokale Sicherung an. Der E-Mail-Versand (SMTP) muss '
              'online neu eingerichtet werden.'),
          CheckboxListTile(
            key: const Key('migration-ack'),
            value: _acknowledged,
            onChanged: (v) => setState(() => _acknowledged = v ?? false),
            title: const Text('Ich habe verstanden: Es gibt kein Zurück zur Offline-Variante.'),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
          ),
          FilledButton(
            onPressed: _acknowledged ? () => setState(() => _step = _Step.account) : null,
            child: const Text('Weiter'),
          ),
        ];
      case _Step.account:
        if (_login == null) {
          return [
            Text('Konto auf dem Server', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            TextField(
              key: const Key('migration-server'),
              controller: _serverCtrl,
              decoration: const InputDecoration(labelText: 'Server-Adresse'),
            ),
            TextField(
              key: const Key('migration-email'),
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'E-Mail'),
            ),
            TextField(
              key: const Key('migration-password'),
              controller: _passwordCtrl,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Passwort (mind. 8 Zeichen)'),
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: _busy ? null : () => _signIn(), child: const Text('Anmelden')),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: _busy ? null : () => _signIn(register: true),
              child: const Text('Neues Konto registrieren'),
            ),
          ];
        }
        return [
          Text('Neue Online-Firma', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          const Text('Der Umzug geht nur in eine neue, leere Firma. Du wirst dort Admin.'),
          TextField(
            key: const Key('migration-company-name'),
            controller: _companyNameCtrl,
            decoration: const InputDecoration(labelText: 'Firmenname online'),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy ? null : _createOnlineCompany,
            child: const Text('Firma anlegen und weiter'),
          ),
        ];
      case _Step.roles:
        final preview = _preview!;
        return [
          Text('Mitarbeiter & Zeiten', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          const Text('Offline gebuchte Zeiten gehören zu einer Rolle, nicht zu einer Person. Wähle je Rolle, welchem '
              'Mitglied die Zeiten online gehören. Weitere Mitarbeiter kannst du jetzt einladen — sie erscheinen, sobald '
              'sie die Einladung eingelöst haben.'),
          const SizedBox(height: 8),
          for (final m in _members)
            ListTile(
              dense: true,
              leading: const Icon(Icons.person_outline),
              title: Text(m.email),
              subtitle: Text(m.isAdmin ? '${m.groupName} · Admin' : m.groupName),
            ),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _busy ? null : _invite,
                icon: const Icon(Icons.person_add_alt),
                label: const Text('Mitarbeiter einladen'),
              ),
              OutlinedButton.icon(
                onPressed: _busy ? null : () => _run(_loadMembersAndPreview),
                icon: const Icon(Icons.refresh),
                label: const Text('Mitglieder aktualisieren'),
              ),
            ],
          ),
          const Divider(height: 32),
          if (preview.roles.isEmpty) const Text('Keine Zeitbuchungen — nichts zuzuordnen.'),
          for (final role in preview.roles)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: DropdownButtonFormField<String>(
                key: Key('migration-role-${role.id}'),
                initialValue: _assignments[role.id],
                decoration: InputDecoration(labelText: '${role.name} (${role.timeEntries} Buchungen)'),
                items: [for (final m in _members) DropdownMenuItem(value: m.id, child: Text(m.email))],
                onChanged: (v) => setState(() => _assignments[role.id] = v!),
              ),
            ),
          const SizedBox(height: 8),
          FilledButton(onPressed: _busy ? null : _check, child: const Text('Prüfen')),
        ];
      case _Step.check:
        final preview = _preview!;
        final ok = preview.errors.isEmpty && preview.missingAssignments.isEmpty;
        return [
          Text('Probelauf', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final e in preview.counts.entries)
            if (e.value > 0)
              Row(children: [Expanded(child: Text(_countLabels[e.key] ?? e.key)), Text('${e.value}')]),
          if (preview.warnings.isNotEmpty) ...[
            const SizedBox(height: 12),
            for (final w in preview.warnings)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.info_outline),
                title: Text(w),
              ),
          ],
          if (preview.errors.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Die Daten können so nicht übernommen werden:', style: TextStyle(color: theme.colorScheme.error)),
            for (final e in preview.errors) Text('• $e', style: TextStyle(color: theme.colorScheme.error)),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            key: const Key('migration-start'),
            onPressed: ok && !_busy ? _migrate : null,
            icon: const Icon(Icons.cloud_upload_outlined),
            label: const Text('Umzug starten'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _busy ? null : () => setState(() => _step = _Step.roles),
            child: const Text('Zurück zur Zuordnung'),
          ),
        ];
      case _Step.done:
        return [
          Icon(Icons.cloud_done_outlined, size: 48, color: theme.colorScheme.primary),
          const SizedBox(height: 8),
          Text('Umzug abgeschlossen', style: theme.textTheme.titleLarge, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(
            '„${widget.company.name}“ ist jetzt online als „${_companyNameCtrl.text.trim()}“. Die Firma auf diesem '
            'Gerät bleibt als schreibgeschütztes Archiv.',
            textAlign: TextAlign.center,
          ),
          if (_backupPath != null) ...[
            const SizedBox(height: 8),
            Text('Sicherung vor dem Umzug: $_backupPath', textAlign: TextAlign.center, style: theme.textTheme.bodySmall),
          ],
          const SizedBox(height: 16),
          FilledButton(onPressed: _openOnline, child: const Text('Zur Online-Firma')),
        ];
    }
  }
}

const _countLabels = {
  'customers': 'Kunden',
  'suppliers': 'Lieferanten',
  'articleGroups': 'Artikelgruppen',
  'articles': 'Artikel',
  'articlePrices': 'Einkaufspreise',
  'projects': 'Projekte',
  'documents': 'Dokumente',
  'vehicles': 'Fahrzeuge',
  'vehicleCosts': 'Fahrzeugkosten',
  'recurringTemplates': 'Wiederkehrende Rechnungen',
  'expenseCategories': 'Belegkategorien',
  'expenses': 'Belege',
  'bankTransactions': 'Bankumsätze',
  'purchaseOrders': 'Bestellungen',
  'stockMovements': 'Lagerbewegungen',
  'inventoryCounts': 'Inventuren',
  'staffRoles': 'Rollen',
  'timeEntries': 'Zeitbuchungen',
  'timeSheets': 'Stundenzettel',
};

class _InviteDialog extends StatefulWidget {
  const _InviteDialog({required this.groups});
  final List<OnlineGroup> groups;

  @override
  State<_InviteDialog> createState() => _InviteDialogState();
}

class _InviteDialogState extends State<_InviteDialog> {
  final _email = TextEditingController();
  late String? _group = widget.groups.where((g) => g.name == 'Monteur').firstOrNull?.id ?? widget.groups.firstOrNull?.id;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Mitarbeiter einladen'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(controller: _email, decoration: const InputDecoration(labelText: 'E-Mail')),
          DropdownButtonFormField<String>(
            initialValue: _group,
            decoration: const InputDecoration(labelText: 'Gruppe'),
            items: [for (final g in widget.groups) DropdownMenuItem(value: g.id, child: Text(g.name))],
            onChanged: (v) => setState(() => _group = v),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
        FilledButton(
          onPressed: () {
            final email = _email.text.trim();
            if (email.isEmpty || _group == null) return;
            Navigator.pop(context, (email, _group!));
          },
          child: const Text('Einladen'),
        ),
      ],
    );
  }
}
