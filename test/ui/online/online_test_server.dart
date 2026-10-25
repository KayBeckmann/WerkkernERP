import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:werkkern_client/werkkern_client.dart';
import 'package:werkkernerp_server/src/business/repository_memory.dart';
import 'package:werkkernerp_server/src/mail.dart';
import 'package:werkkernerp_server/src/repository_memory.dart';
import 'package:werkkernerp_server/src/router.dart';

/// Echter Server-Router (In-Memory) hinter einem MockClient — keine
/// Sockets, daher in `testWidgets` (FakeAsync) zuverlässig.
class OnlineTestServer {
  /// Versendete Mails (statt SMTP) — für Versand-Tests.
  final mailTransport = RecordingMailTransport();

  late final handler = PhaseBRouter(
    repository: InMemoryPhaseBRepository(),
    business: InMemoryBusinessRepository(),
    mail: MailService(transport: mailTransport, secrets: SecretSealer(List<int>.filled(32, 7))),
  ).handler;

  /// Funkloch simulieren: jede Anfrage scheitert wie ohne Netz.
  bool offline = false;

  late final http.Client httpClient = MockClient((request) async {
    if (offline) throw http.ClientException('Netz weg');
    final response = await handler(shelf.Request(
      request.method,
      Uri.parse('http://localhost${request.url.path}${request.url.hasQuery ? '?${request.url.query}' : ''}'),
      body: request.body,
      headers: request.headers,
    ));
    return http.Response.bytes(await response.read().expand((b) => b).toList(), response.statusCode,
        headers: response.headers);
  });

  WerkkernApiClient client() => WerkkernApiClient(baseUrl: Uri.parse('http://localhost'), httpClient: httpClient);

  Future<Map<String, Object?>> _call(String method, String path, Object body, [String? token]) async {
    final response = await handler(shelf.Request(
      method,
      Uri.parse('http://localhost$path'),
      body: jsonEncode(body),
      headers: {if (token != null) 'authorization': 'Bearer $token'},
    ));
    final text = await response.readAsString();
    return text.isEmpty ? {} : jsonDecode(text) as Map<String, Object?>;
  }

  /// Legt Nutzer + Firma an; die Gruppe des Nutzers bekommt [permissions].
  /// Liefert ein firmengebundenes Admin-Token für weitere Vorbereitung.
  Future<String> seedCompany({
    required String email,
    required String companyName,
    List<String> permissions = const [],
  }) async {
    await _call('POST', '/auth/register', {'email': email, 'password': 'passwort-12345'});
    Future<String> identity() async =>
        (await _call('POST', '/auth/login', {'email': email, 'password': 'passwort-12345'}))['identityToken'] as String;
    final companyId = (await _call('POST', '/companies', {'identityToken': await identity(), 'name': companyName}))['companyId'] as String;
    final token = (await _call('POST', '/auth/select-company', {'identityToken': await identity(), 'companyId': companyId}))['token'] as String;
    final response = await handler(shelf.Request('GET', Uri.parse('http://localhost/me'), headers: {'authorization': 'Bearer $token'}));
    final groupId = (jsonDecode(await response.readAsString()) as Map)['groupId'] as String;
    // Startgruppen kommen mit Standardrechten — für exakte Testrechte leeren.
    final existing = await _call('GET', '/groups/$groupId/permissions', const {}, token);
    for (final p in (existing['permissions'] as List).cast<String>()) {
      await _call('PUT', '/groups/$groupId/permissions/$p', {'granted': false}, token);
    }
    for (final p in permissions) {
      await _call('PUT', '/groups/$groupId/permissions/$p', {'granted': true}, token);
    }
    return token;
  }

  Future<Map<String, Object?>> post(String path, Object body, String token) => _call('POST', path, body, token);
  Future<Map<String, Object?>> put(String path, Object body, String token) => _call('PUT', path, body, token);
}
