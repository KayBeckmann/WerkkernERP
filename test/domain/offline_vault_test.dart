import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:werkkernerp/domain/services/offline_vault.dart';
import 'package:werkkernerp/domain/services/offline_vault_native.dart';

class _MemoryKeys implements OfflineKeyStore {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String v) async => value = v;
  @override
  Future<void> delete() async => value = null;
}

void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('offline_vault_test'));
  tearDown(() => dir.deleteSync(recursive: true));

  test('Rundreise über eine echte Datei; der Dateiinhalt enthält keinen Klartext', () async {
    final keys = _MemoryKeys();
    final vault = EncryptedOfflineVault(blobs: FileOfflineBlobStore(dir), keys: keys);
    const secret = '{"customer":"Baustelle Meyer","notes":"Schlüssel unter der Matte"}';
    await vault.write(secret);
    expect(await vault.read(), secret);

    final raw = File('${dir.path}/online_offline_bestand.bin').readAsBytesSync();
    expect(latin1.decode(raw, allowInvalid: true), isNot(contains('Meyer')));
    expect(utf8.decode(raw.sublist(0, 4)), 'WKO1');
    expect(File('${dir.path}/online_offline_bestand.bin.tmp').existsSync(), isFalse, reason: 'atomar geschrieben');
  });

  test('Fremder/verlorener Schlüssel oder beschädigte Datei -> OfflineVaultUnreadable statt falscher Daten', () async {
    final vault = EncryptedOfflineVault(blobs: FileOfflineBlobStore(dir), keys: _MemoryKeys());
    await vault.write('{"a":1}');

    final otherDevice = EncryptedOfflineVault(blobs: FileOfflineBlobStore(dir), keys: _MemoryKeys()..value = base64Encode(List.filled(32, 7)));
    await expectLater(otherDevice.read(), throwsA(isA<OfflineVaultUnreadable>()));

    final noKey = EncryptedOfflineVault(blobs: FileOfflineBlobStore(dir), keys: _MemoryKeys());
    await expectLater(noKey.read(), throwsA(isA<OfflineVaultUnreadable>()));

    final file = File('${dir.path}/online_offline_bestand.bin');
    final bytes = file.readAsBytesSync();
    bytes[bytes.length - 1] ^= 0xFF;
    file.writeAsBytesSync(Uint8List.fromList(bytes));
    await expectLater(vault.read(), throwsA(isA<OfflineVaultUnreadable>()));
  });

  test('clear() löscht Datei UND Schlüssel; leerer Bestand liest null', () async {
    final keys = _MemoryKeys();
    final vault = EncryptedOfflineVault(blobs: FileOfflineBlobStore(dir), keys: keys);
    await vault.write('{}');
    await vault.clear();
    expect(keys.value, isNull);
    expect(await vault.read(), isNull);
  });
}
