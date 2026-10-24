/// Format aller Dokumentnummern (`R-JJxxx`, mit Projekt `R-JJPPxxx`) —
/// gemeinsam für Offline-App und Server, damit beide exakt dieselben
/// Nummern erzeugen. Der Zähler hat mindestens drei Stellen und wächst
/// darüber hinaus ohne Begrenzung (F5), z. B. `R-261000`.
String formatNumberWithPrefix({
  required String prefix,
  required int year,
  required int number,
  int? projectNumber,
}) {
  final shortYear = (year % 100).toString().padLeft(2, '0');
  final paddedNumber = number.toString().padLeft(3, '0');
  final ppPart = projectNumber == null ? '' : projectNumber.toString().padLeft(2, '0');
  return '$prefix-$shortYear$ppPart$paddedNumber';
}

/// Präfix je Dokumentart, Schlüssel = Name des `DocumentKind`-Enums der
/// Offline-App (`invoice`, `quote`, ...). Gutschrift "G" eigener Kreis
/// (Kay-Entscheidung 2026-10-19).
const documentNumberPrefixes = <String, String>{
  'invoice': 'R',
  'quote': 'An',
  'order': 'A',
  'deliveryNote': 'LS',
  'proforma': 'PF',
  'creditNote': 'G',
};

/// Erlaubte Umwandlungen (Quelle -> Ziele), Schlüssel = `DocumentKind`-
/// Name. Gemeinsame Quelle für Offline-App und Server. Rechnung,
/// Lieferschein und Gutschrift sind nie Quelle einer Umwandlung
/// (Gutschriften entstehen über einen eigenen Weg aus der Rechnung).
const documentConversionTargets = <String, Set<String>>{
  'quote': {'order', 'deliveryNote', 'invoice'},
  'order': {'deliveryNote', 'invoice'},
  'proforma': {'invoice'},
};
