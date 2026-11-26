import 'dart:convert';

/// PDF-Layouts, die eine Firma wählen kann — offline wie online dieselben
/// Namen (Server-Spalte `pdf_layout`, lokale Spalte `pdfLayout`).
const pdfLayoutNames = {'classic', 'nordLetterhead'};

/// Unbekannte oder fehlende Namen (Altbelege) gelten als `classic`.
String normalizePdfLayout(String? name) => pdfLayoutNames.contains(name) ? name! : 'classic';

/// Spalten der dreispaltigen Fußzeile in Anzeigereihenfolge.
const footerColumnSides = ['left', 'center', 'right'];

/// Lokale Speicherform der dreispaltigen Fußzeile (JSON-Text). `null`
/// bleibt `null` = bisherige einspaltige Fußzeile.
String? encodeFooterColumns(Map<String, String?>? columns) => columns == null
    ? null
    : jsonEncode({for (final side in footerColumnSides) side: columns[side]});

/// Gegenstück zu [encodeFooterColumns]; beschädigte Werte ergeben `null`
/// statt eines Fehlers beim PDF-Erzeugen.
Map<String, String?>? decodeFooterColumns(String? encoded) {
  if (encoded == null) return null;
  try {
    final raw = jsonDecode(encoded);
    if (raw is! Map) return null;
    return {for (final side in footerColumnSides) side: raw[side] is String ? raw[side] as String : null};
  } on FormatException {
    return null;
  }
}
