import 'package:werkkern_core/werkkern_core.dart';

import 'models.dart';
import 'repository.dart';

class InMemoryBusinessRepository implements BusinessRepository {
  final List<Customer> _customers = [];
  final List<Article> _articles = [];
  final List<Document> _documents = [];
  final List<DocumentItem> _items = [];
  final Map<String, int> _sequences = {};

  bool _matches(String? value, String? query) =>
      query == null || query.isEmpty || (value ?? '').toLowerCase().contains(query.toLowerCase());

  // ---- Kunden -------------------------------------------------------------

  @override
  Future<List<Customer>> listCustomers(String companyId, {String? query}) async =>
      _customers.where((c) => c.companyId == companyId && _matches(c.name, query)).toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  @override
  Future<Customer?> findCustomer(String companyId, String id) async =>
      _customers.where((c) => c.companyId == companyId && c.id == id).firstOrNull;

  @override
  Future<void> createCustomer(Customer customer) async => _customers.add(customer);

  @override
  Future<bool> updateCustomer(Customer customer) async {
    final index = _customers.indexWhere((c) => c.companyId == customer.companyId && c.id == customer.id);
    if (index == -1) return false;
    _customers[index] = customer;
    return true;
  }

  @override
  Future<bool> deleteCustomer(String companyId, String id) async {
    if (await findCustomer(companyId, id) == null) return false;
    if (_documents.any((d) => d.companyId == companyId && d.customerId == id)) {
      throw const BusinessConflict('Kunde ist noch Dokumenten zugeordnet und kann nicht gelöscht werden.');
    }
    _customers.removeWhere((c) => c.companyId == companyId && c.id == id);
    return true;
  }

  // ---- Artikel --------------------------------------------------------------

  @override
  Future<List<Article>> listArticles(String companyId, {String? query, bool includeInactive = false}) async =>
      _articles
          .where((a) => a.companyId == companyId && (includeInactive || a.active) && _matches(a.name, query))
          .toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  @override
  Future<Article?> findArticle(String companyId, String id) async =>
      _articles.where((a) => a.companyId == companyId && a.id == id).firstOrNull;

  @override
  Future<void> createArticle(Article article) async => _articles.add(article);

  @override
  Future<bool> updateArticle(Article article) async {
    final index = _articles.indexWhere((a) => a.companyId == article.companyId && a.id == article.id);
    if (index == -1) return false;
    _articles[index] = article;
    return true;
  }

  // ---- Dokumente --------------------------------------------------------------

  @override
  Future<List<Document>> listDocuments(String companyId, {String? kind, String? status, String? query}) async {
    final customerNames = {for (final c in _customers.where((c) => c.companyId == companyId)) c.id: c.name};
    return _documents
        .where((d) =>
            d.companyId == companyId &&
            (kind == null || d.kind == kind) &&
            (status == null || d.status == status) &&
            (_matches(d.number, query) || _matches(customerNames[d.customerId], query)))
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  Future<Document?> findDocument(String companyId, String id) async =>
      _documents.where((d) => d.companyId == companyId && d.id == id).firstOrNull;

  @override
  Future<List<DocumentItem>> itemsFor(String companyId, String documentId) async {
    if (await findDocument(companyId, documentId) == null) return const [];
    return _items.where((i) => i.documentId == documentId).toList()..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  }

  @override
  Future<void> createDocument(Document document, List<DocumentItem> items) async {
    _documents.add(document);
    _items.addAll(items);
  }

  @override
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
  }) async {
    // Bewusst ohne await zwischen Prüfung und Schreiben — damit ist der
    // Abschnitt in Dart (single-threaded) atomar, wie die
    // SELECT ... FOR UPDATE-Transaktion in Postgres.
    final index = _documents.indexWhere((d) => d.companyId == companyId && d.id == id);
    if (index == -1) return null;
    final existing = _documents[index];
    _checkWritable(existing, expectedVersion);
    final updated = Document(
      id: existing.id,
      companyId: existing.companyId,
      customerId: customerId,
      kind: existing.kind,
      status: existing.status,
      issueDate: issueDate,
      serviceDate: serviceDate,
      paymentTerms: paymentTerms,
      notes: notes,
      createdByUserId: existing.createdByUserId,
      createdAt: existing.createdAt,
      updatedAt: now,
      version: existing.version + 1,
    );
    _documents[index] = updated;
    _items.removeWhere((i) => i.documentId == id);
    _items.addAll(items);
    return updated;
  }

  @override
  Future<bool> deleteDraft(String companyId, String id) async {
    final existing = await findDocument(companyId, id);
    if (existing == null) return false;
    if (!existing.isDraft) throw const BusinessConflict('Finalisierte Dokumente können nicht gelöscht werden.');
    _documents.removeWhere((d) => d.id == id);
    _items.removeWhere((i) => i.documentId == id);
    return true;
  }

  @override
  Future<Document?> finalize({
    required String companyId,
    required String id,
    required int expectedVersion,
    required CompanySnapshot company,
    required DateTime now,
  }) async {
    final index = _documents.indexWhere((d) => d.companyId == companyId && d.id == id);
    if (index == -1) return null;
    final existing = _documents[index];
    _checkWritable(existing, expectedVersion);
    final customer = _customers.firstWhere((c) => c.companyId == companyId && c.id == existing.customerId);

    final key = '$companyId|${existing.kind}|${now.year}';
    final number = (_sequences[key] ?? 0) + 1;
    _sequences[key] = number;

    final finalized = Document(
      id: existing.id,
      companyId: existing.companyId,
      customerId: existing.customerId,
      kind: existing.kind,
      status: 'finalized',
      number: formatNumberWithPrefix(prefix: documentNumberPrefixes[existing.kind]!, year: now.year, number: number),
      numberYear: now.year,
      issueDate: existing.issueDate,
      serviceDate: existing.serviceDate,
      paymentTerms: existing.paymentTerms,
      notes: existing.notes,
      customerSnapshotName: customer.name,
      customerSnapshotAddress: customer.address,
      customerSnapshotVatId: customer.vatId,
      companySnapshotName: company.name,
      companySnapshotAddress: company.address,
      companySnapshotTaxNumber: company.taxNumber,
      companySnapshotVatId: company.vatId,
      companySnapshotIban: company.iban,
      createdByUserId: existing.createdByUserId,
      createdAt: existing.createdAt,
      updatedAt: now,
      finalizedAt: now,
      version: existing.version + 1,
    );
    _documents[index] = finalized;
    return finalized;
  }

  void _checkWritable(Document existing, int expectedVersion) {
    if (!existing.isDraft) throw const BusinessConflict('Dokument ist finalisiert und unveränderlich.');
    if (existing.version != expectedVersion) {
      throw BusinessConflict(
        'Dokument wurde zwischenzeitlich geändert (Version ${existing.version}, erwartet $expectedVersion).',
      );
    }
  }
}
