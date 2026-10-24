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

`finalize_document` (und Löschen eines Entwurfs über die API) legt nur
eine **Freigabe-Anfrage** an. Ausgeführt wird erst, wenn der Nutzer sie
in der App unter *KI-Zugang* bestätigt — dann mit seiner eigenen Sitzung
und vollständiger erneuter Prüfung. `list_approvals` zeigt den Stand.

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

`list_customers`, `create_customer`, `list_articles`, `list_documents`,
`get_document`, `create_document_draft`, `update_document_draft`
(mit `version`, Konflikt -> neu lesen), `finalize_document`
(Freigabe-Anfrage), `convert_document`, `list_approvals`.

Tests: `server/test/mcp_test.dart` (gegen den echten Router, inkl.
echtem stdio-Prozess).
