import 'package:flutter/material.dart';

import '../../../domain/services/online_session.dart';
import 'online_accounting_screen.dart';
import 'online_admin_screen.dart';
import 'online_agent_screen.dart';
import 'online_articles_screen.dart';
import 'online_customers_screen.dart';
import 'online_documents_screen.dart';
import 'online_dunning_screen.dart';
import 'online_fleet_screen.dart';
import 'online_password_dialog.dart';
import 'online_projects_screen.dart';
import 'online_purchasing_screen.dart';
import 'online_stock_screen.dart';
import 'online_time_screen.dart';

/// Hauptansicht im Online-Modus. Tabs erscheinen nur bei wirksamem
/// Leserecht — der Server prüft trotzdem jede Aktion selbst.
class OnlineHomeScreen extends StatefulWidget {
  const OnlineHomeScreen({super.key, required this.session});
  final OnlineSession session;

  @override
  State<OnlineHomeScreen> createState() => _OnlineHomeScreenState();
}

class _OnlineHomeScreenState extends State<OnlineHomeScreen> {
  int _index = 0;
  bool _syncing = false;

  /// Zählt Wechsel je Ziel — ein neuer Schlüssel lädt den Bereich beim
  /// Hinwechseln frisch, statt den Stand vom ersten Aufbau zu zeigen
  /// (z. B. Lager nach einer Bestandskorrektur im Artikelbereich).
  final _visits = <String, int>{};

  @override
  void initState() {
    super.initState();
    // Nach der Anmeldung liegengebliebene Offline-Änderungen sofort
    // übertragen (B2: Rückkehr online).
    if (!widget.session.offlineOnly && widget.session.pendingChanges > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
    }
  }

  @override
  void dispose() {
    widget.session.client.close();
    super.dispose();
  }

  Future<void> _sync() async {
    if (widget.session.offlineOnly) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Abgleich erst nach Anmeldung möglich — Änderungen bleiben auf dem Gerät gespeichert.'),
        ),
      );
      return;
    }
    setState(() => _syncing = true);
    try {
      final result = await widget.session.sync();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(describeSyncResult(result)), duration: const Duration(seconds: 6)));
      }
    } on Exception catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(describeOnlineError(e))));
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<void> _logout() async {
    final session = widget.session;
    var wipe = false;
    final offline = session.offline;
    if (offline != null && !offline.isEmpty) {
      final choice = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Abmelden'),
          content: Text(
            session.pendingChanges > 0
                ? 'Auf diesem Gerät liegen ${session.pendingChanges} noch nicht übertragene Offline-Änderung(en). '
                      'Beim Löschen gehen sie verloren.'
                : 'Offline verfügbare Dokumente auf diesem Gerät behalten oder löschen?',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
            TextButton(onPressed: () => Navigator.pop(context, 'wipe'), child: const Text('Offline-Daten löschen')),
            FilledButton(onPressed: () => Navigator.pop(context, 'keep'), child: const Text('Behalten')),
          ],
        ),
      );
      if (choice == null) return;
      wipe = choice == 'wipe';
    }
    await session.logout(wipeOffline: wipe);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        final tabs = <({String label, IconData icon, Widget body})>[
          if (session.can('invoices.read'))
            (label: 'Dokumente', icon: Icons.receipt_long_outlined, body: OnlineDocumentsScreen(session: session)),
          if (session.can('customers.read') && !session.offlineOnly)
            (label: 'Kunden', icon: Icons.people_outline, body: OnlineCustomersScreen(session: session)),
          if (session.modules.contains('projects') && session.can('projects.read') && !session.offlineOnly)
            (label: 'Projekte', icon: Icons.folder_outlined, body: OnlineProjectsScreen(session: session)),
          if (session.modules.contains('timeTracking') &&
              (session.can('timeTracking.write') || session.can('timeTracking.read')) &&
              !session.offlineOnly)
            (label: 'Zeiten', icon: Icons.timer_outlined, body: OnlineTimeScreen(session: session)),
          if (session.can('articles.read') && !session.offlineOnly)
            (label: 'Artikel', icon: Icons.inventory_2_outlined, body: OnlineArticlesScreen(session: session)),
          if (session.modules.contains('buchhaltung') && session.can('accounting.read') && !session.offlineOnly)
            (label: 'Buchhaltung', icon: Icons.account_balance_outlined, body: OnlineAccountingScreen(session: session)),
          if (session.modules.contains('dunning') && session.can('dunning.read') && !session.offlineOnly)
            (label: 'Mahnwesen', icon: Icons.notification_important_outlined, body: OnlineDunningScreen(session: session)),
          if (session.modules.contains('lagerbestand') && session.can('stock.read') && !session.offlineOnly)
            (label: 'Lager', icon: Icons.warehouse_outlined, body: OnlineStockScreen(session: session)),
          if (session.modules.contains('bestellwesen') && session.can('purchaseOrders.read') && !session.offlineOnly)
            (label: 'Bestellungen', icon: Icons.shopping_cart_outlined, body: OnlinePurchasingScreen(session: session)),
          if (session.modules.contains('fleet') && session.can('fleet.read') && !session.offlineOnly)
            (label: 'Fuhrpark', icon: Icons.local_shipping_outlined, body: OnlineFleetScreen(session: session)),
        ];
        // Höchstens fünf Ziele in der Leiste — der Rest liegt unter „Mehr“.
        const maxDestinations = 5;
        final primary = tabs.length <= maxDestinations ? tabs : tabs.sublist(0, maxDestinations - 1);
        final more = tabs.length <= maxDestinations ? const <({String label, IconData icon, Widget body})>[] : tabs.sublist(maxDestinations - 1);
        final destinations = [
          ...primary,
          if (more.isNotEmpty) (label: 'Mehr', icon: Icons.more_horiz, body: _MoreScreen(entries: more)),
        ];
        final index = _index.clamp(0, destinations.isEmpty ? 0 : destinations.length - 1);
        return Scaffold(
          appBar: AppBar(
            title: Text('${session.companyName} · ${session.offlineOnly ? 'offline' : 'online'}'),
            actions: [
              if (session.offline != null)
                IconButton(
                  tooltip: session.pendingChanges > 0
                      ? '${session.pendingChanges} Offline-Änderung(en) abgleichen'
                      : 'Abgleichen',
                  icon: Badge(
                    isLabelVisible: session.pendingChanges > 0,
                    label: Text('${session.pendingChanges}'),
                    child: const Icon(Icons.sync),
                  ),
                  onPressed: _syncing ? null : _sync,
                ),
              if (session.modules.contains('aiAgents') && !session.offlineOnly)
                IconButton(
                  tooltip: 'KI-Zugang und Freigaben',
                  icon: const Icon(Icons.smart_toy_outlined),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => OnlineAgentScreen(session: session)),
                  ),
                ),
              if (session.isAdmin && !session.offlineOnly)
                IconButton(
                  tooltip: 'Verwaltung',
                  icon: const Icon(Icons.admin_panel_settings_outlined),
                  onPressed: () => Navigator.of(
                    context,
                  ).push(MaterialPageRoute<void>(builder: (_) => OnlineAdminScreen(session: session))),
                ),
              // Seltene Aktionen im Überlaufmenü — auf dem Handy ist in der
              // AppBar sonst kein Platz für den Firmennamen.
              PopupMenuButton<String>(
                tooltip: 'Weitere Aktionen',
                onSelected: (value) async {
                  switch (value) {
                    case 'refresh':
                      try {
                        await session.refreshPermissions();
                      } on Exception catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(describeOnlineError(e))));
                        }
                      }
                    case 'password':
                      final changed = await showDialog<bool>(
                        context: context,
                        builder: (_) => OnlinePasswordDialog(session: session),
                      );
                      if (changed == true && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Passwort geändert — andere Geräte wurden abgemeldet.')),
                        );
                      }
                    case 'logout':
                      await _logout();
                  }
                },
                itemBuilder: (_) => [
                  if (!session.offlineOnly) const PopupMenuItem(value: 'refresh', child: Text('Rechte neu laden')),
                  if (!session.offlineOnly) const PopupMenuItem(value: 'password', child: Text('Passwort ändern')),
                  const PopupMenuItem(value: 'logout', child: Text('Abmelden')),
                ],
              ),
            ],
          ),
          body: Column(
            children: [
              // Ehrliche Offline-Grenze (Abnahme B): im Online-Modus gibt es
              // (noch) keinen lokalen Cache — ohne Netz keine Daten.
              Material(
                color: Theme.of(context).colorScheme.secondaryContainer,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Row(
                    children: [
                      Icon(session.offlineOnly ? Icons.cloud_off_outlined : Icons.cloud_outlined, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          session.offlineOnly
                              ? 'Ohne Verbindung: nur offline markierte Dokumente. Entwürfe bearbeitbar, Abgleich nach Anmeldung.'
                              : session.offline == null
                              ? 'Online-Modus: Daten liegen auf dem Server, keine lokale Kopie.'
                              : 'Online-Modus: nur ausdrücklich offline markierte Dokumente liegen verschlüsselt auf dem Gerät.',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: tabs.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'Für diese Firma sind dir noch keine Rechte zugewiesen. Der Firmen-Admin vergibt sie '
                            'über deine Gruppe oder eine individuelle Ausnahme — als Admin über „Verwaltung“ oben rechts.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : IndexedStack(
                        index: index,
                        children: [
                          for (final t in destinations)
                            KeyedSubtree(key: ValueKey('${t.label}-${_visits[t.label] ?? 0}'), child: t.body),
                        ],
                      ),
              ),
            ],
          ),
          bottomNavigationBar: destinations.length < 2
              ? null
              : NavigationBar(
                  selectedIndex: index,
                  onDestinationSelected: (i) => setState(() {
                    if (i != index) _visits.update(destinations[i].label, (v) => v + 1, ifAbsent: () => 1);
                    _index = i;
                  }),
                  destinations: [for (final t in destinations) NavigationDestination(icon: Icon(t.icon), label: t.label)],
                ),
        );
      },
    );
  }
}

/// Weitere Bereiche, die nicht mehr in die untere Leiste passen — jeder
/// öffnet sich als eigene Seite.
class _MoreScreen extends StatelessWidget {
  const _MoreScreen({required this.entries});
  final List<({String label, IconData icon, Widget body})> entries;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        for (final e in entries)
          Card(
            child: ListTile(
              leading: Icon(e.icon),
              title: Text(e.label),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => Scaffold(appBar: AppBar(title: Text(e.label)), body: e.body),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
