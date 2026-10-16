import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/database/database.dart';
import '../../data/repositories/supplier_repository.dart';
import '../../domain/services/active_company_service.dart';

/// Lieferantenliste der aktiven Firma (A1). Seit Kay-Nachtrag 2026-10-16:
/// Tippen auf einen Lieferanten öffnet dasselbe Formular zum Bearbeiten
/// (vorher nur Anlegen mit reinem Namensfeld möglich), plus erweiterte
/// Datenfelder (Anschrift, Kontakt, USt-IdNr., Notizen) analog zu
/// `CustomersScreen`.
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

  void _reload() => setState(() {
        _future = _load();
      });

  Future<void> _create() async {
    final result = await showDialog<_SupplierFormResult>(
      context: context,
      builder: (context) => const _SupplierFormDialog(),
    );
    if (result == null || !mounted) return;
    final companyId = context.read<ActiveCompanyService>().active!.id;
    await context.read<SupplierRepository>().create(
          companyId: companyId,
          name: result.name,
          address: result.address,
          email: result.email,
          phone: result.phone,
          vatId: result.vatId,
          contactPerson: result.contactPerson,
          notes: result.notes,
        );
    _reload();
  }

  Future<void> _edit(Supplier supplier) async {
    final result = await showDialog<_SupplierFormResult>(
      context: context,
      builder: (context) => _SupplierFormDialog(existing: supplier),
    );
    if (result == null || !mounted) return;
    final companyId = context.read<ActiveCompanyService>().active!.id;
    await context.read<SupplierRepository>().update(
          companyId: companyId,
          supplier: supplier.copyWith(
            name: result.name,
            address: Value(result.address),
            email: Value(result.email),
            phone: Value(result.phone),
            vatId: Value(result.vatId),
            contactPerson: Value(result.contactPerson),
            notes: Value(result.notes),
          ),
        );
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
            itemBuilder: (context, index) {
              final supplier = suppliers[index];
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.local_shipping_outlined),
                  title: Text(supplier.name),
                  subtitle: supplier.address != null ? Text(supplier.address!) : null,
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _edit(supplier),
                ),
              );
            },
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

class _SupplierFormResult {
  const _SupplierFormResult({
    required this.name,
    this.address,
    this.email,
    this.phone,
    this.vatId,
    this.contactPerson,
    this.notes,
  });
  final String name;
  final String? address;
  final String? email;
  final String? phone;
  final String? vatId;
  final String? contactPerson;
  final String? notes;
}

class _SupplierFormDialog extends StatefulWidget {
  const _SupplierFormDialog({this.existing});

  /// `null` = neuer Lieferant; sonst Bearbeiten mit vorausgefüllten Feldern.
  final Supplier? existing;

  @override
  State<_SupplierFormDialog> createState() => _SupplierFormDialogState();
}

class _SupplierFormDialogState extends State<_SupplierFormDialog> {
  late final _nameCtrl = TextEditingController(text: widget.existing?.name);
  late final _addressCtrl = TextEditingController(text: widget.existing?.address);
  late final _emailCtrl = TextEditingController(text: widget.existing?.email);
  late final _phoneCtrl = TextEditingController(text: widget.existing?.phone);
  late final _vatIdCtrl = TextEditingController(text: widget.existing?.vatId);
  late final _contactPersonCtrl = TextEditingController(text: widget.existing?.contactPerson);
  late final _notesCtrl = TextEditingController(text: widget.existing?.notes);

  bool get _isEdit => widget.existing != null;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _vatIdCtrl.dispose();
    _contactPersonCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEdit ? 'Lieferant bearbeiten' : 'Neuer Lieferant'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nameCtrl,
                autofocus: !_isEdit,
                decoration: const InputDecoration(labelText: 'Name *'),
              ),
              TextField(
                controller: _addressCtrl,
                decoration: const InputDecoration(labelText: 'Anschrift'),
                maxLines: 2,
              ),
              TextField(
                controller: _contactPersonCtrl,
                decoration: const InputDecoration(labelText: 'Ansprechpartner'),
              ),
              TextField(
                controller: _emailCtrl,
                decoration: const InputDecoration(labelText: 'E-Mail'),
              ),
              TextField(
                controller: _phoneCtrl,
                decoration: const InputDecoration(labelText: 'Telefon'),
              ),
              TextField(
                controller: _vatIdCtrl,
                decoration: const InputDecoration(labelText: 'USt-IdNr.'),
              ),
              TextField(
                controller: _notesCtrl,
                decoration: const InputDecoration(labelText: 'Notizen'),
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
        FilledButton(
          onPressed: () {
            if (_nameCtrl.text.trim().isEmpty) return;
            Navigator.pop(
              context,
              _SupplierFormResult(
                name: _nameCtrl.text.trim(),
                address: _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
                email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
                phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
                vatId: _vatIdCtrl.text.trim().isEmpty ? null : _vatIdCtrl.text.trim(),
                contactPerson:
                    _contactPersonCtrl.text.trim().isEmpty ? null : _contactPersonCtrl.text.trim(),
                notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
              ),
            );
          },
          child: Text(_isEdit ? 'Speichern' : 'Anlegen'),
        ),
      ],
    );
  }
}
