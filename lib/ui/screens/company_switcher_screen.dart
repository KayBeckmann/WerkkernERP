import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:werkkern_client/werkkern_client.dart';

import '../../data/database/database.dart';
import '../../domain/services/active_company_service.dart';
import '../../domain/services/online_accounts.dart';
import 'home_shell.dart';
import 'migrated_company_screen.dart';
import 'online/online_login_screen.dart';

/// Firmenauswahl/-anlage — der Einstiegspunkt der App (A0). Keine
/// Anmeldung, kein Server: eine Liste lokal geführter Firmen zum
/// Anlegen/Wechseln. Darunter die Online-Firmen früherer Anmeldungen —
/// ein Klick öffnet sie (mit gespeicherter Sitzung ohne Passwort).
class CompanySwitcherScreen extends StatefulWidget {
  const CompanySwitcherScreen({super.key, this.accountStore, this.onlineClientFactory, this.offlineStoreFactory});

  /// Für Widget-Tests; siehe [OnlineLoginScreen].
  final OnlineAccountStore? accountStore;
  final WerkkernApiClient Function(Uri baseUrl)? onlineClientFactory;
  final OfflineStore? Function()? offlineStoreFactory;

  @override
  State<CompanySwitcherScreen> createState() => _CompanySwitcherScreenState();
}

class _CompanySwitcherScreenState extends State<CompanySwitcherScreen> {
  late final OnlineAccountStore _accounts = widget.accountStore ?? defaultOnlineAccountStore();
  List<SavedOnlineAccount> _online = const [];

  @override
  void initState() {
    super.initState();
    context.read<ActiveCompanyService>().loadCompanies();
    _accounts.addListener(_loadOnline);
    _loadOnline();
  }

  @override
  void dispose() {
    _accounts.removeListener(_loadOnline);
    super.dispose();
  }

  Future<void> _loadOnline() async {
    final accounts = await _accounts.load();
    if (mounted) setState(() => _online = accounts);
  }

  /// Anmeldemaske (leer oder für eine bekannte Online-Firma vorbelegt).
  Future<void> _openOnline({SavedOnlineAccount? account, String? companyId}) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => OnlineLoginScreen(
          clientFactory: widget.onlineClientFactory,
          offlineStoreFactory: widget.offlineStoreFactory,
          accountStore: _accounts,
          account: account,
          targetCompanyId: companyId,
        ),
      ),
    );
  }

  Future<void> _removeOnline(SavedOnlineAccount account, OnlineMembership membership) =>
      _accounts.removeCompany(account, membership.companyId);

  Future<void> _createCompany() async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) => const _NewCompanyDialog(),
    );
    if (name == null || name.trim().isEmpty || !mounted) return;
    final service = context.read<ActiveCompanyService>();
    await service.createCompany(name: name.trim());
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomeShell()),
    );
  }

  void _openCompany(ActiveCompanyService service, Company company) {
    // B4: umgezogene Firmen nur noch als Archiv (kein Zurück).
    if (company.migratedAt != null) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => MigratedCompanyScreen(
            company: company,
            accountStore: _accounts,
            clientFactory: widget.onlineClientFactory,
          ),
        ),
      );
      return;
    }
    service.select(company);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomeShell()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<ActiveCompanyService>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? Colors.white : const Color(0xFF1E293B);
    return Scaffold(
      appBar: AppBar(
        title: RichText(
          text: TextSpan(
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: baseColor),
            children: [
              TextSpan(text: 'Werkkern', style: TextStyle(color: baseColor)),
              const TextSpan(text: 'ERP', style: TextStyle(color: Color(0xFF4F46E5))),
              const TextSpan(
                text: ' — Firmen',
                style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.normal),
              ),
            ],
          ),
        ),
        actions: [
          // Phase B: zusätzlicher Online-Modus, ändert nichts an den
          // lokalen Offline-Firmen.
          IconButton(
            tooltip: 'Online anmelden',
            icon: const Icon(Icons.cloud_outlined),
            onPressed: _openOnline,
          ),
        ],
      ),
      body: service.companies.isEmpty && _online.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Noch keine Firma angelegt. Lege deine erste Firma an, um Kunden und '
                  'Rechnungen zu verwalten — vollständig offline, ohne Server oder Konto.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
              children: [
                for (final company in service.companies)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Card(
                      child: ListTile(
                        leading: Icon(company.migratedAt == null ? Icons.business_outlined : Icons.inventory_2_outlined),
                        title: Text(company.name),
                        subtitle: company.migratedAt == null
                            ? null
                            : Text('Umgezogen nach „${company.migratedToCompanyName ?? '?'}“ · nur lesen'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _openCompany(service, company),
                      ),
                    ),
                  ),
                if (_online.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
                    child: Text('Online', style: Theme.of(context).textTheme.titleSmall),
                  ),
                  for (final account in _online)
                    for (final membership in account.memberships)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Card(
                          child: ListTile(
                            leading: const Icon(Icons.cloud_outlined),
                            title: Text(membership.companyName),
                            subtitle: Text(_onlineSubtitle(account)),
                            trailing: PopupMenuButton<String>(
                              tooltip: 'Optionen',
                              onSelected: (_) => _removeOnline(account, membership),
                              itemBuilder: (_) => const [
                                PopupMenuItem(value: 'remove', child: Text('Von der Startseite entfernen')),
                              ],
                            ),
                            onTap: () => _openOnline(account: account, companyId: membership.companyId),
                          ),
                        ),
                      ),
                ],
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'company-switcher-fab',
        onPressed: _createCompany,
        icon: const Icon(Icons.add),
        label: const Text('Firma anlegen'),
      ),
    );
  }
}

String _onlineSubtitle(SavedOnlineAccount account) {
  final host = Uri.tryParse(account.serverUrl)?.host ?? account.serverUrl;
  final expiresAt = account.expiresAt;
  if (!account.hasSessionAt(DateTime.now()) || expiresAt == null) return '${account.email} · $host · Passwort nötig';
  final d = expiresAt.toLocal();
  final until = '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.';
  return '${account.email} · $host · angemeldet bis $until';
}

class _NewCompanyDialog extends StatefulWidget {
  const _NewCompanyDialog();

  @override
  State<_NewCompanyDialog> createState() => _NewCompanyDialogState();
}

class _NewCompanyDialogState extends State<_NewCompanyDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Neue Firma'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(labelText: 'Firmenname'),
        onSubmitted: (value) => Navigator.pop(context, value),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          child: const Text('Anlegen'),
        ),
      ],
    );
  }
}
