import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:werkkern_client/werkkern_client.dart';
import 'package:werkkern_core/werkkern_core.dart' show Money;

import '../../../domain/services/online_session.dart';
import 'online_form.dart';
import 'online_text_prompt.dart';

/// Firmenverwaltung im Online-Modus — nur für Firmen-Admins (B1: "Nur
/// Firmenadmin der betreffenden Firma verwaltet Gruppen, Zuordnung und
/// Ausnahmen"). Jede Änderung prüft der Server erneut.
class OnlineAdminScreen extends StatelessWidget {
  const OnlineAdminScreen({super.key, required this.session});
  final OnlineSession session;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 7,
      child: Scaffold(
        appBar: AppBar(
          title: Text('Verwaltung · ${session.companyName}'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Mitglieder'),
              Tab(text: 'Gruppen & Rechte'),
              Tab(text: 'Einladungen'),
              Tab(text: 'Module'),
              Tab(text: 'Firmendaten'),
              Tab(text: 'E-Mail'),
              Tab(text: 'Protokoll'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _MembersTab(session: session),
            _GroupsTab(session: session),
            _InvitationsTab(session: session),
            _ModulesTab(session: session),
            _ProfileTab(session: session),
            _MailTab(session: session),
            _AuditTab(session: session),
          ],
        ),
      ),
    );
  }
}

void _showError(BuildContext context, Object error) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(describeOnlineError(error))));
}

String _permissionLabel(String key) => onlinePermissionLabels[key] ?? key;

/// Lädt per [load] und zeigt Fehler/Ladezustand einheitlich an.
class _Loader<T> extends StatelessWidget {
  const _Loader({required this.future, required this.builder});
  final Future<T> future;
  final Widget Function(BuildContext context, T data) builder;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(describeOnlineError(snapshot.error!))));
        }
        if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
        return builder(context, snapshot.data as T);
      },
    );
  }
}

// ---- Mitglieder -----------------------------------------------------------------

class _MembersTab extends StatefulWidget {
  const _MembersTab({required this.session});
  final OnlineSession session;

  @override
  State<_MembersTab> createState() => _MembersTabState();
}

class _MembersTabState extends State<_MembersTab> {
  late Future<List<OnlineMember>> _future = widget.session.client.members();

  void _reload() => setState(() {
        _future = widget.session.client.members();
      });

  Future<void> _edit(OnlineMember member) async {
    final client = widget.session.client;
    try {
      final groups = await client.groups();
      final catalog = await client.permissionCatalog();
      final overrides = await client.memberOverrides(member.id);
      if (!mounted) return;
      final changed = await showDialog<bool>(
        context: context,
        builder: (_) => _MemberDialog(
          session: widget.session,
          member: member,
          groups: groups,
          catalog: catalog,
          overrides: overrides,
        ),
      );
      if (changed == true) _reload();
    } on Exception catch (e) {
      if (mounted) _showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _Loader<List<OnlineMember>>(
      future: _future,
      builder: (context, members) => ListView(
        padding: const EdgeInsets.all(12),
        children: [
          for (final m in members)
            Card(
              child: ListTile(
                leading: Icon(m.active ? Icons.person_outline : Icons.person_off_outlined),
                title: Text(m.email),
                subtitle: Text([m.groupName, if (m.isAdmin) 'Admin', if (!m.active) 'deaktiviert'].join(' · ')),
                trailing: const Icon(Icons.edit_outlined),
                onTap: () => _edit(m),
              ),
            ),
        ],
      ),
    );
  }
}

class _MemberDialog extends StatefulWidget {
  const _MemberDialog({
    required this.session,
    required this.member,
    required this.groups,
    required this.catalog,
    required this.overrides,
  });
  final OnlineSession session;
  final OnlineMember member;
  final List<OnlineGroup> groups;
  final List<OnlinePermissionInfo> catalog;
  final Map<String, bool> overrides;

  @override
  State<_MemberDialog> createState() => _MemberDialogState();
}

class _MemberDialogState extends State<_MemberDialog> {
  late String _groupId = widget.member.groupId;
  late bool _active = widget.member.active;
  late bool _isAdmin = widget.member.isAdmin;
  late final _rate = TextEditingController(
    text: widget.member.hourlyCostCents == null ? '' : Money.fromCents(widget.member.hourlyCostCents!).formatEuro(),
  );

  @override
  void dispose() {
    _rate.dispose();
    super.dispose();
  }
  late final Map<String, bool?> _overrides = {
    for (final p in widget.catalog) p.key: widget.overrides[p.key],
  };
  bool _busy = false;

  Future<void> _save() async {
    final client = widget.session.client;
    setState(() => _busy = true);
    try {
      final m = widget.member;
      final rateText = _rate.text.trim();
      final int? rate;
      try {
        rate = rateText.isEmpty ? null : Money.fromEuroString(rateText).cents;
      } on FormatException {
        if (mounted) {
          setState(() => _busy = false);
          _showError(context, const FormatException('Stundensatz ist keine gültige Zahl.'));
        }
        return;
      }
      final rateChanged = rate != m.hourlyCostCents;
      if (_groupId != m.groupId || _active != m.active || _isAdmin != m.isAdmin || rateChanged) {
        await client.updateMember(
          m.id,
          groupId: _groupId != m.groupId ? _groupId : null,
          active: _active != m.active ? _active : null,
          isAdmin: _isAdmin != m.isAdmin ? _isAdmin : null,
          hourlyCostCents: rateChanged ? () => rate : null,
        );
      }
      for (final entry in _overrides.entries) {
        if (entry.value != widget.overrides[entry.key]) {
          await client.setMemberOverride(m.id, entry.key, entry.value);
        }
      }
      if (mounted) Navigator.pop(context, true);
    } on Exception catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        _showError(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.member.email),
      content: SizedBox(
        width: 460,
        child: ListView(
          shrinkWrap: true,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _groupId,
              decoration: const InputDecoration(labelText: 'Gruppe'),
              items: [for (final g in widget.groups) DropdownMenuItem(value: g.id, child: Text(g.name))],
              onChanged: (v) => setState(() => _groupId = v!),
            ),
            SwitchListTile(title: const Text('Aktiv'), value: _active, onChanged: (v) => setState(() => _active = v)),
            TextField(
              key: const Key('online-member-rate'),
              controller: _rate,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Stundenkostensatz (€)',
                helperText: 'Für die Zeiterfassung; wird beim Buchen eingefroren. Leer = nicht gepflegt.',
              ),
            ),
            SwitchListTile(
              title: const Text('Firmen-Admin'),
              subtitle: const Text('Verwaltet Mitglieder, Gruppen, Rechte und Module'),
              value: _isAdmin,
              onChanged: (v) => setState(() => _isAdmin = v),
            ),
            const Divider(),
            const Text('Individuelle Ausnahmen (überschreiben die Gruppe)'),
            for (final p in widget.catalog)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        p.module == null
                            ? _permissionLabel(p.key)
                            : '${_permissionLabel(p.key)} (${onlineModuleLabels[p.module] ?? p.module})',
                      ),
                    ),
                    SegmentedButton<int>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(value: 0, label: Text('Gruppe')),
                        ButtonSegment(value: 1, label: Text('Erlaubt')),
                        ButtonSegment(value: 2, label: Text('Gesperrt')),
                      ],
                      selected: {switch (_overrides[p.key]) { null => 0, true => 1, false => 2 }},
                      onSelectionChanged: (s) => setState(() {
                        _overrides[p.key] = switch (s.first) { 1 => true, 2 => false, _ => null };
                      }),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: const Text('Abbrechen')),
        FilledButton(onPressed: _busy ? null : _save, child: const Text('Speichern')),
      ],
    );
  }
}

// ---- Gruppen & Rechte --------------------------------------------------------------

class _GroupsTab extends StatefulWidget {
  const _GroupsTab({required this.session});
  final OnlineSession session;

  @override
  State<_GroupsTab> createState() => _GroupsTabState();
}

class _GroupsTabState extends State<_GroupsTab> {
  late Future<(List<OnlineGroup>, List<OnlinePermissionInfo>)> _future = _load();

  Future<(List<OnlineGroup>, List<OnlinePermissionInfo>)> _load() async =>
      (await widget.session.client.groups(), await widget.session.client.permissionCatalog());

  Future<void> _createGroup() async {
    final name = await showOnlineTextPrompt(context, title: 'Neue Gruppe', label: 'Name', confirm: 'Anlegen');
    if (name == null || name.isEmpty) return;
    try {
      await widget.session.client.createGroup(name);
      setState(() {
        _future = _load();
      });
    } on Exception catch (e) {
      if (mounted) _showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _Loader<(List<OnlineGroup>, List<OnlinePermissionInfo>)>(
        future: _future,
        builder: (context, data) => ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
          children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                'Startgruppen kommen mit Standardrechten — welche Gruppe was darf, passt du hier an. '
                'Admins brauchen für Fachdaten ebenfalls Rechte über ihre Gruppe.',
              ),
            ),
            for (final g in data.$1)
              _GroupPermissionsCard(session: widget.session, group: g, catalog: data.$2),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'online-admin-groups-fab',
        onPressed: _createGroup,
        icon: const Icon(Icons.add),
        label: const Text('Gruppe anlegen'),
      ),
    );
  }
}

class _GroupPermissionsCard extends StatefulWidget {
  const _GroupPermissionsCard({required this.session, required this.group, required this.catalog});
  final OnlineSession session;
  final OnlineGroup group;
  final List<OnlinePermissionInfo> catalog;

  @override
  State<_GroupPermissionsCard> createState() => _GroupPermissionsCardState();
}

class _GroupPermissionsCardState extends State<_GroupPermissionsCard> {
  Set<String>? _granted;

  Future<void> _expand() async {
    if (_granted != null) return;
    try {
      final granted = await widget.session.client.groupPermissions(widget.group.id);
      if (mounted) setState(() => _granted = granted);
    } on Exception catch (e) {
      if (mounted) _showError(context, e);
    }
  }

  Future<void> _toggle(String key, bool value) async {
    try {
      await widget.session.client.setGroupPermission(widget.group.id, key, granted: value);
      if (!mounted) return;
      setState(() => value ? _granted!.add(key) : _granted!.remove(key));
      // Eigene Rechte könnten betroffen sein (eigene Gruppe).
      await widget.session.refreshPermissions();
    } on Exception catch (e) {
      if (mounted) _showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final granted = _granted;
    return Card(
      child: ExpansionTile(
        leading: const Icon(Icons.group_outlined),
        title: Text(widget.group.name),
        onExpansionChanged: (open) {
          if (open) _expand();
        },
        children: [
          if (granted == null)
            const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator())
          else
            for (final p in widget.catalog)
              CheckboxListTile(
                dense: true,
                title: Text(_permissionLabel(p.key)),
                subtitle: p.module == null ? null : Text('nur mit Modul ${onlineModuleLabels[p.module] ?? p.module}'),
                value: granted.contains(p.key),
                onChanged: (v) => _toggle(p.key, v ?? false),
              ),
        ],
      ),
    );
  }
}

// ---- Einladungen -------------------------------------------------------------------

class _InvitationsTab extends StatefulWidget {
  const _InvitationsTab({required this.session});
  final OnlineSession session;

  @override
  State<_InvitationsTab> createState() => _InvitationsTabState();
}

class _InvitationsTabState extends State<_InvitationsTab> {
  late Future<(List<OnlineInvitation>, List<OnlineGroup>)> _future = _load();

  Future<(List<OnlineInvitation>, List<OnlineGroup>)> _load() async =>
      (await widget.session.client.invitations(), await widget.session.client.groups());

  void _reload() => setState(() {
        _future = _load();
      });

  Future<void> _invite(List<OnlineGroup> groups) async {
    final result = await showDialog<({String email, String groupId, bool sendEmail})>(
      context: context,
      builder: (_) => _InviteDialog(groups: groups, canSendEmail: widget.session.modules.contains('smtp')),
    );
    if (result == null || !mounted) return;
    try {
      final invitation =
          await widget.session.client.createInvitationWithMail(result.email, result.groupId, sendEmail: result.sendEmail);
      final token = invitation.token;
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Einladung erstellt'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                invitation.emailSent
                    ? 'Der Code wurde per E-Mail an ${result.email} geschickt (7 Tage gültig, einmal einlösbar).'
                    : 'Gib diesen Einladungscode an ${result.email} weiter (7 Tage gültig, einmal einlösbar). '
                        'Er wird nur jetzt angezeigt — der Server speichert ihn nicht im Klartext.',
              ),
              if (invitation.emailError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text('E-Mail nicht versendet: ${invitation.emailError}', style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ),
              const SizedBox(height: 12),
              SelectableText(token, key: const Key('online-invitation-token')),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Clipboard.setData(ClipboardData(text: token)),
              child: const Text('Kopieren'),
            ),
            FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Fertig')),
          ],
        ),
      );
      _reload();
    } on Exception catch (e) {
      if (mounted) _showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd.MM.yyyy HH:mm');
    return _Loader<(List<OnlineInvitation>, List<OnlineGroup>)>(
      future: _future,
      builder: (context, data) {
        final groupNames = {for (final g in data.$2) g.id: g.name};
        return Scaffold(
          body: data.$1.isEmpty
              ? const Center(child: Text('Keine offenen Einladungen.'))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
                  children: [
                    for (final i in data.$1)
                      Card(
                        child: ListTile(
                          leading: Icon(i.expired ? Icons.timer_off_outlined : Icons.mail_outline),
                          title: Text(i.email),
                          subtitle: Text(
                            '${groupNames[i.groupId] ?? '?'} · ${i.expired ? 'abgelaufen' : 'gültig bis ${dateFormat.format(i.expiresAt.toLocal())}'}',
                          ),
                          trailing: IconButton(
                            tooltip: 'Widerrufen',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () async {
                              try {
                                await widget.session.client.revokeInvitation(i.id);
                                _reload();
                              } on Exception catch (e) {
                                if (context.mounted) _showError(context, e);
                              }
                            },
                          ),
                        ),
                      ),
                  ],
                ),
          floatingActionButton: FloatingActionButton.extended(
            heroTag: 'online-admin-invite-fab',
            onPressed: () => _invite(data.$2),
            icon: const Icon(Icons.person_add_alt),
            label: const Text('Einladen'),
          ),
        );
      },
    );
  }
}

class _InviteDialog extends StatefulWidget {
  const _InviteDialog({required this.groups, required this.canSendEmail});
  final List<OnlineGroup> groups;
  final bool canSendEmail;

  @override
  State<_InviteDialog> createState() => _InviteDialogState();
}

class _InviteDialogState extends State<_InviteDialog> {
  final _email = TextEditingController();
  late String? _groupId = widget.groups.isEmpty ? null : widget.groups.first.id;
  bool _sendEmail = false;

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
          TextField(
            key: const Key('online-invite-email'),
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'E-Mail'),
          ),
          DropdownButtonFormField<String>(
            initialValue: _groupId,
            decoration: const InputDecoration(labelText: 'Gruppe'),
            items: [for (final g in widget.groups) DropdownMenuItem(value: g.id, child: Text(g.name))],
            onChanged: (v) => setState(() => _groupId = v),
          ),
          if (widget.canSendEmail)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Code per E-Mail senden'),
              value: _sendEmail,
              onChanged: (v) => setState(() => _sendEmail = v ?? false),
            ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
        FilledButton(
          onPressed: () {
            if (_email.text.trim().isEmpty || _groupId == null) return;
            Navigator.pop(context, (email: _email.text.trim(), groupId: _groupId!, sendEmail: _sendEmail));
          },
          child: const Text('Einladung erstellen'),
        ),
      ],
    );
  }
}

// ---- E-Mail -----------------------------------------------------------------------

/// SMTP-Zugang der Firma (Versand über den Server). Das Passwort wird
/// verschlüsselt gespeichert und nie wieder angezeigt.
class _MailTab extends StatefulWidget {
  const _MailTab({required this.session});
  final OnlineSession session;

  @override
  State<_MailTab> createState() => _MailTabState();
}

class _MailTabState extends State<_MailTab> {
  static const _templateLabels = {
    'documentSubject': 'Dokument: Betreff',
    'documentBody': 'Dokument: Text',
    'dunningSubject': 'Mahnung: Betreff',
    'dunningBody': 'Mahnung: Text',
    'purchaseOrderSubject': 'Bestellung: Betreff',
    'purchaseOrderBody': 'Bestellung: Text',
    'invitationSubject': 'Einladung: Betreff',
    'invitationBody': 'Einladung: Text',
  };
  OnlineMailSettings? _settings;
  final _host = TextEditingController();
  final _port = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _from = TextEditingController();
  final _fromName = TextEditingController();
  final _templates = <String, TextEditingController>{};
  bool _useTls = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [_host, _port, _username, _password, _from, _fromName, ..._templates.values]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final s = await widget.session.client.mailSettings();
      _host.text = s.host ?? '';
      _port.text = '${s.port}';
      _username.text = s.username ?? '';
      _from.text = s.fromAddress ?? '';
      _fromName.text = s.fromName ?? '';
      _useTls = s.useTls;
      for (final key in _templateLabels.keys) {
        (_templates[key] ??= TextEditingController()).text = s.templates[key] ?? '';
      }
      if (mounted) setState(() => _settings = s);
    } on Exception catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  String? _value(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();

  Future<void> _save() async {
    final port = int.tryParse(_port.text.trim());
    if (port == null) {
      _showError(context, const FormatException('Port ist keine Zahl.'));
      return;
    }
    await runOnline(context, () async {
      final saved = await widget.session.client.saveMailSettings(
        host: _value(_host),
        port: port,
        username: _value(_username),
        fromAddress: _value(_from),
        fromName: _value(_fromName),
        useTls: _useTls,
        password: _password.text.isEmpty ? null : _password.text,
        templates: {for (final e in _templates.entries) e.key: e.value.text},
      );
      _password.clear();
      if (mounted) setState(() => _settings = saved);
    }, success: 'E-Mail-Einstellungen gespeichert.');
  }

  @override
  Widget build(BuildContext context) {
    final s = _settings;
    if (_error != null) return Center(child: Text(describeOnlineError(_error!)));
    if (s == null) return const Center(child: CircularProgressIndicator());
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        if (!s.available)
          Card(
            color: Theme.of(context).colorScheme.errorContainer,
            child: const ListTile(
              leading: Icon(Icons.warning_amber_outlined),
              title: Text('Mailversand auf diesem Server nicht eingerichtet'),
              subtitle: Text('Der Betreiber muss WERKKERN_SECRET_KEY setzen — sonst kann kein SMTP-Passwort gespeichert werden.'),
            ),
          ),
        if (!widget.session.modules.contains('smtp'))
          const Card(child: ListTile(leading: Icon(Icons.info_outline), title: Text('Modul „E-Mail-Versand“ unter „Module“ aktivieren, um zu versenden.'))),
        TextField(key: const Key('online-mail-host'), controller: _host, decoration: const InputDecoration(labelText: 'SMTP-Server')),
        TextField(controller: _port, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Port (587 STARTTLS, 465 SSL)')),
        SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('TLS verwenden'), value: _useTls, onChanged: (v) => setState(() => _useTls = v)),
        TextField(controller: _username, decoration: const InputDecoration(labelText: 'Benutzername')),
        TextField(
          key: const Key('online-mail-password'),
          controller: _password,
          obscureText: true,
          decoration: InputDecoration(labelText: 'Passwort', helperText: s.hasPassword ? 'gespeichert — leer lassen, um es zu behalten' : 'nicht gesetzt'),
        ),
        TextField(key: const Key('online-mail-from'), controller: _from, decoration: const InputDecoration(labelText: 'Absenderadresse')),
        TextField(controller: _fromName, decoration: const InputDecoration(labelText: 'Absendername')),
        const SizedBox(height: 12),
        Text('Vorlagen — Platzhalter {{kunde}}, {{nummer}}, {{firma}}, bei Einladungen {{code}}',
            style: Theme.of(context).textTheme.titleSmall),
        for (final e in _templateLabels.entries)
          TextField(
            controller: _templates[e.key],
            maxLines: e.key.endsWith('Body') ? 4 : 1,
            decoration: InputDecoration(labelText: e.value),
          ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          children: [
            FilledButton(onPressed: _save, child: const Text('E-Mail-Einstellungen speichern')),
            OutlinedButton(
              onPressed: () async {
                final values = await showOnlineForm(
                  context,
                  title: 'Testnachricht',
                  submitLabel: 'Senden',
                  fields: const [OnlineField('to', 'Empfänger', required: true)],
                );
                if (values == null || !context.mounted) return;
                await runOnline(context, () => widget.session.client.sendTestMail(values['to'] as String), success: 'Testnachricht versendet.');
              },
              child: const Text('Testnachricht senden'),
            ),
          ],
        ),
      ],
    );
  }
}

// ---- Module -----------------------------------------------------------------------

class _ModulesTab extends StatefulWidget {
  const _ModulesTab({required this.session});
  final OnlineSession session;

  @override
  State<_ModulesTab> createState() => _ModulesTabState();
}

class _ModulesTabState extends State<_ModulesTab> {
  late final Set<String> _modules = {...widget.session.modules};
  bool _busy = false;

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      await widget.session.client.setModules(_modules);
      await widget.session.refreshPermissions();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Module gespeichert.')));
    } on Exception catch (e) {
      if (mounted) _showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        const Text(
          'Deaktivierte Module blenden Funktionen und Rechte aus; vorhandene Daten bleiben gespeichert.',
        ),
        for (final entry in onlineModuleLabels.entries)
          SwitchListTile(
            title: Text(entry.value),
            subtitle: entry.key == 'bestellwesen' ? const Text('setzt Lagerbestand voraus') : null,
            value: _modules.contains(entry.key),
            onChanged: (v) => setState(() {
              if (v) {
                _modules.add(entry.key);
                if (entry.key == 'bestellwesen') _modules.add('lagerbestand');
              } else {
                _modules.remove(entry.key);
                if (entry.key == 'lagerbestand') _modules.remove('bestellwesen');
              }
            }),
          ),
        const SizedBox(height: 12),
        FilledButton(onPressed: _busy ? null : _save, child: const Text('Module speichern')),
      ],
    );
  }
}

// ---- Firmendaten ----------------------------------------------------------------

class _ProfileTab extends StatefulWidget {
  const _ProfileTab({required this.session});
  final OnlineSession session;

  @override
  State<_ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<_ProfileTab> {
  final _address = TextEditingController();
  final _taxNumber = TextEditingController();
  final _vatId = TextEditingController();
  final _iban = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _footer = TextEditingController();
  final Map<String, ({TextEditingController intro, TextEditingController closing})> _texts = {};
  bool _smallBusiness = false;
  bool _loading = true;
  bool _busy = false;

  /// Texte für Rechnung + alle Dokumentarten mit aktivem Modul.
  List<String> get _kinds => [
        for (final entry in onlineDocumentKindModules.entries)
          if (entry.value == null || widget.session.modules.contains(entry.value)) entry.key,
      ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in [_address, _taxNumber, _vatId, _iban, _email, _phone, _footer]) {
      c.dispose();
    }
    for (final t in _texts.values) {
      t.intro.dispose();
      t.closing.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final p = await widget.session.client.companyProfile();
      if (!mounted) return;
      _address.text = p.address ?? '';
      _taxNumber.text = p.taxNumber ?? '';
      _vatId.text = p.vatId ?? '';
      _iban.text = p.iban ?? '';
      _email.text = p.email ?? '';
      _phone.text = p.phone ?? '';
      _footer.text = p.footerText ?? '';
      _smallBusiness = p.smallBusinessExempt;
      // Auch Texte inaktiver Arten behalten (werden unverändert zurückgeschickt).
      for (final kind in {..._kinds, ...p.documentTexts.keys}) {
        _texts[kind] = (
          intro: TextEditingController(text: p.documentTexts[kind]?.intro ?? ''),
          closing: TextEditingController(text: p.documentTexts[kind]?.closing ?? ''),
        );
      }
    } on Exception catch (e) {
      if (mounted) _showError(context, e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String? _v(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      await widget.session.client.saveCompanyProfile(OnlineCompanyProfile(
        address: _v(_address),
        taxNumber: _v(_taxNumber),
        vatId: _v(_vatId),
        iban: _v(_iban),
        email: _v(_email),
        phone: _v(_phone),
        footerText: _v(_footer),
        documentTexts: {
          for (final e in _texts.entries) e.key: (intro: _v(e.value.intro), closing: _v(e.value.closing)),
        },
        smallBusinessExempt: _smallBusiness,
      ));
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Firmendaten gespeichert.')));
    } on Exception catch (e) {
      if (mounted) _showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        const Text('Wird beim Finalisieren unveränderlich in jedes Dokument übernommen.'),
        TextField(controller: _address, maxLines: 3, decoration: const InputDecoration(labelText: 'Anschrift')),
        TextField(controller: _taxNumber, decoration: const InputDecoration(labelText: 'Steuernummer')),
        TextField(controller: _vatId, decoration: const InputDecoration(labelText: 'USt-IdNr.')),
        TextField(controller: _iban, decoration: const InputDecoration(labelText: 'IBAN')),
        TextField(controller: _email, decoration: const InputDecoration(labelText: 'E-Mail')),
        TextField(controller: _phone, decoration: const InputDecoration(labelText: 'Telefon')),
        SwitchListTile(
          key: const Key('online-profile-small-business'),
          contentPadding: EdgeInsets.zero,
          title: const Text('Kleinunternehmerregelung (§ 19 UStG)'),
          subtitle: const Text('Alle Positionen 0 % USt, fester Hinweis im PDF. Bitte mit dem Steuerberater klären.'),
          value: _smallBusiness,
          onChanged: (v) => setState(() => _smallBusiness = v),
        ),
        TextField(controller: _footer, maxLines: 2, decoration: const InputDecoration(labelText: 'PDF-Fußzeile')),
        const SizedBox(height: 12),
        Text('Texte je Dokumentart', style: Theme.of(context).textTheme.titleSmall),
        for (final kind in _kinds)
          ExpansionTile(
            title: Text(onlineDocumentKindLabels[kind] ?? kind),
            children: [
              TextField(
                key: Key('online-profile-intro-$kind'),
                controller: _texts[kind]!.intro,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Einleitungstext'),
              ),
              TextField(
                controller: _texts[kind]!.closing,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'Schlusstext'),
              ),
            ],
          ),
        const SizedBox(height: 12),
        FilledButton(onPressed: _busy ? null : _save, child: const Text('Firmendaten speichern')),
      ],
    );
  }
}

// ---- Protokoll -------------------------------------------------------------------

class _AuditTab extends StatelessWidget {
  const _AuditTab({required this.session});
  final OnlineSession session;

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd.MM.yyyy HH:mm');
    return _Loader<List<OnlineAuditEntry>>(
      future: session.client.audit(),
      builder: (context, entries) => entries.isEmpty
          ? const Center(child: Text('Noch keine Einträge.'))
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: entries.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final e = entries[index];
                return ListTile(
                  dense: true,
                  title: Text(e.action),
                  subtitle: Text('${dateFormat.format(e.at.toLocal())} · ${e.userEmail ?? 'unbekannt'} · ${e.entityType}'),
                );
              },
            ),
    );
  }
}
