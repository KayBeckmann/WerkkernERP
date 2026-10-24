import 'models.dart';

/// Fachdaten-Repository. **Jede** Methode ist zwingend firmengebunden
/// (`companyId`-Parameter) — es gibt bewusst keine firmenübergreifende
/// Abfrage, auch keine "nach ID global" (ADR-0001 B0.5). Eine fremde
/// ID liefert dadurch exakt dasselbe Ergebnis wie eine nicht
/// existierende (`null`/`false`), kein Oracle.
abstract class BusinessRepository {
  // ---- Kunden -----------------------------------------------------------
  Future<List<Customer>> listCustomers(String companyId, {String? query});
  Future<Customer?> findCustomer(String companyId, String id);
  Future<void> createCustomer(Customer customer);
  Future<bool> updateCustomer(Customer customer);

  /// Wirft [BusinessConflict], solange Dokumente den Kunden
  /// referenzieren (wie offline `onDelete: restrict`).
  Future<bool> deleteCustomer(String companyId, String id);

  // ---- Artikel ----------------------------------------------------------
  Future<List<Article>> listArticles(String companyId, {String? query, bool includeInactive = false});
  Future<Article?> findArticle(String companyId, String id);
  Future<void> createArticle(Article article);
  Future<bool> updateArticle(Article article);

  // ---- Dokumente ----------------------------------------------------------
  Future<List<Document>> listDocuments(String companyId, {String? kind, String? status, String? query});
  Future<Document?> findDocument(String companyId, String id);
  Future<List<DocumentItem>> itemsFor(String companyId, String documentId);
  Future<void> createDocument(Document document, List<DocumentItem> items);

  /// Ersetzt Kopf + alle Positionen eines **Entwurfs**. Wirft
  /// [BusinessConflict] bei finalisiertem Dokument oder wenn
  /// [expectedVersion] nicht mehr aktuell ist. Liefert die neue
  /// Fassung, `null` wenn nicht gefunden.
  Future<Document?> updateDraft({
    required String companyId,
    required String id,
    required int expectedVersion,
    required String customerId,
    required DateTime issueDate,
    required DateTime serviceDate,
    required String? paymentTerms,
    required String? notes,
    required List<DocumentItem> items,
    required DateTime now,
  });

  Future<bool> deleteDraft(String companyId, String id);

  /// Atomar: Nummer im Firmen-/Typ-/Jahreskreis ziehen, Schnappschüsse
  /// einfrieren, Status setzen (F3). Wirft [BusinessConflict], wenn das
  /// Dokument nicht (mehr) Entwurf ist oder [expectedVersion] veraltet
  /// ist — zwei gleichzeitige Aufrufe ergeben nie zwei Nummern.
  Future<Document?> finalize({
    required String companyId,
    required String id,
    required int expectedVersion,
    required String companySnapshotName,
    required DateTime now,
  });
}
