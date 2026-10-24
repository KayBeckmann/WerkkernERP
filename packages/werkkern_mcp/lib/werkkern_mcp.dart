/// MCP-Server für WerkkernERP (C8). Protokoll: JSON-RPC 2.0, eine
/// Nachricht pro Zeile (MCP stdio-Transport). Jedes Tool ruft genau einen
/// Server-Endpunkt auf und gibt dessen JSON unverändert zurück — keine
/// eigene Fachlogik, keine eigene Rechteprüfung: der Server prüft jeden
/// Aufruf für das Agent-Token (Recht, Modul, Firma), und irreversible
/// Aktionen liefern dort nur eine Freigabe-Anfrage.
library;

import 'dart:convert';

import 'package:werkkern_client/werkkern_client.dart';

const _protocolVersion = '2025-06-18';

typedef _ToolCall = Future<Object?> Function(WerkkernApiClient client, Map<String, Object?> args);

class _Tool {
  const _Tool(this.name, this.description, this.schema, this.call);
  final String name;
  final String description;
  final Map<String, Object?> schema;
  final _ToolCall call;
}

Map<String, Object?> _object(Map<String, Object?> properties, [List<String> required = const []]) => {
      'type': 'object',
      'properties': properties,
      'required': required,
      'additionalProperties': false,
    };

const _string = {'type': 'string'};

final _item = {
  'type': 'object',
  'properties': {
    'kind': {
      'type': 'string',
      'enum': ['article', 'hours', 'text'],
    },
    'articleId': _string,
    'description': _string,
    'quantity': {'type': 'string', 'description': 'Dezimalzahl als Text, z. B. "1.5"'},
    'unitPriceCents': {'type': 'integer', 'description': 'Netto-Einzelpreis in Cent'},
    'vatRatePercent': {'type': 'number'},
    'unit': _string,
    'discountPercent': {'type': 'number'},
    'groupLabel': _string,
  },
  'required': ['kind', 'description', 'quantity', 'unitPriceCents', 'vatRatePercent'],
};

const _kinds = ['invoice', 'quote', 'order', 'deliveryNote', 'proforma', 'creditNote'];

final List<_Tool> _tools = [
  _Tool(
    'list_customers',
    'Kunden der Firma auflisten, optional nach Namen filtern.',
    _object({'query': _string}),
    (c, a) => c.request('GET', '/customers', query: {if (a['query'] != null) 'q': a['query'] as String}),
  ),
  _Tool(
    'create_customer',
    'Neuen Kunden anlegen.',
    _object({
      'name': _string,
      'address': _string,
      'email': _string,
      'phone': _string,
      'vatId': _string,
      'contactPerson': _string,
      'notes': _string,
    }, ['name']),
    (c, a) => c.request('POST', '/customers', body: a),
  ),
  _Tool(
    'list_articles',
    'Artikelstamm auflisten (Netto-Verkaufspreise in Cent).',
    _object({'query': _string}),
    (c, a) => c.request('GET', '/articles', query: {if (a['query'] != null) 'q': a['query'] as String}),
  ),
  _Tool(
    'list_documents',
    'Dokumente (Rechnungen, Angebote, ...) auflisten. Filter: kind, status (draft|finalized), query (Nummer/Kunde).',
    _object({
      'kind': {'type': 'string', 'enum': _kinds},
      'status': {
        'type': 'string',
        'enum': ['draft', 'finalized'],
      },
      'query': _string,
    }),
    (c, a) => c.request('GET', '/documents', query: {
      if (a['kind'] != null) 'kind': a['kind'] as String,
      if (a['status'] != null) 'status': a['status'] as String,
      if (a['query'] != null) 'q': a['query'] as String,
    }),
  ),
  _Tool(
    'get_document',
    'Ein Dokument mit Positionen, Summen je Steuersatz und Version lesen.',
    _object({'id': _string}, ['id']),
    (c, a) => c.request('GET', '/documents/${a['id']}'),
  ),
  _Tool(
    'create_document_draft',
    'Neuen Dokument-ENTWURF anlegen (wird nie automatisch finalisiert). kind Standard: invoice.',
    _object({
      'customerId': _string,
      'kind': {'type': 'string', 'enum': _kinds},
      'items': {'type': 'array', 'items': _item},
      'notes': _string,
      'paymentTerms': _string,
    }, ['customerId']),
    (c, a) => c.request('POST', '/documents', body: a),
  ),
  _Tool(
    'update_document_draft',
    'Entwurf ersetzen (alle Positionen). version = zuletzt gelesene Version; bei Konflikt neu lesen.',
    _object({
      'id': _string,
      'version': {'type': 'integer'},
      'items': {'type': 'array', 'items': _item},
      'notes': _string,
    }, ['id', 'version', 'items']),
    (c, a) => c.request('PUT', '/documents/${a['id']}', body: {
      'version': a['version'],
      'items': a['items'],
      if (a.containsKey('notes')) 'notes': a['notes'],
    }),
  ),
  _Tool(
    'finalize_document',
    'Finalisierung ANFRAGEN. Irreversibel (Nummer, unveränderlich) — der Server legt nur eine Freigabe-Anfrage an, '
        'die der Nutzer in der App bestätigen muss. Status mit list_approvals prüfen.',
    _object({'id': _string, 'version': {'type': 'integer'}}, ['id', 'version']),
    (c, a) => c.request('POST', '/documents/${a['id']}/finalize', body: {'version': a['version']}),
  ),
  _Tool(
    'convert_document',
    'Aus einem finalisierten Dokument einen neuen Entwurf der Zielart erzeugen (z. B. Angebot -> Auftrag -> Rechnung).',
    _object({'id': _string, 'targetKind': {'type': 'string', 'enum': _kinds}}, ['id', 'targetKind']),
    (c, a) => c.request('POST', '/documents/${a['id']}/convert', body: {'kind': a['targetKind']}),
  ),
  _Tool(
    'list_approvals',
    'Eigene Freigabe-Anfragen und ihren Stand (pending/confirmed/rejected) auflisten.',
    _object({
      'status': {
        'type': 'string',
        'enum': ['pending', 'confirmed', 'rejected'],
      },
    }),
    (c, a) => c.request('GET', '/approvals', query: {if (a['status'] != null) 'status': a['status'] as String}),
  ),
];

/// Verarbeitet eine JSON-RPC-Nachricht. Liefert die Antwort oder `null`
/// bei Notifications (ohne `id`).
class WerkkernMcpServer {
  WerkkernMcpServer(this.client);
  final WerkkernApiClient client;

  Future<Map<String, Object?>?> handle(Map<String, Object?> message) async {
    final id = message['id'];
    final method = message['method'];
    final params = (message['params'] as Map<String, Object?>?) ?? const {};
    if (id == null) return null; // Notification (z. B. notifications/initialized)

    Map<String, Object?> result(Object? r) => {'jsonrpc': '2.0', 'id': id, 'result': r};
    Map<String, Object?> error(int code, String text) => {
          'jsonrpc': '2.0',
          'id': id,
          'error': {'code': code, 'message': text},
        };

    switch (method) {
      case 'initialize':
        return result({
          'protocolVersion': params['protocolVersion'] ?? _protocolVersion,
          'capabilities': {
            'tools': {'listChanged': false},
          },
          'serverInfo': {'name': 'werkkern-erp', 'version': '0.1.0'},
          'instructions': 'WerkkernERP: Kunden, Artikel und Dokumente der Firma des Agent-Tokens. Beträge in Cent, '
              'Mengen als Dezimaltext. Finalisieren erzeugt nur eine Freigabe-Anfrage; der Nutzer bestätigt in der App.',
        });
      case 'ping':
        return result(const {});
      case 'tools/list':
        return result({
          'tools': [
            for (final t in _tools) {'name': t.name, 'description': t.description, 'inputSchema': t.schema},
          ],
        });
      case 'tools/call':
        final name = params['name'];
        final tool = _tools.where((t) => t.name == name).firstOrNull;
        if (tool == null) return error(-32602, 'Unbekanntes Tool: $name');
        final args = (params['arguments'] as Map<String, Object?>?) ?? const {};
        try {
          final response = await tool.call(client, args);
          return result({
            'content': [
              {'type': 'text', 'text': const JsonEncoder.withIndent('  ').convert(response)},
            ],
          });
        } on ApiException catch (e) {
          // Fachliche Ablehnung durch den Server (Recht, Konflikt, ...):
          // als Tool-Fehler zurückgeben, damit das Modell reagieren kann.
          return result({
            'isError': true,
            'content': [
              {'type': 'text', 'text': 'Server lehnt ab (${e.statusCode}): ${e.message}'},
            ],
          });
        } on ApiUnreachable catch (e) {
          return result({
            'isError': true,
            'content': [
              {'type': 'text', 'text': '$e'},
            ],
          });
        }
      default:
        return error(-32601, 'Methode nicht unterstützt: $method');
    }
  }
}
