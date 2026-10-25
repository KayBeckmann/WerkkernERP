/// Katalog der serverseitig bekannten Berechtigungs-Schlüssel und
/// Firmenmodule (B1 Punkt 3: "Jede API-... Aktion serverseitig auf
/// Firma, Mitgliedschaft, Funktion und wirksames Recht prüfen").
///
/// Legt fest, welche Schlüssel es überhaupt gibt (und welche
/// Startgruppe welche davon standardmäßig bekommt, siehe
/// [starterGroupPermissions]), damit ein Tippfehler (z. B. `invoice.read` statt
/// `invoices.read`) beim Vergeben abgewiesen wird, statt still ein
/// nie geprüftes Recht anzulegen.
library;

/// Modul-Schlüssel — dieselben Namen wie die `Companies.*Enabled`-
/// Spalten der Offline-App ohne das `Enabled`-Suffix, damit ein
/// späterer Import (ADR-0001 B0.1) die Schalter 1:1 übernehmen kann.
/// Kern-Funktionen (Kunden, Artikel, Rechnungen) haben bewusst
/// **kein** Modul — sie sind in der Offline-App ebenfalls nicht
/// abschaltbar.
const knownModules = <String>{
  'quotes',
  'orders',
  'deliveryNotes',
  'proforma',
  'creditNotes',
  'advancePaymentInvoices',
  'projects',
  'fleet',
  'recurringInvoices',
  'dunning',
  'smtp',
  'buchhaltung',
  'lagerbestand',
  'bestellwesen',
  'timeTracking',
  // C8: LLM-Agenten (MCP/API) — die Firma entscheidet ausdrücklich, ob
  // Agent-Token überhaupt wirken (Roadmap C8: "Vor Aktivierung
  // Anbieterfreigabe ... klären").
  'aiAgents',
};

/// Berechtigung -> erforderliches Firmenmodul (`null` = Kernfunktion,
/// immer verfügbar). Eine deaktivierte Firmenfunktion bleibt vorrangig
/// vor jeder Gruppen-/Ausnahmeentscheidung (siehe
/// `PermissionResolver.hasPermission`).
const permissionCatalog = <String, String?>{
  'customers.read': null,
  'customers.write': null,
  'articles.read': null,
  'articles.write': null,
  'invoices.read': null,
  'invoices.write': null,
  // Getrennt von `invoices.write`: Finalisieren vergibt eine
  // unveränderliche Nummer (F3) — eine Firma soll Entwürfe von Monteuren
  // erstellen lassen können, ohne dass diese selbst finalisieren.
  'invoices.finalize': null,
  // Zahlungseingang/Fälligkeit — getrennt, damit z. B. nur die
  // Buchhaltung Rechnungen als bezahlt markiert.
  'invoices.payment': null,
  'projects.read': 'projects',
  'projects.write': 'projects',
  'timeTracking.read': 'timeTracking',
  'timeTracking.write': 'timeTracking',
  'fleet.read': 'fleet',
  'fleet.write': 'fleet',
  'accounting.read': 'buchhaltung',
  'accounting.write': 'buchhaltung',
  'stock.read': 'lagerbestand',
  'stock.write': 'lagerbestand',
  'purchaseOrders.read': 'bestellwesen',
  'purchaseOrders.write': 'bestellwesen',
  // Mahnwesen: überfällige Rechnungen einsehen bzw. Mahnungen erstellen
  // und Mahn-Einstellungen pflegen.
  'dunning.read': 'dunning',
  'dunning.write': 'dunning',
};

bool isKnownPermission(String permission) => permissionCatalog.containsKey(permission);

/// Modul, das [permission] voraussetzt — `null` bei Kernfunktionen
/// **und** bei unbekannten Schlüsseln (die bereits vorher über
/// [isKnownPermission] abgewiesen werden).
String? requiredModuleFor(String permission) => permissionCatalog[permission];

/// Standardrechte der Startgruppen bei Firmenanlage — Kay-Entscheidung
/// 2026-10-24 (Roadmap B1 Punkt 1). Nur eine Vorbelegung: Admins ändern
/// sie danach frei, Module bleiben vorrangig (ein `fleet.*`-Recht wirkt
/// nicht, solange Fuhrpark abgeschaltet ist).
const starterGroupPermissions = <String, Set<String>>{
  'Projektleiter': {
    'customers.read', 'customers.write',
    'articles.read', 'articles.write',
    'invoices.read', 'invoices.write', 'invoices.finalize',
    'projects.read', 'projects.write',
    'timeTracking.read', 'timeTracking.write',
    'fleet.read', 'fleet.write',
    'stock.read', 'stock.write',
    'purchaseOrders.read', 'purchaseOrders.write',
    'dunning.read',
  },
  // Monteur erstellt Entwürfe und bucht Zeiten/Lager, finalisiert aber
  // nicht und sieht keine Finanzen. Kein `timeTracking.read`: das hieße
  // „sieht die Zeiten aller“ — eigene sieht er über `timeTracking.write`.
  'Monteur': {
    'customers.read',
    'articles.read',
    'invoices.read', 'invoices.write',
    'projects.read',
    'timeTracking.write',
    'fleet.read',
    'stock.read', 'stock.write',
  },
  'Buchhaltung': {
    'customers.read', 'customers.write',
    'articles.read',
    'invoices.read', 'invoices.write', 'invoices.finalize', 'invoices.payment',
    'projects.read',
    'timeTracking.read',
    'fleet.read', 'fleet.write',
    'accounting.read', 'accounting.write',
    'purchaseOrders.read',
    'dunning.read', 'dunning.write',
  },
};
