import 'package:flutter/material.dart';
import 'package:werkkern_core/werkkern_core.dart' show EInvoiceFormat, parsePostalAddress;
import 'package:url_launcher/url_launcher.dart';

import 'section_label.dart';

/// Kontaktperson als reine Anzeige-/Eingabedaten — gemeinsam für den
/// Offline-Modus (Drift) und den Online-Modus (Server). Kay 2026-11-09:
/// mehrere Kontaktpersonen je Kunde, z. B. Max → Betriebstechniker,
/// Erika → Buchhaltung.
class ContactData {
  const ContactData({this.id, required this.name, this.role, this.email, this.phone});

  /// `null` = neu, noch nicht gespeichert.
  final String? id;
  final String name;

  /// Funktion beim Kunden, z. B. „Buchhaltung“.
  final String? role;
  final String? email;
  final String? phone;

  /// „Max (Betriebstechniker)“
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
    this.street,
    this.postalCode,
    this.city,
    this.countryCode = 'DE',
    this.leitwegId,
    this.eInvoiceFormat = 'zugferd',
    this.paymentTermId,
    this.skontoMode = 'company',
    this.skontoPercent,
    this.skontoDays,
  });
  final String name;

  /// A2-Nachtrag: abweichende Zahlungsbedingung (`null` = Firmenstandard)
  /// und Skonto (`company`/`none`/`custom`).
  final String? paymentTermId;
  final String skontoMode;
  final double? skontoPercent;
  final int? skontoDays;
  final String? address;

  /// C15 E-Rechnung: strukturierte Anschrift (BG-8), Leitweg-ID (BT-10)
  /// und das Format (`zugferd`/`xrechnung`), das dieser Kunde erhält.
  final String? street;
  final String? postalCode;
  final String? city;
  final String countryCode;
  final String? leitwegId;
  final String eInvoiceFormat;

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
  const CustomerFormDialog({super.key, this.existing, this.nameKey, this.paymentTerms = const []});

  /// A2-Nachtrag: Zahlungsbedingungen der Firma (leer = Abschnitt verborgen).
  final List<({String id, String label})> paymentTerms;

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
  late final _street = TextEditingController(text: widget.existing?.street);
  late final _postalCode = TextEditingController(text: widget.existing?.postalCode);
  late final _city = TextEditingController(text: widget.existing?.city);
  late final _countryCode = TextEditingController(text: widget.existing?.countryCode ?? 'DE');
  late final _leitwegId = TextEditingController(text: widget.existing?.leitwegId);
  late String _eInvoiceFormat = widget.existing?.eInvoiceFormat ?? 'zugferd';
  late String? _paymentTermId =
      widget.paymentTerms.any((t) => t.id == widget.existing?.paymentTermId) ? widget.existing?.paymentTermId : null;
  late String _skontoMode = widget.existing?.skontoMode ?? 'company';
  late final _skontoPercent = TextEditingController(
    text: widget.existing?.skontoPercent == null ? '' : widget.existing!.skontoPercent.toString().replaceAll('.', ','),
  );
  late final _skontoDays = TextEditingController(text: widget.existing?.skontoDays?.toString() ?? '');
  late final List<ContactData> _contacts = [...?widget.existing?.contacts];
  String? _error;
  String? _skontoError;

  bool get _isEdit => widget.existing != null;

  @override
  void dispose() {
    for (final c in [_name, _address, _email, _invoiceEmail, _phone, _vatId, _notes, _street, _postalCode, _city, _countryCode, _leitwegId, _skontoPercent, _skontoDays]) {
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
    final skontoPercent = double.tryParse(_skontoPercent.text.trim().replaceAll(',', '.'));
    final skontoDays = int.tryParse(_skontoDays.text.trim());
    if (_skontoMode == 'custom' &&
        (skontoPercent == null || skontoPercent <= 0 || skontoPercent >= 100 || skontoDays == null || skontoDays < 0)) {
      setState(() => _skontoError = 'Eigenes Skonto braucht Prozentsatz (0–100) und Frist in Tagen.');
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
        street: _trimmedOrNull(_street),
        postalCode: _trimmedOrNull(_postalCode),
        city: _trimmedOrNull(_city),
        countryCode: (_trimmedOrNull(_countryCode) ?? 'DE').toUpperCase(),
        leitwegId: _trimmedOrNull(_leitwegId),
        eInvoiceFormat: _eInvoiceFormat,
        paymentTermId: _paymentTermId,
        skontoMode: _skontoMode,
        skontoPercent: _skontoMode == 'custom' ? skontoPercent : null,
        skontoDays: _skontoMode == 'custom' ? skontoDays : null,
      ),
    );
  }

  /// Freitext-Anschrift in die strukturierten Felder übernehmen (nur
  /// leere Felder) — spart das Abtippen bei Bestandskunden.
  void _splitAddress() {
    final parsed = parsePostalAddress(_address.text);
    setState(() {
      if (_street.text.trim().isEmpty && parsed.street != null) _street.text = parsed.street!;
      if (_postalCode.text.trim().isEmpty && parsed.postalCode != null) _postalCode.text = parsed.postalCode!;
      if (_city.text.trim().isEmpty && parsed.city != null) _city.text = parsed.city!;
      if (_countryCode.text.trim().isEmpty || _countryCode.text.trim() == 'DE') _countryCode.text = parsed.countryCode;
    });
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
              // C15 E-Rechnung: EN 16931 braucht Straße/PLZ/Ort/Land getrennt
              // (BG-8); der Freitext oben bleibt fürs PDF.
              const SectionLabel('E-Rechnung'),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _street,
                      decoration: const InputDecoration(labelText: 'Straße und Hausnummer'),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Aus der Anschrift übernehmen',
                    icon: const Icon(Icons.call_split),
                    onPressed: _splitAddress,
                  ),
                ],
              ),
              Row(
                children: [
                  SizedBox(
                    width: 110,
                    child: TextField(controller: _postalCode, decoration: const InputDecoration(labelText: 'PLZ')),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: TextField(controller: _city, decoration: const InputDecoration(labelText: 'Ort'))),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 70,
                    child: TextField(
                      controller: _countryCode,
                      maxLength: 2,
                      decoration: const InputDecoration(labelText: 'Land', counterText: ''),
                    ),
                  ),
                ],
              ),
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: _eInvoiceFormat,
                decoration: const InputDecoration(labelText: 'E-Rechnungsformat'),
                items: [
                  for (final f in EInvoiceFormat.values) DropdownMenuItem(value: f.name, child: Text(f.label)),
                ],
                onChanged: (value) => setState(() => _eInvoiceFormat = value ?? 'zugferd'),
              ),
              TextField(
                controller: _leitwegId,
                decoration: const InputDecoration(
                  labelText: 'Leitweg-ID / Käuferreferenz',
                  helperText: 'Pflicht bei XRechnung (öffentliche Auftraggeber).',
                ),
              ),
              if (widget.paymentTerms.isNotEmpty) ...[
                const SizedBox(height: 8),
                const SectionLabel('Zahlung'),
                DropdownButtonFormField<String?>(
                  key: const Key('customer-payment-term'),
                  isExpanded: true,
                  initialValue: _paymentTermId,
                  decoration: const InputDecoration(labelText: 'Zahlungsbedingung'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Firmenstandard')),
                    for (final t in widget.paymentTerms) DropdownMenuItem(value: t.id, child: Text(t.label)),
                  ],
                  onChanged: (value) => setState(() => _paymentTermId = value),
                ),
                DropdownButtonFormField<String>(
                  key: const Key('customer-skonto-mode'),
                  isExpanded: true,
                  initialValue: _skontoMode,
                  decoration: InputDecoration(labelText: 'Skonto', errorText: _skontoError),
                  items: const [
                    DropdownMenuItem(value: 'company', child: Text('Vorgabe der Firma')),
                    DropdownMenuItem(value: 'none', child: Text('Kein Skonto')),
                    DropdownMenuItem(value: 'custom', child: Text('Eigenes Skonto')),
                  ],
                  onChanged: (value) => setState(() => _skontoMode = value ?? 'company'),
                ),
                if (_skontoMode == 'custom')
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          key: const Key('customer-skonto-percent'),
                          controller: _skontoPercent,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(labelText: 'Skonto %'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          key: const Key('customer-skonto-days'),
                          controller: _skontoDays,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Frist (Tage)'),
                        ),
                      ),
                    ],
                  ),
              ],
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
