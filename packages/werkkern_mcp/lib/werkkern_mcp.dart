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

const _date = {'type': 'string', 'description': 'Datum JJJJ-MM-TT'};
const _cents = {'type': 'integer', 'description': 'Betrag in Cent'};
const _decimal = {'type': 'string', 'description': 'Dezimalzahl als Text, z. B. "2.5"'};

/// Query-Parameter aus den gesetzten Argumenten (als Text).
Map<String, String> _query(Map<String, Object?> args, List<String> keys) => {
      for (final k in keys)
        if (args[k] != null) k: '${args[k]}',
    };

/// Body ohne `id` (die steckt im Pfad).
Map<String, Object?> _withoutId(Map<String, Object?> args) => {
      for (final e in args.entries)
        if (e.key != 'id') e.key: e.value,
    };


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
    'Dokument ersetzen (alle Positionen), nur wenn get_document editable=true liefert: Entwurf, oder finalisiertes '
        'Angebot/Auftrag/Proforma ohne Umwandlung (Nummer bleibt). version = zuletzt gelesene Version; bei Konflikt neu lesen.',
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

  // ---- Übersicht ---------------------------------------------------------------
  _Tool(
    'get_dashboard',
    'Übersicht der Firma (Umsatz, offene/überfällige Rechnungen, TÜV, Projekte ...) — nur Kacheln mit Leserecht.',
    _object({}),
    (c, a) => c.request('GET', '/dashboard'),
  ),

  // ---- Projekte und Zeiten -----------------------------------------------------
  _Tool(
    'list_projects',
    'Projekte auflisten (Modul Projekte).',
    _object({
      'includeArchived': {'type': 'boolean'},
    }),
    (c, a) => c.request('GET', '/projects', query: _query(a, ['includeArchived'])),
  ),
  _Tool(
    'get_project',
    'Projekt mit Dokumenten, Soll/Ist-Stunden, Kosten und Erlösen lesen.',
    _object({'id': _string}, ['id']),
    (c, a) => c.request('GET', '/projects/${a['id']}'),
  ),
  _Tool(
    'create_project',
    'Neues Projekt anlegen; die Projektnummer vergibt der Server.',
    _object({'name': _string, 'customerId': _string}, ['name']),
    (c, a) => c.request('POST', '/projects', body: a),
  ),
  _Tool(
    'list_time_entries',
    'Zeitbuchungen auflisten. Ohne Leserecht für alle nur die eigenen.',
    _object({
      'documentId': _string,
      'projectId': _string,
      'from': _date,
      'to': _date,
      'mine': {'type': 'boolean'},
    }),
    (c, a) => c.request('GET', '/time-entries', query: _query(a, ['documentId', 'projectId', 'from', 'to', 'mine'])),
  ),
  _Tool(
    'create_time_entry',
    'Eigene Arbeitszeit buchen — auf einen Auftrag/eine Rechnung (documentId) oder ein Projekt (projectId).',
    _object({
      'date': _date,
      'hours': {'type': 'string', 'description': 'Stunden als Dezimaltext, > 0 und <= 24'},
      'documentId': _string,
      'projectId': _string,
      'note': _string,
    }, ['date', 'hours']),
    (c, a) => c.request('POST', '/time-entries', body: a),
  ),
  _Tool(
    'list_time_sheets',
    'Kunden-Stundenzettel auflisten (Unterschreiben nur in der App durch den Kunden).',
    _object({}),
    (c, a) => c.request('GET', '/time-sheets'),
  ),

  // ---- Lieferanten und Bestellwesen -----------------------------------------------
  _Tool(
    'list_suppliers',
    'Lieferanten auflisten, optional nach Namen filtern.',
    _object({'query': _string}),
    (c, a) => c.request('GET', '/suppliers', query: {if (a['query'] != null) 'q': a['query'] as String}),
  ),
  _Tool(
    'create_supplier',
    'Neuen Lieferanten anlegen.',
    _object({
      'name': _string,
      'address': _string,
      'email': _string,
      'phone': _string,
      'vatId': _string,
      'contactPerson': _string,
      'deliveryTerms': _string,
      'minimumOrderQuantity': _decimal,
      'notes': _string,
    }, ['name']),
    (c, a) => c.request('POST', '/suppliers', body: a),
  ),
  _Tool(
    'list_purchase_orders',
    'Bestellungen auflisten. status: draft|finalized|partiallyReceived|fullyReceived.',
    _object({
      'status': {
        'type': 'string',
        'enum': ['draft', 'finalized', 'partiallyReceived', 'fullyReceived'],
      },
    }),
    (c, a) => c.request('GET', '/purchase-orders', query: _query(a, ['status'])),
  ),
  _Tool(
    'get_purchase_order',
    'Eine Bestellung mit Positionen (inkl. gelieferter Mengen) und Version lesen.',
    _object({'id': _string}, ['id']),
    (c, a) => c.request('GET', '/purchase-orders/${a['id']}'),
  ),
  _Tool(
    'purchase_order_suggestions',
    'Bestellvorschläge: Artikel unter Mindestbestand je Lieferant (günstigster Preis).',
    _object({}),
    (c, a) => c.request('GET', '/purchase-orders/suggestions'),
  ),
  _Tool(
    'create_purchase_order_draft',
    'Neuen Bestell-ENTWURF bei einem Lieferanten anlegen (Einkaufspreise netto in Cent).',
    _object({
      'supplierId': _string,
      'items': {
        'type': 'array',
        'items': {
          'type': 'object',
          'properties': {
            'articleId': _string,
            'description': _string,
            'quantity': _decimal,
            'purchasePriceCents': _cents,
          },
          'required': ['description', 'quantity'],
        },
      },
      'projectId': _string,
      'expenseCategoryId': _string,
      'issueDate': _date,
      'notes': _string,
    }, ['supplierId', 'items']),
    (c, a) => c.request('POST', '/purchase-orders', body: a),
  ),
  _Tool(
    'finalize_purchase_order',
    'Finalisierung einer Bestellung ANFRAGEN (Nummer, unveränderlich) — nur Freigabe-Anfrage, der Nutzer bestätigt in der App.',
    _object({
      'id': _string,
      'version': {'type': 'integer'},
    }, ['id', 'version']),
    (c, a) => c.request('POST', '/purchase-orders/${a['id']}/finalize', body: {'version': a['version']}),
  ),
  _Tool(
    'receive_purchase_order',
    'Wareneingang ANFRAGEN: receipts = {Positions-ID: gelieferte Menge}. Bucht Bestand erst nach Bestätigung in der App.',
    _object({
      'id': _string,
      'receipts': {'type': 'object', 'additionalProperties': _decimal},
    }, ['id', 'receipts']),
    (c, a) => c.request('POST', '/purchase-orders/${a['id']}/receive', body: {'receipts': a['receipts']}),
  ),

  // ---- Lager -------------------------------------------------------------------------
  _Tool('list_low_stock', 'Artikel unter Mindestbestand.', _object({}), (c, a) => c.request('GET', '/stock/low')),
  _Tool(
    'list_stock_movements',
    'Lagerbewegungen, optional für einen Artikel.',
    _object({'articleId': _string}),
    (c, a) => c.request('GET', '/stock/movements', query: _query(a, ['articleId'])),
  ),
  _Tool(
    'correct_stock',
    'Bestandskorrektur ANFRAGEN (gezählte Menge + Grund). Gebucht wird erst nach Bestätigung in der App.',
    _object({'id': _string, 'countedQuantity': _decimal, 'reason': _string}, ['id', 'countedQuantity', 'reason']),
    (c, a) => c.request('POST', '/articles/${a['id']}/stock-correction', body: _withoutId(a)),
  ),

  // ---- Fuhrpark ------------------------------------------------------------------------
  _Tool(
    'list_vehicles',
    'Fahrzeuge mit nächstem TÜV-Termin.',
    _object({
      'includeInactive': {'type': 'boolean'},
    }),
    (c, a) => c.request('GET', '/vehicles', query: _query(a, ['includeInactive'])),
  ),
  _Tool(
    'list_vehicle_costs',
    'Fahrzeugkosten mit Summen je Kategorie, optional je Fahrzeug/Zeitraum.',
    _object({'vehicleId': _string, 'from': _date, 'to': _date}),
    (c, a) => c.request('GET', '/vehicle-costs', query: _query(a, ['vehicleId', 'from', 'to'])),
  ),
  _Tool(
    'create_vehicle_cost',
    'Fahrzeugkosten erfassen (z. B. Tankbeleg).',
    _object({
      'vehicleId': _string,
      'date': _date,
      'amountCents': _cents,
      'category': {
        'type': 'string',
        'enum': ['fuel', 'maintenance', 'leasing', 'insurance', 'other'],
      },
      'description': _string,
      'projectId': _string,
      'principalAmountCents': _cents,
      'interestAmountCents': _cents,
    }, ['vehicleId', 'date', 'amountCents', 'category']),
    (c, a) => c.request('POST', '/vehicle-costs', body: a),
  ),

  // ---- Buchhaltung und Mahnwesen ----------------------------------------------------
  _Tool(
    'list_expenses',
    'Belege/Ausgaben, optional nach Zeitraum oder Projekt.',
    _object({'from': _date, 'to': _date, 'projectId': _string}),
    (c, a) => c.request('GET', '/expenses', query: _query(a, ['from', 'to', 'projectId'])),
  ),
  _Tool(
    'create_expense',
    'Beleg/Ausgabe erfassen (Bruttobetrag in Cent).',
    _object({
      'date': _date,
      'description': _string,
      'amountGrossCents': _cents,
      'vatRatePercent': {'type': 'number'},
      'categoryId': _string,
      'projectId': _string,
      'supplierReference': _string,
    }, ['date', 'description', 'amountGrossCents', 'vatRatePercent']),
    (c, a) => c.request('POST', '/expenses', body: a),
  ),
  _Tool(
    'list_open_items',
    'Offene Posten: finalisierte, unbezahlte Rechnungen je Kunde.',
    _object({}),
    (c, a) => c.request('GET', '/accounting/open-items'),
  ),
  _Tool(
    'get_euer',
    'Interne EÜR-Übersicht für einen Zeitraum (keine steuerliche Erklärung).',
    _object({'from': _date, 'to': _date}, ['from', 'to']),
    (c, a) => c.request('GET', '/accounting/euer', query: _query(a, ['from', 'to'])),
  ),
  _Tool(
    'list_overdue_invoices',
    'Überfällige Rechnungen mit heutiger Mahnstufe, Gebühr und Zins.',
    _object({}),
    (c, a) => c.request('GET', '/dunning/overdue'),
  ),
  _Tool(
    'create_dunning_notice',
    'Mahnung zur heutigen Stufe ANFRAGEN — wird erst nach Bestätigung in der App erstellt. Versand nur aus der App.',
    _object({'documentId': _string}, ['documentId']),
    (c, a) => c.request('POST', '/documents/${a['documentId']}/dunning-notices'),
  ),
  _Tool(
    'list_recurring_templates',
    'Vorlagen für wiederkehrende Rechnungen mit nächster Fälligkeit.',
    _object({
      'includeInactive': {'type': 'boolean'},
    }),
    (c, a) => c.request('GET', '/recurring-templates', query: _query(a, ['includeInactive'])),
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
          'serverInfo': {'name': 'werkkern-erp', 'version': '0.2.0'},
          'instructions': 'WerkkernERP: Kunden, Artikel, Dokumente, Projekte/Zeiten, Bestellwesen, Lager, Fuhrpark, '
              'Buchhaltung und Mahnwesen der Firma des Agent-Tokens — je nach Rechten und aktivierten Modulen. '
              'Beträge in Cent, Mengen als Dezimaltext. Irreversible Aktionen (Finalisieren, Wareneingang, '
              'Bestandskorrektur, Mahnung, Löschen) erzeugen nur eine Freigabe-Anfrage; der Nutzer bestätigt in der App.',
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
