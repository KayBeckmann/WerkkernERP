import 'package:flutter/material.dart';
import 'package:werkkern_client/werkkern_client.dart';

import '../../../domain/services/online_session.dart';

/// Kunden der Online-Firma — Liste mit Suche, Anlegen/Bearbeiten nur
/// mit `customers.write`.
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

  Future<void> _edit([OnlineCustomer? existing]) async {
    final result = await showDialog<OnlineCustomer>(
      context: context,
      builder: (_) => OnlineCustomerDialog(existing: existing),
    );
    if (result == null || !mounted) return;
    try {
      if (existing == null) {
        await widget.session.client.createCustomer(result);
      } else {
        await widget.session.client.updateCustomer(result);
      }
      _reload();
    } on Exception catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(describeOnlineError(e))));
    }
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
                if (customers.isEmpty) return const Center(child: Text('Keine Kunden gefunden.'));
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
                          trailing: canWrite ? const Icon(Icons.edit_outlined) : null,
                          onTap: canWrite ? () => _edit(c) : null,
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
              onPressed: _edit,
              icon: const Icon(Icons.add),
              label: const Text('Kunde anlegen'),
            )
          : null,
    );
  }
}

class OnlineCustomerDialog extends StatefulWidget {
  const OnlineCustomerDialog({super.key, this.existing});
  final OnlineCustomer? existing;

  @override
  State<OnlineCustomerDialog> createState() => _OnlineCustomerDialogState();
}

class _OnlineCustomerDialogState extends State<OnlineCustomerDialog> {
  late final _name = TextEditingController(text: widget.existing?.name);
  late final _address = TextEditingController(text: widget.existing?.address);
  late final _email = TextEditingController(text: widget.existing?.email);
  late final _phone = TextEditingController(text: widget.existing?.phone);
  late final _vatId = TextEditingController(text: widget.existing?.vatId);
  late final _contact = TextEditingController(text: widget.existing?.contactPerson);
  late final _notes = TextEditingController(text: widget.existing?.notes);

  @override
  void dispose() {
    for (final c in [_name, _address, _email, _phone, _vatId, _contact, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _value(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'Neuer Kunde' : 'Kunde bearbeiten'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(key: const Key('online-customer-name'), controller: _name, decoration: const InputDecoration(labelText: 'Name *')),
              TextField(controller: _address, maxLines: 2, decoration: const InputDecoration(labelText: 'Anschrift')),
              TextField(controller: _contact, decoration: const InputDecoration(labelText: 'Ansprechpartner')),
              TextField(controller: _email, decoration: const InputDecoration(labelText: 'E-Mail')),
              TextField(controller: _phone, decoration: const InputDecoration(labelText: 'Telefon')),
              TextField(controller: _vatId, decoration: const InputDecoration(labelText: 'USt-IdNr.')),
              TextField(controller: _notes, maxLines: 2, decoration: const InputDecoration(labelText: 'Notizen')),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
        FilledButton(
          onPressed: () {
            if (_name.text.trim().isEmpty) return;
            Navigator.pop(
              context,
              OnlineCustomer(
                id: widget.existing?.id ?? '',
                name: _name.text.trim(),
                address: _value(_address),
                email: _value(_email),
                phone: _value(_phone),
                vatId: _value(_vatId),
                contactPerson: _value(_contact),
                notes: _value(_notes),
              ),
            );
          },
          child: const Text('Speichern'),
        ),
      ],
    );
  }
}
