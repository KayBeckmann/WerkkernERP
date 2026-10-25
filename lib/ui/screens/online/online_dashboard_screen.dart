import 'package:flutter/material.dart';
import 'package:werkkern_client/werkkern_client.dart';
import 'package:werkkern_core/werkkern_core.dart';

import '../../../domain/services/online_session.dart';
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
  'vehicles': Icons.local_shipping_outlined,
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

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<OnlineDashboard>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text(describeOnlineError(snapshot.error!)));
        final data = snapshot.data;
        if (data == null) return const Center(child: CircularProgressIndicator());
        return RefreshIndicator(
          onRefresh: () async => _reload(),
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: data.available.isEmpty ? null : () => _customize(data),
                  icon: const Icon(Icons.tune),
                  label: const Text('Anpassen'),
                ),
              ),
              if (data.tiles.isEmpty) const Padding(padding: EdgeInsets.all(24), child: Center(child: Text('Keine Kacheln eingeblendet.'))),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final t in data.tiles)
                    SizedBox(
                      width: 260,
                      child: Card(
                        child: ListTile(
                          key: Key('dashboard-${t.key}'),
                          leading: Icon(_icons[t.key] ?? Icons.dashboard_outlined),
                          title: Text(t.title),
                          subtitle: t.detail == null ? null : Text(t.detail!.replaceAll('.', ',')),
                          trailing: Text(_main(t), style: Theme.of(context).textTheme.titleMedium),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
