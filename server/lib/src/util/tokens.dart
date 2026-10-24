import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

/// Opake Tokens, serverseitig nur als Hash gespeichert — gleiches
/// Prinzip wie bei LibreECAD (siehe ADR-0001: kein JWT, sofort
/// widerrufbar).
class Tokens {
  Tokens._();

  static final _random = Random.secure();

  static String generate() {
    final bytes = List<int>.generate(32, (_) => _random.nextInt(256));
    return base64Url.encode(bytes);
  }

  static String hashOf(String rawToken) => sha256.convert(utf8.encode(rawToken)).toString();
}
