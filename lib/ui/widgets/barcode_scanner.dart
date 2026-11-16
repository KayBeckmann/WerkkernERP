import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// A1/C5.5-Nachtrag (Kay, 16.11.2026): Barcode erfassen — per Kamera
/// (Android, Web mit Kamera) oder per Eingabe (Handscanner als Tastatur,
/// Geräte ohne Kamera). Liefert den Code als Text oder `null` bei Abbruch.
/// In Tests ersetzbar (gleiches Muster wie `phoneLauncher`).
Future<String?> Function(BuildContext context) barcodeScanner = _scanWithCamera;

Future<String?> _scanWithCamera(BuildContext context) =>
    Navigator.of(context).push<String>(MaterialPageRoute(builder: (_) => const _BarcodeScanPage()));

class _BarcodeScanPage extends StatefulWidget {
  const _BarcodeScanPage();

  @override
  State<_BarcodeScanPage> createState() => _BarcodeScanPageState();
}

class _BarcodeScanPageState extends State<_BarcodeScanPage> {
  final _manual = TextEditingController();
  final _controller = MobileScannerController(detectionSpeed: DetectionSpeed.noDuplicates);
  bool _done = false;

  @override
  void dispose() {
    _manual.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _finish(String? code) {
    final value = code?.trim();
    if (_done || value == null || value.isEmpty) return;
    _done = true;
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Barcode scannen')),
      body: Column(
        children: [
          Expanded(
            child: MobileScanner(
              controller: _controller,
              onDetect: (capture) => _finish(capture.barcodes.firstOrNull?.rawValue),
              errorBuilder: (context, error) => const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Kamera nicht verfügbar. Code bitte unten eingeben oder mit einem Handscanner erfassen.',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              key: const Key('barcode-manual'),
              controller: _manual,
              decoration: InputDecoration(
                labelText: 'Code eingeben',
                suffixIcon: IconButton(
                  tooltip: 'Übernehmen',
                  icon: const Icon(Icons.check),
                  onPressed: () => _finish(_manual.text),
                ),
              ),
              onSubmitted: _finish,
            ),
          ),
        ],
      ),
    );
  }
}

/// Eingabefeld „Barcode“ mit Scan-Knopf (Artikelstamm offline und online).
class BarcodeField extends StatelessWidget {
  const BarcodeField({super.key, required this.controller, this.errorText});
  final TextEditingController controller;
  final String? errorText;

  @override
  Widget build(BuildContext context) => TextField(
        key: const Key('article-barcode'),
        controller: controller,
        decoration: InputDecoration(
          labelText: 'Barcode (optional)',
          helperText: 'Code der Verpackung — nur zur Erkennung, keine Menge.',
          errorText: errorText,
          suffixIcon: IconButton(
            tooltip: 'Barcode scannen',
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: () async {
              final code = await barcodeScanner(context);
              if (code != null) controller.text = code;
            },
          ),
        ),
      );
}
