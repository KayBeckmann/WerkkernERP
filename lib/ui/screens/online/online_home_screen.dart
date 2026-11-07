import 'dart:async';

import 'package:flutter/material.dart';
import 'package:werkkern_client/werkkern_client.dart' show ApiException;

import '../../../domain/services/online_session.dart';
import '../../widgets/app_shell.dart';
import 'online_accounting_screen.dart';
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
import 'online_settings_screen.dart';
import 'online_stock_screen.dart';
import 'online_time_screen.dart';
import 'online_time_sheets_screen.dart';

/// Hauptansicht im Online-Modus. Tabs erscheinen nur bei wirksamem
/// Leserecht — der Server prüft trotzdem jede Aktion selbst.
/// Tab-Titel je Dokumentart wie offline (`DocumentLabels.listTitle`).
const onlineDocumentKindTabTitles = <String, String>{
  'invoice': 'Rechnungen',
  'quote': 'Angebote',
  'order': 'Aufträge',
  'deliveryNote': 'Lieferscheine',
  'proforma': 'Proforma-Rechnungen',
  'creditNote': 'Gutschriften',
};

const _documentKindIcons = <String, IconData>{
  'invoice': Icons.receipt_long_outlined,
  'quote': Icons.request_quote_outlined,
  'order': Icons.assignment_outlined,
  'deliveryNote': Icons.outbox_outlined,
  'proforma': Icons.fact_check_outlined,
  'creditNote': Icons.receipt_long_outlined,
};

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
    if (widget.session.expiresAt != null && !widget.session.offlineOnly) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _checkExpiry());
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
  /// Jede Nutzung verlängert die Sitzung serverseitig (7 Tage ab
  /// jetzt). Die App fragt das Ablaufdatum deshalb beim Öffnen, stündlich
  /// und beim bisher bekannten Ablauf ab, statt blind abzumelden.
  static const _expiryCheckInterval = Duration(hours: 1);

  Future<void> _checkExpiry() async {
    _expiryTimer?.cancel();
    try {
      await widget.session.refreshExpiry();
    } on ApiException catch (e) {
      if (e.isUnauthorized) return _expired();
    } on Exception {
      // Kein Netz: bekanntes Ablaufdatum gilt weiter.
    }
    if (!mounted) return;
    final expiresAt = widget.session.expiresAt;
    if (expiresAt == null) return;
    final left = expiresAt.difference(DateTime.now().toUtc());
    if (left <= Duration.zero) {
      // Abgelaufen und der Server war nicht zu erreichen (sonst hätte er
      // 401 oder ein späteres Datum geliefert).
      return _expired();
    }
    _expiryTimer = Timer(left < _expiryCheckInterval ? left : _expiryCheckInterval, _checkExpiry);
  }

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
        // Gleiche Bereiche, Namen und Reihenfolge wie offline
        // (`home_shell.dart`); jeweils nur bei wirksamem Leserecht + Modul.
        final documentKinds = [
          for (final entry in onlineDocumentKindModules.entries)
            if (entry.value == null || session.modules.contains(entry.value)) entry.key,
        ];
        final accounting = session.modules.contains('buchhaltung') && session.can('accounting.read') && online;
        final timeTracking = session.modules.contains('timeTracking') && online;
        final tabs = [
          // Der Server liefert nur Kacheln, für die Rechte und Module
          // passen (ohne Verbindung keine Übersicht).
          if (online && session.permissions.isNotEmpty)
            tab('Dashboard', Icons.dashboard_outlined, ShellSection.dashboard, OnlineDashboardScreen(session: session)),
          if (session.can('invoices.read'))
            for (final kind in documentKinds)
              tab(
                onlineDocumentKindTabTitles[kind]!,
                _documentKindIcons[kind]!,
                ShellSection.fakturierung,
                OnlineDocumentsScreen(session: session, kind: kind),
              ),
          if (session.modules.contains('recurringInvoices') && session.can('invoices.read') && online)
            tab('Vorlagen', Icons.repeat_outlined, ShellSection.fakturierung, OnlineRecurringScreen(session: session)),
          // Nur online: Übersicht überfälliger Rechnungen.
          if (session.modules.contains('dunning') && session.can('dunning.read') && online)
            tab('Mahnwesen', Icons.notification_important_outlined, ShellSection.fakturierung, OnlineDunningScreen(session: session)),
          if (session.can('customers.read') && online)
            tab('Kunden', Icons.group_outlined, ShellSection.stammdaten, OnlineCustomersScreen(session: session)),
          if (session.can('articles.read') && online) ...[
            tab('Artikel', Icons.inventory_2_outlined, ShellSection.stammdaten, OnlineArticlesScreen(session: session)),
            tab('Lieferanten', Icons.local_shipping_outlined, ShellSection.stammdaten, OnlineSuppliersScreen(session: session)),
          ],
          if (session.modules.contains('projects') && session.can('projects.read') && online)
            tab('Projekte', Icons.folder_outlined, ShellSection.stammdaten, OnlineProjectsScreen(session: session)),
          if (session.modules.contains('fleet') && session.can('fleet.read') && online)
            tab('Fuhrpark', Icons.directions_car_outlined, ShellSection.stammdaten, OnlineFleetScreen(session: session)),
          if (session.modules.contains('bestellwesen') && session.can('purchaseOrders.read') && online)
            tab('Bestellungen', Icons.shopping_cart_outlined, ShellSection.stammdaten, OnlinePurchasingScreen(session: session)),
          if (session.modules.contains('lagerbestand') && session.can('stock.read') && online)
            tab('Inventur', Icons.fact_check_outlined, ShellSection.stammdaten, OnlineStockScreen(session: session)),
          if (timeTracking && (session.can('timeTracking.write') || session.can('timeTracking.read')))
            tab('Zeiterfassung', Icons.schedule_outlined, ShellSection.stammdaten, OnlineTimeScreen(session: session)),
          if (timeTracking && session.can('timeTracking.write'))
            tab('Stundenzettel', Icons.draw_outlined, ShellSection.stammdaten, OnlineTimeSheetsScreen(session: session)),
          if (accounting) ...[
            tab('Offene Posten', Icons.account_balance_wallet_outlined, ShellSection.buchhaltung, OnlineOpenItemsScreen(session: session)),
            tab('Belege', Icons.receipt_outlined, ShellSection.buchhaltung, OnlineExpensesScreen(session: session)),
            tab('EÜR-Übersicht', Icons.insights_outlined, ShellSection.buchhaltung, OnlineEuerScreen(session: session)),
            tab('Bankabgleich', Icons.sync_alt_outlined, ShellSection.buchhaltung, OnlineBankScreen(session: session)),
          ],
        ];
        // Ohne jedes Recht bleibt der Hinweis „keine Rechte“ statt einer
        // Navigation, die nur aus den Einstellungen besteht.
        if (online && (tabs.isNotEmpty || session.isAdmin)) {
          tabs.add(tab('Einstellungen', Icons.settings_outlined, ShellSection.einstellungen, OnlineSettingsScreen(session: session)));
        }
        return AppShell(
          companyName: session.companyName,
          companyCaption: online ? 'online' : 'offline',
          tabs: tabs,
          pinnedNarrowIds: const ['Dashboard', 'Rechnungen', 'Kunden'],
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
                'über deine Gruppe oder eine individuelle Ausnahme — als Admin unter „Einstellungen“.',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        );
      },
    );
  }
}
