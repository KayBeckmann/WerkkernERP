import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:shelf/shelf.dart';

/// Gemeinsame Eingabehilfen der Fachmodule.
Future<Map<String, Object?>> readJsonBody(Request request) async {
  final raw = await request.readAsString();
  if (raw.isEmpty) return const {};
  final decoded = jsonDecode(raw);
  if (decoded is! Map<String, Object?>) throw const FormatException('JSON-Objekt erwartet');
  return decoded;
}

/// Getrimmter Text oder `null` (leer/fehlend).
String? trimmedOrNull(Object? value) {
  final s = (value is String ? value : null)?.trim();
  return (s == null || s.isEmpty) ? null : s;
}

/// Dezimalzahl als String ("2.5"); Komma wird akzeptiert. `null` bei
/// leer, [FormatException] bei Unsinn.
String? decimalOrNull(Object? value) {
  if (value == null) return null;
  final text = value is num ? value.toString() : trimmedOrNull(value)?.replaceAll(',', '.');
  if (text == null) return null;
  final parsed = Decimal.tryParse(text);
  if (parsed == null) throw FormatException('Keine Zahl: $value');
  return parsed.toString();
}

/// Datum `JJJJ-MM-TT` als UTC-Mitternacht, sonst `null`.
DateTime? dateOrNull(Object? value) {
  final text = trimmedOrNull(value);
  if (text == null || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(text)) return null;
  final parsed = DateTime.tryParse('${text}T00:00:00Z');
  return parsed;
}

String dateJson(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
