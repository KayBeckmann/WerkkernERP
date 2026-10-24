import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:werkkern_client/werkkern_client.dart';

export 'offline_vault_web.dart' if (dart.library.io) 'offline_vault_native.dart';

/// Rohe Byte-Ablage (Datei auf dem Gerät) — plattformabhängig, siehe
/// `offline_vault_native.dart`.
abstract class OfflineBlobStore {
  Future<Uint8List?> read();
  Future<void> write(Uint8List bytes);
  Future<void> delete();
}

/// Ablage des Geräteschlüssels.
abstract class OfflineKeyStore {
  Future<String?> read();
  Future<void> write(String value);
  Future<void> delete();
}

class SecureOfflineKeyStore implements OfflineKeyStore {
  SecureOfflineKeyStore({FlutterSecureStorage? storage}) : _storage = storage ?? const FlutterSecureStorage();
  final FlutterSecureStorage _storage;
  static const _key = 'online_offline_cache_key';

  @override
  Future<String?> read() => _storage.read(key: _key);
  @override
  Future<void> write(String value) => _storage.write(key: _key, value: value);
  @override
  Future<void> delete() => _storage.delete(key: _key);
}

/// Der Inhalt passt nicht zum Schlüssel (z. B. nach Neuinstallation
/// ohne Keystore-Schlüssel) oder ist beschädigt — nie stillschweigend
/// falsche Daten liefern.
class OfflineVaultUnreadable implements Exception {
  const OfflineVaultUnreadable(this.message);
  final String message;
  @override
  String toString() => message;
}

/// B2 Punkt 2 "verschlüsselter Geräte-Cache": AES-256-GCM mit einem
/// **gerätegebundenen** Zufallsschlüssel (Android Keystore über
/// `flutter_secure_storage`) — kein Passwort-Zwang. Der Server bleibt
/// maßgeblich: bei Geräteverlust sperrt der Admin die Mitgliedschaft,
/// die Kopie auf dem verlorenen Gerät ist ohne dessen Keystore nicht
/// lesbar.
class EncryptedOfflineVault implements OfflineVault {
  EncryptedOfflineVault({required this.blobs, required this.keys});
  final OfflineBlobStore blobs;
  final OfflineKeyStore keys;

  static const _magic = [0x57, 0x4B, 0x4F, 0x31]; // "WKO1"
  static final _cipher = AesGcm.with256bits();
  static final _random = Random.secure();

  Future<SecretKey> _key({required bool create}) async {
    final stored = await keys.read();
    if (stored != null) return SecretKey(base64Decode(stored));
    if (!create) throw const OfflineVaultUnreadable('Kein Geräteschlüssel für den Offline-Bestand vorhanden.');
    final bytes = List<int>.generate(32, (_) => _random.nextInt(256));
    await keys.write(base64Encode(bytes));
    return SecretKey(bytes);
  }

  @override
  Future<String?> read() async {
    final bytes = await blobs.read();
    if (bytes == null) return null;
    if (bytes.length < _magic.length + 12 + 16 || !_startsWithMagic(bytes)) {
      throw const OfflineVaultUnreadable('Offline-Bestand ist beschädigt.');
    }
    try {
      final box = SecretBox.fromConcatenation(bytes.sublist(_magic.length), nonceLength: 12, macLength: 16);
      final plain = await _cipher.decrypt(box, secretKey: await _key(create: false));
      return utf8.decode(plain);
    } on SecretBoxAuthenticationError {
      throw const OfflineVaultUnreadable('Offline-Bestand passt nicht zum Geräteschlüssel oder ist beschädigt.');
    }
  }

  @override
  Future<void> write(String content) async {
    final box = await _cipher.encrypt(utf8.encode(content), secretKey: await _key(create: true));
    await blobs.write(Uint8List.fromList([..._magic, ...box.concatenation()]));
  }

  @override
  Future<void> clear() async {
    await blobs.delete();
    // Neuer Schlüssel beim nächsten Schreiben — alte Kopien (z. B. aus
    // einem Gerätebackup) bleiben damit dauerhaft unlesbar.
    await keys.delete();
  }

  bool _startsWithMagic(Uint8List bytes) {
    for (var i = 0; i < _magic.length; i++) {
      if (bytes[i] != _magic[i]) return false;
    }
    return true;
  }
}
