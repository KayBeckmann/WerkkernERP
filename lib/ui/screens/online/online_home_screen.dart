import 'package:flutter/material.dart';

import '../../../domain/services/online_session.dart';
import 'online_articles_screen.dart';
import 'online_customers_screen.dart';
import 'online_documents_screen.dart';

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

  @override
  void dispose() {
    widget.session.client.close();
    super.dispose();
  }

  Future<void> _logout() async {
    await widget.session.logout();
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
          if (session.can('customers.read'))
            (label: 'Kunden', icon: Icons.people_outline, body: OnlineCustomersScreen(session: session)),
          if (session.can('articles.read'))
            (label: 'Artikel', icon: Icons.inventory_2_outlined, body: OnlineArticlesScreen(session: session)),
        ];
        final index = _index.clamp(0, tabs.isEmpty ? 0 : tabs.length - 1);
        return Scaffold(
          appBar: AppBar(
            title: Text('${session.companyName} · online'),
            actions: [
              IconButton(
                tooltip: 'Rechte neu laden',
                icon: const Icon(Icons.refresh),
                onPressed: () => session.refreshPermissions().catchError((Object e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(describeOnlineError(e))));
                  }
                }),
              ),
              IconButton(tooltip: 'Abmelden', icon: const Icon(Icons.logout), onPressed: _logout),
            ],
          ),
          body: Column(
            children: [
              // Ehrliche Offline-Grenze (Abnahme B): im Online-Modus gibt es
              // (noch) keinen lokalen Cache — ohne Netz keine Daten.
              Material(
                color: Theme.of(context).colorScheme.secondaryContainer,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Row(
                    children: [
                      Icon(Icons.cloud_outlined, size: 16),
                      SizedBox(width: 8),
                      Expanded(child: Text('Online-Modus: Daten liegen auf dem Server, keine lokale Kopie.')),
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
                            'über deine Gruppe oder eine individuelle Ausnahme.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : IndexedStack(index: index, children: [for (final t in tabs) t.body]),
              ),
            ],
          ),
          bottomNavigationBar: tabs.length < 2
              ? null
              : NavigationBar(
                  selectedIndex: index,
                  onDestinationSelected: (i) => setState(() => _index = i),
                  destinations: [for (final t in tabs) NavigationDestination(icon: Icon(t.icon), label: t.label)],
                ),
        );
      },
    );
  }
}
