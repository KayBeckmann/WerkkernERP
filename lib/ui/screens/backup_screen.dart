import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/backup/backup_service.dart';

/// Backup erstellen/wiederherstellen (A4) — lokal, kein automatischer
/// Cloud-Upload. Nur auf Android/Desktop verfügbar; im Web-Build (Kays
/// LAN-Vorschau) bewusst nicht angeboten.
class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  bool _busy = false;

  Future<String?> _askPassphrase({required bool forExport}) {
    return showDialog<String>(
      context: context,
      builder: (context) => _PassphraseDialog(forExport: forExport),
    );
  }

  Future<void> _createBackup() async {
    final passphrase = await _askPassphrase(forExport: true);
    if (passphrase == null || !mounted) return; // Dialog abgebrochen

    setState(() => _busy = true);
    try {
      final service = context.read<BackupService>();
      final bytes = await service.createBackup(passphrase: passphrase.isEmpty ? null : passphrase);
      final timestamp = DateTime.now().toIso8601String().replaceAll(RegExp('[:.]'), '-');
      // Audit-Befund 2026-10-17 (Abweichungen.md Abschnitt 2.2): die
      // Rückgabe von saveFile() wurde bisher nicht geprüft, bevor
      // "Backup erstellt" erschien — ein abgebrochener Dateidialog
      // (Rückgabe `null`) zeigte fälschlich einen Erfolg an.
      final savedUri = await FilePicker.saveFile(
        fileName: 'werkkernerp-backup-$timestamp.wkbackup',
        bytes: bytes,
        dialogTitle: 'Backup speichern',
      );
      if (!mounted) return;
      if (savedUri == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Speichern abgebrochen — kein Backup erstellt.')),
        );
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Backup erstellt.')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Backup fehlgeschlagen: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restoreBackup() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Backup wiederherstellen?'),
        content: const Text(
          'Die aktuellen Daten werden durch den Inhalt des Backups ersetzt. '
          'Diese Aktion kann nicht rückgängig gemacht werden. Fahre erst fort, '
          'wenn du dir sicher bist.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Abbrechen')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Fortfahren'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final result = await FilePicker.pickFiles(dialogTitle: 'Backup-Datei wählen');
    if (result.isEmpty || !mounted) return;
    final Uint8List bytes;
    try {
      bytes = await result.first.readAsBytes();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Datei konnte nicht gelesen werden: $e')),
        );
      }
      return;
    }

    final passphrase = await _askPassphrase(forExport: false);
    if (passphrase == null || !mounted) return;

    setState(() => _busy = true);
    try {
      final service = context.read<BackupService>();
      final backupResult = await service.restoreBackup(
        bytes,
        passphrase: passphrase.isEmpty ? null : passphrase,
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('Wiederherstellung abgeschlossen'),
          content: Text(
            'Backup vom ${backupResult.exportedAt.toLocal().toString().split('.').first} '
            'wurde eingespielt. Bitte starte die App jetzt neu, damit die wiederhergestellten '
            'Daten geladen werden.',
          ),
          actions: [
            FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('Verstanden')),
          ],
        ),
      );
    } on RestoreWriteException catch (e) {
      // Audit-Befund 2026-10-17 (Abweichungen.md Abschnitt 2.2): dieser
      // Fehler tritt NACH dem Schließen der aktiven Verbindung auf —
      // die alte Datei ist dank atomarem Austausch unangetastet, aber
      // die App braucht einen Neustart, bevor überhaupt wieder
      // gearbeitet werden kann. "Daten sind unverändert" allein wäre
      // hier irreführend, ohne den nötigen Neustart zu erwähnen.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    } catch (e) {
      // Validierung in restoreBackup() läuft vollständig VOR jedem
      // Eingriff in die Live-Daten (inkl. Schließen der Verbindung) —
      // ein Fehler hier bedeutet wirklich uneingeschränkt, dass die
      // aktuellen Daten unverändert sind UND die App normal weiterläuft.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Wiederherstellung fehlgeschlagen: $e. Deine Daten sind unverändert.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Backup/Wiederherstellung ist in der Web-Vorschau nicht verfügbar — '
            'nur auf Android.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Lokales Backup — keine automatische Cloud-Sicherung. '
                    'Die exportierte Datei zusätzlich extern aufzubewahren liegt in deiner '
                    'Verantwortung.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _busy ? null : _createBackup,
                    icon: const Icon(Icons.backup_outlined),
                    label: const Text('Backup erstellen'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _restoreBackup,
                    icon: const Icon(Icons.restore_outlined),
                    label: const Text('Backup wiederherstellen'),
                  ),
                  if (_busy)
                    const Padding(
                      padding: EdgeInsets.only(top: 24),
                      child: CircularProgressIndicator(),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PassphraseDialog extends StatefulWidget {
  const _PassphraseDialog({required this.forExport});
  final bool forExport;

  @override
  State<_PassphraseDialog> createState() => _PassphraseDialogState();
}

class _PassphraseDialogState extends State<_PassphraseDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.forExport ? 'Backup verschlüsseln?' : 'Passphrase eingeben'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.forExport
                ? 'Optional: Passphrase zum Schutz der Backup-Datei. Ohne Passphrase ist '
                    'die Datei unverschlüsselt lesbar. Es gibt keine Möglichkeit, eine '
                    'vergessene Passphrase wiederherzustellen.'
                : 'Falls das Backup verschlüsselt ist, hier die Passphrase eingeben — '
                    'sonst leer lassen.',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Passphrase (optional)'),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          child: const Text('Weiter'),
        ),
      ],
    );
  }
}
