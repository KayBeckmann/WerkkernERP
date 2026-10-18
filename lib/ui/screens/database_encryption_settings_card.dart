import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/services/database_encryption_io.dart'
    show resolveDatabaseFilePath;
import '../../domain/services/database_encryption_service.dart';

/// F4-Verschlüsselung (Kay-Entscheidung 2026-10-19: "Verschlüsselung
/// soll optional sein und der User soll entscheiden ob ein Passwort
/// oder ein Geräteschlüssel verwendet wird"). Eigenständiger Baustein
/// in den Einstellungen unter "Daten & Sicherung" (gleiches Prinzip
/// wie `BackupScreen` dort) — bewusst NICHT firmenbezogen, gilt
/// geräteweit für die eine gemeinsame SQLite-Datei (A0).
///
/// Nach einer Änderung muss die App neu gestartet werden, damit die
/// laufende `AppDatabase`-Verbindung mit dem neuen Schlüssel neu
/// geöffnet wird — ein Hot-Swap der offenen Verbindung wäre deutlich
/// riskanter (laufende Transaktionen, Provider-Baum) als einmal neu
/// zu starten.
class DatabaseEncryptionSettingsCard extends StatefulWidget {
  const DatabaseEncryptionSettingsCard({super.key});

  @override
  State<DatabaseEncryptionSettingsCard> createState() =>
      _DatabaseEncryptionSettingsCardState();
}

class _DatabaseEncryptionSettingsCardState
    extends State<DatabaseEncryptionSettingsCard> {
  // Bewusst KEIN FutureBuilder/Ladezustand: `shared_preferences` hängt
  // sich in Widget-Tests ohne gemockten Plugin-Kanal auf (löst keine
  // Exception aus, die ein try/catch fangen könnte — der Future
  // schließt einfach nie ab). Ein FutureBuilder mit Lade-Spinner würde
  // dadurch jeden Test, der die Einstellungen öffnet, über
  // `pumpAndSettle()` in ein Timeout laufen lassen (unendlich
  // rotierender `CircularProgressIndicator` hält die Pump-Schleife am
  // Leben). Deshalb wie `ThemePreferenceService.load()`: optimistisch
  // mit "aus" starten, Feuer-und-vergiss-Nachladen per `setState()`,
  // sobald/falls es fertig ist.
  DbEncryptionConfig _config = DbEncryptionConfig.disabled;
  bool _busy = false;
  DbKeyType? _pendingKeyType;
  final _passwordCtrl = TextEditingController();
  final _passwordConfirmCtrl = TextEditingController();
  final _currentPasswordCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  void _loadConfig() {
    context
        .read<DatabaseEncryptionService>()
        .loadConfig()
        .then((config) {
          if (mounted) setState(() => _config = config);
        })
        .catchError((_) {
          // Bleibt bei DbEncryptionConfig.disabled.
        });
  }

  @override
  void dispose() {
    _passwordCtrl.dispose();
    _passwordConfirmCtrl.dispose();
    _currentPasswordCtrl.dispose();
    super.dispose();
  }

  void _reload() => _loadConfig();

  Future<void> _showRestartDialog() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Neustart erforderlich'),
        content: const Text(
          'Die Verschlüsselung wurde geändert. Bitte starte WerkkernERP jetzt neu, damit die '
          'Datenbank mit dem neuen Schlüssel geöffnet wird.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Verstanden'),
          ),
        ],
      ),
    );
  }

  Future<void> _apply({
    required bool newEnabled,
    required DbKeyType newKeyType,
  }) async {
    final service = context.read<DatabaseEncryptionService>();
    final oldKey = context.read<ActiveDbKey>().value;
    final newPassword = _passwordCtrl.text;

    if (newEnabled && newKeyType == DbKeyType.password) {
      if (newPassword.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bitte ein Passwort eingeben.')),
        );
        return;
      }
      if (newPassword != _passwordConfirmCtrl.text) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Die beiden Passwörter stimmen nicht überein.'),
          ),
        );
        return;
      }
    }

    setState(() => _busy = true);
    try {
      final dbPath = await resolveDatabaseFilePath();
      await service.applyChange(
        dbPath: dbPath,
        oldKey: oldKey,
        newEnabled: newEnabled,
        newKeyType: newKeyType,
        newPassword: newEnabled && newKeyType == DbKeyType.password
            ? newPassword
            : null,
      );
      _passwordCtrl.clear();
      _passwordConfirmCtrl.clear();
      _currentPasswordCtrl.clear();
      if (!mounted) return;
      _pendingKeyType = null;
      _reload();
      // _busy schon HIER zurücksetzen, nicht erst im finally-Block
      // unten — die eigentliche Arbeit (Migration + Speichern) ist
      // bereits abgeschlossen; der Button soll während des
      // Neustart-Dialogs nicht weiter einen Lade-Spinner zeigen (ein
      // endlos drehender `CircularProgressIndicator` würde
      // `pumpAndSettle()` in Widget-Tests sonst nie zur Ruhe kommen
      // lassen, solange der Dialog offen ist).
      setState(() => _busy = false);
      await _showRestartDialog();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Fehler: $e')));
      }
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'Datenbank-Verschlüsselung ist in der Web-Vorschau nicht verfügbar — nur auf Android.',
        ),
      );
    }

    final config = _config;
    final selectedType = _pendingKeyType ?? config.keyType;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Optional (F4) — standardmäßig aus. Verschlüsselt die lokale Datenbankdatei mit '
            'SQLite3MultipleCiphers. Entweder ein gerätegebundener Schlüssel (kein Passwort '
            'nötig, aber an dieses Gerät gebunden) oder ein eigenes Passwort (musst du bei '
            'jedem App-Start eingeben — verloren bedeutet verloren, es gibt keine '
            'Wiederherstellung ohne das Passwort).',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Datenbank verschlüsseln'),
            value: config.enabled,
            onChanged: _busy
                ? null
                : (value) {
                    if (!value) {
                      _apply(newEnabled: false, newKeyType: config.keyType);
                    } else {
                      setState(() => _pendingKeyType = DbKeyType.device);
                    }
                  },
          ),
          if (config.enabled || _pendingKeyType != null) ...[
            const SizedBox(height: 8),
            SegmentedButton<DbKeyType>(
              segments: const [
                ButtonSegment(
                  value: DbKeyType.device,
                  label: Text('Geräteschlüssel'),
                ),
                ButtonSegment(
                  value: DbKeyType.password,
                  label: Text('Passwort'),
                ),
              ],
              selected: {selectedType},
              onSelectionChanged: _busy
                  ? null
                  : (selection) =>
                        setState(() => _pendingKeyType = selection.first),
            ),
            if (selectedType == DbKeyType.password) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _passwordCtrl,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Neues Passwort'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _passwordConfirmCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Passwort bestätigen',
                ),
              ),
            ],
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                onPressed: _busy
                    ? null
                    : () => _apply(newEnabled: true, newKeyType: selectedType),
                child: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Übernehmen'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
