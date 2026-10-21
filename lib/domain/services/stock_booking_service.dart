import '../../data/database/tables.dart';

/// C5.1 Lagerbestand (Nachtrag 2026-10-19, Kay-Entscheidung auf
/// Rückfrage) — reine Entscheidungslogik, kein DB-Zugriff (gleiches
/// Trennungsprinzip wie `open_items_service.dart`/`euer_service.dart`).
///
/// Bestandsrelevant sind nur Auftrag, Rechnung und Lieferschein — ein
/// Angebot ("dürfen dem Lager noch nicht als entnommen gekennzeichnet
/// werden") und eine Proforma-Rechnung lösen nie eine Buchung aus. Eine
/// Gutschrift ist ebenfalls bewusst NICHT hier enthalten — sie löst nie
/// eine ERST-Abbuchung aus, sondern immer eine eigenständige
/// Rückbuchung, siehe [shouldBookStockReturnOnCreditNoteFinalize].
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

/// C5-Nachtrag (Kay-Entscheidung 2026-10-21 auf die Frage "was ist noch
/// offen im ERP?": "Automatisch beim Finalisieren der Gutschrift") —
/// eine Gutschrift bucht beim eigenen Finalisieren immer eine
/// Rückbuchung der betroffenen Artikel-Positionen, unabhängig vom
/// Vorgängerdokument und unabhängig davon, ob dieses je gebucht hat.
/// Das ist bewusst keine "Gegenbuchung" im Sinne einer exakten
/// Umkehrung der ursprünglichen Buchung (eine Gutschrift kann eine
/// Teilmenge der Original-Positionen sein, siehe
/// `InvoiceRepository.createCreditNoteDraft`) — sie bucht einfach die
/// Mengen zurück, die sie selbst als Positionen enthält.
bool shouldBookStockReturnOnCreditNoteFinalize({required DocumentKind kind}) {
  return kind == DocumentKind.creditNote;
}
