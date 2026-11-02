import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/services/active_company_service.dart';
import 'backup_screen.dart';
import 'migration_wizard_screen.dart';

/// Dünner Wrapper, der [BackupScreen] (bewusst inhaltsreine Karte, kein
/// eigenes AppBar/Scaffold — siehe dort) zu einer eigenen Unterseite
/// macht (Nachtrag 2026-10-18: "Die Einstellungen müssen aufgeräumt
/// werden" — in Unterseiten aufgeteilt).
class SettingsBackupScreen extends StatelessWidget {
  const SettingsBackupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Daten & Sicherung')),
      body: ListView(
        children: [
          const BackupScreen(),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Die Firma wächst? Alle Daten einmalig auf einen WerkkernERP-Server umziehen und dort mit '
                          'mehreren Mitarbeitern weiterarbeiten.',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                          key: const Key('migration-open'),
                          onPressed: () {
                            final company = context.read<ActiveCompanyService>().active;
                            if (company == null) return;
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(builder: (_) => MigrationWizardScreen(company: company)),
                            );
                          },
                          icon: const Icon(Icons.cloud_upload_outlined),
                          label: const Text('Auf Server umziehen'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
