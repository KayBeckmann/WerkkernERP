import 'models.dart';

/// Reine Entscheidungslogik, kein DB-Zugriff (gleiches
/// Trennungsprinzip wie `stock_booking_service.dart`/
/// `open_items_service.dart` in der Offline-App) — leicht isoliert
/// testbar, von `MembershipRepository`/Router unabhängig von Postgres
/// oder In-Memory genutzt.
///
/// Reihenfolge laut Roadmap B1 Punkt 2, wörtlich: "Individuelles
/// Erlauben/Sperren je Berechtigung überschreibt die Gruppe; fehlende
/// Mitgliedschaft oder deaktivierte Firmenfunktion bleibt vorrangig."
/// Das heißt: zuerst Mitgliedschaft/Modul prüfen (hartes Nein, nicht
/// übersteuerbar), danach Override, zuletzt Gruppenvorgabe.
class PermissionResolver {
  PermissionResolver._();

  static bool hasPermission({
    required Membership? membership,
    required Company company,
    required PermissionKey permission,
    required List<GroupPermission> groupPermissions,
    required List<MembershipPermissionOverride> overrides,
    String? requiredModule,
  }) {
    // Fehlende/inaktive Mitgliedschaft — vorrangig, keine Ausnahme.
    if (membership == null || !membership.active) return false;

    // Deaktivierte Firmenfunktion — ebenfalls vorrangig. requiredModule
    // ist bewusst ein expliziter Parameter der aufrufenden Stelle
    // (z. B. eines konkreten API-Endpunkts), nicht hart in dieser
    // generischen Grundlage verdrahtet — welches Modul welche
    // Berechtigung voraussetzt, ist fachlich noch nicht festgelegt.
    if (requiredModule != null && !company.enabledModules.contains(requiredModule)) {
      return false;
    }

    // Individuelle Ausnahme überschreibt die Gruppe — in beide
    // Richtungen (explizit gewährt ODER explizit gesperrt).
    for (final override in overrides) {
      if (override.membershipId == membership.id && override.permission == permission) {
        return override.allowed;
      }
    }

    // Keine Ausnahme -> Gruppenvorgabe.
    return groupPermissions.any((gp) => gp.groupId == membership.groupId && gp.permission == permission);
  }
}
