bool get encryptionSupported => false;

Never _unsupported() => throw UnsupportedError(
      'Datenbank-Verschlüsselung ist in der Web-Vorschau nicht verfügbar — '
      'das ist nur Kays LAN-Testvorschau, nicht Teil der Android-Offline-'
      'Roadmap (F4 ist ausdrücklich ein Android-Punkt).',
    );

Future<String> resolveDatabaseFilePath() async => _unsupported();

Future<void> rekeyDatabaseFile({
  required String path,
  String? oldKey,
  String? newKey,
}) async =>
    _unsupported();

Future<bool> verifyDatabaseKey({required String path, String? key}) async => _unsupported();
