import 'package:test/test.dart';
import 'package:werkkern_core/werkkern_core.dart';

void main() {
  test('Startformat R-JJxxx mit mindestens drei Stellen', () {
    expect(formatNumberWithPrefix(prefix: 'R', year: 2026, number: 54), 'R-26054');
  });

  test('Zähler wächst über 999 hinaus ohne Überlauf (F5)', () {
    expect(formatNumberWithPrefix(prefix: 'R', year: 2026, number: 1000), 'R-261000');
  });

  test('Projektnummer PP wird zweistellig zwischen Jahr und Zähler eingefügt (C2)', () {
    expect(formatNumberWithPrefix(prefix: 'An', year: 2026, number: 7, projectNumber: 3), 'An-2603007');
  });

  test('Jede Dokumentart hat ein eigenes Präfix', () {
    expect(documentNumberPrefixes.values.toSet(), hasLength(documentNumberPrefixes.length));
  });
}
