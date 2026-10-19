import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/services/active_company_service.dart';
import 'settings_appearance_screen.dart';
import 'settings_backup_screen.dart';
import 'settings_document_texts_screen.dart';
import 'settings_dunning_screen.dart';
import 'settings_encryption_screen.dart';
import 'settings_modules_screen.dart';
import 'settings_smtp_screen.dart';
import 'settings_tax_screen.dart';

/// Einstellungen der aktiven Firma — reine Menüseite (Nachtrag
/// 2026-10-18: "Die Einstellungen müssen aufgeräumt werden". Kay-
/// Entscheidung auf Rückfrage: "In Unterseiten aufteilen... wie ein
/// typisches App-Einstellungsmenü"). Jeder frühere Abschnitt
/// (Darstellung, Module, Umsatzsteuer, Dokumenttexte, Mahnwesen,
/// SMTP, Daten & Sicherung, Verschlüsselung) ist jetzt eine eigene
/// Unterseite mit eigenem State/Controllern statt alles auf einer
/// immer länger werdenden Seite zu sammeln.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final company = context.watch<ActiveCompanyService>().active;
    if (company == null) return const SizedBox.shrink();

    return ListView(
      children: [
        _MenuTile(
          icon: Icons.palette_outlined,
          title: 'Darstellung',
          subtitle: 'Hell/Dunkel/System',
          onTap: () => _push(context, const SettingsAppearanceScreen()),
        ),
        _MenuTile(
          icon: Icons.extension_outlined,
          title: 'Module',
          subtitle: 'Angebote, Aufträge, Buchhaltung, Gutschriften …',
          onTap: () => _push(context, const SettingsModulesScreen()),
        ),
        _MenuTile(
          icon: Icons.receipt_long_outlined,
          title: 'Umsatzsteuer',
          subtitle: 'Kleinunternehmer nach § 19 UStG',
          onTap: () => _push(context, const SettingsTaxScreen()),
        ),
        _MenuTile(
          icon: Icons.description_outlined,
          title: 'Dokumenttexte',
          subtitle: 'Einleitung/Schluss je Dokumentart, Fußzeile',
          onTap: () => _push(context, const SettingsDocumentTextsScreen()),
        ),
        if (company.dunningEnabled)
          _MenuTile(
            icon: Icons.notifications_active_outlined,
            title: 'Mahnwesen',
            subtitle: 'Fristen, Gebühren, Zins, Mahnschreiben',
            onTap: () => _push(context, const SettingsDunningScreen()),
          ),
        if (company.smtpEnabled)
          _MenuTile(
            icon: Icons.outgoing_mail,
            title: 'Versand (SMTP)',
            subtitle: 'Server, Zugangsdaten, E-Mail-Vorlagen',
            onTap: () => _push(context, const SettingsSmtpScreen()),
          ),
        _MenuTile(
          icon: Icons.save_outlined,
          title: 'Daten & Sicherung',
          subtitle: 'Backup erstellen/wiederherstellen',
          onTap: () => _push(context, const SettingsBackupScreen()),
        ),
        _MenuTile(
          icon: Icons.lock_outline,
          title: 'Datenbank-Verschlüsselung',
          subtitle: 'Optional — Geräteschlüssel oder Passwort',
          onTap: () => _push(context, const SettingsEncryptionScreen()),
        ),
      ],
    );
  }

  void _push(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
