import 'package:flutter/material.dart';
import 'package:werkkern_client/werkkern_client.dart';

import '../../../domain/services/online_session.dart';
import '../../widgets/customer_contacts.dart';

/// Kunden der Online-Firma — Liste mit Suche und Detailansicht
/// (Kontaktpersonen, Anrufen); Anlegen/Bearbeiten nur mit `customers.write`.
class OnlineCustomersScreen extends StatefulWidget {
  const OnlineCustomersScreen({super.key, required this.session});
  final OnlineSession session;

  @override
  State<OnlineCustomersScreen> createState() => _OnlineCustomersScreenState();
}

class _OnlineCustomersScreenState extends State<OnlineCustomersScreen> {
  late Future<List<OnlineCustomer>> _future;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<OnlineCustomer>> _load() => widget.session.client.customers(query: _query);

  void _reload() => setState(() {
        _future = _load();
      });

  static CustomerFormResult _form(OnlineCustomer c) => CustomerFormResult(
        name: c.name,
        address: c.address,
        email: c.email,
        invoiceEmail: c.invoiceEmail,
        phone: c.phone,
        vatId: c.vatId,
        notes: c.notes,
        contacts: [
          for (final x in c.contacts) ContactData(id: x.id, name: x.name, role: x.role, email: x.email, phone: x.phone),
        ],
      );

  static OnlineCustomer _customer(String id, CustomerFormResult r) => OnlineCustomer(
        id: id,
        name: r.name,
        address: r.address,
        email: r.email,
        phone: r.phone,
        vatId: r.vatId,
        notes: r.notes,
        invoiceEmail: r.invoiceEmail,
        contacts: [
          for (final x in r.contacts) OnlineContact(id: x.id, name: x.name, role: x.role, email: x.email, phone: x.phone),
        ],
      );

  /// Formular öffnen und speichern; liefert den gespeicherten Stand.
  Future<OnlineCustomer?> _save([OnlineCustomer? existing]) async {
    final result = await showDialog<CustomerFormResult>(
      context: context,
      builder: (_) => CustomerFormDialog(
        existing: existing == null ? null : _form(existing),
        nameKey: const Key('online-customer-name'),
      ),
    );
    if (result == null || !mounted) return null;
    try {
      final saved = existing == null
          ? await widget.session.client.createCustomer(_customer('', result))
          : await widget.session.client.updateCustomer(_customer(existing.id, result));
      _reload();
      return saved;
    } on Exception catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(describeOnlineError(e))));
      return null;
    }
  }

  Future<void> _open(OnlineCustomer customer) async {
    var current = customer;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CustomerDetailPage(
          customer: _form(customer),
          onEdit: widget.session.can('customers.write')
              ? (_) async {
                  final saved = await _save(current);
                  if (saved == null) return null;
                  current = saved;
                  return _form(saved);
                }
              : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canWrite = widget.session.can('customers.write');
    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: TextField(
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Kunden suchen'),
              onSubmitted: (value) {
                _query = value.trim();
                _reload();
              },
            ),
          ),
          Expanded(
            child: FutureBuilder<List<OnlineCustomer>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.hasError) return Center(child: Text(describeOnlineError(snapshot.error!)));
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                final customers = snapshot.data!;
                if (customers.isEmpty) {
                  return Center(child: Text(_query.isEmpty ? 'Noch keine Kunden angelegt.' : 'Keine Kunden gefunden.'));
                }
                return RefreshIndicator(
                  onRefresh: () async => _reload(),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
                    itemCount: customers.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final c = customers[index];
                      return Card(
                        child: ListTile(
                          leading: const Icon(Icons.person_outline),
                          title: Text(c.name),
                          subtitle: c.address != null ? Text(c.address!) : null,
                          trailing: c.phone == null
                              ? const Icon(Icons.chevron_right)
                              : IconButton(
                                  tooltip: '${c.name} anrufen',
                                  icon: const Icon(Icons.call),
                                  onPressed: () => callPhone(context, c.phone!),
                                ),
                          onTap: () => _open(c),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: canWrite
          ? FloatingActionButton.extended(
              heroTag: 'online-customers-fab',
              onPressed: _save,
              icon: const Icon(Icons.add),
              label: const Text('Kunde anlegen'),
            )
          : null,
    );
  }
}
