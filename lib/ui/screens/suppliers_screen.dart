import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/database/database.dart';
import '../../data/repositories/supplier_repository.dart';
import '../../domain/services/active_company_service.dart';

/// Lieferantenliste der aktiven Firma (A1).
class SuppliersScreen extends StatefulWidget {
  const SuppliersScreen({super.key});

  @override
  State<SuppliersScreen> createState() => _SuppliersScreenState();
}

class _SuppliersScreenState extends State<SuppliersScreen> {
  late Future<List<Supplier>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Supplier>> _load() {
    final companyId = context.read<ActiveCompanyService>().active!.id;
    return context.read<SupplierRepository>().listForCompany(companyId);
  }

  void _reload() => setState(() => _future = _load());

  Future<void> _create() async {
    final name = await showDialog<String>(
      context: context,
      builder: (context) => const _NewSupplierDialog(),
    );
    if (name == null || name.trim().isEmpty || !mounted) return;
    final companyId = context.read<ActiveCompanyService>().active!.id;
    await context.read<SupplierRepository>().create(companyId: companyId, name: name.trim());
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<List<Supplier>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final suppliers = snapshot.data!;
          if (suppliers.isEmpty) {
            return const Center(child: Text('Noch keine Lieferanten angelegt.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
            itemCount: suppliers.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) => Card(
              child: ListTile(
                leading: const Icon(Icons.local_shipping_outlined),
                title: Text(suppliers[index].name),
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'suppliers-fab',
        onPressed: _create,
        icon: const Icon(Icons.add),
        label: const Text('Lieferant anlegen'),
      ),
    );
  }
}

class _NewSupplierDialog extends StatefulWidget {
  const _NewSupplierDialog();

  @override
  State<_NewSupplierDialog> createState() => _NewSupplierDialogState();
}

class _NewSupplierDialogState extends State<_NewSupplierDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Neuer Lieferant'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(labelText: 'Name'),
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
