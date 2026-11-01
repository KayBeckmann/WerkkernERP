import 'package:flutter/material.dart';
import 'package:werkkern_client/werkkern_client.dart';
import 'package:werkkern_core/werkkern_core.dart';

import '../../../domain/services/online_session.dart';
import '../../theme/app_theme.dart';
import 'online_form.dart';

const dashboardTileLabels = {
  'openInvoices': 'Offene Rechnungen',
  'revenue': 'Umsatz',
  'drafts': 'Meine Entwürfe',
  'overdue': 'Zu mahnen',
  'projects': 'Aktive Projekte',
  'myHours': 'Meine Stunden',
  'timeSheets': 'Offene Stundenzettel',
  'lowStock': 'Unter Mindestbestand',
  'purchaseOrders': 'Offene Bestellungen',
  'vehicles': 'TÜV in 30 Tagen',
  'recurring': 'Wiederkehrende Rechnungen',
};

const _icons = {
  'openInvoices': Icons.request_quote_outlined,
  'revenue': Icons.trending_up,
  'drafts': Icons.edit_note,
  'overdue': Icons.notification_important_outlined,
  'projects': Icons.folder_outlined,
  'myHours': Icons.timer_outlined,
  'timeSheets': Icons.draw_outlined,
  'lowStock': Icons.warning_amber_outlined,
  'purchaseOrders': Icons.shopping_cart_outlined,
  'vehicles': Icons.directions_car_outlined,
  'recurring': Icons.autorenew,
};

/// Übersicht als Einstieg (wie offline das Dashboard): Kacheln nach den
/// eigenen Rechten — Finanzen nur, wer sie sehen darf; ausblendbar je Nutzer.
class OnlineDashboardScreen extends StatefulWidget {
  const OnlineDashboardScreen({super.key, required this.session});
  final OnlineSession session;

  @override
  State<OnlineDashboardScreen> createState() => _OnlineDashboardScreenState();
}

class _OnlineDashboardScreenState extends State<OnlineDashboardScreen> {
  late Future<OnlineDashboard> _future = widget.session.client.dashboard();

  void _reload() => setState(() {
        _future = widget.session.client.dashboard();
      });

  Future<void> _customize(OnlineDashboard data) async {
    final values = await showOnlineForm(
      context,
      title: 'Kacheln anzeigen',
      fields: [
        for (final key in data.available)
          OnlineField(key, dashboardTileLabels[key] ?? key, type: OnlineFieldType.toggle, initial: !data.hidden.contains(key)),
      ],
    );
    if (values == null || !mounted) return;
    if (await runOnline(
      context,
      () => widget.session.client.setDashboardHidden([for (final e in values.entries) if (e.value == false) e.key]),
    )) {
      _reload();
    }
  }

  String _main(OnlineDashboardTile t) {
    if (t.amountCents != null) return Money.fromCents(t.amountCents!).toString();
    if (t.value != null) return '${t.value!.replaceAll('.', ',')} Std.';
    return '${t.count ?? 0}';
  }

  static String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';

  /// Kacheln in Reihenfolge, Beschriftung und Darstellung wie das
  /// Offline-Dashboard; Kacheln, die es nur online gibt, folgen danach.
  List<Widget> _cards(List<OnlineDashboardTile> tiles) {
    final byKey = {for (final t in tiles) t.key: t};
    final cards = <Widget>[];
    final revenue = byKey['revenue'];
    if (revenue != null) {
      cards
        ..add(_KpiCard(
          key: const Key('dashboard-revenue'),
          icon: Icons.euro_outlined,
          label: 'Rechnungssumme diesen Monat',
          value: Money.fromCents(revenue.amountCents ?? 0).toString(),
        ))
        ..add(_KpiCard(
          key: const Key('dashboard-revenue-year'),
          icon: Icons.calendar_today_outlined,
          label: 'Rechnungssumme dieses Jahr',
          value: Money.fromCents(revenue.yearAmountCents ?? 0).toString(),
        ));
    }
    final open = byKey['openInvoices'];
    if (open != null) {
      cards.add(_KpiCard(
        key: const Key('dashboard-openInvoices'),
        icon: Icons.pending_actions_outlined,
        label: open.detail == null ? 'Offene Rechnungen' : 'Offene Rechnungen · ${open.detail}',
        value: '${open.count ?? 0} (${Money.fromCents(open.amountCents ?? 0)})',
      ));
    }
    final overdue = byKey['overdue'];
    if (overdue != null) {
      cards.add(_KpiCard(
        key: const Key('dashboard-overdue'),
        icon: Icons.warning_amber_outlined,
        label: 'Überfällig (Mahnstufe erreicht)',
        value: '${overdue.count ?? 0}',
        highlight: (overdue.count ?? 0) > 0,
      ));
    }
    final projects = byKey['projects'];
    if (projects != null) {
      cards.add(_KpiCard(
        key: const Key('dashboard-projects'),
        icon: Icons.folder_outlined,
        label: 'Aktive Projekte',
        value: '${projects.count ?? 0}',
      ));
    }
    final vehicles = byKey['vehicles'];
    if (vehicles != null) {
      cards.add(_KpiCard(
        key: const Key('dashboard-vehicles'),
        icon: Icons.directions_car_outlined,
        label: 'TÜV fällig (< 30 Tage)',
        value: '${vehicles.count ?? 0}',
        highlight: (vehicles.count ?? 0) > 0,
      ));
    }
    final recurring = byKey['recurring'];
    if (recurring != null) {
      final next = DateTime.tryParse(recurring.detail?.replaceFirst('nächste ', '') ?? '');
      cards.add(_KpiCard(
        key: const Key('dashboard-recurring'),
        icon: Icons.repeat_outlined,
        label: 'Aktive wiederkehrende Vorlagen',
        value: next == null ? '${recurring.count ?? 0}' : '${recurring.count ?? 0} — nächste Fälligkeit ${_formatDate(next)}',
      ));
    }
    const offlineKeys = {'revenue', 'openInvoices', 'overdue', 'projects', 'vehicles', 'recurring'};
    for (final t in tiles) {
      if (offlineKeys.contains(t.key)) continue;
      cards.add(_KpiCard(
        key: Key('dashboard-${t.key}'),
        icon: _icons[t.key] ?? Icons.dashboard_outlined,
        label: t.detail == null ? t.title : '${t.title} · ${t.detail!.replaceAll('.', ',')}',
        value: _main(t),
        highlight: t.key == 'lowStock' && (t.count ?? 0) > 0,
      ));
    }
    return cards;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<OnlineDashboard>(
      future: _future,
      builder: (context, snapshot) {
        final data = snapshot.data;
        return Scaffold(
          appBar: AppBar(
            // Bereich der Navigation, keine eigene Seite: kein Zurück-Pfeil.
            automaticallyImplyLeading: false,
            title: const Text('Dashboard'),
            actions: [
              // Nur online: Kacheln je Nutzer ausblenden.
              IconButton(
                icon: const Icon(Icons.tune),
                tooltip: 'Kacheln anpassen',
                onPressed: data == null || data.available.isEmpty ? null : () => _customize(data),
              ),
              IconButton(icon: const Icon(Icons.refresh_outlined), tooltip: 'Aktualisieren', onPressed: _reload),
            ],
          ),
          body: snapshot.hasError
              ? Center(child: Text(describeOnlineError(snapshot.error!)))
              : data == null
              ? const Center(child: CircularProgressIndicator())
              : data.tiles.isEmpty
              ? const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('Keine Kacheln eingeblendet.')))
              : RefreshIndicator(
                  onRefresh: () async {
                    _reload();
                    await _future;
                  },
                  // Raster wie offline (2 bzw. 3 Spalten), aber mit fester
                  // Kachelhöhe — auf schmalen Handys reicht das Seitenverhältnis
                  // sonst nicht für Wert + zweizeilige Beschriftung.
                  child: GridView(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: MediaQuery.sizeOf(context).width >= AppMetrics.wideLayoutBreakpoint ? 3 : 2,
                      mainAxisExtent: 136,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    children: _cards(data.tiles),
                  ),
                ),
        );
      },
    );
  }
}

/// Kennzahl-Kachel wie offline (`dashboard_screen.dart`).
class _KpiCard extends StatelessWidget {
  const _KpiCard({super.key, required this.icon, required this.label, required this.value, this.highlight = false});

  final IconData icon;
  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      color: highlight ? colorScheme.errorContainer : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: highlight ? colorScheme.onErrorContainer : colorScheme.primary),
            const Spacer(),
            // Lange Werte („3 (1.190,00 €)“) verkleinern statt umbrechen —
            // die Kachel hat eine feste Höhe.
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(color: highlight ? colorScheme.onErrorContainer : null),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: highlight ? colorScheme.onErrorContainer : colorScheme.onSurfaceVariant,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
