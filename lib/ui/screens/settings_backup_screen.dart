import 'package:flutter/material.dart';

import 'backup_screen.dart';

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
      body: const BackupScreen(),
    );
  }
}
