import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Einfache Touch-Zeichenfläche für Unterschriften (C3-Rest, Nachtrag
/// 2026-10-21, Kay-Entscheidung auf Rückfrage: "Touch-Zeichenfläche in
/// der App"). **Bewusst kein Drittanbieter-Paket** — eine Unterschrift
/// ist technisch nur eine Reihe von Strichen, die sich mit Flutters
/// eigenem `CustomPainter`/`RenderRepaintBoundary` ohne zusätzliche
/// Abhängigkeit aufzeichnen und als PNG exportieren lassen. Liefert
/// über [SignaturePadController.exportPng] die fertigen Bild-Bytes.
///
/// **Keine qualifizierte elektronische Signatur** (eIDAS) — reine
/// Touch-Zeichnung ohne kryptographische Identitätsprüfung. Jede
/// Stelle, die das Ergebnis anzeigt oder in ein PDF einbettet, muss
/// diesen Hinweis mit ausgeben (siehe `TimeSheetDetailScreen`/
/// `time_sheet_pdf_builder.dart`).
class SignaturePadController extends ChangeNotifier {
  final List<List<Offset>> _strokes = [];
  List<Offset>? _currentStroke;
  final GlobalKey repaintBoundaryKey = GlobalKey();

  bool get isEmpty => _strokes.isEmpty;
  List<List<Offset>> get strokes => List.unmodifiable(_strokes);

  void startStroke(Offset point) {
    _currentStroke = [point];
    _strokes.add(_currentStroke!);
    notifyListeners();
  }

  void extendStroke(Offset point) {
    _currentStroke?.add(point);
    notifyListeners();
  }

  void endStroke() {
    _currentStroke = null;
  }

  void clear() {
    _strokes.clear();
    _currentStroke = null;
    notifyListeners();
  }

  /// Rendert die aktuelle Zeichenfläche als PNG. `null`, wenn noch
  /// nichts gezeichnet wurde (Aufrufer sollte das vorher über [isEmpty]
  /// prüfen, statt sich auf `null` zu verlassen).
  Future<Uint8List?> exportPng() async {
    if (isEmpty) return null;
    final boundary =
        repaintBoundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return null;
    final image = await boundary.toImage(pixelRatio: 2);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  }
}

class SignaturePad extends StatefulWidget {
  const SignaturePad({super.key, required this.controller});
  final SignaturePadController controller;

  @override
  State<SignaturePad> createState() => _SignaturePadState();
}

class _SignaturePadState extends State<SignaturePad> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: widget.controller.repaintBoundaryKey,
      child: Container(
        color: Colors.white,
        child: GestureDetector(
          onPanStart: (details) => widget.controller.startStroke(details.localPosition),
          onPanUpdate: (details) => widget.controller.extendStroke(details.localPosition),
          onPanEnd: (_) => widget.controller.endStroke(),
          child: CustomPaint(
            painter: _SignaturePainter(widget.controller.strokes),
            size: Size.infinite,
          ),
        ),
      ),
    );
  }
}

class _SignaturePainter extends CustomPainter {
  _SignaturePainter(this.strokes);
  final List<List<Offset>> strokes;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    for (final stroke in strokes) {
      for (var i = 0; i < stroke.length - 1; i++) {
        canvas.drawLine(stroke[i], stroke[i + 1], paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SignaturePainter oldDelegate) => true;
}

/// Fester Hinweistext (C3-Rest, Nachtrag 2026-10-21, Kay-Entscheidung
/// auf Rückfrage: "Fester Hinweistext: keine qualifizierte
/// elektronische Signatur") — überall anzuzeigen, wo eine Unterschrift
/// erfasst oder dargestellt wird.
const signatureDisclaimer =
    'Hinweis: Diese Unterschrift ist eine einfache Touch-Zeichnung, keine '
    'qualifizierte elektronische Signatur im Sinne der eIDAS-Verordnung.';

/// Unterschrift des Kunden erfassen — Dialog mit Zeichenfläche und festem
/// Hinweis, liefert das PNG oder `null` bei Abbruch. Das PNG wird
/// exportiert, solange die Zeichenfläche (und ihr `RepaintBoundary`)
/// noch im Baum steckt; nach `Navigator.pop()` lieferte `exportPng()`
/// nur noch `null`. `ListenableBuilder`, damit „Unterschreiben“ beim
/// Zeichnen freigeschaltet wird.
Future<Uint8List?> showSignatureDialog(BuildContext context) {
  final controller = SignaturePadController();
  return showDialog<Uint8List>(
    context: context,
    builder: (dialogContext) => ListenableBuilder(
      listenable: controller,
      builder: (context, _) => AlertDialog(
        title: const Text('Unterschrift des Kunden'),
        content: SizedBox(
          width: 420,
          height: 280,
          child: Column(
            children: [
              Expanded(
                child: DecoratedBox(
                  decoration: BoxDecoration(border: Border.all(color: Colors.grey)),
                  child: SignaturePad(controller: controller),
                ),
              ),
              const SizedBox(height: 8),
              const Text(signatureDisclaimer, style: TextStyle(fontSize: 11), textAlign: TextAlign.center),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => controller.clear(), child: const Text('Löschen')),
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Abbrechen')),
          FilledButton(
            onPressed: controller.isEmpty
                ? null
                : () async {
                    final bytes = await controller.exportPng();
                    if (dialogContext.mounted) Navigator.pop(dialogContext, bytes);
                  },
            child: const Text('Unterschreiben'),
          ),
        ],
      ),
    ),
  );
}
