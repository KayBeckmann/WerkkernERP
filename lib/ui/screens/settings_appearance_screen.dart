import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/services/theme_preference_service.dart';

/// "Darstellung" als eigene Unterseite (Nachtrag 2026-10-18: "Die
/// Einstellungen müssen aufgeräumt werden" — Kay-Entscheidung: in
/// Unterseiten aufteilen, wie ein typisches App-Einstellungsmenü,
/// statt einer immer länger werdenden einzelnen Seite).
class SettingsAppearanceScreen extends StatelessWidget {
  const SettingsAppearanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themePreference = context.watch<ThemePreferenceService>();
    return Scaffold(
      appBar: AppBar(title: const Text('Darstellung')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
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
        ],
      ),
    );
  }
}
