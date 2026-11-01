import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Secure Storage hat in `flutter test` keinen Plattformkanal — ohne
/// Mock warten Bildschirme mit Standard-Ablage (z. B. gemerkte
/// Online-Konten) ewig. Jede Testdatei startet mit leerer Ablage.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  FlutterSecureStorage.setMockInitialValues({});
  await testMain();
}
