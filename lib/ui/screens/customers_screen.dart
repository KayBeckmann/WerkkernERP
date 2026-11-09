import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/database/database.dart';
import '../../data/repositories/customer_repository.dart';
import '../../domain/services/active_company_service.dart';
import '../widgets/customer_contacts.dart';

/// Kundenliste der aktiven Firma (A1) — Liste → Detailansicht → Formular,
/// mobil-tauglich statt Desktop-Dreispaltenlayout. Seit Kay 2026-11-09:
/// mehrere Kontaktpersonen, Rechnungs-E-Mail und Anrufen per Tippen auf
/// die Telefonnummer.
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
    final result = await showDialog<CustomerFormResult>(
      context: context,
      builder: (context) => const CustomerFormDialog(),
    );
    if (result == null || !mounted) return;
    final companyId = context.read<ActiveCompanyService>().active!.id;
    final contactRepository = context.read<CustomerContactRepository>();
    final customer = await context.read<CustomerRepository>().create(
          companyId: companyId,
          name: result.name,
          address: result.address,
          email: result.email,
          phone: result.phone,
          vatId: result.vatId,
          notes: result.notes,
          invoiceEmail: result.invoiceEmail,
        );
    await contactRepository.replaceForCustomer(
      companyId: companyId,
      customerId: customer.id,
      contacts: [for (final c in result.contacts) _input(c)],
    );
    _reload();
  }

  static ContactInput _input(ContactData c) => (id: c.id, name: c.name, role: c.role, email: c.email, phone: c.phone);

  static ContactData _data(CustomerContact c) =>
      ContactData(id: c.id, name: c.name, role: c.role, email: c.email, phone: c.phone);

  Future<CustomerFormResult> _formData(Customer customer) async {
    final contacts = await context
        .read<CustomerContactRepository>()
        .listForCustomer(companyId: customer.companyId, customerId: customer.id);
    return CustomerFormResult(
      name: customer.name,
      address: customer.address,
      email: customer.email,
      invoiceEmail: customer.invoiceEmail,
      phone: customer.phone,
      vatId: customer.vatId,
      notes: customer.notes,
      contacts: [for (final c in contacts) _data(c)],
    );
  }

  /// Speichert das Formular; liefert den neuen Stand für die Detailansicht.
  Future<CustomerFormResult?> _edit(Customer customer, CustomerFormResult current) async {
    final result = await showDialog<CustomerFormResult>(
      context: context,
      builder: (context) => CustomerFormDialog(existing: current),
    );
    if (result == null || !mounted) return null;
    final companyId = context.read<ActiveCompanyService>().active!.id;
    final contactRepository = context.read<CustomerContactRepository>();
    final customerRepository = context.read<CustomerRepository>();
    final latest = await customerRepository.findById(companyId: companyId, id: customer.id) ?? customer;
    await customerRepository.update(
      companyId: companyId,
      customer: latest.copyWith(
        name: result.name,
        address: Value(result.address),
        email: Value(result.email),
        phone: Value(result.phone),
        vatId: Value(result.vatId),
        notes: Value(result.notes),
        invoiceEmail: Value(result.invoiceEmail),
      ),
    );
    final contacts = await contactRepository.replaceForCustomer(
      companyId: companyId,
      customerId: customer.id,
      contacts: [for (final c in result.contacts) _input(c)],
    );
    _reload();
    return CustomerFormResult(
      name: result.name,
      address: result.address,
      email: result.email,
      invoiceEmail: result.invoiceEmail,
      phone: result.phone,
      vatId: result.vatId,
      notes: result.notes,
      contacts: [for (final c in contacts) _data(c)],
    );
  }

  Future<void> _open(Customer customer) async {
    final data = await _formData(customer);
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CustomerDetailPage(customer: data, onEdit: (current) => _edit(customer, current)),
      ),
    );
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
                  trailing: customer.phone == null
                      ? const Icon(Icons.chevron_right)
                      : IconButton(
                          tooltip: '${customer.name} anrufen',
                          icon: const Icon(Icons.call),
                          onPressed: () => callPhone(context, customer.phone!),
                        ),
                  onTap: () => _open(customer),
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
