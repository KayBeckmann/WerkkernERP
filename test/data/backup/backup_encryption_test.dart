import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:werkkernerp/data/backup/backup_encryption.dart';

void main() {
  final plain = Uint8List.fromList(utf8.encode('Testinhalt eines Backups — äöüß€'));

  test('Unverschlüsseltes Backup (keine Passphrase) lässt sich wieder entschlüsseln', () async {
    final encoded = await BackupEncryption.encryptIfRequested(plain, null);
    final decoded = await BackupEncryption.decryptIfNeeded(encoded, null);
    expect(decoded, plain);
  });

  test(
    'A4-Abnahme: mit Passphrase verschlüsseltes Backup lässt sich nur mit derselben '
    'Passphrase wiederherstellen',
    () async {
      final encoded = await BackupEncryption.encryptIfRequested(plain, 'mein-geheimnis-123');
      final decoded = await BackupEncryption.decryptIfNeeded(encoded, 'mein-geheimnis-123');
      expect(decoded, plain);
    },
  );

  test('Falsche Passphrase schlägt mit einem Authentifizierungsfehler fehl, nicht mit falschen Bytes', () async {
    final encoded = await BackupEncryption.encryptIfRequested(plain, 'richtig');
    expect(
      () => BackupEncryption.decryptIfNeeded(encoded, 'falsch'),
      throwsA(isA<SecretBoxAuthenticationError>()),
    );
  });

  test('Verschlüsseltes Backup ohne Passphrase-Angabe beim Import schlägt verständlich fehl', () async {
    final encoded = await BackupEncryption.encryptIfRequested(plain, 'richtig');
    expect(
      () => BackupEncryption.decryptIfNeeded(encoded, null),
      throwsFormatException,
    );
  });

  test('Beschädigte/fremde Datei wird als ungültiges Format erkannt, nicht als Daten interpretiert', () async {
    final garbage = Uint8List.fromList(utf8.encode('Das ist keine Backup-Datei.'));
    expect(() => BackupEncryption.decryptIfNeeded(garbage, null), throwsFormatException);
  });

  test('Zu kurze Datei wird klar abgelehnt', () async {
    expect(() => BackupEncryption.decryptIfNeeded(Uint8List(2), null), throwsFormatException);
  });
}
