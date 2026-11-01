import 'package:flutter/material.dart';
import 'package:werkkern_client/werkkern_client.dart';

import 'app.dart';

/// Server-Adresse: im Container reicht nginx `/api/` an den Server
/// weiter (gleicher Origin). Für die Entwicklung überschreibbar:
/// `flutter run -d chrome --dart-define=WERKKERN_API=http://localhost:8190`.
const _apiOverride = String.fromEnvironment('WERKKERN_API');

void main() {
  final api = _apiOverride.isNotEmpty ? Uri.parse(_apiOverride) : Uri.base.resolve('api');
  runApp(SuperadminApp(clientFactory: () => WerkkernApiClient(baseUrl: api)));
}
