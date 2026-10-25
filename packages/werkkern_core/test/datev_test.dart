import 'package:test/test.dart';
import 'package:werkkern_core/werkkern_core.dart';

void main() {
  test('encodeDatevAnsi: Umlaute bleiben Latin-1, € und Gedankenstrich stürzen nicht ab', () {
    expect(encodeDatevAnsi('Kabel – 10 € für Müller'), 'Kabel - 10 EUR für Müller'.codeUnits);
    expect(encodeDatevAnsi('ß'), [0xDF]);
    expect(encodeDatevAnsi('漢'), [0x3F]);
  });
}
