import 'offline_vault.dart';

/// Im Web-Build (nur LAN-Vorschau) bewusst kein Offline-Bestand —
/// gleiches Prinzip wie Backup/Restore und F4: Browser-Speicher ist
/// kein vertrauenswürdiger, gerätegebundener Schlüsselspeicher.
const offlineCacheSupported = false;

OfflineBlobStore? createDeviceOfflineBlobStore() => null;
