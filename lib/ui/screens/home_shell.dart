import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/database/database.dart';
import '../../data/database/tables.dart';
import '../../domain/services/active_company_service.dart';
import '../theme/app_theme.dart';
import '../widgets/section_label.dart';
import '../widgets/sidebar_nav_item.dart';
import 'articles_screen.dart';
import 'company_switcher_screen.dart';
import 'customers_screen.dart';
import 'invoices_screen.dart';
import 'settings_screen.dart';
import 'suppliers_screen.dart';

/// Stabile Kennung eines Tabs, unabhängig von seiner **Position** in der
/// Liste. A5 fügt Angebot/Auftrag mittendrin ein (zwischen Rechnungen
/// und Kunden) — ein reiner Positions-Index ("Index 4 ist Einstellungen")
/// würde dadurch beim Umschalten eines Moduls plötzlich auf einen ganz
/// anderen Tab zeigen, obwohl der Nutzer gar nicht navigiert hat
/// (gefunden über einen Widget-Test: Angebote auf der Einstellungen-
/// Seite aktivieren sprang kommentarlos auf "Lieferanten", weil
/// Einstellungen von Index 4 auf Index 5 rutschte). Die ID bleibt
/// stabil, die tatsächliche Listenposition wird bei jedem Build neu
/// aufgelöst.
enum _TabId { invoice, quote, order, customers, articles, suppliers, settings }

/// Ein Navigationseintrag der Shell. Angebot/Auftrag (A5) sind nur
/// Instanzen von [InvoicesScreen] mit anderer [DocumentKind] — die
/// Liste wird deshalb pro Build aus den Modul-Flags der aktiven Firma
/// zusammengesetzt statt fest zu sein.
class _Tab {
  const _Tab({
    required this.id,
    required this.icon,
    required this.title,
    required this.screen,
    required this.section,
  });
  final _TabId id;
  final IconData icon;
  final String title;
  final Widget screen;
  final _Section section;
}

enum _Section { fakturierung, stammdaten, einstellungen }

/// Navigationsrahmen innerhalb einer gewählten Firma.
///
/// Adaptiv: auf dem schmalen Android-Smartphone (Roadmap A0 Punkt 4)
/// bleibt die Bottom-Navigation die richtige Wahl (Detailansichten
/// decken sie wie gewohnt vollflächig ab — normales Mobil-Verhalten).
/// Auf breiteren Fenstern (Kays Web-/LAN-Vorschau, Desktop-Browser)
/// übernimmt eine gruppierte Sidebar das Layout-Muster von RechnungsFee
/// (Sektionen, Indigo-Akzent, kompakte Zeilen) — eigenständig in
/// Flutter nachgebaut, kein Code/Asset von dort.
///
/// Bugfix (Kay-Feedback 2026-10-16): Eine Rechnung/Artikel zu öffnen
/// pushte bisher über den Root-Navigator der ganzen App — das deckte
/// im Breit-Layout die Sidebar mit ab ("Menüleiste verschwindet"). Der
/// Inhaltsbereich bekommt deshalb einen eigenen, verschachtelten
/// [Navigator]; `Navigator.of(context)`-Aufrufe aus den Tab-Screens
/// finden automatisch diesen statt des Root-Navigators, weil er näher
/// im Widget-Baum liegt — die Sidebar bleibt dadurch immer sichtbar.
///
/// A5: Angebote/Aufträge erscheinen als zusätzliche Fakturierung-Tabs,
/// sobald die Firma das jeweilige Modul aktiviert (`SettingsScreen`).
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  _TabId _narrowId = _TabId.invoice;
  final _wideId = ValueNotifier<_TabId>(_TabId.invoice);
  // Die Tab-Liste selbst muss ebenfalls über ein Listenable laufen, nicht
  // nur die aktuelle ID: der Inhaltsbereich liegt in der ERSTEN Route
  // eines verschachtelten Navigators (siehe unten), deren `builder`-
  // Closure nur EINMAL beim Erststart des Navigators ausgeführt wird. Ein
  // simpler `List<_Tab>`-Konstruktorparameter wäre darin für immer auf
  // dem Stand von damals eingefroren — ein per Schalter später
  // aktiviertes Angebot/Auftrag-Modul wäre im Inhaltsbereich nie
  // erschienen, obwohl die Sidebar (bei jedem Rebuild frisch gebaut)
  // korrekt reagiert hätte.
  final _tabsNotifier = ValueNotifier<List<_Tab>>(const []);
  final _contentNavKey = GlobalKey<NavigatorState>();

  List<_Tab> _buildTabs(Company company) => [
        const _Tab(
          id: _TabId.invoice,
          icon: Icons.receipt_long_outlined,
          title: 'Rechnungen',
          screen: InvoicesScreen(),
          section: _Section.fakturierung,
        ),
        if (company.quotesEnabled)
          const _Tab(
            id: _TabId.quote,
            icon: Icons.request_quote_outlined,
            title: 'Angebote',
            screen: InvoicesScreen(kind: DocumentKind.quote),
            section: _Section.fakturierung,
          ),
        if (company.ordersEnabled)
          const _Tab(
            id: _TabId.order,
            icon: Icons.assignment_outlined,
            title: 'Aufträge',
            screen: InvoicesScreen(kind: DocumentKind.order),
            section: _Section.fakturierung,
          ),
        const _Tab(
          id: _TabId.customers,
          icon: Icons.group_outlined,
          title: 'Kunden',
          screen: CustomersScreen(),
          section: _Section.stammdaten,
        ),
        const _Tab(
          id: _TabId.articles,
          icon: Icons.inventory_2_outlined,
          title: 'Artikel',
          screen: ArticlesScreen(),
          section: _Section.stammdaten,
        ),
        const _Tab(
          id: _TabId.suppliers,
          icon: Icons.local_shipping_outlined,
          title: 'Lieferanten',
          screen: SuppliersScreen(),
          section: _Section.stammdaten,
        ),
        const _Tab(
          id: _TabId.settings,
          icon: Icons.settings_outlined,
          title: 'Einstellungen',
          screen: SettingsScreen(),
          section: _Section.einstellungen,
        ),
      ];

  @override
  void dispose() {
    _wideId.dispose();
    _tabsNotifier.dispose();
    super.dispose();
  }

  /// Löst eine [_TabId] auf ihre aktuelle Position in [tabs] auf. `-1`
  /// (ID existiert gerade nicht, z.B. Modul wurde währenddessen
  /// deaktiviert) fällt auf den ersten Tab zurück statt abzustürzen.
  int _positionOf(_TabId id, List<_Tab> tabs) {
    final index = tabs.indexWhere((t) => t.id == id);
    return index == -1 ? 0 : index;
  }

  void _selectWide(_TabId id) {
    // Beim Tab-Wechsel zuerst zurück auf die Liste springen, falls z.B.
    // gerade eine Rechnung im Inhaltsbereich geöffnet ist — sonst bliebe
    // der alte Push-Stack unter dem neuen Tab-Inhalt "verborgen" stehen.
    _contentNavKey.currentState?.popUntil((route) => route.isFirst);
    _wideId.value = id;
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<ActiveCompanyService>();
    final company = service.active;

    if (company == null) {
      return const CompanySwitcherScreen();
    }

    final tabs = _buildTabs(company);
    _tabsNotifier.value = tabs;

    final isWide = MediaQuery.sizeOf(context).width >= AppMetrics.wideLayoutBreakpoint;

    if (isWide) {
      return _WideShell(
        companyName: company.name,
        currentId: _wideId,
        tabsNotifier: _tabsNotifier,
        contentNavKey: _contentNavKey,
        onSelect: _selectWide,
        tabs: tabs,
      );
    }

    final narrowIndex = _positionOf(_narrowId, tabs);

    return Scaffold(
      appBar: AppBar(
        title: Text('${company.name} — ${tabs[narrowIndex].title}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.swap_horiz),
            tooltip: 'Firma wechseln',
            onPressed: () => Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const CompanySwitcherScreen()),
            ),
          ),
        ],
      ),
      body: IndexedStack(index: narrowIndex, children: [for (final tab in tabs) tab.screen]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: narrowIndex,
        onDestinationSelected: (index) => setState(() => _narrowId = tabs[index].id),
        destinations: [
          for (final tab in tabs) NavigationDestination(icon: Icon(tab.icon), label: tab.title),
        ],
      ),
    );
  }
}

/// Sidebar-Layout für breite Fenster. Gruppiert nach [_Section] — exakt
/// dieselbe grobe Gliederung wie RechnungsFees Sidebar ("Fakturierung",
/// "Stammdaten"), aber nur mit den Modulen, die die aktive Firma
/// tatsächlich aktiviert hat.
class _WideShell extends StatelessWidget {
  const _WideShell({
    required this.companyName,
    required this.currentId,
    required this.tabsNotifier,
    required this.contentNavKey,
    required this.onSelect,
    required this.tabs,
  });

  final String companyName;
  final ValueNotifier<_TabId> currentId;
  final ValueNotifier<List<_Tab>> tabsNotifier;
  final GlobalKey<NavigatorState> contentNavKey;
  final ValueChanged<_TabId> onSelect;

  /// Für die Sidebar: die ist Teil des normalen Widget-Baums und wird
  /// bei jedem `HomeShell`-Rebuild neu mit dem aktuellen Stand gebaut,
  /// ein einfacher Parameter reicht dafür aus (im Gegensatz zum
  /// Inhaltsbereich, siehe [tabsNotifier] und die Doc-Notiz in
  /// `_HomeShellState`).
  final List<_Tab> tabs;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? AppColors.slate700 : AppColors.slate200;

    return Scaffold(
      body: Row(
        children: [
          SizedBox(
            width: AppMetrics.sidebarWidth,
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.slate900 : Colors.white,
                border: Border(right: BorderSide(color: borderColor)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(border: Border(bottom: BorderSide(color: borderColor))),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: AppColors.indigo,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          alignment: Alignment.center,
                          child: const Text(
                            'W',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              RichText(
                                overflow: TextOverflow.ellipsis,
                                text: TextSpan(
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : AppColors.slate800,
                                  ),
                                  children: const [
                                    TextSpan(text: 'Werkkern'),
                                    TextSpan(text: 'ERP', style: TextStyle(color: AppColors.indigo)),
                                  ],
                                ),
                              ),
                              Text(
                                companyName,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark ? AppColors.slate500 : AppColors.slate400,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ValueListenableBuilder<_TabId>(
                      valueListenable: currentId,
                      builder: (context, current, _) {
                        final children = <Widget>[];
                        _Section? lastSection;
                        for (final tab in tabs) {
                          if (tab.section != lastSection) {
                            if (tab.section == _Section.fakturierung) {
                              children.add(const SectionLabel('Fakturierung'));
                            } else if (tab.section == _Section.stammdaten) {
                              children.add(const SectionLabel('Stammdaten'));
                            } else {
                              children.add(const Divider(height: 24));
                            }
                            lastSection = tab.section;
                          }
                          children.add(
                            SidebarNavItem(
                              icon: tab.icon,
                              label: tab.title,
                              selected: current == tab.id,
                              onTap: () => onSelect(tab.id),
                            ),
                          );
                        }
                        return ListView(padding: const EdgeInsets.symmetric(vertical: 4), children: children);
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: SidebarNavItem(
                      icon: Icons.swap_horiz,
                      label: 'Firma wechseln',
                      selected: false,
                      onTap: () => Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (_) => const CompanySwitcherScreen()),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  height: 56,
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  decoration: BoxDecoration(border: Border(bottom: BorderSide(color: borderColor))),
                  child: ValueListenableBuilder<_TabId>(
                    valueListenable: currentId,
                    builder: (context, current, _) {
                      final tab = tabs.where((t) => t.id == current).firstOrNull ?? tabs.first;
                      return Text(tab.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600));
                    },
                  ),
                ),
                Expanded(
                  // Eigener, verschachtelter Navigator statt direktem
                  // IndexedStack als Root-Inhalt: Navigator.of(context)
                  // aus den Tab-Screens (z.B. "Neue Rechnung öffnen")
                  // findet diesen hier zuerst und pusht dadurch INNERHALB
                  // des Inhaltsbereichs statt über die ganze App inkl.
                  // Sidebar (siehe Klassendoc-Kommentar oben).
                  child: Navigator(
                    key: contentNavKey,
                    onGenerateRoute: (settings) => MaterialPageRoute(
                      settings: settings,
                      builder: (context) => ListenableBuilder(
                        // Auf BEIDE hören, nicht nur auf currentId: ein
                        // neu aktiviertes Modul ändert die Tab-Liste
                        // selbst, nicht nur die Auswahl (siehe Doc-Notiz
                        // zu `_tabsNotifier` in `_HomeShellState`).
                        listenable: Listenable.merge([tabsNotifier, currentId]),
                        builder: (context, _) {
                          final currentTabs = tabsNotifier.value;
                          final index = currentTabs.isEmpty
                              ? 0
                              : currentTabs.indexWhere((t) => t.id == currentId.value).clamp(
                                    0,
                                    currentTabs.length - 1,
                                  );
                          return IndexedStack(
                            index: index < 0 ? 0 : index,
                            children: [for (final tab in currentTabs) tab.screen],
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
