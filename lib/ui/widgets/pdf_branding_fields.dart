import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:werkkern_core/werkkern_core.dart' show validatePdfLogo;

/// Gemeinsame Bedienelemente für Logo, Layout und dreispaltige Fußzeile —
/// offline (`SettingsDocumentTextsScreen`, `SettingsCompanyScreen`) und
/// online (`OnlineAdminScreen`) identisch (Parität offline/online,
/// Nachtrag 26.11.2026). [keyPrefix] hält die Widget-Schlüssel je Modus
/// unterscheidbar (`online-` bzw. leer).

/// Vorbelegung der Spalten nur, solange nie Spalten gespeichert wurden.
String footerEditorInitialText(Map<String, String?>? columns, String side, String defaultText) =>
    columns == null ? defaultText : columns[side] ?? '';

/// Standardtexte der drei Spalten (wie der automatische Briefbogen-Fuß).
const footerColumnDefaults = {
  'left': '{{companyName}}\n{{address}}',
  'center': 'IBAN: {{iban}}',
  'right': 'Steuernummer: {{taxNumber}}',
};

const pdfLayoutLabels = {
  'classic': 'Klassisches Layout',
  'nordLetterhead': 'Nord-Impuls-Briefbogen',
};

/// Datei wählen, Größe begrenzen und den Inhalt tatsächlich dekodieren.
/// Liefert Base64 oder `null` (abgebrochen bzw. ungültig — dann mit Hinweis).
Future<String?> pickPdfLogo(BuildContext context) async {
  final messenger = ScaffoldMessenger.of(context);
  void fail(String text) => messenger.showSnackBar(SnackBar(content: Text(text)));
  final files = await FilePicker.pickFiles(
    dialogTitle: 'PDF-Logo wählen',
    type: FileType.custom,
    allowedExtensions: ['png', 'jpg', 'jpeg'],
  );
  if (files.isEmpty) return null;
  final buffer = BytesBuilder(copy: false);
  await for (final chunk in files.first.readAsByteStream()) {
    if (buffer.length + chunk.length > 1024 * 1024) {
      fail('Logo darf höchstens 1 MiB groß sein.');
      return null;
    }
    buffer.add(chunk);
  }
  final encoded = base64Encode(buffer.takeBytes());
  try {
    validatePdfLogo(encoded);
  } on FormatException {
    fail('Logo muss ein gültiges PNG/JPEG mit höchstens 2048 × 2048 Pixeln sein.');
    return null;
  }
  return encoded;
}

/// Vorschau, Hochladen/Ersetzen und Entfernen des PDF-Kopflogos.
class PdfLogoField extends StatelessWidget {
  const PdfLogoField({
    super.key,
    required this.logoBase64,
    required this.onChanged,
    this.enabled = true,
    this.keyPrefix = '',
  });

  final String? logoBase64;
  final ValueChanged<String?> onChanged;
  final bool enabled;
  final String keyPrefix;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('PDF-Kopflogo (PNG/JPEG, maximal 1 MiB und 2048 × 2048 Pixel; '
              'ohne Logo bleibt der klassische Kopf erhalten).'),
          if (logoBase64 != null)
            Image.memory(
              key: Key('${keyPrefix}pdf-logo-preview'),
              base64Decode(logoBase64!),
              width: 180,
              height: 55,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => const Text('Ungültiges Bild – anderes Logo wählen.'),
            ),
          Wrap(spacing: 8, children: [
            OutlinedButton.icon(
              key: Key('${keyPrefix}pdf-logo-upload'),
              onPressed: enabled
                  ? () async {
                      final logo = await pickPdfLogo(context);
                      if (logo != null) onChanged(logo);
                    }
                  : null,
              icon: const Icon(Icons.image_outlined),
              label: Text(logoBase64 == null ? 'Logo hochladen' : 'Logo ersetzen'),
            ),
            if (logoBase64 != null)
              TextButton(
                key: Key('${keyPrefix}pdf-logo-remove'),
                onPressed: enabled ? () => onChanged(null) : null,
                child: const Text('Logo entfernen'),
              ),
          ]),
        ],
      );
}

/// Schalter und drei Textfelder der dreispaltigen Fußzeile.
class FooterColumnsEditor extends StatelessWidget {
  const FooterColumnsEditor({
    super.key,
    required this.enabled,
    required this.onEnabledChanged,
    required this.controllers,
    this.keyPrefix = '',
  });

  final bool enabled;
  final ValueChanged<bool> onEnabledChanged;

  /// Je Seite (`left`, `center`, `right`) ein Controller.
  final Map<String, TextEditingController> controllers;
  final String keyPrefix;

  static const _labels = {'left': 'Links', 'center': 'Mitte', 'right': 'Rechts'};

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            key: Key('${keyPrefix}footer-columns-enabled'),
            contentPadding: EdgeInsets.zero,
            title: const Text('Dreispaltige PDF-Fußzeile'),
            subtitle: const Text('Ersetzt die bisherige Fußzeile; im Nord-Briefbogen auch die automatisch '
                'gesetzten Firmen-/Bank-/Steuerdaten.'),
            value: enabled,
            onChanged: onEnabledChanged,
          ),
          if (enabled) ...[
            const Text('Platzhalter: {{companyName}}, {{address}}, {{iban}}, {{bic}}, {{taxNumber}}, {{vatId}}, '
                '{{customerName}}, {{customerAddress}}, {{documentNumber}}. Zeilen mit fehlenden Werten entfallen.'),
            for (final side in _labels.keys)
              TextField(
                key: Key('${keyPrefix}footer-$side'),
                controller: controllers[side],
                maxLines: 3,
                decoration: InputDecoration(labelText: _labels[side]),
              ),
          ],
        ],
      );
}
