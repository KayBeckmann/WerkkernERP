import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'section_label.dart';
import 'sidebar_nav_item.dart';

/// Gruppen der Navigation — offline und online dieselben.
enum ShellSection { dashboard, fakturierung, stammdaten, buchhaltung, einstellungen }

/// Ein Navigationseintrag. [id] ist eine stabile Kennung (z. B. ein
/// Enum-Wert), unabhängig von der Position in der Liste — Module können
/// Einträge mittendrin ein- oder ausblenden, ohne dass die Auswahl auf
/// einen anderen Eintrag springt.
class ShellTab {
  const ShellTab({
    required this.id,
    required this.icon,
    required this.title,
    required this.screen,
    required this.section,
  });
  final Object id;
  final IconData icon;
  final String title;
  final Widget screen;
  final ShellSection section;
}

/// Welche Überschrift/Trennlinie vor dem ersten Eintrag einer
/// [ShellSection] steht — gemeinsame Logik für die breite Sidebar und die
/// schmale „Mehr“-Übersicht, damit beide niemals auseinanderlaufen.
/// `null` = keine Überschrift (Dashboard: der Einstiegspunkt ist keine
/// Kategorie mit mehreren Einträgen).
Widget? _sectionHeaderFor(ShellSection section) {
  switch (section) {
    case ShellSection.fakturierung:
      return const SectionLabel('Fakturierung');
    case ShellSection.stammdaten:
      return const SectionLabel('Stammdaten');
    case ShellSection.buchhaltung:
      return const SectionLabel('Buchhaltung');
    case ShellSection.dashboard:
      return null;
    case ShellSection.einstellungen:
      return const Divider(height: 24);
  }
}

/// Navigationsrahmen innerhalb einer Firma — für lokale (offline) und
/// Online-Firmen derselbe (Kay-Feedback 2026-11-01: „Beide sollen das
/// gleiche Layout verwenden“).
///
/// Adaptiv: auf dem schmalen Smartphone eine feste Bottom-Navigation mit
/// höchstens drei Einträgen plus „Mehr“ (Kay-Feedback 2026-10-19: „Das
/// wird zu voll in der bottom Menüleiste“); „Mehr“ zeigt dieselbe
/// gruppierte Übersicht wie die Sidebar. Auf breiten Fenstern eine
/// gruppierte Sidebar im RechnungsFee-Layout-Muster (Sektionen,
/// Indigo-Akzent, kompakte Zeilen) — eigenständig in Flutter nachgebaut.
///
/// Der Inhaltsbereich im Breit-Layout hat einen eigenen, verschachtelten
/// [Navigator] (Kay-Feedback 2026-10-16, „Menüleiste verschwindet“):
/// `Navigator.of(context)` aus den Bereichen findet ihn zuerst, Details
/// öffnen sich dadurch neben der Sidebar statt über der ganzen App.
class AppShell extends StatefulWidget {
  const AppShell({
    super.key,
    required this.companyName,
    required this.tabs,
    required this.pinnedNarrowIds,
    required this.onSwitchCompany,
    this.companyCaption,
    this.actions = const [],
    this.banner,
    this.emptyBody,
    this.onTabSelected,
    this.contentNavigatorKey,
  });

  final String companyName;

  /// Zweite Zeile unter dem Firmennamen in der Sidebar, z. B. „online“.
  final String? companyCaption;
  final List<ShellTab> tabs;

  /// Bevorzugte feste Einträge der schmalen Bottom-Bar (bis zu drei).
  /// Fehlt einer (Modul/Recht), rücken die nächsten Einträge nach.
  final List<Object> pinnedNarrowIds;
  final VoidCallback onSwitchCompany;

  /// Zusätzliche Aktionen — schmal in der AppBar, breit rechts in der
  /// Kopfzeile des Inhaltsbereichs.
  final List<Widget> actions;

  /// Hinweiszeile über dem Inhalt (z. B. Online-Modus).
  final Widget? banner;

  /// Inhalt, wenn es keinen einzigen Eintrag gibt (z. B. ohne Rechte).
  final Widget? emptyBody;

  /// Der Nutzer hat [ShellTab.id] gewählt (auch erneut).
  final ValueChanged<Object>? onTabSelected;

  /// Schlüssel des verschachtelten Inhalts-Navigators (Breit-Layout) —
  /// damit Aktionen ihre Seiten ebenfalls neben der Sidebar öffnen.
  final GlobalKey<NavigatorState>? contentNavigatorKey;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  // Kay-Anfrage 2026-10-17: Dashboard als Einstiegspunkt — der erste
  // Eintrag ist der Standard.
  Object? _narrowId;
  late final _wideId = ValueNotifier<Object?>(widget.tabs.firstOrNull?.id);
  // Die Tab-Liste muss ebenfalls über ein Listenable laufen: der
  // Inhaltsbereich liegt in der ERSTEN Route eines verschachtelten
  // Navigators, deren `builder` nur EINMAL läuft. Eine einfache Liste wäre
  // darin für immer auf dem Stand des Erststarts eingefroren — ein später
  // aktiviertes Modul wäre im Inhaltsbereich nie erschienen.
  final _tabsNotifier = ValueNotifier<List<ShellTab>>(const []);
  late final _contentNavKey = widget.contentNavigatorKey ?? GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    _narrowId = widget.tabs.firstOrNull?.id;
    _tabsNotifier.value = widget.tabs;
  }

  @override
  void didUpdateWidget(AppShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    _tabsNotifier.value = widget.tabs;
  }

  @override
  void dispose() {
    _wideId.dispose();
    _tabsNotifier.dispose();
    super.dispose();
  }

  /// Position von [id] in [tabs]; fehlt die ID gerade (Modul während-
  /// dessen deaktiviert), fällt sie auf den ersten Eintrag zurück.
  int _positionOf(Object? id, List<ShellTab> tabs) {
    final index = tabs.indexWhere((t) => t.id == id);
    return index == -1 ? 0 : index;
  }

  /// Feste Einträge der Bottom-Bar: bevorzugte, dann die nächsten bis
  /// drei; bliebe für „Mehr“ nur ein einziger übrig, steht er direkt da.
  List<ShellTab> _pinned(List<ShellTab> tabs) {
    final pinned = [for (final id in widget.pinnedNarrowIds) ...tabs.where((t) => t.id == id)];
    for (final tab in tabs) {
      if (pinned.length >= 3) break;
      if (!pinned.contains(tab)) pinned.add(tab);
    }
    if (tabs.length == pinned.length + 1) pinned.add(tabs.firstWhere((t) => !pinned.contains(t)));
    return pinned;
  }

  void _select(Object id) {
    widget.onTabSelected?.call(id);
  }

  Future<void> _openMoreOverview(List<ShellTab> tabs) async {
    final selected = await Navigator.of(context).push<Object>(
      MaterialPageRoute(
        builder: (_) => _MoreOverviewScreen(tabs: tabs, currentId: _narrowId),
      ),
    );
    if (selected != null && mounted) {
      _select(selected);
      setState(() => _narrowId = selected);
    }
  }

  void _selectWide(Object id) {
    // Beim Wechsel zuerst zurück auf die Liste, falls z. B. gerade eine
    // Rechnung im Inhaltsbereich geöffnet ist — sonst bliebe der alte
    // Push-Stack unter dem neuen Inhalt verborgen stehen.
    _contentNavKey.currentState?.popUntil((route) => route.isFirst);
    _select(id);
    _wideId.value = id;
  }

  @override
  Widget build(BuildContext context) {
    final tabs = widget.tabs;
    final isWide = MediaQuery.sizeOf(context).width >= AppMetrics.wideLayoutBreakpoint;

    if (isWide) {
      return _WideShell(
        companyName: widget.companyName,
        companyCaption: widget.companyCaption,
        currentId: _wideId,
        tabsNotifier: _tabsNotifier,
        contentNavKey: _contentNavKey,
        onSelect: _selectWide,
        onSwitchCompany: widget.onSwitchCompany,
        tabs: tabs,
        actions: widget.actions,
        banner: widget.banner,
        emptyBody: widget.emptyBody,
      );
    }

    final narrowIndex = _positionOf(_narrowId, tabs);
    final pinned = _pinned(tabs);
    final hasMore = pinned.length < tabs.length;
    final pinnedIndex = pinned.indexWhere((t) => t.id == _narrowId);
    final destinationCount = pinned.length + (hasMore ? 1 : 0);

    return Scaffold(
      appBar: AppBar(
        title: Text(tabs.isEmpty ? widget.companyName : '${widget.companyName} — ${tabs[narrowIndex].title}'),
        actions: [
          ...widget.actions,
          IconButton(icon: const Icon(Icons.swap_horiz), tooltip: 'Firma wechseln', onPressed: widget.onSwitchCompany),
        ],
      ),
      body: Column(
        children: [
          ?widget.banner,
          Expanded(
            child: tabs.isEmpty
                ? (widget.emptyBody ?? const SizedBox.shrink())
                : IndexedStack(index: narrowIndex, children: [for (final tab in tabs) tab.screen]),
          ),
        ],
      ),
      bottomNavigationBar: destinationCount < 2
          ? null
          : NavigationBar(
              selectedIndex: pinnedIndex == -1 ? pinned.length : pinnedIndex,
              onDestinationSelected: (index) {
                if (index < pinned.length) {
                  _select(pinned[index].id);
                  setState(() => _narrowId = pinned[index].id);
                } else {
                  _openMoreOverview(tabs);
                }
              },
              destinations: [
                for (final tab in pinned) NavigationDestination(icon: Icon(tab.icon), label: tab.title),
                if (hasMore) const NavigationDestination(icon: Icon(Icons.more_horiz), label: 'Mehr'),
              ],
            ),
    );
  }
}

/// „Mehr“-Übersicht für die schmale Bottom-Bar — zeigt ALLE Einträge
/// gruppiert nach Sektion, exakt wie die breite Sidebar. Ein Tipp gibt
/// die ID zurück und schließt die Seite; die eigentliche Umschaltung
/// bleibt Sache von [_AppShellState].
class _MoreOverviewScreen extends StatelessWidget {
  const _MoreOverviewScreen({required this.tabs, required this.currentId});
  final List<ShellTab> tabs;
  final Object? currentId;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    ShellSection? lastSection;
    for (final tab in tabs) {
      if (tab.section != lastSection) {
        final header = _sectionHeaderFor(tab.section);
        if (header != null) children.add(header);
        lastSection = tab.section;
      }
      children.add(
        ListTile(
          leading: Icon(tab.icon),
          title: Text(tab.title),
          selected: tab.id == currentId,
          onTap: () => Navigator.of(context).pop(tab.id),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Mehr')),
      body: ListView(children: children),
    );
  }
}

/// Sidebar-Layout für breite Fenster, gruppiert nach [ShellSection].
class _WideShell extends StatelessWidget {
  const _WideShell({
    required this.companyName,
    required this.companyCaption,
    required this.currentId,
    required this.tabsNotifier,
    required this.contentNavKey,
    required this.onSelect,
    required this.onSwitchCompany,
    required this.tabs,
    required this.actions,
    required this.banner,
    required this.emptyBody,
  });

  final String companyName;
  final String? companyCaption;
  final ValueNotifier<Object?> currentId;
  final ValueNotifier<List<ShellTab>> tabsNotifier;
  final GlobalKey<NavigatorState> contentNavKey;
  final ValueChanged<Object> onSelect;
  final VoidCallback onSwitchCompany;
  final List<Widget> actions;
  final Widget? banner;
  final Widget? emptyBody;

  /// Für die Sidebar: die ist Teil des normalen Widget-Baums und wird bei
  /// jedem Rebuild neu gebaut — ein einfacher Parameter reicht (im
  /// Gegensatz zum Inhaltsbereich, siehe [tabsNotifier]).
  final List<ShellTab> tabs;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark ? AppColors.slate700 : AppColors.slate200;
    final caption = companyCaption == null ? companyName : '$companyName · $companyCaption';

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
                    decoration: BoxDecoration(
                      border: Border(bottom: BorderSide(color: borderColor)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(color: AppColors.indigo, borderRadius: BorderRadius.circular(8)),
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
                                    TextSpan(
                                      text: 'ERP',
                                      style: TextStyle(color: AppColors.indigo),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                caption,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 11, color: isDark ? AppColors.slate500 : AppColors.slate400),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ValueListenableBuilder<Object?>(
                      valueListenable: currentId,
                      builder: (context, current, _) {
                        final children = <Widget>[];
                        ShellSection? lastSection;
                        for (final tab in tabs) {
                          if (tab.section != lastSection) {
                            final header = _sectionHeaderFor(tab.section);
                            if (header != null) children.add(header);
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
                      onTap: onSwitchCompany,
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
                  padding: const EdgeInsets.only(left: 24, right: 8),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: borderColor)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: ValueListenableBuilder<Object?>(
                          valueListenable: currentId,
                          builder: (context, current, _) {
                            final tab = tabs.where((t) => t.id == current).firstOrNull ?? tabs.firstOrNull;
                            return Text(
                              tab?.title ?? '',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                            );
                          },
                        ),
                      ),
                      ...actions,
                    ],
                  ),
                ),
                ?banner,
                Expanded(
                  child: tabs.isEmpty
                      ? (emptyBody ?? const SizedBox.shrink())
                      // Eigener, verschachtelter Navigator statt direktem
                      // IndexedStack: Navigator.of(context) aus den
                      // Bereichen findet diesen hier zuerst und pusht
                      // INNERHALB des Inhaltsbereichs statt über die ganze
                      // App inkl. Sidebar (siehe Klassendoc von [AppShell]).
                      // Eigener ScaffoldMessenger: Hinweise aus einer hier
                      // geöffneten Seite erscheinen über deren Knopfleiste,
                      // statt sie im Fenster-Scaffold zu verdecken.
                      : ScaffoldMessenger(
                          child: Navigator(
                            key: contentNavKey,
                            onGenerateRoute: (settings) => MaterialPageRoute(
                              settings: settings,
                              builder: (context) => ListenableBuilder(
                                // Auf BEIDE hören: ein neu aktiviertes Modul
                                // ändert die Liste selbst, nicht nur die Auswahl.
                                listenable: Listenable.merge([tabsNotifier, currentId]),
                                builder: (context, _) {
                                  final currentTabs = tabsNotifier.value;
                                  final index = currentTabs.indexWhere((t) => t.id == currentId.value);
                                  return IndexedStack(
                                    index: index < 0 ? 0 : index,
                                    children: [for (final tab in currentTabs) tab.screen],
                                  );
                                },
                              ),
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
