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
    required this.email,
    required this.companyId,
    required this.companyName,
    required this.isAdmin,
    required this.permissions,
    required this.modules,
    this.offline,
    this.offlineOnly = false,
  });

  final WerkkernApiClient client;
  final Uri serverUrl;
  final String email;
  final String companyId;
  final String companyName;
  final bool isAdmin;
  Set<String> permissions;
  Set<String> modules;

  /// B2: selektiver, verschlüsselter Offline-Bestand — `null`, wo nicht
  /// verfügbar (Web) oder nicht nutzbar (fremde offene Änderungen).
  final OfflineStore? offline;

  /// Ohne Anmeldung aus dem Offline-Bestand geöffnet (kein Server
  /// erreichbar) — nur markierte Dokumente, Abgleich erst nach Anmeldung.
  final bool offlineOnly;

  int get pendingChanges => offline?.outbox.length ?? 0;

  /// Outbox übertragen und markierte Dokumente aktualisieren.
  Future<SyncResult> sync() async {
    final store = offline;
    if (store == null) return SyncResult();
    final result = await const SyncService().sync(client, store);
    notifyListeners();
    return result;
  }

  /// Nach lokalen Änderungen am Bestand (markieren, offline speichern).
  void offlineChanged() => notifyListeners();

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

  Future<void> logout({bool wipeOffline = false}) async {
    if (wipeOffline) await offline?.wipe();
    if (offlineOnly) return;
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

/// Kurzfassung eines Abgleichs für Snackbar/Dialog.
String describeSyncResult(SyncResult r) {
  if (r.needsLogin) return 'Abgleich nicht möglich: bitte neu anmelden (Sitzung abgelaufen oder Zugang entzogen).';
  final parts = <String>[
    if (r.sent > 0) '${r.sent} Offline-Änderung(en) übertragen',
    if (r.conflicts.isNotEmpty) '${r.conflicts.length} Konflikt(e) — inzwischen anders gespeichert',
    if (r.rejected.isNotEmpty) '${r.rejected.length} abgewiesen',
    if (r.revoked.isNotEmpty) '${r.revoked.length} Dokument(e) nicht mehr freigegeben und vom Gerät entfernt',
    if (r.unreachable) 'Server nicht erreichbar — Änderungen bleiben gespeichert',
  ];
  return parts.isEmpty ? 'Alles abgeglichen.' : '${parts.join('; ')}.';
}

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
