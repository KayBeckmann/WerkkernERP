import 'package:flutter/material.dart';
import 'package:werkkern_client/werkkern_client.dart';

import '../../../domain/services/online_session.dart';
import 'online_form.dart';

/// Einstellungen → Zahlungsbedingungen online (A2-Nachtrag, Kay
/// 15./16.11.2026) — wie offline: Liste mit Standard, Skonto-Vorgabe der
/// Firma. Nur für Admins.
class OnlinePaymentTermsScreen extends StatefulWidget {
  const OnlinePaymentTermsScreen({super.key, required this.session});
  final OnlineSession session;

  @override
  State<OnlinePaymentTermsScreen> createState() => _OnlinePaymentTermsScreenState();
}

class _OnlinePaymentTermsScreenState extends State<OnlinePaymentTermsScreen> {
  WerkkernApiClient get _client => widget.session.client;
  late Future<(List<OnlinePaymentTerm>, OnlineCompanyProfile)> _future = _load();
  final _skontoPercent = TextEditingController();
  final _skontoDays = TextEditingController();

  Future<(List<OnlinePaymentTerm>, OnlineCompanyProfile)> _load() async {
    final terms = await _client.paymentTerms();
    final profile = await _client.companyProfile();
    _skontoPercent.text = profile.skontoPercent == null ? '' : _num(profile.skontoPercent!);
    _skontoDays.text = profile.skontoDays?.toString() ?? '';
    return (terms, profile);
  }

  static String _num(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString().replaceAll('.', ',');

  void _reload() => setState(() {
        _future = _load();
      });

  @override
  void dispose() {
    _skontoPercent.dispose();
    _skontoDays.dispose();
    super.dispose();
  }

  Future<void> _edit([OnlinePaymentTerm? existing]) async {
    final values = await showOnlineForm(
      context,
      title: existing == null ? 'Neue Zahlungsbedingung' : 'Zahlungsbedingung bearbeiten',
      fields: [
        OnlineField('label', 'Bezeichnung', required: true, initial: existing?.label),
        OnlineField('days', 'Zahlungsziel in Tagen', type: OnlineFieldType.decimal, required: true, initial: existing?.netDays.toString()),
      ],
    );
    if (values == null || !mounted) return;
    final days = int.tryParse((values['days'] as String).split('.').first);
    if (days == null || days < 0) return;
    if (await runOnline(context, () => _client.savePaymentTerm(id: existing?.id, label: values['label'] as String, netDays: days))) {
      _reload();
    }
  }

  /// Profil komplett zurückschicken — der Server überschreibt sonst
  /// Anschrift & Co. mit leeren Werten.
  Future<void> _saveSkonto(OnlineCompanyProfile p) async {
    final percentText = _skontoPercent.text.trim().replaceAll(',', '.');
    final daysText = _skontoDays.text.trim();
    final percent = percentText.isEmpty ? null : double.tryParse(percentText);
    final days = daysText.isEmpty ? null : int.tryParse(daysText);
    await runOnline(
      context,
      () => _client.saveCompanyProfile(OnlineCompanyProfile(
        address: p.address,
        taxNumber: p.taxNumber,
        vatId: p.vatId,
        iban: p.iban,
        email: p.email,
        phone: p.phone,
        footerText: p.footerText,
        documentTexts: p.documentTexts,
        smallBusinessExempt: p.smallBusinessExempt,
        street: p.street,
        postalCode: p.postalCode,
        city: p.city,
        countryCode: p.countryCode,
        bic: p.bic,
        skontoPercent: percent,
        skontoDays: days,
        quoteValidityDays: p.quoteValidityDays,
      )),
      success: percent == null ? 'Kein Skonto als Vorgabe.' : 'Skonto-Vorgabe gespeichert.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Zahlungsbedingungen')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'online-payment-terms-fab',
        onPressed: _edit,
        icon: const Icon(Icons.add),
        label: const Text('Bedingung anlegen'),
      ),
      body: FutureBuilder<(List<OnlinePaymentTerm>, OnlineCompanyProfile)>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text(describeOnlineError(snapshot.error!)));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final (terms, profile) = snapshot.data!;
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
                  if (await runOnline(context, () => _client.setDefaultPaymentTerm(id))) _reload();
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
                          onPressed: () async {
                            if (await runOnline(context, () => _client.deletePaymentTerm(t.id))) _reload();
                          },
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
                      key: const Key('online-company-skonto-percent'),
                      controller: _skontoPercent,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Skonto %'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      key: const Key('online-company-skonto-days'),
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
                child: FilledButton(onPressed: () => _saveSkonto(profile), child: const Text('Skonto-Vorgabe speichern')),
              ),
            ],
          );
        },
      ),
    );
  }
}
