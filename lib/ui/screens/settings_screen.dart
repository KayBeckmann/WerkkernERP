import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/database/tables.dart';
import '../../data/repositories/company_repository.dart';
import '../../domain/models/money.dart';
import '../../domain/services/active_company_service.dart';
import '../../domain/services/smtp_credential_store.dart';
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

  // C12 Mahnwesen — Nachbesserung (Kay-Feedback 2026-10-17: "Wo stelle
  // ich die Gebühren und die Fristen ein?"). Mahnschreiben-Texte folgen
  // demselben Muster wie die Dokumentart-Texte oben, sind aber nicht an
  // einen DocumentKind gebunden (siehe Doc-Kommentar bei
  // `Companies.pdfIntroTextDunning` in tables.dart).
  late final TextEditingController _dunningIntroCtrl;
  late final TextEditingController _dunningClosingCtrl;
  late final TextEditingController _dunningReminder2DaysCtrl;
  late final TextEditingController _dunningReminder3DaysCtrl;
  late final TextEditingController _dunningFeeLevel1Ctrl;
  late final TextEditingController _dunningFeeLevel2Ctrl;
  late final TextEditingController _dunningFeeLevel3Ctrl;
  late final TextEditingController _dunningInterestRateCtrl;
  bool _dunningSettingsSaving = false;

  // C7a SMTP-Versand (Kay-Nachfrage 2026-10-17: "Gibt es schon den SMTP
  // Versand? Wo konfiguriere ich den Betreff und den Body der Mail?").
  // Das Passwort steht bewusst NICHT in einem dieser Controller — es
  // wird getrennt über `SmtpCredentialStore` gelesen/geschrieben (siehe
  // Doc-Kommentar dort) und hier nur über `_smtpHasPassword`
  // (asynchron geladen) angezeigt.
  late final TextEditingController _smtpHostCtrl;
  late final TextEditingController _smtpPortCtrl;
  late final TextEditingController _smtpUsernameCtrl;
  late final TextEditingController _smtpFromAddressCtrl;
  late final TextEditingController _smtpFromNameCtrl;
  late final TextEditingController _smtpPasswordCtrl;
  late final TextEditingController _smtpInvoiceSubjectCtrl;
  late final TextEditingController _smtpInvoiceBodyCtrl;
  late final TextEditingController _smtpDunningSubjectCtrl;
  late final TextEditingController _smtpDunningBodyCtrl;
  bool _smtpUseTls = true;
  bool _smtpSettingsSaving = false;
  bool _smtpPasswordSaving = false;
  bool? _smtpHasPassword;

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
      DocumentKind.creditNote: TextEditingController(text: company?.pdfIntroTextCreditNote),
    };
    _closingCtrls = {
      DocumentKind.invoice: TextEditingController(text: company?.pdfClosingText),
      DocumentKind.quote: TextEditingController(text: company?.pdfClosingTextQuote),
      DocumentKind.order: TextEditingController(text: company?.pdfClosingTextOrder),
      DocumentKind.deliveryNote: TextEditingController(text: company?.pdfClosingTextDeliveryNote),
      DocumentKind.proforma: TextEditingController(text: company?.pdfClosingTextProforma),
      DocumentKind.creditNote: TextEditingController(text: company?.pdfClosingTextCreditNote),
    };
    _footerCtrl = TextEditingController(text: company?.pdfFooterText);
    _dunningIntroCtrl = TextEditingController(text: company?.pdfIntroTextDunning);
    _dunningClosingCtrl = TextEditingController(text: company?.pdfClosingTextDunning);
    _dunningReminder2DaysCtrl =
        TextEditingController(text: (company?.dunningReminder2AfterDays ?? 14).toString());
    _dunningReminder3DaysCtrl =
        TextEditingController(text: (company?.dunningReminder3AfterDays ?? 28).toString());
    _dunningFeeLevel1Ctrl =
        TextEditingController(text: _centsToEuroText(company?.dunningFeeLevel1Cents ?? 0));
    _dunningFeeLevel2Ctrl =
        TextEditingController(text: _centsToEuroText(company?.dunningFeeLevel2Cents ?? 0));
    _dunningFeeLevel3Ctrl =
        TextEditingController(text: _centsToEuroText(company?.dunningFeeLevel3Cents ?? 0));
    _dunningInterestRateCtrl =
        TextEditingController(text: (company?.dunningInterestRatePercent ?? 0).toString());
    _smtpHostCtrl = TextEditingController(text: company?.smtpHost);
    _smtpPortCtrl = TextEditingController(text: (company?.smtpPort ?? 587).toString());
    _smtpUsernameCtrl = TextEditingController(text: company?.smtpUsername);
    _smtpFromAddressCtrl = TextEditingController(text: company?.smtpFromAddress);
    _smtpFromNameCtrl = TextEditingController(text: company?.smtpFromName);
    _smtpPasswordCtrl = TextEditingController();
    _smtpInvoiceSubjectCtrl = TextEditingController(text: company?.smtpInvoiceSubjectTemplate);
    _smtpInvoiceBodyCtrl = TextEditingController(text: company?.smtpInvoiceBodyTemplate);
    _smtpDunningSubjectCtrl = TextEditingController(text: company?.smtpDunningSubjectTemplate);
    _smtpDunningBodyCtrl = TextEditingController(text: company?.smtpDunningBodyTemplate);
    _smtpUseTls = company?.smtpUseTls ?? true;
    if (company != null) {
      // Lesen aus dem Secure Storage ist asynchron — erst nach dem
      // ersten Frame nachladen, nicht den synchronen initState
      // blockieren.
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadSmtpPasswordState(company.id));
    }
  }

  Future<void> _loadSmtpPasswordState(String companyId) async {
    try {
      final hasPassword = await context.read<SmtpCredentialStore>().hasPassword(companyId);
      if (mounted) setState(() => _smtpHasPassword = hasPassword);
    } catch (_) {
      // Secure Storage kann auf manchen Plattformen/Testumgebungen ohne
      // registrierten Platform-Channel fehlschlagen — dann bleibt der
      // Zustand unbekannt (`null`, von der UI bereits als "nicht
      // anzeigen" behandelt) statt die ganze Einstellungsseite
      // abstürzen zu lassen.
    }
  }

  static String _centsToEuroText(int cents) => (cents / 100).toStringAsFixed(2);

  @override
  void dispose() {
    for (final c in _introCtrls.values) {
      c.dispose();
    }
    for (final c in _closingCtrls.values) {
      c.dispose();
    }
    _footerCtrl.dispose();
    _dunningIntroCtrl.dispose();
    _dunningClosingCtrl.dispose();
    _dunningReminder2DaysCtrl.dispose();
    _dunningReminder3DaysCtrl.dispose();
    _dunningFeeLevel1Ctrl.dispose();
    _dunningFeeLevel2Ctrl.dispose();
    _dunningFeeLevel3Ctrl.dispose();
    _dunningInterestRateCtrl.dispose();
    _smtpHostCtrl.dispose();
    _smtpPortCtrl.dispose();
    _smtpUsernameCtrl.dispose();
    _smtpFromAddressCtrl.dispose();
    _smtpFromNameCtrl.dispose();
    _smtpPasswordCtrl.dispose();
    _smtpInvoiceSubjectCtrl.dispose();
    _smtpInvoiceBodyCtrl.dispose();
    _smtpDunningSubjectCtrl.dispose();
    _smtpDunningBodyCtrl.dispose();
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
    bool? dunningEnabled,
    bool? smtpEnabled,
    bool? buchhaltungEnabled,
    bool? creditNotesEnabled,
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
            dunningEnabled: dunningEnabled ?? company.dunningEnabled,
            smtpEnabled: smtpEnabled ?? company.smtpEnabled,
            buchhaltungEnabled: buchhaltungEnabled ?? company.buchhaltungEnabled,
            creditNotesEnabled: creditNotesEnabled ?? company.creditNotesEnabled,
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
              pdfIntroTextCreditNote: Value(_textOrNull(_introCtrls[DocumentKind.creditNote]!)),
              pdfClosingTextCreditNote: Value(_textOrNull(_closingCtrls[DocumentKind.creditNote]!)),
              pdfFooterText: Value(_textOrNull(_footerCtrl)),
              pdfIntroTextDunning: Value(_textOrNull(_dunningIntroCtrl)),
              pdfClosingTextDunning: Value(_textOrNull(_dunningClosingCtrl)),
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

  /// C12 Mahnwesen — Nachbesserung (Kay-Feedback 2026-10-17): Fristen/
  /// Gebühren/Zins sind Kays eigene Werte, siehe ausführlichen Doc-
  /// Kommentar bei `DunningConfig` in `domain/services/dunning_service.dart`.
  /// Ungültige Eingaben werden nicht stillschweigend auf 0 gesetzt,
  /// sondern lehnen das Speichern mit einer Fehlermeldung ab — sonst
  /// könnte ein Tippfehler unbemerkt eine Gebühr auf 0 € zurücksetzen.
  Future<void> _saveDunningSettings() async {
    final reminder2Days = int.tryParse(_dunningReminder2DaysCtrl.text.trim());
    final reminder3Days = int.tryParse(_dunningReminder3DaysCtrl.text.trim());
    final interestRate =
        double.tryParse(_dunningInterestRateCtrl.text.trim().replaceAll(',', '.'));
    Money? fee1;
    Money? fee2;
    Money? fee3;
    try {
      fee1 = Money.fromEuroString(_dunningFeeLevel1Ctrl.text.trim());
      fee2 = Money.fromEuroString(_dunningFeeLevel2Ctrl.text.trim());
      fee3 = Money.fromEuroString(_dunningFeeLevel3Ctrl.text.trim());
    } catch (_) {
      fee1 = null;
    }
    if (reminder2Days == null ||
        reminder3Days == null ||
        interestRate == null ||
        fee1 == null ||
        fee2 == null ||
        fee3 == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bitte gültige Zahlen für Fristen/Gebühren/Zins eingeben.')),
      );
      return;
    }
    final service = context.read<ActiveCompanyService>();
    final company = service.active;
    if (company == null) return;
    setState(() => _dunningSettingsSaving = true);
    try {
      await context.read<CompanyRepository>().update(
            company.copyWith(
              dunningReminder2AfterDays: reminder2Days,
              dunningReminder3AfterDays: reminder3Days,
              dunningFeeLevel1Cents: fee1.cents,
              dunningFeeLevel2Cents: fee2.cents,
              dunningFeeLevel3Cents: fee3.cents,
              dunningInterestRatePercent: interestRate,
            ),
          );
      await service.refreshActive();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mahnwesen-Einstellungen gespeichert.')),
        );
      }
    } finally {
      if (mounted) setState(() => _dunningSettingsSaving = false);
    }
  }

  /// C7a SMTP-Versand (Kay-Nachfrage 2026-10-17). Speichert Verbindungs-
  /// daten + Betreff-/Text-Vorlagen — **nicht** das Passwort, das läuft
  /// getrennt über [_setSmtpPassword]/[_clearSmtpPassword].
  Future<void> _saveSmtpSettings() async {
    final port = int.tryParse(_smtpPortCtrl.text.trim());
    if (port == null || port <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bitte einen gültigen Port eingeben.')),
      );
      return;
    }
    final service = context.read<ActiveCompanyService>();
    final company = service.active;
    if (company == null) return;
    setState(() => _smtpSettingsSaving = true);
    try {
      await context.read<CompanyRepository>().update(
            company.copyWith(
              smtpHost: Value(_textOrNull(_smtpHostCtrl)),
              smtpPort: port,
              smtpUsername: Value(_textOrNull(_smtpUsernameCtrl)),
              smtpFromAddress: Value(_textOrNull(_smtpFromAddressCtrl)),
              smtpFromName: Value(_textOrNull(_smtpFromNameCtrl)),
              smtpUseTls: _smtpUseTls,
              smtpInvoiceSubjectTemplate: Value(_textOrNull(_smtpInvoiceSubjectCtrl)),
              smtpInvoiceBodyTemplate: Value(_textOrNull(_smtpInvoiceBodyCtrl)),
              smtpDunningSubjectTemplate: Value(_textOrNull(_smtpDunningSubjectCtrl)),
              smtpDunningBodyTemplate: Value(_textOrNull(_smtpDunningBodyCtrl)),
            ),
          );
      await service.refreshActive();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('SMTP-Einstellungen gespeichert.')),
        );
      }
    } finally {
      if (mounted) setState(() => _smtpSettingsSaving = false);
    }
  }

  Future<void> _setSmtpPassword() async {
    final password = _smtpPasswordCtrl.text;
    if (password.isEmpty) return;
    final company = context.read<ActiveCompanyService>().active;
    if (company == null) return;
    setState(() => _smtpPasswordSaving = true);
    try {
      await context.read<SmtpCredentialStore>().writePassword(company.id, password);
      if (mounted) {
        // Controller erst nach dem mounted-Check anfassen — ein schon
        // verworfener Controller wirft bei jedem Zugriff (siehe
        // email_send_dialog.dart für denselben Fehlerklasse-Fund).
        _smtpPasswordCtrl.clear();
        setState(() => _smtpHasPassword = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('SMTP-Passwort gespeichert.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('SMTP-Passwort konnte nicht gespeichert werden.')),
        );
      }
    } finally {
      if (mounted) setState(() => _smtpPasswordSaving = false);
    }
  }

  Future<void> _clearSmtpPassword() async {
    final company = context.read<ActiveCompanyService>().active;
    if (company == null) return;
    setState(() => _smtpPasswordSaving = true);
    try {
      await context.read<SmtpCredentialStore>().deletePassword(company.id);
      if (mounted) {
        setState(() => _smtpHasPassword = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('SMTP-Passwort gelöscht.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('SMTP-Passwort konnte nicht gelöscht werden.')),
        );
      }
    } finally {
      if (mounted) setState(() => _smtpPasswordSaving = false);
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
      if (company.creditNotesEnabled) DocumentKind.creditNote,
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
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Mahnwesen'),
                    value: company.dunningEnabled,
                    onChanged: _busy ? null : (value) => _setModule(dunningEnabled: value),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Versand (SMTP)'),
                    value: company.smtpEnabled,
                    onChanged: _busy ? null : (value) => _setModule(smtpEnabled: value),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Buchhaltung'),
                    value: company.buchhaltungEnabled,
                    onChanged: _busy ? null : (value) => _setModule(buchhaltungEnabled: value),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Gutschriften'),
                    value: company.creditNotesEnabled,
                    onChanged: _busy ? null : (value) => _setModule(creditNotesEnabled: value),
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
        // C12 Mahnwesen — Nachbesserung (Kay-Feedback 2026-10-17: "Wo
        // stelle ich die Gebühren und die Fristen ein?"). Eigene Sektion
        // statt in "Dokumenttexte", da hier auch Zahlenwerte (Fristen/
        // Gebühren/Zins) dazukommen, nicht nur Texte.
        if (company.dunningEnabled) ...[
          const SectionLabel('Mahnwesen'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Eigene Angaben — keine Rechtsprüfung, ob Frist/Gebühr/Zins im '
                      'Einzelfall zulässig sind (siehe Roadmap C12).',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _dunningReminder2DaysCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: '2. Mahnstufe ab (Tage)'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _dunningReminder3DaysCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: '3. Mahnstufe ab (Tage)'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _dunningFeeLevel1Ctrl,
                            decoration: const InputDecoration(labelText: 'Mahngebühr 1. Stufe (€)'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _dunningFeeLevel2Ctrl,
                            decoration: const InputDecoration(labelText: 'Mahngebühr 2. Stufe (€)'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _dunningFeeLevel3Ctrl,
                            decoration: const InputDecoration(labelText: 'Mahngebühr 3. Stufe (€)'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _dunningInterestRateCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Verzugszins (% pro Jahr, 0 = ohne Zins)',
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Mahnschreiben',
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _dunningIntroCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Einleitungstext (Mahnschreiben)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _dunningClosingCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Schlusstext (Mahnschreiben)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton(
                        onPressed: _dunningSettingsSaving ? null : _saveDunningSettings,
                        child: _dunningSettingsSaving
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
        ],
        // C7a SMTP-Versand (Kay-Nachfrage 2026-10-17: "Gibt es schon den
        // SMTP Versand? Wo konfiguriere ich den Betreff und den Body der
        // Mail?").
        if (company.smtpEnabled) ...[
          const SectionLabel('Versand (SMTP)'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Auf Android wird per echtem SMTP versendet. Im Web-Build ist das aus '
                      'technischen Gründen (kein Rohsocket-Zugriff im Browser) nicht möglich — '
                      'dort bleibt nur PDF herunterladen/teilen.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextField(
                            controller: _smtpHostCtrl,
                            decoration: const InputDecoration(labelText: 'SMTP-Server'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _smtpPortCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Port'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _smtpUsernameCtrl,
                      decoration: const InputDecoration(labelText: 'Benutzername'),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _smtpFromAddressCtrl,
                            decoration: const InputDecoration(labelText: 'Absenderadresse'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _smtpFromNameCtrl,
                            decoration: const InputDecoration(labelText: 'Absendername (optional)'),
                          ),
                        ),
                      ],
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Verschlüsselte Verbindung (STARTTLS/SSL)'),
                      value: _smtpUseTls,
                      onChanged: (value) => setState(() => _smtpUseTls = value),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _smtpPasswordCtrl,
                            obscureText: true,
                            decoration: InputDecoration(
                              labelText: 'Passwort',
                              helperText: _smtpHasPassword == null
                                  ? null
                                  : (_smtpHasPassword!
                                      ? 'Ein Passwort ist gespeichert.'
                                      : 'Kein Passwort gespeichert.'),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        TextButton(
                          onPressed: _smtpPasswordSaving ? null : _setSmtpPassword,
                          child: const Text('Speichern'),
                        ),
                        if (_smtpHasPassword == true)
                          TextButton(
                            onPressed: _smtpPasswordSaving ? null : _clearSmtpPassword,
                            child: const Text('Löschen'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Betreff/Text je Anlass — Platzhalter {{kunde}}, {{nummer}}, {{firma}} '
                      'werden beim Öffnen des Versanddialogs ersetzt, dort aber noch frei '
                      'editierbar.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    Text('Rechnung/Angebot/Auftrag', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _smtpInvoiceSubjectCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Betreff',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _smtpInvoiceBodyCtrl,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Text',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    if (company.dunningEnabled) ...[
                      const SizedBox(height: 16),
                      Text('Mahnschreiben', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _smtpDunningSubjectCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Betreff',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _smtpDunningBodyCtrl,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: 'Text',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton(
                        onPressed: _smtpSettingsSaving ? null : _saveSmtpSettings,
                        child: _smtpSettingsSaving
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
        ],
        const SectionLabel('Daten & Sicherung'),
        const BackupScreen(),
      ],
    );
  }
}
