import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/database/tables.dart';
import '../../data/repositories/company_repository.dart';
import '../../domain/services/active_company_service.dart';
import '../../domain/services/theme_preference_service.dart';
import '../widgets/section_label.dart';
import 'backup_screen.dart';
import 'invoices_screen.dart' show DocumentLabels;

/// Einstellungen der aktiven Firma, thematisch gegliedert (Kay-Nachtrag
/// 2026-10-16, zweiter Nachtrag: "Die Einstellungen sollten auch gleich
/// thematisch sortiert werden" — bei RechnungsFee angeschaut, dort über
/// eine eigene Navigation mit Unterseiten gelöst; hier als klar
/// beschriftete Abschnitte auf einer Seite, da WerkkernERP (noch)
/// deutlich weniger Einstellungen hat): Darstellung, Module,
/// Dokumenttexte je Dokumentart, Daten & Sicherung.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _busy = false;
  bool _textsSaving = false;

  // Ein Controller-Paar je Dokumentart, unabhängig davon, ob das Modul
  // aktuell aktiv ist (Kay-Nachtrag, zweiter Nachtrag: "müssen pro
  // Dokument abweichend sein") — alle vier existieren immer, nur die
  // TextFields werden je nach aktivem Modul ein-/ausgeblendet. So bleibt
  // der Zustand erhalten, wenn ein Modul während der Bearbeitung ein-
  // oder ausgeschaltet wird, ohne Controller dynamisch anlegen/verwerfen
  // zu müssen.
  late final Map<DocumentKind, TextEditingController> _introCtrls;
  late final Map<DocumentKind, TextEditingController> _closingCtrls;
  late final TextEditingController _footerCtrl;

  @override
  void initState() {
    super.initState();
    final company = context.read<ActiveCompanyService>().active;
    _introCtrls = {
      DocumentKind.invoice: TextEditingController(text: company?.pdfIntroText),
      DocumentKind.quote: TextEditingController(text: company?.pdfIntroTextQuote),
      DocumentKind.order: TextEditingController(text: company?.pdfIntroTextOrder),
      DocumentKind.deliveryNote: TextEditingController(text: company?.pdfIntroTextDeliveryNote),
      DocumentKind.proforma: TextEditingController(text: company?.pdfIntroTextProforma),
    };
    _closingCtrls = {
      DocumentKind.invoice: TextEditingController(text: company?.pdfClosingText),
      DocumentKind.quote: TextEditingController(text: company?.pdfClosingTextQuote),
      DocumentKind.order: TextEditingController(text: company?.pdfClosingTextOrder),
      DocumentKind.deliveryNote: TextEditingController(text: company?.pdfClosingTextDeliveryNote),
      DocumentKind.proforma: TextEditingController(text: company?.pdfClosingTextProforma),
    };
    _footerCtrl = TextEditingController(text: company?.pdfFooterText);
  }

  @override
  void dispose() {
    for (final c in _introCtrls.values) {
      c.dispose();
    }
    for (final c in _closingCtrls.values) {
      c.dispose();
    }
    _footerCtrl.dispose();
    super.dispose();
  }

  Future<void> _setModule({
    bool? quotesEnabled,
    bool? ordersEnabled,
    bool? deliveryNotesEnabled,
    bool? proformaEnabled,
    bool? projectsEnabled,
    bool? fleetEnabled,
    bool? recurringInvoicesEnabled,
    bool? advancePaymentInvoicesEnabled,
  }) async {
    final service = context.read<ActiveCompanyService>();
    final company = service.active;
    if (company == null) return;
    setState(() => _busy = true);
    try {
      await context.read<CompanyRepository>().setModules(
            companyId: company.id,
            quotesEnabled: quotesEnabled ?? company.quotesEnabled,
            ordersEnabled: ordersEnabled ?? company.ordersEnabled,
            deliveryNotesEnabled: deliveryNotesEnabled ?? company.deliveryNotesEnabled,
            proformaEnabled: proformaEnabled ?? company.proformaEnabled,
            projectsEnabled: projectsEnabled ?? company.projectsEnabled,
            fleetEnabled: fleetEnabled ?? company.fleetEnabled,
            recurringInvoicesEnabled: recurringInvoicesEnabled ?? company.recurringInvoicesEnabled,
            advancePaymentInvoicesEnabled:
                advancePaymentInvoicesEnabled ?? company.advancePaymentInvoicesEnabled,
          );
      await service.refreshActive();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String? _textOrNull(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();

  /// Speichert alle Textfelder — Einleitung/Schluss je Dokumentart
  /// (Kay-Nachtrag 2026-10-16, zweiter Nachtrag) + die gemeinsame
  /// Fußzeile.
  Future<void> _saveTexts() async {
    final service = context.read<ActiveCompanyService>();
    final company = service.active;
    if (company == null) return;
    setState(() => _textsSaving = true);
    try {
      await context.read<CompanyRepository>().update(
            company.copyWith(
              pdfIntroText: Value(_textOrNull(_introCtrls[DocumentKind.invoice]!)),
              pdfClosingText: Value(_textOrNull(_closingCtrls[DocumentKind.invoice]!)),
              pdfIntroTextQuote: Value(_textOrNull(_introCtrls[DocumentKind.quote]!)),
              pdfClosingTextQuote: Value(_textOrNull(_closingCtrls[DocumentKind.quote]!)),
              pdfIntroTextOrder: Value(_textOrNull(_introCtrls[DocumentKind.order]!)),
              pdfClosingTextOrder: Value(_textOrNull(_closingCtrls[DocumentKind.order]!)),
              pdfIntroTextDeliveryNote: Value(_textOrNull(_introCtrls[DocumentKind.deliveryNote]!)),
              pdfClosingTextDeliveryNote: Value(_textOrNull(_closingCtrls[DocumentKind.deliveryNote]!)),
              pdfIntroTextProforma: Value(_textOrNull(_introCtrls[DocumentKind.proforma]!)),
              pdfClosingTextProforma: Value(_textOrNull(_closingCtrls[DocumentKind.proforma]!)),
              pdfFooterText: Value(_textOrNull(_footerCtrl)),
            ),
          );
      await service.refreshActive();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dokumenttexte gespeichert.')),
        );
      }
    } finally {
      if (mounted) setState(() => _textsSaving = false);
    }
  }

  Widget _textPair(DocumentKind kind) {
    final label = DocumentLabels.title(kind);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 6),
          TextField(
            controller: _introCtrls[kind],
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'Einleitungstext ($label)',
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _closingCtrls[kind],
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'Schlusstext ($label)',
              border: const OutlineInputBorder(),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final company = context.watch<ActiveCompanyService>().active;
    if (company == null) return const SizedBox.shrink();

    final themePreference = context.watch<ThemePreferenceService>();
    final activeKinds = [
      DocumentKind.invoice,
      if (company.quotesEnabled) DocumentKind.quote,
      if (company.ordersEnabled) DocumentKind.order,
      if (company.deliveryNotesEnabled) DocumentKind.deliveryNote,
      if (company.proformaEnabled) DocumentKind.proforma,
    ];

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        const SectionLabel('Darstellung'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Design', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 12),
                  SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode_outlined), label: Text('Hell')),
                      ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode_outlined), label: Text('Dunkel')),
                      ButtonSegment(
                        value: ThemeMode.system,
                        icon: Icon(Icons.brightness_auto_outlined),
                        label: Text('System'),
                      ),
                    ],
                    selected: {themePreference.mode},
                    onSelectionChanged: (selection) => themePreference.setMode(selection.first),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SectionLabel('Module'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pro Firma ein-/ausblendbar. Bereits vorhandene Daten bleiben beim '
                    'Deaktivieren erhalten.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Angebote'),
                    value: company.quotesEnabled,
                    onChanged: _busy ? null : (value) => _setModule(quotesEnabled: value),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Aufträge'),
                    value: company.ordersEnabled,
                    onChanged: _busy ? null : (value) => _setModule(ordersEnabled: value),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Lieferscheine'),
                    value: company.deliveryNotesEnabled,
                    onChanged: _busy ? null : (value) => _setModule(deliveryNotesEnabled: value),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Proforma-Rechnungen'),
                    value: company.proformaEnabled,
                    onChanged: _busy ? null : (value) => _setModule(proformaEnabled: value),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Projekte'),
                    value: company.projectsEnabled,
                    onChanged: _busy ? null : (value) => _setModule(projectsEnabled: value),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Fuhrpark'),
                    value: company.fleetEnabled,
                    onChanged: _busy ? null : (value) => _setModule(fleetEnabled: value),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Wiederkehrende Rechnungen'),
                    value: company.recurringInvoicesEnabled,
                    onChanged: _busy ? null : (value) => _setModule(recurringInvoicesEnabled: value),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Abschlagsrechnungen'),
                    value: company.advancePaymentInvoicesEnabled,
                    onChanged: _busy
                        ? null
                        : (value) => _setModule(advancePaymentInvoicesEnabled: value),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SectionLabel('Dokumenttexte'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Einleitung/Schluss je Dokumentart (z. B. Bindefrist im Angebot, '
                    'Zahlungsziel in der Rechnung). Nur aktive Module werden angezeigt.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  for (final kind in activeKinds) _textPair(kind),
                  TextField(
                    controller: _footerCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Fußzeile (gemeinsam für alle Dokumentarten)',
                      hintText: 'z. B. Firmenname — Anschrift',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton(
                      onPressed: _textsSaving ? null : _saveTexts,
                      child: _textsSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Speichern'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SectionLabel('Daten & Sicherung'),
        const BackupScreen(),
      ],
    );
  }
}
