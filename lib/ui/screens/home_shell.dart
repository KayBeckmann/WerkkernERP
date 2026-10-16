import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/services/active_company_service.dart';
import 'articles_screen.dart';
import 'company_switcher_screen.dart';
import 'customers_screen.dart';
import 'invoices_screen.dart';
import 'suppliers_screen.dart';

/// Navigationsrahmen innerhalb einer gewählten Firma — Bottom-Navigation
/// statt des RechnungsFee-Desktop-Dreispaltenlayouts, passend für
/// Android-Smartphones (Roadmap A0 Punkt 4).
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
  ];

  static const _screens = [
    InvoicesScreen(),
    CustomersScreen(),
    ArticlesScreen(),
    SuppliersScreen(),
  ];

  static const _titles = ['Rechnungen', 'Kunden', 'Artikel', 'Lieferanten'];

  @override
  Widget build(BuildContext context) {
    final service = context.watch<ActiveCompanyService>();
    final company = service.active;

    if (company == null) {
      return const CompanySwitcherScreen();
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
