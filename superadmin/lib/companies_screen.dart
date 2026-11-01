import 'package:flutter/material.dart';
import 'package:werkkern_client/werkkern_client.dart';

import 'app.dart';
import 'company_dialog.dart';
import 'login_screen.dart';

enum _Filter { all, overdue, suspended }

/// Alle Firmen der Plattform mit Abo-Status; Klick öffnet Abo/Sperre.
class CompaniesScreen extends StatefulWidget {
  const CompaniesScreen({super.key, required this.client, required this.email, required this.clientFactory});

  final WerkkernApiClient client;
  final String email;
  final WerkkernApiClient Function() clientFactory;

  @override
  State<CompaniesScreen> createState() => _CompaniesScreenState();
}

class _CompaniesScreenState extends State<CompaniesScreen> {
  List<PlatformCompanyInfo>? _companies;
  String? _error;
  _Filter _filter = _Filter.all;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final companies = await widget.client.platformCompanies();
      if (mounted) setState(() => _companies = companies);
    } on Exception catch (e) {
      if (e is ApiException && e.isUnauthorized) return _expired();
      if (mounted) setState(() => _error = describeError(e));
    }
  }

  void _expired() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(MaterialPageRoute<void>(
      builder: (_) => LoginScreen(
        clientFactory: widget.clientFactory,
        notice: 'Sitzung abgelaufen — bitte erneut anmelden.',
      ),
    ));
  }

  Future<void> _logout() async {
    try {
      await widget.client.platformLogout();
    } on Exception {
      // Abmelden klappt lokal immer; die Sitzung läuft serverseitig ab.
    }
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => LoginScreen(clientFactory: widget.clientFactory)),
    );
  }

  Future<void> _open(PlatformCompanyInfo company) async {
    final result = await showDialog<CompanyDialogResult>(
      context: context,
      builder: (_) => CompanyDialog(client: widget.client, company: company),
    );
    if (result == null || !mounted) return;
    if (result.unauthorized) return _expired();
    final updated = result.company!;
    setState(() => _companies = [for (final c in _companies!) c.id == updated.id ? updated : c]);
  }

  bool _matches(PlatformCompanyInfo c) {
    final passesFilter = switch (_filter) {
      _Filter.all => true,
      _Filter.overdue => c.overdue && !c.suspended,
      _Filter.suspended => c.suspended,
    };
    if (!passesFilter) return false;
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return c.name.toLowerCase().contains(q) || c.adminEmails.any((e) => e.toLowerCase().contains(q));
  }

  @override
  Widget build(BuildContext context) {
    final companies = _companies;
    final visible = companies?.where(_matches).toList() ?? const <PlatformCompanyInfo>[];
    int count(bool Function(PlatformCompanyInfo) test) => companies?.where(test).length ?? 0;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Firmen'),
        actions: [
          IconButton(tooltip: 'Neu laden', onPressed: _load, icon: const Icon(Icons.refresh)),
          PopupMenuButton<String>(
            tooltip: 'Konto',
            icon: const Icon(Icons.account_circle_outlined),
            onSelected: (_) => _logout(),
            itemBuilder: (_) => [
              PopupMenuItem(enabled: false, child: Text(widget.email)),
              const PopupMenuItem(value: 'logout', child: Text('Abmelden')),
            ],
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 960),
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SegmentedButton<_Filter>(
                      segments: [
                        ButtonSegment(value: _Filter.all, label: Text('Alle (${count((_) => true)})')),
                        ButtonSegment(
                          value: _Filter.overdue,
                          label: Text('Überfällig (${count((c) => c.overdue && !c.suspended)})'),
                        ),
                        ButtonSegment(value: _Filter.suspended, label: Text('Gesperrt (${count((c) => c.suspended)})')),
                      ],
                      selected: {_filter},
                      onSelectionChanged: (s) => setState(() => _filter = s.single),
                    ),
                    SizedBox(
                      width: 280,
                      child: TextField(
                        key: const Key('companies-search'),
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.search),
                          hintText: 'Firma oder Admin-E-Mail',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        onChanged: (v) => setState(() => _query = v),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (_error != null)
                  Card(
                    color: Theme.of(context).colorScheme.errorContainer,
                    child: ListTile(leading: const Icon(Icons.error_outline), title: Text(_error!)),
                  ),
                if (companies == null && _error == null)
                  const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator())),
                if (companies != null && visible.isEmpty)
                  const Padding(padding: EdgeInsets.all(32), child: Center(child: Text('Keine Firmen in dieser Ansicht.'))),
                for (final c in visible)
                  Card(
                    child: ListTile(
                      leading: Icon(c.suspended ? Icons.lock_outline : Icons.business_outlined),
                      title: Text(c.name),
                      subtitle: Text(_subtitle(c)),
                      isThreeLine: true,
                      trailing: _StatusChip(company: c),
                      onTap: () => _open(c),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _subtitle(PlatformCompanyInfo c) {
  final admins = c.adminEmails.isEmpty ? 'kein aktiver Admin' : c.adminEmails.join(', ');
  final members = c.activeMembers == 1 ? '1 Mitglied' : '${c.activeMembers} Mitglieder';
  final billing = [
    c.plan ?? 'kein Tarif',
    c.paidUntil == null ? 'bezahlt bis: –' : 'bezahlt bis ${formatDate(c.paidUntil!)}',
  ].join(' · ');
  return '$admins · $members\n$billing · seit ${formatDate(c.createdAt.toLocal())}';
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.company});
  final PlatformCompanyInfo company;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (label, bg, fg) = company.suspended
        ? ('Gesperrt', scheme.errorContainer, scheme.onErrorContainer)
        : company.overdue
            ? ('Überfällig', scheme.tertiaryContainer, scheme.onTertiaryContainer)
            : ('Aktiv', scheme.secondaryContainer, scheme.onSecondaryContainer);
    return Chip(
      label: Text(label, style: TextStyle(color: fg)),
      backgroundColor: bg,
      side: BorderSide.none,
      visualDensity: VisualDensity.compact,
    );
  }
}
