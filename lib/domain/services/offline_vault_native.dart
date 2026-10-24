import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'offline_vault.dart';

/// Offline-Bestand ist auf Android/Desktop verfügbar.
const offlineCacheSupported = true;

/// Datei im App-Dokumentenverzeichnis, atomar geschrieben (erst Temp-
/// Datei, dann rename — wie `writeDatabaseFile()` beim Restore).
class FileOfflineBlobStore implements OfflineBlobStore {
  FileOfflineBlobStore([this._directory]);
  final Directory? _directory;

  Future<File> _file() async {
    final dir = _directory ?? await getApplicationDocumentsDirectory();
    return File(p.join(dir.path, 'online_offline_bestand.bin'));
  }

  @override
  Future<Uint8List?> read() async {
    final file = await _file();
    return await file.exists() ? file.readAsBytes() : null;
  }

  @override
  Future<void> write(Uint8List bytes) async {
    final file = await _file();
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsBytes(bytes, flush: true);
    await tmp.rename(file.path);
  }

  @override
  Future<void> delete() async {
    final file = await _file();
    if (await file.exists()) await file.delete();
  }
}

OfflineBlobStore? createDeviceOfflineBlobStore() => FileOfflineBlobStore();
