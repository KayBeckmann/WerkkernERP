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
/// bleibt die Bottom-Navigation die richtige Wahl; auf breiteren
/// Fenstern (Kays Web-/LAN-Vorschau, Desktop-Browser) übernimmt eine
/// gruppierte Sidebar das Layout-Muster von RechnungsFee (Sektionen,
/// Indigo-Akzent, kompakte Zeilen) — eigenständig in Flutter nachgebaut,
/// kein Code/Asset von dort.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

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
        selectedIndex: _index,
        onSelect: (i) => setState(() => _index = i),
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
    required this.onSelect,
    required this.titles,
    required this.screens,
    required this.icons,
  });

  final String companyName;
  final int selectedIndex;
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
                    child: ListView(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      children: [
                        const SectionLabel('Fakturierung'),
                        SidebarNavItem(
                          icon: icons[0],
                          label: titles[0],
                          selected: selectedIndex == 0,
                          onTap: () => onSelect(0),
                        ),
                        const SectionLabel('Stammdaten'),
                        for (var i = 1; i <= 3; i++)
                          SidebarNavItem(
                            icon: icons[i],
                            label: titles[i],
                            selected: selectedIndex == i,
                            onTap: () => onSelect(i),
                          ),
                        const Divider(height: 24),
                        SidebarNavItem(
                          icon: icons[4],
                          label: titles[4],
                          selected: selectedIndex == 4,
                          onTap: () => onSelect(4),
                        ),
                      ],
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
                  child: Text(
                    titles[selectedIndex],
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
                Expanded(child: IndexedStack(index: selectedIndex, children: screens)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
