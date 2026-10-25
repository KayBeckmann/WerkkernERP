import 'package:werkkern_core/werkkern_core.dart' as core;

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
/// Bestandsbuchung auslösen soll — Regel in `werkkern_core`
/// (`shouldBookStockOnFinalizeKind`), gemeinsam mit dem Server.
bool shouldBookStockOnFinalize({
  required DocumentKind kind,
  required DocumentKind? predecessorKind,
}) =>
    core.shouldBookStockOnFinalizeKind(kind: kind.name, predecessorKind: predecessorKind?.name);

/// Eine Gutschrift bucht beim eigenen Finalisieren immer eine
/// Rückbuchung ihrer Artikelmengen — siehe `werkkern_core`.
bool shouldBookStockReturnOnCreditNoteFinalize({required DocumentKind kind}) =>
    core.shouldBookStockReturnKind(kind.name);
