import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/database/database.dart';
import '../../data/repositories/company_repository.dart';
import '../../data/repositories/payment_term_repository.dart';
import '../../domain/services/active_company_service.dart';

/// Einstellungen → Zahlungsbedingungen (A2-Nachtrag, Kay 15.11.2026):
/// wiederverwendbare Bedingungen je Firma, genau eine als Standard, dazu
/// die optionale Skonto-Vorgabe der Firma. Kunden können abweichen, jeder
/// Beleg kann bewusst geändert werden.
class SettingsPaymentTermsScreen extends StatefulWidget {
  const SettingsPaymentTermsScreen({super.key});

  @override
  State<SettingsPaymentTermsScreen> createState() => _SettingsPaymentTermsScreenState();
}

class _SettingsPaymentTermsScreenState extends State<SettingsPaymentTermsScreen> {
  late Future<List<PaymentTerm>> _future;
  final _skontoPercent = TextEditingController();
  final _skontoDays = TextEditingController();

  @override
  void initState() {
    super.initState();
    _future = _load();
    final company = context.read<ActiveCompanyService>().active!;
    _skontoPercent.text = company.skontoPercent == null ? '' : _num(company.skontoPercent!);
    _skontoDays.text = company.skontoDays?.toString() ?? '';
  }

  @override
  void dispose() {
    _skontoPercent.dispose();
    _skontoDays.dispose();
    super.dispose();
  }

  static String _num(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString().replaceAll('.', ',');

  Future<List<PaymentTerm>> _load() =>
      context.read<PaymentTermRepository>().listForCompany(context.read<ActiveCompanyService>().active!.id);

  void _reload() => setState(() {
        _future = _load();
      });

  String get _companyId => context.read<ActiveCompanyService>().active!.id;

  Future<void> _edit([PaymentTerm? existing]) async {
    final result = await showDialog<({String label, int days})>(
      context: context,
      builder: (_) => _TermDialog(existing: existing),
    );
    if (result == null || !mounted) return;
    final repo = context.read<PaymentTermRepository>();
    if (existing == null) {
      await repo.create(companyId: _companyId, label: result.label, netDays: result.days);
    } else {
      await repo.update(companyId: _companyId, id: existing.id, label: result.label, netDays: result.days);
    }
    _reload();
  }

  Future<void> _delete(PaymentTerm term) async {
    try {
      await context.read<PaymentTermRepository>().delete(companyId: _companyId, id: term.id);
    } on StateError catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
    _reload();
  }

  Future<void> _saveSkonto() async {
    final percentText = _skontoPercent.text.trim().replaceAll(',', '.');
    final daysText = _skontoDays.text.trim();
    final percent = percentText.isEmpty ? null : double.tryParse(percentText);
    final days = daysText.isEmpty ? null : int.tryParse(daysText);
    final messenger = ScaffoldMessenger.of(context);
    if ((percent == null) != (days == null) || (percent != null && (percent <= 0 || percent >= 100)) || (days != null && days < 0)) {
      messenger.showSnackBar(const SnackBar(content: Text('Skonto braucht Prozentsatz (0–100) und Frist in Tagen — oder beides leer.')));
      return;
    }
    final service = context.read<ActiveCompanyService>();
    await context.read<CompanyRepository>().update(
          service.active!.copyWith(skontoPercent: Value(percent), skontoDays: Value(days)),
        );
    await service.refreshActive();
    messenger.showSnackBar(SnackBar(content: Text(percent == null ? 'Kein Skonto als Vorgabe.' : 'Skonto-Vorgabe gespeichert.')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Zahlungsbedingungen')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'payment-terms-fab',
        onPressed: _edit,
        icon: const Icon(Icons.add),
        label: const Text('Bedingung anlegen'),
      ),
      body: FutureBuilder<List<PaymentTerm>>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final terms = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
            children: [
              Text(
                'Standard für neue Aufträge und Rechnungen, sofern der Kunde keine eigene Bedingung hat. '
                '„Sofort netto“ heißt sofort fällig ohne Abzug.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              RadioGroup<String>(
                groupValue: terms.where((t) => t.isDefault).firstOrNull?.id,
                onChanged: (id) async {
                  if (id == null) return;
                  await context.read<PaymentTermRepository>().setDefault(companyId: _companyId, id: id);
                  _reload();
                },
                child: Column(
                  children: [
                    for (final t in terms)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Radio<String>(value: t.id),
                        title: Text(t.label),
                        subtitle: Text(t.netDays == 0 ? 'sofort fällig' : '${t.netDays} Tage Zahlungsziel'),
                        onTap: () => _edit(t),
                        trailing: IconButton(
                          tooltip: 'Löschen',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _delete(t),
                        ),
                      ),
                  ],
                ),
              ),
              const Divider(height: 32),
              Text('Skonto-Vorgabe der Firma (optional)', style: Theme.of(context).textTheme.titleSmall),
              const Text(
                'Ohne § 19 UStG auf den Nettobetrag, mit § 19 auf den Rechnungsbetrag. Leer = kein Skonto.',
                style: TextStyle(fontSize: 12),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('company-skonto-percent'),
                      controller: _skontoPercent,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Skonto %'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      key: const Key('company-skonto-days'),
                      controller: _skontoDays,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Skontofrist (Tage)'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton(onPressed: _saveSkonto, child: const Text('Skonto-Vorgabe speichern')),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _TermDialog extends StatefulWidget {
  const _TermDialog({this.existing});
  final PaymentTerm? existing;

  @override
  State<_TermDialog> createState() => _TermDialogState();
}

class _TermDialogState extends State<_TermDialog> {
  late final _label = TextEditingController(text: widget.existing?.label);
  late final _days = TextEditingController(text: widget.existing?.netDays.toString() ?? '');
  String? _error;

  @override
  void dispose() {
    _label.dispose();
    _days.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.existing == null ? 'Neue Zahlungsbedingung' : 'Zahlungsbedingung bearbeiten'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _label, decoration: const InputDecoration(labelText: 'Bezeichnung *')),
            TextField(
              controller: _days,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: 'Zahlungsziel in Tagen *', errorText: _error),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
          FilledButton(
            onPressed: () {
              final days = int.tryParse(_days.text.trim());
              if (_label.text.trim().isEmpty || days == null || days < 0) {
                setState(() => _error = 'Bezeichnung und Tage (≥ 0) angeben.');
                return;
              }
              Navigator.pop(context, (label: _label.text.trim(), days: days));
            },
            child: const Text('Speichern'),
          ),
        ],
      );
}
