import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:werkkernerp/domain/services/ecad_material_preview.dart';

void main() {
  final input = File(
    'test/fixtures/libre_ecad_material.json',
  ).readAsStringSync();
  test(
    'reads actual LibreECAD export, reload replaces instead of duplicating',
    () async {
      final a = await EcadMaterialPreview.parse(input);
      final b = await EcadMaterialPreview.parse(input);
      expect(a.packetId, b.packetId);
      expect(a.rows, hasLength(3));
      expect(b.rows, a.rows);
      expect(a.rows.fold<int>(0, (n, r) => n + (r['quantity'] as int)), 3);
      final row = a.rows.first;
      expect(
        a
            .candidates(row, [
              {'id': 'a', 'name': row['name'], 'unit': 'Stk'},
              {'id': 'b', 'name': row['name'], 'unit': 'm'},
              {'id': 'c', 'name': 'different', 'unit': 'piece'},
            ])
            .map((v) => v['id']),
        ['a'],
      );
    },
  );
  test('rejects altered amounts, duplicate rows and unknown schemas', () async {
    for (final edit in <void Function(Map<String, dynamic>)>[
      (p) => p['items'][0]['quantity'] = 2,
      (p) => p['items'].add(p['items'][0]),
      (p) => p['schema'] = 'unknown',
      (p) => p['items'][0]['unit'] = 'm',
    ]) {
      final packet = jsonDecode(input) as Map<String, dynamic>;
      edit(packet);
      await expectLater(
        EcadMaterialPreview.parse(jsonEncode(packet)),
        throwsFormatException,
      );
    }
    await expectLater(EcadMaterialPreview.parse('[]'), throwsFormatException);
  });
}
