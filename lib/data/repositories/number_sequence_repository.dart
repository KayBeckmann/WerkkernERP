import 'package:drift/drift.dart';

import '../database/database.dart';
import '../database/tables.dart';

/// Nummernkreise je Firma, Dokumenttyp und Jahr (F3/F5). `allocateNext()`
/// **muss** innerhalb derselben Drift-Transaktion laufen wie die
/// anschließende Finalisierung, die die Nummer tatsächlich verwendet —
/// sonst könnte zwischen Allokation und Verwendung eine andere
/// Transaktion dieselbe Nummer vergeben. Drifts `NativeDatabase`
/// serialisiert alle Schreibzugriffe auf einer einzigen Verbindung;
/// solange Lesen+Schreiben in einem `transaction()`-Block liegen, ist das
/// ausreichend gegen gleichzeitiges/doppeltes Antippen (kein separates
/// Datenbank-Locking nötig).
class NumberSequenceRepository {
  NumberSequenceRepository(this._db);

  final AppDatabase _db;

  /// Erhöht den Zähler für (companyId, documentType, year) um eins und
  /// gibt den neuen Wert zurück. **Nicht** auf drei Stellen begrenzt (F5:
  /// "niemals bei Überlauf wiederverwendete Nummern ausgeben") — das
  /// Anzeigeformat ([formatInvoiceNumber]) wächst natürlich über `xxx`
  /// hinaus.
  Future<int> allocateNext({
    required String companyId,
    required String documentType,
    required int year,
  }) async {
    final existing = await (_db.select(_db.numberSequences)
          ..where(
            (s) =>
                s.companyId.equals(companyId) &
                s.documentType.equals(documentType) &
                s.year.equals(year),
          ))
        .getSingleOrNull();

    final next = (existing?.lastNumber ?? 0) + 1;
    if (existing == null) {
      await _db.into(_db.numberSequences).insert(
            NumberSequencesCompanion.insert(
              companyId: companyId,
              documentType: documentType,
              year: year,
              lastNumber: Value(next),
            ),
          );
    } else {
      await (_db.update(_db.numberSequences)
            ..where(
              (s) =>
                  s.companyId.equals(companyId) &
                  s.documentType.equals(documentType) &
                  s.year.equals(year),
            ))
          .write(NumberSequencesCompanion(lastNumber: Value(next)));
    }
    return next;
  }
}

/// Präfix je Dokumentart (Roadmap: "An" Angebot, "A" Auftrag, "R"
/// Rechnung — nie mit dem Rechnungszähler vermischt, siehe A5).
String _prefixFor(DocumentKind kind) => switch (kind) {
      DocumentKind.invoice => 'R',
      DocumentKind.quote => 'An',
      DocumentKind.order => 'A',
      DocumentKind.deliveryNote => 'LS',
    };

/// `R-JJxxx`/`An-JJxxx`/`A-JJxxx`, z. B. `R-26054` — mindestens drei
/// Stellen, wächst darüber hinaus ohne Begrenzung (F5).
String formatDocumentNumber({required DocumentKind kind, required int year, required int number}) {
  final shortYear = (year % 100).toString().padLeft(2, '0');
  final paddedNumber = number.toString().padLeft(3, '0');
  return '${_prefixFor(kind)}-$shortYear$paddedNumber';
}
