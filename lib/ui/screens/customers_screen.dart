import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/database/database.dart';
import '../../data/repositories/customer_repository.dart';
import '../../domain/services/active_company_service.dart';

/// Kundenliste der aktiven Firma (A1) — Liste → Formular, mobil-tauglich
/// statt Desktop-Dreispaltenlayout.
class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});

  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  late Future<List<Customer>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Customer>> _load() {
    final companyId = context.read<ActiveCompanyService>().active!.id;
    return context.read<CustomerRepository>().listForCompany(companyId);
  }

  void _reload() => setState(() { _future = _load(); });

  Future<void> _create() async {
    final result = await showDialog<_CustomerFormResult>(
      context: context,
      builder: (context) => const _CustomerFormDialog(),
    );
    if (result == null || !mounted) return;
    final companyId = context.read<ActiveCompanyService>().active!.id;
    await context.read<CustomerRepository>().create(
          companyId: companyId,
          name: result.name,
          address: result.address,
          email: result.email,
          phone: result.phone,
        );
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<List<Customer>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final customers = snapshot.data!;
          if (customers.isEmpty) {
            return const Center(child: Text('Noch keine Kunden angelegt.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
            itemCount: customers.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final customer = customers[index];
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: Text(customer.name),
                  subtitle: customer.address != null ? Text(customer.address!) : null,
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'customers-fab',
        onPressed: _create,
        icon: const Icon(Icons.add),
        label: const Text('Kunde anlegen'),
      ),
    );
  }
}

class _CustomerFormResult {
  const _CustomerFormResult({required this.name, this.address, this.email, this.phone});
  final String name;
  final String? address;
  final String? email;
  final String? phone;
}

class _CustomerFormDialog extends StatefulWidget {
  const _CustomerFormDialog();

  @override
  State<_CustomerFormDialog> createState() => _CustomerFormDialogState();
}

class _CustomerFormDialogState extends State<_CustomerFormDialog> {
  final _nameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Neuer Kunde'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameCtrl,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Name *'),
            ),
            TextField(
              controller: _addressCtrl,
              decoration: const InputDecoration(labelText: 'Anschrift'),
              maxLines: 2,
            ),
            TextField(
              controller: _emailCtrl,
              decoration: const InputDecoration(labelText: 'E-Mail'),
            ),
            TextField(
              controller: _phoneCtrl,
              decoration: const InputDecoration(labelText: 'Telefon'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
        FilledButton(
          onPressed: () {
            if (_nameCtrl.text.trim().isEmpty) return;
            Navigator.pop(
              context,
              _CustomerFormResult(
                name: _nameCtrl.text.trim(),
                address: _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
                email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
                phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
              ),
            );
          },
          child: const Text('Anlegen'),
        ),
      ],
    );
  }
}
