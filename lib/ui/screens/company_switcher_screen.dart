import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/database/database.dart';
import '../../domain/services/active_company_service.dart';
import 'home_shell.dart';

/// Firmenauswahl/-anlage — der Einstiegspunkt der App (A0). Keine
/// Anmeldung, kein Server: eine Liste lokal geführter Firmen zum
/// Anlegen/Wechseln.
class CompanySwitcherScreen extends StatefulWidget {
  const CompanySwitcherScreen({super.key});

  @override
  State<CompanySwitcherScreen> createState() => _CompanySwitcherScreenState();
}

class _CompanySwitcherScreenState extends State<CompanySwitcherScreen> {
  @override
  void initState() {
    super.initState();
    context.read<ActiveCompanyService>().loadCompanies();
  }

  Future<void> _createCompany() async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) => const _NewCompanyDialog(),
    );
    if (name == null || name.trim().isEmpty || !mounted) return;
    final service = context.read<ActiveCompanyService>();
    await service.createCompany(name: name.trim());
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomeShell()),
    );
  }

  void _openCompany(ActiveCompanyService service, Company company) {
    service.select(company);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomeShell()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<ActiveCompanyService>();
    return Scaffold(
      appBar: AppBar(title: const Text('WerkkernERP — Firmen')),
      body: service.companies.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Noch keine Firma angelegt. Lege deine erste Firma an, um Kunden und '
                  'Rechnungen zu verwalten — vollständig offline, ohne Server oder Konto.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView.separated(
              itemCount: service.companies.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final company = service.companies[index];
                return ListTile(
                  leading: const Icon(Icons.business_outlined),
                  title: Text(company.name),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _openCompany(service, company),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'company-switcher-fab',
        onPressed: _createCompany,
        icon: const Icon(Icons.add),
        label: const Text('Firma anlegen'),
      ),
    );
  }
}

class _NewCompanyDialog extends StatefulWidget {
  const _NewCompanyDialog();

  @override
  State<_NewCompanyDialog> createState() => _NewCompanyDialogState();
}

class _NewCompanyDialogState extends State<_NewCompanyDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Neue Firma'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(labelText: 'Firmenname'),
        onSubmitted: (value) => Navigator.pop(context, value),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          child: const Text('Anlegen'),
        ),
      ],
    );
  }
}
