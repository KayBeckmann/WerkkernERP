import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/services/active_company_service.dart';
import '../theme/app_theme.dart';
import '../widgets/section_label.dart';
import '../widgets/sidebar_nav_item.dart';
import 'articles_screen.dart';
import 'backup_screen.dart';
import 'company_switcher_screen.dart';
import 'customers_screen.dart';
import 'invoices_screen.dart';
import 'suppliers_screen.dart';

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
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  final _wideIndex = ValueNotifier<int>(0);
  final _contentNavKey = GlobalKey<NavigatorState>();

  static const _destinations = [
    NavigationDestination(icon: Icon(Icons.receipt_long_outlined), label: 'Rechnungen'),
    NavigationDestination(icon: Icon(Icons.group_outlined), label: 'Kunden'),
    NavigationDestination(icon: Icon(Icons.inventory_2_outlined), label: 'Artikel'),
    NavigationDestination(icon: Icon(Icons.local_shipping_outlined), label: 'Lieferanten'),
    NavigationDestination(icon: Icon(Icons.settings_outlined), label: 'Einstellungen'),
  ];

  static const _sidebarIcons = [
    Icons.receipt_long_outlined,
    Icons.group_outlined,
    Icons.inventory_2_outlined,
    Icons.local_shipping_outlined,
    Icons.settings_outlined,
  ];

  static const _screens = [
    InvoicesScreen(),
    CustomersScreen(),
    ArticlesScreen(),
    SuppliersScreen(),
    BackupScreen(),
  ];

  static const _titles = ['Rechnungen', 'Kunden', 'Artikel', 'Lieferanten', 'Einstellungen'];

  @override
  void dispose() {
    _wideIndex.dispose();
    super.dispose();
  }

  void _selectWide(int i) {
    // Beim Tab-Wechsel zuerst zurück auf die Liste springen, falls z.B.
    // gerade eine Rechnung im Inhaltsbereich geöffnet ist — sonst bliebe
    // der alte Push-Stack unter dem neuen Tab-Inhalt "verborgen" stehen.
    _contentNavKey.currentState?.popUntil((route) => route.isFirst);
    _wideIndex.value = i;
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<ActiveCompanyService>();
    final company = service.active;

    if (company == null) {
      return const CompanySwitcherScreen();
    }

    final isWide = MediaQuery.sizeOf(context).width >= AppMetrics.wideLayoutBreakpoint;

    if (isWide) {
      return _WideShell(
        companyName: company.name,
        selectedIndex: _wideIndex,
        contentNavKey: _contentNavKey,
        onSelect: _selectWide,
        titles: _titles,
        screens: _screens,
        icons: _sidebarIcons,
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('${company.name} — ${_titles[_index]}'),
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
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (index) => setState(() => _index = index),
        destinations: _destinations,
      ),
    );
  }
}

/// Sidebar-Layout für breite Fenster. Zwei Gruppen ("Fakturierung",
/// "Stammdaten") plus ein alleinstehender "Einstellungen"-Eintrag unten
/// — dieselbe grobe Gliederung wie RechnungsFees Sidebar, aber nur mit
/// den Modulen, die WerkkernERP aktuell tatsächlich hat (A0–A4; weitere
/// Module/Sektionen kommen erst mit A5/Phase C).
class _WideShell extends StatelessWidget {
  const _WideShell({
    required this.companyName,
    required this.selectedIndex,
    required this.contentNavKey,
    required this.onSelect,
    required this.titles,
    required this.screens,
    required this.icons,
  });

  final String companyName;
  final ValueNotifier<int> selectedIndex;
  final GlobalKey<NavigatorState> contentNavKey;
  final ValueChanged<int> onSelect;
  final List<String> titles;
  final List<Widget> screens;
  final List<IconData> icons;

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
                    child: ValueListenableBuilder<int>(
                      valueListenable: selectedIndex,
                      builder: (context, current, _) => ListView(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        children: [
                          const SectionLabel('Fakturierung'),
                          SidebarNavItem(
                            icon: icons[0],
                            label: titles[0],
                            selected: current == 0,
                            onTap: () => onSelect(0),
                          ),
                          const SectionLabel('Stammdaten'),
                          for (var i = 1; i <= 3; i++)
                            SidebarNavItem(
                              icon: icons[i],
                              label: titles[i],
                              selected: current == i,
                              onTap: () => onSelect(i),
                            ),
                          const Divider(height: 24),
                          SidebarNavItem(
                            icon: icons[4],
                            label: titles[4],
                            selected: current == 4,
                            onTap: () => onSelect(4),
                          ),
                        ],
                      ),
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
                  child: ValueListenableBuilder<int>(
                    valueListenable: selectedIndex,
                    builder: (context, current, _) => Text(
                      titles[current],
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
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
                      builder: (context) => ValueListenableBuilder<int>(
                        valueListenable: selectedIndex,
                        builder: (context, current, _) =>
                            IndexedStack(index: current, children: screens),
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
