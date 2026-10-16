import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// Optionale Backup-Verschlüsselung mit einer **vom Nutzer gewählten
/// Passphrase** — bewusst **kein** gerätegebundener Schlüssel.
///
/// Ein gerätegebundener Schlüssel (F4-Ansatz für die laufende App selbst,
/// siehe `connection.dart`) würde ein Backup bei Geräteverlust/-wechsel
/// nutzlos machen — genau der Fall, für den ein Backup überhaupt
/// gedacht ist. Die Passphrase wird **nur** beim Export/Import abgefragt,
/// nicht für die normale App-Nutzung — kein Login-Zwang für die App
/// selbst (A0-Prinzip), nur ein Schutz für die exportierte Datei, die
/// das App-Sandbox-Verzeichnis verlässt.
class BackupEncryption {
  static const _magicUnencrypted = [0x57, 0x4B, 0x42, 0x31, 0x00]; // "WKB1" + 0x00
  static const _magicEncrypted = [0x57, 0x4B, 0x42, 0x31, 0x01]; // "WKB1" + 0x01
  static const _saltLength = 16;
  static const _iterations = 200000;
  static const _nonceLength = 12;
  static const _macLength = 16;

  static final _pbkdf2 = Pbkdf2.hmacSha256(iterations: _iterations, bits: 256);
  static final _cipher = AesGcm.with256bits();

  /// `passphrase == null` → Backup bleibt unverschlüsselt (nur mit dem
  /// Magic-Byte-Präfix markiert, damit [decryptIfNeeded] weiß, was zu
  /// tun ist).
  static Future<Uint8List> encryptIfRequested(Uint8List plainZip, String? passphrase) async {
    if (passphrase == null || passphrase.isEmpty) {
      return Uint8List.fromList([..._magicUnencrypted, ...plainZip]);
    }

    final salt = _randomBytes(_saltLength);
    final secretKey = await _pbkdf2.deriveKeyFromPassword(password: passphrase, nonce: salt);
    final secretBox = await _cipher.encrypt(plainZip, secretKey: secretKey);

    return Uint8List.fromList([
      ..._magicEncrypted,
      ...salt,
      ...secretBox.concatenation(nonce: true, mac: true),
    ]);
  }

  /// Wirft [FormatException] bei unbekanntem/beschädigtem Format und
  /// [SecretBoxAuthenticationError] bei falscher Passphrase — beides vor
  /// jeder Änderung an den Live-Daten abzufangen (A4: "kein stilles
  /// Überschreiben" bei einem ungültigen Import).
  static Future<Uint8List> decryptIfNeeded(Uint8List fileBytes, String? passphrase) async {
    if (fileBytes.length < 5) {
      throw const FormatException('Datei ist zu kurz, um ein gültiges Backup zu sein.');
    }
    final header = fileBytes.sublist(0, 5);
    final rest = fileBytes.sublist(5);

    if (_listEquals(header, _magicUnencrypted)) {
      return rest;
    }
    if (!_listEquals(header, _magicEncrypted)) {
      throw const FormatException('Unbekanntes Backup-Format (Kennung stimmt nicht).');
    }
    if (passphrase == null || passphrase.isEmpty) {
      throw const FormatException('Dieses Backup ist verschlüsselt — Passphrase erforderlich.');
    }
    if (rest.length < _saltLength + _nonceLength + _macLength) {
      throw const FormatException('Backup-Datei ist beschädigt (zu kurz für Salt/Nonce/MAC).');
    }

    final salt = rest.sublist(0, _saltLength);
    final boxBytes = rest.sublist(_saltLength);
    final secretKey = await _pbkdf2.deriveKeyFromPassword(password: passphrase, nonce: salt);
    final secretBox = SecretBox.fromConcatenation(
      boxBytes,
      nonceLength: _nonceLength,
      macLength: _macLength,
    );
    // Wirft SecretBoxAuthenticationError bei falscher Passphrase oder
    // manipulierten/beschädigten Daten — genau das gewünschte
    // Fehlverhalten statt stillschweigend falscher Bytes.
    final decrypted = await _cipher.decrypt(secretBox, secretKey: secretKey);
    return Uint8List.fromList(decrypted);
  }

  static Uint8List _randomBytes(int length) {
    final random = Random.secure();
    return Uint8List.fromList(List.generate(length, (_) => random.nextInt(256)));
  }

  static bool _listEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
