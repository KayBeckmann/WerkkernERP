import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

/// C15.4 E-Rechnung — gemeinsame Bedienelemente für Offline- und
/// Online-Editor: Prüfergebnis anzeigen, Warnung vor dem Finalisieren,
/// XML speichern.

/// Hinweis, der vor dem Finalisieren nie zählt (die Nummer entsteht erst dabei).
const _notYetFinalized = 'Dokument ist noch nicht finalisiert (keine Nummer).';

List<String> problemsBeforeFinalize(List<String> problems) =>
    problems.where((p) => p != _notYetFinalized).toList();

/// Ergebnis der Prüfung als Dialog — „bereit“ oder Liste fehlender Angaben.
Future<void> showEInvoiceCheckDialog(
  BuildContext context, {
  required String formatLabel,
  required List<String> problems,
}) =>
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('E-Rechnung prüfen'),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Format: $formatLabel'),
                const SizedBox(height: 12),
                if (problems.isEmpty)
                  const Text('Alle Pflichtangaben vorhanden — die E-Rechnung kann erzeugt werden.')
                else ...[
                  const Text('Es fehlen Angaben:'),
                  const SizedBox(height: 4),
                  for (final p in problems)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('• $p', style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
                    ),
                  const SizedBox(height: 12),
                  const Text(
                    'Firmendaten unter Einstellungen → Firmendaten, Kundendaten im Kundenstamm ergänzen.',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
      ),
    );

/// Vor dem Finalisieren: fehlende Pflichtangaben anzeigen, aber nicht
/// blockieren (Kay entscheidet). `true` = trotzdem finalisieren.
Future<bool> confirmFinalizeDespiteEInvoiceProblems(BuildContext context, List<String> problems) async {
  if (problems.isEmpty) return true;
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('E-Rechnung unvollständig'),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Für die E-Rechnung fehlen Angaben:'),
              for (final p in problems) Padding(padding: const EdgeInsets.only(top: 4), child: Text('• $p')),
              const SizedBox(height: 12),
              const Text(
                'Ohne diese Angaben entsteht nach dem Finalisieren nur ein normales PDF ohne eingebettete '
                'E-Rechnung. Die beim Finalisieren eingefrorenen Daten lassen sich danach nicht mehr ändern.',
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Abbrechen')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Trotzdem finalisieren')),
      ],
    ),
  );
  return result == true;
}

/// XML über den Dateidialog speichern (Android: Speicherort wählen, Web: Download).
Future<void> saveEInvoiceXml(BuildContext context, Uint8List bytes, String fileName) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    final saved = await FilePicker.saveFile(fileName: fileName, bytes: bytes, dialogTitle: 'E-Rechnung speichern');
    if (saved == null) return;
    messenger.showSnackBar(SnackBar(content: Text('$fileName gespeichert.')));
  } on Exception {
    messenger.showSnackBar(const SnackBar(content: Text('E-Rechnung konnte nicht gespeichert werden.')));
  }
}
