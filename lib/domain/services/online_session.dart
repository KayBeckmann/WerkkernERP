import 'package:flutter/foundation.dart';
import 'package:werkkern_client/werkkern_client.dart';

/// Angemeldete Online-Sitzung (Phase B) — bewusst völlig getrennt von
/// `ActiveCompanyService`/`AppDatabase` der Offline-App: Online-Daten
/// liegen ausschließlich auf dem Server und werden nicht in die lokale
/// SQLite übernommen (ADR-0001 B0.1; selektiver Offline-Cache ist B2).
class OnlineSession extends ChangeNotifier {
  OnlineSession({
    required this.client,
    required this.serverUrl,
    required this.companyName,
    required this.isAdmin,
    required this.permissions,
    required this.modules,
  });

  final WerkkernApiClient client;
  final Uri serverUrl;
  final String companyName;
  final bool isAdmin;
  Set<String> permissions;
  Set<String> modules;

  /// Nur zur Anzeige — jede Aktion prüft der Server selbst.
  bool can(String permission) => permissions.contains(permission);

  /// Rechte/Module neu laden, z. B. nach einem 403 (Admin hat
  /// zwischenzeitlich etwas entzogen — wirkt serverseitig sofort).
  Future<void> refreshPermissions() async {
    final mine = await client.myPermissions();
    permissions = mine.permissions;
    modules = await client.modules();
    notifyListeners();
  }

  Future<void> logout() async {
    try {
      await client.logout();
    } on Exception {
      // Abmelden muss lokal immer gelingen, auch ohne Netz — das Token
      // läuft serverseitig ohnehin ab.
    }
  }
}

/// Deutsche Bezeichnungen der Dokumentarten (wie offline).
const onlineDocumentKindLabels = <String, String>{
  'invoice': 'Rechnung',
  'quote': 'Angebot',
  'order': 'Auftrag',
  'deliveryNote': 'Lieferschein',
  'proforma': 'Proforma-Rechnung',
  'creditNote': 'Gutschrift',
};

/// Modul je Dokumentart (`null` = immer verfügbar), gespiegelt vom Server.
const onlineDocumentKindModules = <String, String?>{
  'invoice': null,
  'quote': 'quotes',
  'order': 'orders',
  'deliveryNote': 'deliveryNotes',
  'proforma': 'proforma',
  'creditNote': 'creditNotes',
};

/// Verständliche Meldung für jeden Fehler eines API-Aufrufs.
String describeOnlineError(Object error) => switch (error) {
      ApiUnreachable() => 'Server nicht erreichbar. Online-Daten sind ohne Verbindung nicht verfügbar.',
      ApiException(isUnauthorized: true) => 'Sitzung abgelaufen oder beendet — bitte neu anmelden.',
      ApiException(isForbidden: true, :final message) => 'Keine Berechtigung: $message',
      ApiException(:final message) => message,
      _ => 'Unerwarteter Fehler: $error',
    };

/// Anzeigenamen der Firmenmodule (Schlüssel wie offline `*Enabled`).
const onlineModuleLabels = <String, String>{
  'quotes': 'Angebote',
  'orders': 'Aufträge',
  'deliveryNotes': 'Lieferscheine',
  'proforma': 'Proforma-Rechnungen',
  'creditNotes': 'Gutschriften',
  'advancePaymentInvoices': 'Abschlagsrechnungen',
  'projects': 'Projekte',
  'fleet': 'Fuhrpark',
  'recurringInvoices': 'Wiederkehrende Rechnungen',
  'dunning': 'Mahnwesen',
  'smtp': 'E-Mail-Versand',
  'buchhaltung': 'Buchhaltung',
  'lagerbestand': 'Lagerbestand',
  'bestellwesen': 'Bestellwesen',
  'timeTracking': 'Zeiterfassung',
};

/// Anzeigenamen der Berechtigungen; unbekannte Schlüssel werden roh
/// angezeigt (der Server kann neuere Schlüssel kennen als die App).
const onlinePermissionLabels = <String, String>{
  'customers.read': 'Kunden ansehen',
  'customers.write': 'Kunden bearbeiten',
  'articles.read': 'Artikel ansehen',
  'articles.write': 'Artikel bearbeiten',
  'invoices.read': 'Dokumente ansehen',
  'invoices.write': 'Dokumente bearbeiten',
  'invoices.finalize': 'Dokumente finalisieren',
  'projects.read': 'Projekte ansehen',
  'projects.write': 'Projekte bearbeiten',
  'timeTracking.read': 'Zeiten ansehen',
  'timeTracking.write': 'Zeiten buchen',
  'fleet.read': 'Fuhrpark ansehen',
  'fleet.write': 'Fuhrpark bearbeiten',
  'accounting.read': 'Buchhaltung ansehen',
  'accounting.write': 'Buchhaltung bearbeiten',
  'stock.read': 'Lager ansehen',
  'stock.write': 'Lager buchen',
  'purchaseOrders.read': 'Bestellungen ansehen',
  'purchaseOrders.write': 'Bestellungen bearbeiten',
};
