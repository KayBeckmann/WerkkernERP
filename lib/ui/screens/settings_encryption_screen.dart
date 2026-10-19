import 'package:flutter/material.dart';

import 'database_encryption_settings_card.dart';

/// Dünner Wrapper, der [DatabaseEncryptionSettingsCard] zu einer
/// eigenen Unterseite macht (Nachtrag 2026-10-18: "Die Einstellungen
/// müssen aufgeräumt werden" — in Unterseiten aufgeteilt).
class SettingsEncryptionScreen extends StatelessWidget {
  const SettingsEncryptionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Datenbank-Verschlüsselung')),
      body: const SingleChildScrollView(
        child: Card(
          margin: EdgeInsets.all(12),
          child: DatabaseEncryptionSettingsCard(),
        ),
      ),
    );
  }
}
