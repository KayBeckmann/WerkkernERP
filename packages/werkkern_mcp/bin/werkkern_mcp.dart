import 'dart:convert';
import 'dart:io';

import 'package:werkkern_client/werkkern_client.dart';
import 'package:werkkern_mcp/werkkern_mcp.dart';

/// MCP-stdio-Server. Konfiguration über Umgebungsvariablen:
///   WERKKERN_URL          z. B. https://erp.example.org
///   WERKKERN_AGENT_TOKEN  in der App unter "KI-Zugang" erzeugt (wka_…)
/// Ausgabe auf stdout ist ausschließlich das Protokoll; Hinweise gehen
/// nach stderr.
Future<void> main() async {
  final url = Platform.environment['WERKKERN_URL'];
  final token = Platform.environment['WERKKERN_AGENT_TOKEN'];
  if (url == null || token == null || !token.startsWith('wka_')) {
    stderr.writeln('WERKKERN_URL und WERKKERN_AGENT_TOKEN (wka_…) müssen gesetzt sein.');
    exit(64);
  }
  final client = WerkkernApiClient(baseUrl: Uri.parse(url))..token = token;
  final server = WerkkernMcpServer(client);
  await for (final line in stdin.transform(utf8.decoder).transform(const LineSplitter())) {
    if (line.trim().isEmpty) continue;
    Map<String, Object?>? response;
    try {
      response = await server.handle(jsonDecode(line) as Map<String, Object?>);
    } on FormatException {
      response = {
        'jsonrpc': '2.0',
        'id': null,
        'error': {'code': -32700, 'message': 'Parse error'},
      };
    }
    if (response != null) stdout.writeln(jsonEncode(response));
  }
  client.close();
}
