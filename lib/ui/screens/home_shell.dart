import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/services/active_company_service.dart';
import 'company_switcher_screen.dart';

/// Navigationsrahmen innerhalb einer gewählten Firma. Liste/Detail-Logik
/// pro Modul (Kunden, Rechnungen, ...) kommt mit A1/A2 — hier zunächst
/// der Firmenkontext samt Wechsel-Aktion (A0-Abnahme).
class HomeShell extends StatelessWidget {
  const HomeShell({super.key});

  @override
  Widget build(BuildContext context) {
    final service = context.watch<ActiveCompanyService>();
    final company = service.active;

    if (company == null) {
      return const CompanySwitcherScreen();
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(company.name),
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
      body: Center(
        child: Text(
          'Firma „${company.name}" ist aktiv.\n'
          'Kunden/Rechnungen folgen mit A1/A2.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
    );
  }
}
