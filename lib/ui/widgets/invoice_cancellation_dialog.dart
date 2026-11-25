import 'package:flutter/material.dart';

Future<bool> confirmInvoiceCancellation(BuildContext context, String number) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rechnung stornieren?'),
        content: Text(
          'Für Rechnung $number wird ein endgültiger Stornobeleg im Gutschriften-Nummernkreis erstellt. '
          'Die ursprüngliche Rechnung bleibt erhalten. Lagerbestände und bereits erfolgte Zahlungen werden nicht verändert. '
          'Anschließend kannst du die Rechnung kopieren, den Entwurf bearbeiten und neu ausstellen.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Abbrechen')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Jetzt stornieren')),
        ],
      ),
    ) ??
    false;
