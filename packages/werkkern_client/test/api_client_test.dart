import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';
import 'package:werkkern_client/werkkern_client.dart';

/// Reine Client-Tests (ohne Server) — der Vertrag gegen den echten
/// Router steckt in `server/test/client_contract_test.dart`.
void main() {
  test('archive client parses metadata and forwards bounded page query', () async {
    final client = WerkkernApiClient(baseUrl: Uri.parse('https://erp.example/api'),
      httpClient: MockClient((request) async {
        expect(request.url.toString(), 'https://erp.example/api/pdf-archive/versions?limit=2&offset=3');
        return http.Response(jsonEncode({'versions': [
          {'sourceType': 'document', 'sourceId': 'd1', 'version': 2,
           'createdAt': '2026-01-01T00:00:00Z', 'sha256': 'abc', 'sizeBytes': 42}
        ], 'limit': 2, 'offset': 3, 'hasMore': true}), 200);
      }));
    final page = await client.browsePdfArchive(limit: 2, offset: 3);
    expect(page.versions.single.sourceId, 'd1');
    expect(page.versions.single.sizeBytes, 42);
    expect(page.hasMore, isTrue);
    expect(page.offset, 3);
  });
  test('Bearer-Token wird nach selectCompany mitgesendet, Basis-Pfad bleibt erhalten', () async {
    final seen = <http.Request>[];
    final client = WerkkernApiClient(
      baseUrl: Uri.parse('https://erp.example.org/api'),
      httpClient: MockClient((request) async {
        seen.add(request);
        if (request.url.path == '/api/auth/select-company') return http.Response(jsonEncode({'token': 't-123'}), 200);
        return http.Response(jsonEncode({'customers': []}), 200);
      }),
    );
    await client.selectCompany('id', 'c1');
    await client.customers(query: 'mü');
    expect(seen.last.url.toString(), 'https://erp.example.org/api/customers?q=m%C3%BC');
    expect(seen.last.headers['authorization'], 'Bearer t-123');
  });

  test('Serverfehler wird zu ApiException mit Meldung, Umlaute bleiben korrekt (UTF-8)', () async {
    final client = WerkkernApiClient(
      baseUrl: Uri.parse('http://x'),
      httpClient: MockClient((_) async => http.Response.bytes(
            utf8.encode(jsonEncode({'error': 'Dokument wurde zwischenzeitlich geändert.'})),
            409,
          )),
    );
    await expectLater(
      client.finalizeDocument('d1', version: 1),
      throwsA(isA<ApiException>()
          .having((e) => e.isConflict, 'isConflict', isTrue)
          .having((e) => e.message, 'message', 'Dokument wurde zwischenzeitlich geändert.')),
    );
  });

  test('Verbindungsfehler wird zu ApiUnreachable statt Fachfehler', () async {
    final client = WerkkernApiClient(
      baseUrl: Uri.parse('http://x'),
      httpClient: MockClient((_) async => throw http.ClientException('connection refused')),
    );
    await expectLater(client.health(), throwsA(isA<ApiUnreachable>()));
  });

  test('Nicht-JSON-Fehlerantwort (z. B. HTML-502 eines Proxys) wird zu ApiException statt FormatException', () async {
    final client = WerkkernApiClient(
      baseUrl: Uri.parse('http://x'),
      httpClient: MockClient((_) async => http.Response('<html>502 Bad Gateway</html>', 502)),
    );
    await expectLater(
      client.health(),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 502)),
    );
  });
}
