import 'package:decimal/decimal.dart';

/// C3.4 Stunden je Rolle abrechnen (Nachtrag 2026-11-03) — gemeinsam für
/// Offline-App und Server, damit beide Varianten Stunden gleich abrechnen.

/// Einheit, die eine Stunden-Position vorbelegt bekommt.
const hoursUnit = 'h';

/// Beschreibung der Ist-Stunden-Position ohne Rolle (bisheriger Text).
const unassignedHoursDescription = 'Geleistete Stunden (Ist-Zeit)';

/// Verrechnungssatz (Preis je Stunde für den Kunden) einer Rolle.
///
/// Einzige Stelle, an der der Stundenpreis ermittelt wird. [customerId]
/// und [workDate] sind für die vorgemerkten Erweiterungen da
/// (kundenspezifische Sätze, Zuschläge für Nacht/Überstunden/Wochenende,
/// Kay 2026-11-03: „Das kommt erst später.“) und werden heute nicht
/// ausgewertet.
///
/// `null` = kein Satz hinterlegt (0 €) — der Aufrufer lässt den Preis
/// dann leer, statt still 0 € zu berechnen.
int? resolveHourlyBillingRateCents({
  required int roleBillingRateCents,
  String? customerId,
  DateTime? workDate,
}) =>
    roleBillingRateCents > 0 ? roleBillingRateCents : null;

/// Stunden-Position aus dem Auftrag (geplante Stunden), Preisquelle beim
/// Umwandeln.
class PlannedHoursItem {
  const PlannedHoursItem({
    required this.staffRoleId,
    required this.unitPriceCents,
    required this.vatRatePercent,
    this.unit,
    this.groupLabel,
  });

  final String? staffRoleId;
  final int unitPriceCents;
  final double vatRatePercent;
  final String? unit;
  final String? groupLabel;
}

/// Rolle mit Name und Verrechnungssatz.
class BillingRole {
  const BillingRole({required this.id, required this.name, required this.billingRateCents});

  final String id;
  final String name;
  final int billingRateCents;
}

/// Eine Ist-Stunden-Position der Rechnung.
class BookedHoursLine {
  const BookedHoursLine({
    required this.staffRoleId,
    required this.description,
    required this.hours,
    required this.unitPriceCents,
    required this.vatRatePercent,
    required this.unit,
    this.groupLabel,
  });

  final String? staffRoleId;
  final String description;
  final Decimal hours;
  final int unitPriceCents;
  final double vatRatePercent;
  final String? unit;
  final String? groupLabel;
}

/// Verteilt gebuchte Ist-Stunden beim Umwandeln Auftrag → Rechnung (ohne
/// Festpreis) auf **eine Position je Rolle** (Kay 2026-11-03).
///
/// Preis je Rolle: Auftrags-Position derselben Rolle (was dem Kunden
/// angeboten wurde), sonst der Verrechnungssatz der Rolle, sonst die
/// erste Stunden-Position des Auftrags. Stunden ohne Rolle (oder mit
/// inzwischen gelöschter Rolle): erste Stunden-Position ohne Rolle,
/// sonst die erste Stunden-Position — das bisherige Verhalten.
///
/// Reihenfolge: Rollen in der Reihenfolge ihrer Auftrags-Positionen,
/// dann weitere Rollen nach Name, „ohne Rolle“ zuletzt. Rollen ohne
/// gebuchte Stunden erscheinen nicht; ist gar nichts gebucht, bleibt eine
/// Position „ohne Rolle“ mit 0 h. [plannedItems] darf nicht leer
/// sein (ohne geplante Stunden werden keine Ist-Stunden abgerechnet).
List<BookedHoursLine> billBookedHoursByRole({
  required Map<String?, Decimal> bookedHoursByRole,
  required List<PlannedHoursItem> plannedItems,
  required List<BillingRole> roles,
  String? customerId,
}) {
  if (plannedItems.isEmpty) throw ArgumentError('Keine Stunden-Positionen im Auftrag.');
  final roleById = {for (final r in roles) r.id: r};
  final fallback = plannedItems.first;

  final hours = <String?, Decimal>{};
  bookedHoursByRole.forEach((roleId, value) {
    final key = roleId != null && roleById.containsKey(roleId) ? roleId : null;
    hours[key] = (hours[key] ?? Decimal.zero) + value;
  });
  hours.removeWhere((_, value) => value <= Decimal.zero);
  // Gar nichts gebucht: eine Position mit 0 h bleibt sichtbar stehen
  // (bisheriges Verhalten), statt dass die Stunden still fehlen.
  if (hours.isEmpty) hours[null] = Decimal.zero;

  final ordered = <String>{
    for (final item in plannedItems)
      if (item.staffRoleId != null && hours.containsKey(item.staffRoleId)) item.staffRoleId!,
  }.toList();
  final rest = hours.keys.whereType<String>().where((id) => !ordered.contains(id)).toList()
    ..sort((a, b) => roleById[a]!.name.compareTo(roleById[b]!.name));
  ordered.addAll(rest);

  final lines = <BookedHoursLine>[];
  for (final roleId in ordered) {
    final role = roleById[roleId]!;
    final planned = plannedItems.where((i) => i.staffRoleId == roleId).firstOrNull;
    final rate = resolveHourlyBillingRateCents(roleBillingRateCents: role.billingRateCents, customerId: customerId);
    final source = planned ?? fallback;
    lines.add(BookedHoursLine(
      staffRoleId: roleId,
      description: '${role.name} – geleistete Stunden (Ist-Zeit)',
      hours: hours[roleId]!,
      unitPriceCents: planned?.unitPriceCents ?? rate ?? fallback.unitPriceCents,
      vatRatePercent: source.vatRatePercent,
      unit: planned?.unit ?? hoursUnit,
      groupLabel: source.groupLabel,
    ));
  }
  final unassigned = hours[null];
  if (unassigned != null) {
    final source = plannedItems.where((i) => i.staffRoleId == null).firstOrNull ?? fallback;
    lines.add(BookedHoursLine(
      staffRoleId: null,
      description: unassignedHoursDescription,
      hours: unassigned,
      unitPriceCents: source.unitPriceCents,
      vatRatePercent: source.vatRatePercent,
      unit: source.unit,
      groupLabel: source.groupLabel,
    ));
  }
  return lines;
}
