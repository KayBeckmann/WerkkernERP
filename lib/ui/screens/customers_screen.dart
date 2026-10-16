import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/database/database.dart';
import '../../data/repositories/customer_repository.dart';
import '../../domain/services/active_company_service.dart';

/// Kundenliste der aktiven Firma (A1) — Liste → Formular, mobil-tauglich
/// statt Desktop-Dreispaltenlayout. Seit Kay-Nachtrag 2026-10-16: Tippen
/// auf einen Kunden öffnet dasselbe Formular zum Bearbeiten (vorher nur
/// Anlegen möglich), plus erweiterte Datenfelder (USt-IdNr.,
/// Ansprechpartner, Notizen).
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

  void _reload() => setState(() {
        _future = _load();
      });

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
          vatId: result.vatId,
          contactPerson: result.contactPerson,
          notes: result.notes,
        );
    _reload();
  }

  Future<void> _edit(Customer customer) async {
    final result = await showDialog<_CustomerFormResult>(
      context: context,
      builder: (context) => _CustomerFormDialog(existing: customer),
    );
    if (result == null || !mounted) return;
    final companyId = context.read<ActiveCompanyService>().active!.id;
    await context.read<CustomerRepository>().update(
          companyId: companyId,
          customer: customer.copyWith(
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
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _edit(customer),
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
  const _CustomerFormResult({
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

class _CustomerFormDialog extends StatefulWidget {
  const _CustomerFormDialog({this.existing});

  /// `null` = neuer Kunde; sonst Bearbeiten mit vorausgefüllten Feldern.
  final Customer? existing;

  @override
  State<_CustomerFormDialog> createState() => _CustomerFormDialogState();
}

class _CustomerFormDialogState extends State<_CustomerFormDialog> {
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
      title: Text(_isEdit ? 'Kunde bearbeiten' : 'Neuer Kunde'),
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
              _CustomerFormResult(
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
