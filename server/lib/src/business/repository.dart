import 'models.dart';
import 'accounting.dart';
import 'fleet.dart';
import 'stock.dart';
import 'suppliers.dart';

/// Fachdaten-Repository. **Jede** Methode ist zwingend firmengebunden
/// (`companyId`-Parameter) — es gibt bewusst keine firmenübergreifende
/// Abfrage, auch keine "nach ID global" (ADR-0001 B0.5). Eine fremde
/// ID liefert dadurch exakt dasselbe Ergebnis wie eine nicht
/// existierende (`null`/`false`), kein Oracle.
abstract class BusinessRepository implements SupplierStore, FleetStore, StockStore, AccountingStore {
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
  /// Legt ein Dokument an. Bei einer Umwandlung ([Document.convertedFromId])
  /// mit [expectedSourceVersion] wird die Quelle gesperrt und ihre Version
  /// geprüft ([BusinessConflict] bei Abweichung) — sonst könnte eine
  /// gleichzeitige Bearbeitung der noch editierbaren Quelle (siehe
  /// [updateDraft]) nach der Umwandlung durchrutschen.
  Future<void> createDocument(Document document, List<DocumentItem> items, {int? expectedSourceVersion});

  /// Ersetzt Kopf + alle Positionen eines bearbeitbaren Dokuments
  /// (Entwurf, oder finalisiertes Angebot/Auftrag/Proforma ohne
  /// Umwandlung — siehe `isDocumentEditable`). Wirft [BusinessConflict]
  /// bei nicht mehr bearbeitbarem Dokument oder wenn [expectedVersion]
  /// nicht mehr aktuell ist. Hat das Dokument schon Bestand gebucht
  /// ([Document.stockBooked]), wird die Mengendifferenz der Artikel in
  /// derselben Transaktion nachgebucht (Bewegung durch [userId]). Liefert die neue
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
    bool? isAdvancePayment,
    bool? isFixedPrice,
    String? userId,
  });

  Future<bool> deleteDraft(String companyId, String id);

  /// Atomar: Nummer im Firmen-/Typ-/Jahreskreis ziehen, Schnappschüsse
  /// einfrieren, Status setzen (F3). Wirft [BusinessConflict], wenn das
  /// Dokument nicht (mehr) Entwurf ist oder [expectedVersion] veraltet
  /// ist — zwei gleichzeitige Aufrufe ergeben nie zwei Nummern.
  /// [stockBooking]: in derselben Transaktion den Bestand der
  /// Artikelpositionen bewegen (Abgang bzw. Gutschrift-Rückbuchung); die
  /// Entscheidung trifft der Aufrufer nach `shouldBookStockOnFinalizeKind`.
  Future<Document?> finalize({
    required String companyId,
    required String id,
    required int expectedVersion,
    required CompanySnapshot company,
    required DateTime now,
    ({StockBookingMode mode, String userId})? stockBooking,
  });

  /// Dokumente, die per Umwandlung aus [sourceId] entstanden sind.
  Future<List<Document>> listConvertedFrom(String companyId, String sourceId);

  /// Zahlungsstatus (`open`/`paid`, setzt/löscht `paidAt`) und/oder
  /// Fälligkeit eines **finalisierten** Dokuments; wirft
  /// [BusinessConflict] bei einem Entwurf. `dueDate: () => null` löscht
  /// die Fälligkeit, `dueDate: null` lässt sie unverändert.
  Future<Document?> setPaymentInfo({
    required String companyId,
    required String id,
    String? paymentStatus,
    DateTime? Function()? dueDate,
    required DateTime now,
  });

  // ---- Zeiterfassung (C3 online) ----------------------------------------
  Future<List<TimeEntry>> listTimeEntries(
    String companyId, {
    String? userId,
    String? documentId,
    String? projectId,
    DateTime? from,
    DateTime? to,
  });
  Future<TimeEntry?> findTimeEntry(String companyId, String id);
  Future<void> createTimeEntry(TimeEntry entry);
  Future<bool> updateTimeEntry(TimeEntry entry);
  Future<bool> deleteTimeEntry(String companyId, String id);

  // ---- Projekte (C1 online) --------------------------------------------
  Future<List<Project>> listProjects(String companyId, {bool includeArchived = false});
  Future<Project?> findProject(String companyId, String id);

  /// Vergibt atomar die nächste Projektnummer (PP) im Firmen-/Jahreskreis.
  Future<Project> createProject({
    required String id,
    required String companyId,
    required String name,
    String? customerId,
    required DateTime now,
  });
  Future<bool> updateProject(Project project);

  /// Wirft [BusinessConflict], solange Dokumente/Zeiten zugeordnet sind
  /// (archivieren statt löschen, wie offline).
  Future<bool> deleteProject(String companyId, String id);
  Future<List<Document>> listDocumentsForProject(String companyId, String projectId);

  /// Projektzuordnung eines **Entwurfs** ändern (finalisierte Dokumente
  /// behalten ihre Nummer samt PP — daher dort unveränderlich).
  Future<Document?> setDocumentProject({
    required String companyId,
    required String id,
    required int expectedVersion,
    required String? projectId,
    required DateTime now,
  });
}
