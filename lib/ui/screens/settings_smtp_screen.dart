import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/repositories/company_repository.dart';
import '../../domain/services/active_company_service.dart';
import '../../domain/services/smtp_credential_store.dart';

/// "Versand (SMTP)" als eigene Unterseite (Nachtrag 2026-10-18: "Die
/// Einstellungen müssen aufgeräumt werden" — in Unterseiten
/// aufgeteilt). C7a SMTP-Versand (Kay-Nachfrage 2026-10-17).
class SettingsSmtpScreen extends StatefulWidget {
  const SettingsSmtpScreen({super.key});

  @override
  State<SettingsSmtpScreen> createState() => _SettingsSmtpScreenState();
}

class _SettingsSmtpScreenState extends State<SettingsSmtpScreen> {
  late final TextEditingController _hostCtrl;
  late final TextEditingController _portCtrl;
  late final TextEditingController _usernameCtrl;
  late final TextEditingController _fromAddressCtrl;
  late final TextEditingController _fromNameCtrl;
  late final TextEditingController _passwordCtrl;
  late final TextEditingController _invoiceSubjectCtrl;
  late final TextEditingController _invoiceBodyCtrl;
  late final TextEditingController _dunningSubjectCtrl;
  late final TextEditingController _dunningBodyCtrl;
  bool _useTls = true;
  bool _settingsSaving = false;
  bool _passwordSaving = false;
  bool? _hasPassword;

  @override
  void initState() {
    super.initState();
    final company = context.read<ActiveCompanyService>().active;
    _hostCtrl = TextEditingController(text: company?.smtpHost);
    _portCtrl = TextEditingController(text: (company?.smtpPort ?? 587).toString());
    _usernameCtrl = TextEditingController(text: company?.smtpUsername);
    _fromAddressCtrl = TextEditingController(text: company?.smtpFromAddress);
    _fromNameCtrl = TextEditingController(text: company?.smtpFromName);
    _passwordCtrl = TextEditingController();
    _invoiceSubjectCtrl = TextEditingController(text: company?.smtpInvoiceSubjectTemplate);
    _invoiceBodyCtrl = TextEditingController(text: company?.smtpInvoiceBodyTemplate);
    _dunningSubjectCtrl = TextEditingController(text: company?.smtpDunningSubjectTemplate);
    _dunningBodyCtrl = TextEditingController(text: company?.smtpDunningBodyTemplate);
    _useTls = company?.smtpUseTls ?? true;
    if (company != null) {
      // Lesen aus dem Secure Storage ist asynchron — erst nach dem
      // ersten Frame nachladen, nicht den synchronen initState
      // blockieren.
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadPasswordState(company.id));
    }
  }

  Future<void> _loadPasswordState(String companyId) async {
    try {
      final hasPassword = await context.read<SmtpCredentialStore>().hasPassword(companyId);
      if (mounted) setState(() => _hasPassword = hasPassword);
    } catch (_) {
      // Secure Storage kann auf manchen Plattformen/Testumgebungen ohne
      // registrierten Platform-Channel fehlschlagen — dann bleibt der
      // Zustand unbekannt (`null`, von der UI bereits als "nicht
      // anzeigen" behandelt) statt die ganze Seite abstürzen zu lassen.
    }
  }

  @override
  void dispose() {
    _hostCtrl.dispose();
    _portCtrl.dispose();
    _usernameCtrl.dispose();
    _fromAddressCtrl.dispose();
    _fromNameCtrl.dispose();
    _passwordCtrl.dispose();
    _invoiceSubjectCtrl.dispose();
    _invoiceBodyCtrl.dispose();
    _dunningSubjectCtrl.dispose();
    _dunningBodyCtrl.dispose();
    super.dispose();
  }

  String? _textOrNull(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();

  Future<void> _saveSettings() async {
    final port = int.tryParse(_portCtrl.text.trim());
    if (port == null || port <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bitte einen gültigen Port eingeben.')),
      );
      return;
    }
    final service = context.read<ActiveCompanyService>();
    final company = service.active;
    if (company == null) return;
    setState(() => _settingsSaving = true);
    try {
      await context.read<CompanyRepository>().update(
            company.copyWith(
              smtpHost: Value(_textOrNull(_hostCtrl)),
              smtpPort: port,
              smtpUsername: Value(_textOrNull(_usernameCtrl)),
              smtpFromAddress: Value(_textOrNull(_fromAddressCtrl)),
              smtpFromName: Value(_textOrNull(_fromNameCtrl)),
              smtpUseTls: _useTls,
              smtpInvoiceSubjectTemplate: Value(_textOrNull(_invoiceSubjectCtrl)),
              smtpInvoiceBodyTemplate: Value(_textOrNull(_invoiceBodyCtrl)),
              smtpDunningSubjectTemplate: Value(_textOrNull(_dunningSubjectCtrl)),
              smtpDunningBodyTemplate: Value(_textOrNull(_dunningBodyCtrl)),
            ),
          );
      await service.refreshActive();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('SMTP-Einstellungen gespeichert.')),
        );
      }
    } finally {
      if (mounted) setState(() => _settingsSaving = false);
    }
  }

  Future<void> _setPassword() async {
    final password = _passwordCtrl.text;
    if (password.isEmpty) return;
    final company = context.read<ActiveCompanyService>().active;
    if (company == null) return;
    setState(() => _passwordSaving = true);
    try {
      await context.read<SmtpCredentialStore>().writePassword(company.id, password);
      if (mounted) {
        // Controller erst nach dem mounted-Check anfassen — ein schon
        // verworfener Controller wirft bei jedem Zugriff.
        _passwordCtrl.clear();
        setState(() => _hasPassword = true);
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
      if (mounted) setState(() => _passwordSaving = false);
    }
  }

  Future<void> _clearPassword() async {
    final company = context.read<ActiveCompanyService>().active;
    if (company == null) return;
    setState(() => _passwordSaving = true);
    try {
      await context.read<SmtpCredentialStore>().deletePassword(company.id);
      if (mounted) {
        setState(() => _hasPassword = false);
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
      if (mounted) setState(() => _passwordSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final company = context.watch<ActiveCompanyService>().active;
    if (company == null) return const Scaffold(body: SizedBox.shrink());

    return Scaffold(
      appBar: AppBar(title: const Text('Versand (SMTP)')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
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
                          controller: _hostCtrl,
                          decoration: const InputDecoration(labelText: 'SMTP-Server'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _portCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Port'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _usernameCtrl,
                    decoration: const InputDecoration(labelText: 'Benutzername'),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _fromAddressCtrl,
                          decoration: const InputDecoration(labelText: 'Absenderadresse'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _fromNameCtrl,
                          decoration: const InputDecoration(labelText: 'Absendername (optional)'),
                        ),
                      ),
                    ],
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Verschlüsselte Verbindung (STARTTLS/SSL)'),
                    value: _useTls,
                    onChanged: (value) => setState(() => _useTls = value),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _passwordCtrl,
                          obscureText: true,
                          decoration: InputDecoration(
                            labelText: 'Passwort',
                            helperText: _hasPassword == null
                                ? null
                                : (_hasPassword!
                                    ? 'Ein Passwort ist gespeichert.'
                                    : 'Kein Passwort gespeichert.'),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      TextButton(
                        onPressed: _passwordSaving ? null : _setPassword,
                        child: const Text('Speichern'),
                      ),
                      if (_hasPassword == true)
                        TextButton(
                          onPressed: _passwordSaving ? null : _clearPassword,
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
                    controller: _invoiceSubjectCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Betreff',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _invoiceBodyCtrl,
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
                      controller: _dunningSubjectCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Betreff',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _dunningBodyCtrl,
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
                      onPressed: _settingsSaving ? null : _saveSettings,
                      child: _settingsSaving
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
        ],
      ),
    );
  }
}
