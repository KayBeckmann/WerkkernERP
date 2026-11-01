import 'dart:async';

import 'package:flutter/material.dart';

import '../../../domain/services/online_session.dart';
import '../../widgets/app_shell.dart';
import 'online_accounting_screen.dart';
import 'online_admin_screen.dart';
import 'online_agent_screen.dart';
import 'online_articles_screen.dart';
import 'online_customers_screen.dart';
import 'online_dashboard_screen.dart';
import 'online_documents_screen.dart';
import 'online_dunning_screen.dart';
import 'online_fleet_screen.dart';
import 'online_password_dialog.dart';
import 'online_projects_screen.dart';
import 'online_purchasing_screen.dart';
import 'online_recurring_screen.dart';
import 'online_stock_screen.dart';
import 'online_time_screen.dart';

/// Hauptansicht im Online-Modus. Tabs erscheinen nur bei wirksamem
/// Leserecht — der Server prüft trotzdem jede Aktion selbst.
class OnlineHomeScreen extends StatefulWidget {
  const OnlineHomeScreen({super.key, required this.session, this.expiredBuilder});
  final OnlineSession session;

  /// Anmeldemaske nach Ablauf der Sitzung (mit Hinweistext); ohne
  /// Builder geht es zurück zur Startseite.
  final Widget Function(String notice)? expiredBuilder;

  @override
  State<OnlineHomeScreen> createState() => _OnlineHomeScreenState();
}

class _OnlineHomeScreenState extends State<OnlineHomeScreen> {
  bool _syncing = false;

  /// Zählt Wechsel je Ziel — ein neuer Schlüssel lädt den Bereich beim
  /// Hinwechseln frisch, statt den Stand vom ersten Aufbau zu zeigen
  /// (z. B. Lager nach einer Bestandskorrektur im Artikelbereich).
  final _visits = <String, int>{};
  Timer? _expiryTimer;

  @override
  void initState() {
    super.initState();
    final expiresAt = widget.session.expiresAt;
    if (expiresAt != null && !widget.session.offlineOnly) {
      final left = expiresAt.difference(DateTime.now().toUtc());
      _expiryTimer = Timer(left.isNegative ? Duration.zero : left, _expired);
    }
    // Nach der Anmeldung liegengebliebene Offline-Änderungen sofort
    // übertragen (B2: Rückkehr online).
    if (!widget.session.offlineOnly && widget.session.pendingChanges > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
    }
  }

  @override
  void dispose() {
    _expiryTimer?.cancel();
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

  /// Sitzung nach 7 Tagen abgelaufen: automatisch abmelden, Passwort neu
  /// eingeben. Offline markierte Dokumente bleiben auf dem Gerät.
  Future<void> _expired() async {
    await widget.session.logout();
    if (!mounted) return;
    const notice = 'Deine Anmeldung ist abgelaufen — bitte das Passwort erneut eingeben.';
    final builder = widget.expiredBuilder;
    if (builder == null) {
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(const SnackBar(content: Text(notice)));
    } else {
      await Navigator.of(context).pushReplacement(MaterialPageRoute<void>(builder: (_) => builder(notice)));
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

  /// Seiten aus Aktionen (KI, Verwaltung) im Breit-Layout neben der
  /// Sidebar öffnen, schmal wie gewohnt vollflächig.
  final _contentNavKey = GlobalKey<NavigatorState>();

  void _push(Widget page) =>
      (_contentNavKey.currentState ?? Navigator.of(context)).push(MaterialPageRoute<void>(builder: (_) => page));

  /// Zurück zur Startseite. Mit „angemeldet bleiben“ bleibt die Sitzung
  /// für den nächsten Klick bestehen, sonst wird sie beendet.
  Future<void> _switchCompany() async {
    final navigator = Navigator.of(context);
    if (!widget.session.keepSignedIn) await widget.session.logout();
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        final online = !session.offlineOnly;
        ShellTab tab(String title, IconData icon, ShellSection section, Widget body) => ShellTab(
              id: title,
              icon: icon,
              title: title,
              section: section,
              // Neuer Schlüssel je Wechsel: der Bereich lädt beim
              // Hinwechseln frisch (siehe [_visits]).
              screen: KeyedSubtree(key: ValueKey('$title-${_visits[title] ?? 0}'), child: body),
            );
        // Gleiche Gliederung wie offline (Fakturierung, Stammdaten,
        // Buchhaltung); Bereiche nur bei wirksamem Leserecht + Modul.
        final tabs = [
          // Einstieg wie offline; der Server liefert nur Kacheln, für die
          // Rechte und Module passen (ohne Verbindung keine Übersicht).
          if (online && session.permissions.isNotEmpty)
            tab('Übersicht', Icons.dashboard_outlined, ShellSection.dashboard, OnlineDashboardScreen(session: session)),
          if (session.can('invoices.read'))
            tab('Dokumente', Icons.receipt_long_outlined, ShellSection.fakturierung, OnlineDocumentsScreen(session: session)),
          if (session.modules.contains('recurringInvoices') && session.can('invoices.read') && online)
            tab('Wiederkehrend', Icons.autorenew, ShellSection.fakturierung, OnlineRecurringScreen(session: session)),
          if (session.modules.contains('dunning') && session.can('dunning.read') && online)
            tab('Mahnwesen', Icons.notification_important_outlined, ShellSection.fakturierung, OnlineDunningScreen(session: session)),
          if (session.can('customers.read') && online)
            tab('Kunden', Icons.people_outline, ShellSection.stammdaten, OnlineCustomersScreen(session: session)),
          if (session.can('articles.read') && online)
            tab('Artikel', Icons.inventory_2_outlined, ShellSection.stammdaten, OnlineArticlesScreen(session: session)),
          if (session.modules.contains('projects') && session.can('projects.read') && online)
            tab('Projekte', Icons.folder_outlined, ShellSection.stammdaten, OnlineProjectsScreen(session: session)),
          if (session.modules.contains('fleet') && session.can('fleet.read') && online)
            tab('Fuhrpark', Icons.local_shipping_outlined, ShellSection.stammdaten, OnlineFleetScreen(session: session)),
          if (session.modules.contains('bestellwesen') && session.can('purchaseOrders.read') && online)
            tab('Bestellungen', Icons.shopping_cart_outlined, ShellSection.stammdaten, OnlinePurchasingScreen(session: session)),
          if (session.modules.contains('lagerbestand') && session.can('stock.read') && online)
            tab('Lager', Icons.warehouse_outlined, ShellSection.stammdaten, OnlineStockScreen(session: session)),
          if (session.modules.contains('timeTracking') &&
              (session.can('timeTracking.write') || session.can('timeTracking.read')) &&
              online)
            tab('Zeiten', Icons.timer_outlined, ShellSection.stammdaten, OnlineTimeScreen(session: session)),
          if (session.modules.contains('buchhaltung') && session.can('accounting.read') && online)
            tab('Buchhaltung', Icons.account_balance_outlined, ShellSection.buchhaltung, OnlineAccountingScreen(session: session)),
        ];
        return AppShell(
          companyName: session.companyName,
          companyCaption: online ? 'online' : 'offline',
          tabs: tabs,
          pinnedNarrowIds: const ['Übersicht', 'Dokumente', 'Kunden'],
          contentNavigatorKey: _contentNavKey,
          onSwitchCompany: _switchCompany,
          onTabSelected: (id) => setState(() => _visits.update(id as String, (v) => v + 1, ifAbsent: () => 1)),
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
            if (session.modules.contains('aiAgents') && online)
              IconButton(
                tooltip: 'KI-Zugang und Freigaben',
                icon: const Icon(Icons.smart_toy_outlined),
                onPressed: () => _push(OnlineAgentScreen(session: session)),
              ),
            if (session.isAdmin && online)
              IconButton(
                tooltip: 'Verwaltung',
                icon: const Icon(Icons.admin_panel_settings_outlined),
                onPressed: () => _push(OnlineAdminScreen(session: session)),
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
                if (online) const PopupMenuItem(value: 'refresh', child: Text('Rechte neu laden')),
                if (online) const PopupMenuItem(value: 'password', child: Text('Passwort ändern')),
                const PopupMenuItem(value: 'logout', child: Text('Abmelden')),
              ],
            ),
          ],
          // Ehrliche Offline-Grenze (Abnahme B): ohne Netz nur die
          // ausdrücklich markierten Dokumente.
          banner: Material(
            color: Theme.of(context).colorScheme.secondaryContainer,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                children: [
                  Icon(online ? Icons.cloud_outlined : Icons.cloud_off_outlined, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      !online
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
          emptyBody: const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Für diese Firma sind dir noch keine Rechte zugewiesen. Der Firmen-Admin vergibt sie '
                'über deine Gruppe oder eine individuelle Ausnahme — als Admin über „Verwaltung“ oben rechts.',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        );
      },
    );
  }
}
