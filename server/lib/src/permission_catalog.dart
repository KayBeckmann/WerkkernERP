/// Katalog der serverseitig bekannten Berechtigungs-Schlüssel und
/// Firmenmodule (B1 Punkt 3: "Jede API-... Aktion serverseitig auf
/// Firma, Mitgliedschaft, Funktion und wirksames Recht prüfen").
///
/// Bewusst nur der **Mechanismus** — welche Startgruppe welche Rechte
/// standardmäßig bekommt, ist laut Roadmap B1 Punkt 1 "nicht
/// entschieden und muss vor Rollout fachlich festgelegt werden". Die
/// Startgruppen werden deshalb weiterhin ohne vorbelegte Rechte
/// angelegt; dieser Katalog legt nur fest, welche Schlüssel es
/// überhaupt gibt, damit ein Tippfehler (z. B. `invoice.read` statt
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
};

bool isKnownPermission(String permission) => permissionCatalog.containsKey(permission);

/// Modul, das [permission] voraussetzt — `null` bei Kernfunktionen
/// **und** bei unbekannten Schlüsseln (die bereits vorher über
/// [isKnownPermission] abgewiesen werden).
String? requiredModuleFor(String permission) => permissionCatalog[permission];
