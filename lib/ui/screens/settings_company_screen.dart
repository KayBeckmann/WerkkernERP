import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:werkkern_core/werkkern_core.dart' show normalizePdfLayout, parsePostalAddress;

import '../../data/repositories/company_repository.dart';
import '../widgets/pdf_branding_fields.dart' show pdfLayoutLabels;
import '../widgets/quote_validity_dialog.dart' show parseQuoteValidityDays;
import '../../domain/services/active_company_service.dart';

/// Einstellungen → Firmendaten (C15.1, Kay 2026-11-15). Bis dahin gab es
/// offline keine Maske für Anschrift, Steuernummer, USt-IdNr. und IBAN —
/// die Felder existierten seit A0 nur in der Datenbank. Die E-Rechnung
/// braucht sie vollständig und zusätzlich strukturiert (Straße, PLZ, Ort,
/// Land) sowie die BIC. Alles landet beim Finalisieren unveränderlich im
/// Dokument (siehe `InvoiceRepository.finalize`).
class SettingsCompanyScreen extends StatefulWidget {
  const SettingsCompanyScreen({super.key});

  @override
  State<SettingsCompanyScreen> createState() => _SettingsCompanyScreenState();
}

class _SettingsCompanyScreenState extends State<SettingsCompanyScreen> {
  final _name = TextEditingController();
  final _address = TextEditingController();
  final _street = TextEditingController();
  final _postalCode = TextEditingController();
  final _city = TextEditingController();
  final _countryCode = TextEditingController();
  final _taxNumber = TextEditingController();
  final _vatId = TextEditingController();
  final _iban = TextEditingController();
  final _bic = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();

  /// A5-Nachtrag: Standard-Bindefrist neuer Angebote (Tage).
  final _quoteValidity = TextEditingController();

  /// Parität offline/online (26.11.2026): Beleglayout wie online.
  String _pdfLayout = 'classic';
  bool _busy = false;
  bool _loaded = false;

  List<TextEditingController> get _all =>
      [_name, _address, _street, _postalCode, _city, _countryCode, _taxNumber, _vatId, _iban, _bic, _email, _phone, _quoteValidity];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    final company = context.read<ActiveCompanyService>().active;
    if (company == null) return;
    _name.text = company.name;
    _address.text = company.address ?? '';
    _street.text = company.street ?? '';
    _postalCode.text = company.postalCode ?? '';
    _city.text = company.city ?? '';
    _countryCode.text = company.countryCode;
    _taxNumber.text = company.taxNumber ?? '';
    _vatId.text = company.vatId ?? '';
    _iban.text = company.iban ?? '';
    _bic.text = company.bic ?? '';
    _email.text = company.email ?? '';
    _phone.text = company.phone ?? '';
    _quoteValidity.text = company.quoteValidityDays?.toString() ?? '';
    _pdfLayout = normalizePdfLayout(company.pdfLayout);
    _loaded = true;
  }

  @override
  void dispose() {
    for (final c in _all) {
      c.dispose();
    }
    super.dispose();
  }

  String? _v(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();

  /// Freitext-Anschrift in die strukturierten Felder übernehmen (nur leere).
  void _splitAddress() {
    final parsed = parsePostalAddress(_address.text);
    setState(() {
      if (_street.text.trim().isEmpty && parsed.street != null) _street.text = parsed.street!;
      if (_postalCode.text.trim().isEmpty && parsed.postalCode != null) _postalCode.text = parsed.postalCode!;
      if (_city.text.trim().isEmpty && parsed.city != null) _city.text = parsed.city!;
      _countryCode.text = parsed.countryCode;
    });
  }

  Future<void> _save() async {
    final service = context.read<ActiveCompanyService>();
    final company = service.active;
    if (company == null || _name.text.trim().isEmpty) return;
    final validity = parseQuoteValidityDays(_quoteValidity.text);
    if (!validity.ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bindefrist: ganze Tage von 0 bis 3650 oder leer lassen.')),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await context.read<CompanyRepository>().update(
            company.copyWith(
              name: _name.text.trim(),
              address: Value(_v(_address)),
              street: Value(_v(_street)),
              postalCode: Value(_v(_postalCode)),
              city: Value(_v(_city)),
              countryCode: (_v(_countryCode) ?? 'DE').toUpperCase(),
              taxNumber: Value(_v(_taxNumber)),
              vatId: Value(_v(_vatId)),
              iban: Value(_v(_iban)?.replaceAll(' ', '')),
              bic: Value(_v(_bic)),
              email: Value(_v(_email)),
              phone: Value(_v(_phone)),
              quoteValidityDays: Value(validity.days),
              pdfLayout: _pdfLayout,
            ),
          );
      await service.refreshActive();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Firmendaten gespeichert.')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Firmendaten')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Wird beim Finalisieren unveränderlich in jedes Dokument übernommen. Für die E-Rechnung '
            '(EN 16931) müssen Straße, PLZ, Ort, Land, E-Mail, Telefon und eine Steuernummer oder '
            'USt-IdNr. vorhanden sein.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            key: const Key('company-pdf-layout'),
            initialValue: _pdfLayout,
            decoration: const InputDecoration(
              labelText: 'PDF-Layout',
              helperText: 'Gilt für Entwürfe und neu finalisierte Belege; Logo und Fußzeile unter Dokumenttexte.',
            ),
            items: [
              for (final e in pdfLayoutLabels.entries) DropdownMenuItem(value: e.key, child: Text(e.value)),
            ],
            onChanged: _busy ? null : (value) => setState(() => _pdfLayout = value ?? 'classic'),
          ),
          TextField(controller: _name, decoration: const InputDecoration(labelText: 'Firmenname *')),
          TextField(
            controller: _address,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Anschrift (Freitext, fürs PDF)'),
          ),
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
          TextField(controller: _taxNumber, decoration: const InputDecoration(labelText: 'Steuernummer')),
          TextField(controller: _vatId, decoration: const InputDecoration(labelText: 'USt-IdNr.')),
          TextField(controller: _iban, decoration: const InputDecoration(labelText: 'IBAN')),
          TextField(controller: _bic, decoration: const InputDecoration(labelText: 'BIC')),
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
            key: const Key('company-quote-validity'),
            controller: _quoteValidity,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Standard-Bindefrist für Angebote (Tage)',
              helperText: 'Vorbelegung für neue Angebote, gilt ab Finalisierung. Leer = keine.',
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy ? null : _save,
            child: Text(_busy ? 'Bitte warten…' : 'Firmendaten speichern'),
          ),
        ],
      ),
    );
  }
}
