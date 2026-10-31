# werkkern_mcp — MCP-Server für WerkkernERP (Roadmap C8)

Dünne Adapterschicht (Model Context Protocol, stdio) über der REST-API
des WerkkernERP-Servers (`server/`). Jedes Tool ruft genau einen
Endpunkt auf und gibt dessen JSON zurück — **keine eigene Fachlogik,
keine eigene Rechteprüfung**. Der Server prüft jeden Aufruf für das
Agent-Token.

## Voraussetzungen (in der App)

1. Firmen-Admin aktiviert unter *Verwaltung → Module* **KI-Agenten (MCP/API)**.
2. Der Nutzer erzeugt unter *KI-Zugang* (Roboter-Symbol) ein Token
   `wka_…` — es wird genau einmal angezeigt.

Der Agent hat damit **genau die aktuell wirksamen Rechte dieses Nutzers**
in dieser einen Firma, aber nie Admin-Funktionen. Widerruf (Token
löschen, Modul aus, Mitgliedschaft deaktiviert, Recht entzogen) wirkt
beim nächsten Aufruf.

## Irreversible Aktionen

Was eine Nummer vergibt, Bestand bucht, eine Mahnung protokolliert oder
einen Entwurf/Beleg löscht, legt über das Agent-Token nur eine
**Freigabe-Anfrage** an (HTTP 202):

- `finalize_document`, Löschen eines Dokument-Entwurfs
- `finalize_purchase_order`, `receive_purchase_order` (Wareneingang),
  Löschen eines Bestell-Entwurfs
- `correct_stock` (Bestandskorrektur), Inventur abschließen
- `create_dunning_notice` (Mahnung)
- Löschen eines Stundenzettel-Entwurfs oder Belegs

Ausgeführt wird erst, wenn der Nutzer sie in der App unter *KI-Zugang*
bestätigt — dann mit seiner eigenen Sitzung und vollständiger erneuter
Prüfung. `list_approvals` zeigt den Stand. **Nie** über ein Agent-Token:
Stundenzettel unterschreiben (das macht der Kunde auf dem Gerät),
Mailversand, Admin-Funktionen.

## Einrichten (z. B. Claude Desktop / Claude Code)

```json
{
  "mcpServers": {
    "werkkern": {
      "command": "dart",
      "args": ["run", "/pfad/zu/WerkkernERP/packages/werkkern_mcp/bin/werkkern_mcp.dart"],
      "env": {
        "WERKKERN_URL": "https://erp.example.org",
        "WERKKERN_AGENT_TOKEN": "wka_…"
      }
    }
  }
}
```

Schneller startend als kompilierte Datei:

```bash
dart compile exe bin/werkkern_mcp.dart -o werkkern_mcp
```

## Tools

Welche davon wirken, hängt von den Rechten des Nutzers und den
aktivierten Modulen der Firma ab — sonst meldet der Server 403 als
Tool-Fehler.

- **Kunden/Artikel/Dokumente:** `list_customers`, `create_customer`,
  `list_articles`, `list_documents`, `get_document`,
  `create_document_draft`, `update_document_draft` (mit `version`,
  Konflikt -> neu lesen), `finalize_document` (Freigabe),
  `convert_document`, `list_approvals`
- **Übersicht:** `get_dashboard`
- **Projekte/Zeiten:** `list_projects`, `get_project`, `create_project`,
  `list_time_entries`, `create_time_entry`, `list_time_sheets`
- **Lieferanten/Bestellwesen:** `list_suppliers`, `create_supplier`,
  `list_purchase_orders`, `get_purchase_order`,
  `purchase_order_suggestions`, `create_purchase_order_draft`,
  `finalize_purchase_order` (Freigabe), `receive_purchase_order` (Freigabe)
- **Lager:** `list_low_stock`, `list_stock_movements`, `correct_stock` (Freigabe)
- **Fuhrpark:** `list_vehicles`, `list_vehicle_costs`, `create_vehicle_cost`
- **Buchhaltung/Mahnwesen:** `list_expenses`, `create_expense`,
  `list_open_items`, `get_euer`, `list_overdue_invoices`,
  `create_dunning_notice` (Freigabe), `list_recurring_templates`

Tests: `server/test/mcp_test.dart` (gegen den echten Router, inkl.
echtem stdio-Prozess).
