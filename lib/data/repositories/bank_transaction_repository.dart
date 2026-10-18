import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../domain/services/bank_csv_import_service.dart';
import '../database/database.dart';

/// C14.4 Bankabgleich (Kay-Priorisierungsentscheidung 2026-10-18) —
/// gleiche companyId-Isolation wie alle übrigen A0-Repositories.
class BankTransactionRepository {
  BankTransactionRepository(this._db);

  final AppDatabase _db;
  static const _uuid = Uuid();

  Future<List<BankTransaction>> listForCompany(
    String companyId, {
    bool onlyUnmatched = false,
  }) {
    final query = _db.select(_db.bankTransactions)..where((t) => t.companyId.equals(companyId));
    if (onlyUnmatched) {
      query.where((t) => t.matchedInvoiceId.isNull());
    }
    query.orderBy([(t) => OrderingTerm.desc(t.date)]);
    return query.get();
  }

  /// Importiert geparste Transaktionen, überspringt dabei bereits
  /// vorhandene (gleicher `importHash` für dieselbe Firma) — so kann
  /// derselbe CSV-Export mehrfach (z. B. mit überlappendem Zeitraum)
  /// importiert werden, ohne Duplikate zu erzeugen. Gibt zurück, wie
  /// viele tatsächlich neu angelegt und wie viele übersprungen wurden.
  Future<({int imported, int skippedDuplicates})> importParsed({
    required String companyId,
    required List<ParsedBankTransaction> transactions,
  }) async {
    final existingHashes = (await listForCompany(companyId)).map((t) => t.importHash).toSet();
    var imported = 0;
    var skipped = 0;
    final now = DateTime.now();
    for (final tx in transactions) {
      if (existingHashes.contains(tx.importHash)) {
        skipped++;
        continue;
      }
      await _db.into(_db.bankTransactions).insert(
            BankTransactionsCompanion.insert(
              id: _uuid.v4(),
              companyId: companyId,
              date: tx.date,
              amountCents: tx.amountCents,
              purpose: Value(tx.purpose),
              counterparty: Value(tx.counterparty),
              importHash: tx.importHash,
              importedAt: now,
            ),
          );
      existingHashes.add(tx.importHash);
      imported++;
    }
    return (imported: imported, skippedDuplicates: skipped);
  }

  /// Ordnet eine Transaktion EINER Rechnung zu — rein auf der
  /// Transaktion, löst **keine** Buchung auf der Rechnung selbst aus
  /// (das macht der Aufruf-Code zusätzlich bewusst getrennt über
  /// `InvoiceRepository.markPaid()`, falls gewünscht; siehe
  /// `BankReconciliationScreen`).
  Future<bool> setMatchedInvoice({
    required String companyId,
    required String id,
    required String? invoiceId,
  }) async {
    final rows = await (_db.update(_db.bankTransactions)
          ..where((t) => t.id.equals(id) & t.companyId.equals(companyId)))
        .write(BankTransactionsCompanion(matchedInvoiceId: Value(invoiceId)));
    return rows > 0;
  }

  Future<bool> delete({required String companyId, required String id}) async {
    final rows = await (_db.delete(_db.bankTransactions)
          ..where((t) => t.id.equals(id) & t.companyId.equals(companyId)))
        .go();
    return rows > 0;
  }
}
