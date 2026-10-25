import 'dart:convert';

import 'package:cryptography/cryptography.dart';

typedef EcadJson = Map<String, dynamic>;
String _canonical(EcadJson d) {
  Object? sort(Object? v) {
    if (v is Map) {
      final keys = v.keys.cast<String>().toList()..sort();
      return {for (final k in keys) k: sort(v[k])};
    }
    if (v is List) {
      final rows = [...v];
      if (rows.isNotEmpty && rows.every((x) => x is Map && x['id'] is String)) {
        rows.sort((a, b) => (a['id'] as String).compareTo(b['id']));
      }
      return rows.map(sort).toList();
    }
    return v;
  }

  return '${const JsonEncoder.withIndent('  ').convert(sort(d))}\n';
}

Future<String> _hash(EcadJson d) async => (await Sha256().hash(
  utf8.encode(_canonical(d)),
)).bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();

/// Read-only import plan. Loading replaces the previous plan; never appends rows.
class EcadMaterialPreview {
  EcadMaterialPreview._(this.packet);
  final EcadJson packet;
  String get packetId => packet['packetId'];
  List<EcadJson> get rows => (packet['items'] as List).cast<EcadJson>();
  static Future<EcadMaterialPreview> parse(String input) async {
    if (utf8.encode(input).length > 4194304) {
      throw const FormatException('Materialdatei maximal 4 MiB.');
    }
    final p = jsonDecode(input);
    if (p is! EcadJson ||
        p['schema'] != 'libre-ecad.material.v1' ||
        p['status'] != 'planned-unapproved' ||
        p['projectVersion'] is! int ||
        p['projectVersion'] < 1) {
      throw const FormatException('Unbekanntes Materialformat.');
    }
    for (final key in [
      'source',
      'projectId',
      'projectName',
      'packetId',
      'drawingSha256',
    ]) {
      if (p[key] is! String || p[key].isEmpty || p[key].length > 2000) {
        throw const FormatException('Projekt-/Quellangaben fehlen.');
      }
    }
    final content = <String, dynamic>{...p}..remove('packetId');
    if (await _hash(content) != p['packetId']) {
      throw const FormatException(
        'Paket-Prüfsumme stimmt nicht. Datei erneut aus LibreECAD exportieren.',
      );
    }
    if (p['items'] is! List ||
        p['items'].length > 500 ||
        p['unassigned'] is! List ||
        p['unassigned'].length > 500) {
      throw const FormatException('Zu viele Materialpositionen.');
    }
    final ids = <String>{}, devices = <String>{};
    for (final r in p['items']) {
      if (r is! EcadJson ||
          r['id'] is! String ||
          !ids.add(r['id']) ||
          r['unit'] != 'piece' ||
          r['quantity'] is! int ||
          r['quantity'] < 1 ||
          r['quantity'] > 500 ||
          r['articleVersion'] is! int ||
          r['articleVersion'] < 1 ||
          r['deviceIds'] is! List ||
          r['deviceIds'].length != r['quantity'] ||
          r['bmks'] is! List ||
          r['bmks'].length != r['quantity']) {
        throw const FormatException(
          'Ungültige oder doppelte Materialposition.',
        );
      }
      for (final key in [
        'articleId',
        'articleNumber',
        'name',
        'manufacturer',
        'variant',
        'origin',
        'license',
      ]) {
        if (r[key] is! String || r[key].length > 2000) {
          throw const FormatException('Ungültiger Artikeltext.');
        }
      }
      if (r['articleId'].isEmpty ||
          r['name'].isEmpty ||
          r['articleNumber'].isEmpty) {
        throw const FormatException('Artikelidentität fehlt.');
      }
      for (final id in r['deviceIds']) {
        if (id is! String || id.isEmpty || !devices.add(id)) {
          throw const FormatException('Gerät wird mehrfach gezählt.');
        }
      }
      if (r['bmks'].any((b) => b is! String || b.isEmpty || b.length > 160)) {
        throw const FormatException('Ungültige Betriebsmittelkennung.');
      }
      if (await _hash({
            'articleId': r['articleId'],
            'articleVersion': r['articleVersion'],
            'variant': r['variant'],
            'unit': r['unit'],
          }) !=
          r['id']) {
        throw const FormatException('Artikelpositions-ID stimmt nicht.');
      }
    }
    for (final u in p['unassigned']) {
      if (u is! EcadJson ||
          u['deviceId'] is! String ||
          !devices.add(u['deviceId']) ||
          u['bmk'] is! String ||
          u['label'] is! String ||
          u['reason'] is! String) {
        throw const FormatException('Ungültige nicht zugeordnete Position.');
      }
    }
    return EcadMaterialPreview._(p);
  }

  static bool pieceUnit(Object? unit) => [
    'stück',
    'stueck',
    'st',
    'stk',
    'piece',
    'pcs',
  ].contains('$unit'.trim().toLowerCase());

  /// Candidate names are suggestions only; caller must confirm a stable ERP ID.
  List<EcadJson> candidates(EcadJson row, List<EcadJson> articles) => articles
      .where(
        (a) =>
            pieceUnit(a['unit']) &&
            '${a['name']}'.trim().toLowerCase() ==
                (row['name'] as String).trim().toLowerCase(),
      )
      .toList();
}
