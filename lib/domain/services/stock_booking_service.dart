import '../../data/database/tables.dart';

/// C5.1 Lagerbestand (Nachtrag 2026-10-19, Kay-Entscheidung auf
/// Rückfrage) — reine Entscheidungslogik, kein DB-Zugriff (gleiches
/// Trennungsprinzip wie `open_items_service.dart`/`euer_service.dart`).
///
/// Bestandsrelevant sind nur Auftrag, Rechnung und Lieferschein — ein
/// Angebot ("dürfen dem Lager noch nicht als entnommen gekennzeichnet
/// werden"), eine Proforma-Rechnung und eine Gutschrift lösen nie eine
/// Buchung aus. Eine Rückbuchung bei einer Gutschrift (Warenretoure)
/// ist bewusst nicht Teil dieses ersten Entwurfs (siehe Roadmap).
const stockRelevantDocumentKinds = {
  DocumentKind.order,
  DocumentKind.invoice,
  DocumentKind.deliveryNote,
};

/// Ob die Finalisierung eines Dokuments der Art [kind] jetzt eine
/// Bestandsbuchung auslösen soll.
///
/// Kays Vorgabe ("Erst wenn ein Angebot zum Auftrag/Rechnung gewandelt
/// wird, dürfen die Lagerbestände ... gebucht werden" + "Artikel in
/// einem Auftrag dürfen NICHT doppelt gebucht werden, wenn eine
/// Rechnung erstellt wird") wird hier generisch für JEDE Dokumenten-
/// kette umgesetzt, nicht nur Auftrag→Rechnung: **genau eine Buchung
/// pro Kette**, ausgelöst durch das erste bestandsrelevante Dokument.
/// Da Rechnung/Lieferschein nie selbst Quelle einer Umwandlung sind
/// (siehe `allowedConversionTargets`), reicht ein Blick auf das
/// unmittelbare Vorgängerdokument (`convertedFromId`) — ist dieses
/// bereits bestandsrelevant gewesen, hat es beim eigenen Finalisieren
/// schon gebucht, und das aktuelle Dokument darf nicht erneut buchen.
///
/// [predecessorKind] ist `null`, wenn das Dokument keine Umwandlung
/// ist (`convertedFromId == null`) — dann zählt es als "erstes"
/// Dokument seiner eigenen (einelementigen) Kette.
bool shouldBookStockOnFinalize({
  required DocumentKind kind,
  required DocumentKind? predecessorKind,
}) {
  if (!stockRelevantDocumentKinds.contains(kind)) return false;
  if (predecessorKind != null && stockRelevantDocumentKinds.contains(predecessorKind)) {
    return false;
  }
  return true;
}
