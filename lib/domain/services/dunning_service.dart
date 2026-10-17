import '../../data/database/database.dart';
import '../../data/database/tables.dart';

/// Mahnstufe (C12, Kay-Priorisierungsentscheidung 2026-10-17). Rein
/// datums-/statusbasierte Anzeige — **keine** Mahngebühr- oder
/// Verzugszins-Berechnung. Das bräuchte eine eigene fachlich/rechtlich
/// geprüfte Grundlage (§ 286/288 BGB), die laut Roadmap C12 ausdrücklich
/// noch offen ist. Diese Stufen sind eine Arbeitsvorgabe für die
/// Anzeige, keine Rechtsaussage — niemals als "rechtskonforme Mahnung"
/// darstellen.
enum DunningLevel { none, overdue, reminder2, reminder3 }

/// Tage seit Fälligkeit, ab denen die jeweils nächste Stufe gilt.
/// Bewusst grobe, selbst festgelegte Schwellen (keine gesetzliche
/// Vorgabe) — dienen nur der groben Priorisierung in der Liste/im
/// Editor, nicht einer rechtlich bindenden Mahnfrist.
const _reminder2AfterDays = 14;
const _reminder3AfterDays = 28;

/// Berechnet die Mahnstufe aus [invoice] und dem aktuellen Zeitpunkt
/// [now]. `DunningLevel.none`, wenn das Dokument bereits bezahlt ist,
/// kein Fälligkeitsdatum gesetzt hat, oder die Fälligkeit noch nicht
/// erreicht ist.
DunningLevel dunningLevelFor(Invoice invoice, DateTime now) {
  if (invoice.status != InvoiceStatus.finalized) return DunningLevel.none;
  if (invoice.paymentStatus == PaymentStatus.paid) return DunningLevel.none;
  final dueDate = invoice.dueDate;
  if (dueDate == null) return DunningLevel.none;
  if (!now.isAfter(dueDate)) return DunningLevel.none;

  final overdueDays = now.difference(dueDate).inDays;
  if (overdueDays >= _reminder3AfterDays) return DunningLevel.reminder3;
  if (overdueDays >= _reminder2AfterDays) return DunningLevel.reminder2;
  return DunningLevel.overdue;
}

/// Anzeigetext je Stufe — bewusst "überfällig"/"1./2. Mahnstufe" statt
/// "1./2./3. Mahnung", um keine bereits versendete Mahnung zu
/// unterstellen (diese App versendet/erzeugt noch kein Mahnschreiben,
/// siehe Klassendoc).
String dunningLevelLabel(DunningLevel level) => switch (level) {
      DunningLevel.none => '',
      DunningLevel.overdue => 'Überfällig',
      DunningLevel.reminder2 => 'Überfällig (2. Mahnstufe)',
      DunningLevel.reminder3 => 'Überfällig (3. Mahnstufe)',
    };
