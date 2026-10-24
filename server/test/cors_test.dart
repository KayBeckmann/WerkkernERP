import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:test/test.dart';
import 'package:werkkernerp_server/src/repository_memory.dart';
import 'package:werkkernerp_server/src/router.dart';

void main() {
  Future<(HttpServer, Uri)> serve(Set<String> origins) async {
    final router = PhaseBRouter(repository: InMemoryPhaseBRepository(), corsAllowedOrigins: origins);
    final server = await shelf_io.serve(router.handler.call, 'localhost', 0);
    return (server, Uri.parse('http://localhost:${server.port}'));
  }

  test('Erlaubter Origin: Preflight 204 mit CORS-Headern, normale Antwort trägt sie ebenfalls', () async {
    final (server, base) = await serve({'http://lan:8085'});
    addTearDown(() => server.close(force: true));
    final preflight = await http.Response.fromStream(
      await (http.Request('OPTIONS', base.resolve('/customers'))..headers['origin'] = 'http://lan:8085').send(),
    );
    expect(preflight.statusCode, 204);
    expect(preflight.headers['access-control-allow-origin'], 'http://lan:8085');
    expect(preflight.headers['access-control-allow-headers'], contains('authorization'));
    final health = await http.get(base.resolve('/health'), headers: {'origin': 'http://lan:8085'});
    expect(health.headers['access-control-allow-origin'], 'http://lan:8085');
  });

  test('Fremder Origin bekommt keine CORS-Header; ohne Konfiguration gar keine', () async {
    final (server, base) = await serve({'http://lan:8085'});
    addTearDown(() => server.close(force: true));
    final foreign = await http.get(base.resolve('/health'), headers: {'origin': 'http://evil.example'});
    expect(foreign.headers.containsKey('access-control-allow-origin'), isFalse);

    final (plain, plainBase) = await serve({});
    addTearDown(() => plain.close(force: true));
    final none = await http.get(plainBase.resolve('/health'), headers: {'origin': 'http://lan:8085'});
    expect(none.headers.containsKey('access-control-allow-origin'), isFalse);
  });
}
