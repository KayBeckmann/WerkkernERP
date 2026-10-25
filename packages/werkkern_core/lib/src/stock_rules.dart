/// C5.1 Lagerbestand — Buchungsregeln, gemeinsam für Offline-App und
/// Server (Schlüssel = `DocumentKind`-Name).
///
/// Bestandsrelevant sind nur Auftrag, Rechnung und Lieferschein — ein
/// Angebot und eine Proforma buchen nie. **Genau eine Buchung pro
/// Dokumentenkette**, ausgelöst durch das erste bestandsrelevante
/// Dokument: Da Rechnung/Lieferschein nie Quelle einer Umwandlung sind,
/// reicht der Blick auf das unmittelbare Vorgängerdokument.
const stockRelevantDocumentKinds = {'order', 'invoice', 'deliveryNote'};

/// Ob die Finalisierung eines Dokuments der Art [kind] eine Abbuchung
/// auslöst. [predecessorKind] ist `null` ohne Umwandlung.
bool shouldBookStockOnFinalizeKind({required String kind, required String? predecessorKind}) {
  if (!stockRelevantDocumentKinds.contains(kind)) return false;
  return predecessorKind == null || !stockRelevantDocumentKinds.contains(predecessorKind);
}

/// Eine Gutschrift bucht beim Finalisieren immer eine Rückbuchung ihrer
/// eigenen Artikelmengen (C5-Nachtrag 2026-10-21).
bool shouldBookStockReturnKind(String kind) => kind == 'creditNote';
