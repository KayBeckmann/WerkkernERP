import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';
import 'package:werkkern_client/werkkern_client.dart';

/// Reine Client-Tests (ohne Server) — der Vertrag gegen den echten
/// Router steckt in `server/test/client_contract_test.dart`.
void main() {
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
}
