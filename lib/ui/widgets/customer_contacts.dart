import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'section_label.dart';

/// Kontaktperson als reine Anzeige-/Eingabedaten — gemeinsam für den
/// Offline-Modus (Drift) und den Online-Modus (Server). Kay 2026-11-09:
/// mehrere Kontaktpersonen je Kunde, z. B. Vincent → Betriebstechniker,
/// Annika → Buchhaltung.
class ContactData {
  const ContactData({this.id, required this.name, this.role, this.email, this.phone});

  /// `null` = neu, noch nicht gespeichert.
  final String? id;
  final String name;

  /// Funktion beim Kunden, z. B. „Buchhaltung“.
  final String? role;
  final String? email;
  final String? phone;

  /// „Vincent (Betriebstechniker)“
  String get label => role == null ? name : '$name ($role)';
}

/// Kundenstammdaten aus dem Formular bzw. für die Detailansicht.
class CustomerFormResult {
  const CustomerFormResult({
    required this.name,
    this.address,
    this.email,
    this.invoiceEmail,
    this.phone,
    this.vatId,
    this.notes,
    this.contacts = const [],
  });
  final String name;
  final String? address;

  /// Allgemeine E-Mail des Kunden — letzter Fallback beim Versand.
  final String? email;

  /// Vorrangige Adresse für Rechnungen, Gutschriften, Proforma und Mahnungen.
  final String? invoiceEmail;
  final String? phone;
  final String? vatId;
  final String? notes;
  final List<ContactData> contacts;
}

/// Startet den Telefon-Wähler; in Tests ersetzbar.
Future<bool> Function(Uri uri) phoneLauncher = launchUrl;

/// Ruft [number] an (Android: Wähler mit vorausgefüllter Nummer).
Future<void> callPhone(BuildContext context, String number) async {
  final digits = number.replaceAll(RegExp(r'[^0-9+]'), '');
  var started = false;
  if (digits.isNotEmpty) {
    try {
      started = await phoneLauncher(Uri(scheme: 'tel', path: digits));
    } on Exception {
      started = false;
    }
  }
  if (!started && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Anruf an $number konnte nicht gestartet werden.')));
  }
}

String? _trimmedOrNull(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();

/// Formular für Kunde inkl. Rechnungs-E-Mail und Kontaktpersonen —
/// offline und online gleich.
class CustomerFormDialog extends StatefulWidget {
  const CustomerFormDialog({super.key, this.existing, this.nameKey});

  /// `null` = neuer Kunde.
  final CustomerFormResult? existing;

  /// Optionaler Key des Namensfelds (bestehende Tests).
  final Key? nameKey;

  @override
  State<CustomerFormDialog> createState() => _CustomerFormDialogState();
}

class _CustomerFormDialogState extends State<CustomerFormDialog> {
  late final _name = TextEditingController(text: widget.existing?.name);
  late final _address = TextEditingController(text: widget.existing?.address);
  late final _email = TextEditingController(text: widget.existing?.email);
  late final _invoiceEmail = TextEditingController(text: widget.existing?.invoiceEmail);
  late final _phone = TextEditingController(text: widget.existing?.phone);
  late final _vatId = TextEditingController(text: widget.existing?.vatId);
  late final _notes = TextEditingController(text: widget.existing?.notes);
  late final List<ContactData> _contacts = [...?widget.existing?.contacts];
  String? _error;

  bool get _isEdit => widget.existing != null;

  @override
  void dispose() {
    for (final c in [_name, _address, _email, _invoiceEmail, _phone, _vatId, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _editContact([int? index]) async {
    final result = await showDialog<ContactData>(
      context: context,
      builder: (_) => ContactFormDialog(existing: index == null ? null : _contacts[index]),
    );
    if (result == null || !mounted) return;
    setState(() => index == null ? _contacts.add(result) : _contacts[index] = result);
  }

  void _submit() {
    if (_name.text.trim().isEmpty) return;
    final invoiceEmail = _trimmedOrNull(_invoiceEmail);
    if (invoiceEmail != null && !invoiceEmail.contains('@')) {
      setState(() => _error = 'Die Rechnungs-E-Mail ist keine E-Mail-Adresse.');
      return;
    }
    Navigator.pop(
      context,
      CustomerFormResult(
        name: _name.text.trim(),
        address: _trimmedOrNull(_address),
        email: _trimmedOrNull(_email),
        invoiceEmail: invoiceEmail,
        phone: _trimmedOrNull(_phone),
        vatId: _trimmedOrNull(_vatId),
        notes: _trimmedOrNull(_notes),
        contacts: _contacts,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEdit ? 'Kunde bearbeiten' : 'Neuer Kunde'),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                key: widget.nameKey,
                controller: _name,
                autofocus: !_isEdit,
                decoration: const InputDecoration(labelText: 'Name *'),
              ),
              TextField(controller: _address, maxLines: 2, decoration: const InputDecoration(labelText: 'Anschrift')),
              TextField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'E-Mail'),
              ),
              TextField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Telefon'),
              ),
              TextField(
                controller: _invoiceEmail,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Rechnungs-E-Mail',
                  helperText: 'Für Rechnungen und Mahnungen. Leer = Kontaktperson, sonst E-Mail des Kunden.',
                  helperMaxLines: 2,
                  errorText: _error,
                ),
              ),
              TextField(controller: _vatId, decoration: const InputDecoration(labelText: 'USt-IdNr.')),
              TextField(controller: _notes, maxLines: 2, decoration: const InputDecoration(labelText: 'Notizen')),
              const SizedBox(height: 8),
              const SectionLabel('Kontaktpersonen'),
              for (final (index, contact) in _contacts.indexed)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.badge_outlined),
                  title: Text(contact.label),
                  subtitle: _contactDetails(contact),
                  onTap: () => _editContact(index),
                  trailing: IconButton(
                    tooltip: 'Kontaktperson entfernen',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => setState(() => _contacts.removeAt(index)),
                  ),
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _editContact,
                  icon: const Icon(Icons.person_add_alt),
                  label: const Text('Kontaktperson hinzufügen'),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
        FilledButton(onPressed: _submit, child: Text(_isEdit ? 'Speichern' : 'Anlegen')),
      ],
    );
  }
}

Widget? _contactDetails(ContactData contact) {
  final details = [?contact.email, ?contact.phone];
  return details.isEmpty ? null : Text(details.join(' · '));
}

/// Eine Kontaktperson anlegen/bearbeiten.
class ContactFormDialog extends StatefulWidget {
  const ContactFormDialog({super.key, this.existing});
  final ContactData? existing;

  @override
  State<ContactFormDialog> createState() => _ContactFormDialogState();
}

class _ContactFormDialogState extends State<ContactFormDialog> {
  late final _name = TextEditingController(text: widget.existing?.name);
  late final _role = TextEditingController(text: widget.existing?.role);
  late final _email = TextEditingController(text: widget.existing?.email);
  late final _phone = TextEditingController(text: widget.existing?.phone);
  String? _emailError;

  @override
  void dispose() {
    for (final c in [_name, _role, _email, _phone]) {
      c.dispose();
    }
    super.dispose();
  }

  void _submit() {
    if (_name.text.trim().isEmpty) return;
    final email = _trimmedOrNull(_email);
    if (email != null && !email.contains('@')) {
      setState(() => _emailError = 'Keine E-Mail-Adresse.');
      return;
    }
    Navigator.pop(
      context,
      ContactData(
        id: widget.existing?.id,
        name: _name.text.trim(),
        role: _trimmedOrNull(_role),
        email: email,
        phone: _trimmedOrNull(_phone),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'Neue Kontaktperson' : 'Kontaktperson bearbeiten'),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _name,
              autofocus: widget.existing == null,
              decoration: const InputDecoration(labelText: 'Name der Kontaktperson *'),
            ),
            TextField(
              controller: _role,
              decoration: const InputDecoration(labelText: 'Funktion', hintText: 'z. B. Buchhaltung'),
            ),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(labelText: 'E-Mail der Kontaktperson', errorText: _emailError),
            ),
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Telefon der Kontaktperson'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
        FilledButton(onPressed: _submit, child: const Text('Übernehmen')),
      ],
    );
  }
}

/// Detailansicht eines Kunden: Stammdaten, Kontaktpersonen, Anrufen per
/// Tippen auf eine Telefonnummer. [onEdit] öffnet das Formular und
/// liefert den gespeicherten Stand (`null` = abgebrochen/kein Recht).
class CustomerDetailPage extends StatefulWidget {
  const CustomerDetailPage({super.key, required this.customer, this.onEdit});
  final CustomerFormResult customer;
  final Future<CustomerFormResult?> Function(CustomerFormResult current)? onEdit;

  @override
  State<CustomerDetailPage> createState() => _CustomerDetailPageState();
}

class _CustomerDetailPageState extends State<CustomerDetailPage> {
  late CustomerFormResult _customer = widget.customer;

  Future<void> _edit() async {
    final updated = await widget.onEdit!(_customer);
    if (updated != null && mounted) setState(() => _customer = updated);
  }

  Widget _phoneTile(String label, String number) => ListTile(
        leading: const Icon(Icons.phone_outlined),
        title: Text(number),
        subtitle: Text(label),
        onTap: () => callPhone(context, number),
        trailing: IconButton(
          tooltip: '$number anrufen',
          icon: const Icon(Icons.call),
          onPressed: () => callPhone(context, number),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final c = _customer;
    return Scaffold(
      appBar: AppBar(
        title: Text(c.name),
        actions: [
          if (widget.onEdit != null) IconButton(tooltip: 'Bearbeiten', icon: const Icon(Icons.edit_outlined), onPressed: _edit),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          if (c.address != null)
            ListTile(leading: const Icon(Icons.place_outlined), title: Text(c.address!), subtitle: const Text('Anschrift')),
          if (c.phone != null) _phoneTile('Telefon', c.phone!),
          if (c.email != null)
            ListTile(leading: const Icon(Icons.mail_outline), title: Text(c.email!), subtitle: const Text('E-Mail')),
          if (c.invoiceEmail != null)
            ListTile(
              leading: const Icon(Icons.receipt_long_outlined),
              title: Text(c.invoiceEmail!),
              subtitle: const Text('Rechnungs-E-Mail'),
            ),
          if (c.vatId != null) ListTile(leading: const Icon(Icons.badge_outlined), title: Text(c.vatId!), subtitle: const Text('USt-IdNr.')),
          if (c.notes != null) ListTile(leading: const Icon(Icons.notes), title: Text(c.notes!), subtitle: const Text('Notizen')),
          const SectionLabel('Kontaktpersonen'),
          if (c.contacts.isEmpty)
            const ListTile(title: Text('Keine Kontaktpersonen hinterlegt.')),
          for (final contact in c.contacts)
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: Text(contact.label),
              subtitle: _contactDetails(contact),
              onTap: contact.phone == null ? null : () => callPhone(context, contact.phone!),
              trailing: contact.phone == null
                  ? null
                  : IconButton(
                      tooltip: '${contact.name} anrufen',
                      icon: const Icon(Icons.call),
                      onPressed: () => callPhone(context, contact.phone!),
                    ),
            ),
        ],
      ),
    );
  }
}
