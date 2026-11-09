import 'dart:typed_data';

import 'package:decimal/decimal.dart';
import 'package:uuid/uuid.dart';
import 'package:werkkern_core/werkkern_core.dart';

import 'models.dart';
import 'repository.dart';
import 'suppliers.dart';
import 'accounting.dart';
import 'dunning.dart';
import 'fleet.dart';
import 'purchasing.dart';
import 'recurring.dart';
import 'staff_roles.dart';
import 'timesheets.dart';
import 'company_import.dart';
import 'stock.dart';

part 'memory/suppliers.dart';
part 'memory/fleet.dart';
part 'memory/stock.dart';
part 'memory/accounting.dart';
part 'memory/purchasing.dart';
part 'memory/dunning.dart';
part 'memory/recurring.dart';
part 'memory/timesheets.dart';
part 'memory/staff_roles.dart';

class InMemoryBusinessRepository with _InMemorySuppliers, _InMemoryFleet, _InMemoryStock, _InMemoryAccounting, _InMemoryPurchasing, _InMemoryDunning, _InMemoryRecurring, _InMemoryTimeSheets, _InMemoryStaffRoles implements BusinessRepository {
  final List<Customer> _customers = [];
  @override
  final List<Article> _articles = [];
  @override
  final List<Document> _documents = [];
  @override
  final List<DocumentItem> _items = [];
  @override
  final Map<String, int> _sequences = {};
  @override
  final List<TimeEntry> _timeEntries = [];
  final List<Project> _projects = [];

  @override
  Future<List<Project>> listProjects(String companyId, {bool includeArchived = false}) async =>
      _projects.where((p) => p.companyId == companyId && (includeArchived || p.status == 'active')).toList()
        ..sort((a, b) => b.foundingYear != a.foundingYear
            ? b.foundingYear.compareTo(a.foundingYear)
            : b.projectNumber.compareTo(a.projectNumber));

  @override
  Future<Project?> findProject(String companyId, String id) async =>
      _projects.where((p) => p.companyId == companyId && p.id == id).firstOrNull;

  @override
  Future<Project> createProject({
    required String id,
    required String companyId,
    required String name,
    String? customerId,
    String? notes,
    required DateTime now,
  }) async {
    final key = '$companyId|project|${now.year}';
    final number = (_sequences[key] ?? 0) + 1;
    _sequences[key] = number;
    final project = Project(
      id: id,
      companyId: companyId,
      name: name,
      customerId: customerId,
      notes: notes,
      status: 'active',
      foundingYear: now.year,
      projectNumber: number,
      createdAt: now,
    );
    _projects.add(project);
    return project;
  }

  @override
  Future<bool> updateProject(Project project) async {
    final i = _projects.indexWhere((p) => p.companyId == project.companyId && p.id == project.id);
    if (i == -1) return false;
    _projects[i] = project;
    return true;
  }

  @override
  Future<bool> deleteProject(String companyId, String id) async {
    if (await findProject(companyId, id) == null) return false;
    if (_documents.any((d) => d.projectId == id) || _timeEntries.any((t) => t.projectId == id)) {
      throw const BusinessConflict('Dem Projekt sind noch Dokumente oder Zeiten zugeordnet — archivieren statt löschen.');
    }
    _projects.removeWhere((p) => p.id == id);
    return true;
  }

  @override
  Future<List<Document>> listDocumentsForProject(String companyId, String projectId) async =>
      _documents.where((d) => d.companyId == companyId && d.projectId == projectId).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  @override
  Future<Document?> setDocumentProject({
    required String companyId,
    required String id,
    required int expectedVersion,
    required String? projectId,
    required DateTime now,
  }) async {
    final index = _documents.indexWhere((d) => d.companyId == companyId && d.id == id);
    if (index == -1) return null;
    final existing = _documents[index];
    _checkWritable(existing, expectedVersion);
    final updated = existing.copyWith(projectId: () => projectId, updatedAt: now, version: existing.version + 1);
    _documents[index] = updated;
    return updated;
  }

  @override
  Future<List<TimeEntry>> listTimeEntries(
    String companyId, {
    String? userId,
    String? documentId,
    String? projectId,
    DateTime? from,
    DateTime? to,
  }) async =>
      _timeEntries
          .where((t) =>
              t.companyId == companyId &&
              (userId == null || t.userId == userId) &&
              (documentId == null || t.documentId == documentId) &&
              (projectId == null || t.projectId == projectId) &&
              (from == null || !t.workDate.isBefore(from)) &&
              (to == null || !t.workDate.isAfter(to)))
          .toList()
        ..sort((a, b) => b.workDate.compareTo(a.workDate));

  @override
  Future<TimeEntry?> findTimeEntry(String companyId, String id) async =>
      _timeEntries.where((t) => t.companyId == companyId && t.id == id).firstOrNull;

  @override
  Future<void> createTimeEntry(TimeEntry entry) async => _timeEntries.add(entry);

  @override
  Future<bool> updateTimeEntry(TimeEntry entry) async {
    final i = _timeEntries.indexWhere((t) => t.companyId == entry.companyId && t.id == entry.id);
    if (i == -1) return false;
    _timeEntries[i] = entry;
    return true;
  }

  @override
  Future<bool> deleteTimeEntry(String companyId, String id) async {
    final before = _timeEntries.length;
    _timeEntries.removeWhere((t) => t.companyId == companyId && t.id == id);
    return _timeEntries.length < before;
  }

  bool _matches(String? value, String? query) =>
      query == null || query.isEmpty || (value ?? '').toLowerCase().contains(query.toLowerCase());

  // ---- Kunden -------------------------------------------------------------

  final List<CustomerContact> _contacts = [];

  Customer _withContacts(Customer c) => c.withContacts(
        _contacts.where((x) => x.companyId == c.companyId && x.customerId == c.id).toList()
          ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder)),
      );

  @override
  Future<List<Customer>> listCustomers(String companyId, {String? query}) async =>
      _customers.where((c) => c.companyId == companyId && _matches(c.name, query)).map(_withContacts).toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  @override
  Future<Customer?> findCustomer(String companyId, String id) async {
    final customer = _customers.where((c) => c.companyId == companyId && c.id == id).firstOrNull;
    return customer == null ? null : _withContacts(customer);
  }

  @override
  Future<void> createCustomer(Customer customer) async => _customers.add(customer.withContacts(const []));

  @override
  Future<bool> updateCustomer(Customer customer) async {
    final index = _customers.indexWhere((c) => c.companyId == customer.companyId && c.id == customer.id);
    if (index == -1) return false;
    _customers[index] = customer.withContacts(const []);
    return true;
  }

  @override
  Future<bool> deleteCustomer(String companyId, String id) async {
    if (await findCustomer(companyId, id) == null) return false;
    if (_documents.any((d) => d.companyId == companyId && d.customerId == id)) {
      throw const BusinessConflict('Kunde ist noch Dokumenten zugeordnet und kann nicht gelöscht werden.');
    }
    _customers.removeWhere((c) => c.companyId == companyId && c.id == id);
    _contacts.removeWhere((x) => x.companyId == companyId && x.customerId == id);
    return true;
  }

  @override
  Future<void> replaceContacts(String companyId, String customerId, List<CustomerContact> contacts) async {
    final keep = {for (final c in contacts) c.id};
    final removed = {
      for (final x in _contacts)
        if (x.companyId == companyId && x.customerId == customerId && !keep.contains(x.id)) x.id,
    };
    _contacts.removeWhere((x) => x.companyId == companyId && x.customerId == customerId);
    _contacts.addAll(contacts);
    for (var i = 0; i < _documents.length; i++) {
      if (removed.contains(_documents[i].contactId)) _documents[i] = _documents[i].copyWith(contactId: () => null);
    }
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
    // Bestand ändert sich nur über Bewegungen (wie Postgres).
    _articles[index] = article.withStock(_articles[index].stockQuantity);
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
  Future<void> createDocument(Document document, List<DocumentItem> items, {int? expectedSourceVersion}) async {
    if (expectedSourceVersion != null) {
      final source = _documents.firstWhere((d) => d.companyId == document.companyId && d.id == document.convertedFromId);
      if (source.version != expectedSourceVersion) {
        throw const BusinessConflict('Quelle wurde zwischenzeitlich geändert — bitte neu laden.');
      }
    }
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
    bool? isAdvancePayment,
    bool? isFixedPrice,
    DateTime? Function()? dueDate,
    String? userId,
    String? Function()? contactId,
  }) async {
    // Bewusst ohne await zwischen Prüfung und Schreiben — damit ist der
    // Abschnitt in Dart (single-threaded) atomar, wie die
    // SELECT ... FOR UPDATE-Transaktion in Postgres.
    final index = _documents.indexWhere((d) => d.companyId == companyId && d.id == id);
    if (index == -1) return null;
    final existing = _documents[index];
    _checkEditable(existing, expectedVersion);
    final updated = existing.copyWith(
      customerId: customerId,
      issueDate: issueDate,
      serviceDate: serviceDate,
      paymentTerms: () => paymentTerms,
      notes: () => notes,
      updatedAt: now,
      version: existing.version + 1,
      isAdvancePayment: isAdvancePayment,
      isFixedPrice: isFixedPrice,
      dueDate: dueDate,
      contactId: contactId,
    );
    _documents[index] = updated;
    if (existing.stockBooked) {
      Map<String, Decimal> quantities(Iterable<DocumentItem> list) =>
          articleQuantities(list.map((i) => (articleId: i.articleId, quantity: i.quantity)));
      final before = quantities(_items.where((i) => i.documentId == id));
      final after = quantities(items);
      _bookStockSync(
        companyId,
        [
          for (final articleId in {...before.keys, ...after.keys})
            StockDelta(articleId, (before[articleId] ?? Decimal.zero) - (after[articleId] ?? Decimal.zero)),
        ],
        StockBookingContext(
          type: 'documentBooking',
          userId: userId ?? existing.createdByUserId,
          now: now,
          referenceLabel: existing.number,
          note: 'Korrektur nach Bearbeitung',
          documentId: id,
        ),
      );
    }
    _items.removeWhere((i) => i.documentId == id);
    _items.addAll(items);
    return updated;
  }

  @override
  Future<bool> deleteDraft(String companyId, String id) async {
    final existing = await findDocument(companyId, id);
    if (existing == null) return false;
    if (!existing.isDraft) throw const BusinessConflict('Finalisierte Dokumente können nicht gelöscht werden.');
    if (_timeEntries.any((t) => t.documentId == id)) {
      throw const BusinessConflict('Auf diesen Entwurf sind Zeiten gebucht — erst umbuchen oder löschen.');
    }
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
    ({StockBookingMode mode, String userId})? stockBooking,
  }) async {
    final index = _documents.indexWhere((d) => d.companyId == companyId && d.id == id);
    if (index == -1) return null;
    final existing = _documents[index];
    _checkWritable(existing, expectedVersion);
    final customer = _customers.firstWhere((c) => c.companyId == companyId && c.id == existing.customerId);

    // C2: projektbezogen -> JJ = Gründungsjahr des Projekts + PP; der
    // Zähler bucht konsistent in genau diesem Jahr (wie offline).
    final project = existing.projectId == null
        ? null
        : _projects.where((p) => p.id == existing.projectId).firstOrNull;
    final year = project?.foundingYear ?? now.year;
    final key = '$companyId|${existing.kind}|$year';
    final number = (_sequences[key] ?? 0) + 1;
    _sequences[key] = number;

    final finalized = existing.copyWith(
      status: 'finalized',
      number: formatNumberWithPrefix(
        prefix: documentNumberPrefixes[existing.kind]!,
        year: year,
        number: number,
        projectNumber: project?.projectNumber,
      ),
      numberYear: year,
      customerSnapshotName: customer.name,
      customerSnapshotAddress: customer.address,
      customerSnapshotVatId: customer.vatId,
      company: company,
      updatedAt: now,
      finalizedAt: now,
      version: existing.version + 1,
      stockBooked: stockBooking?.mode == StockBookingMode.issue,
    );
    _documents[index] = finalized;
    if (stockBooking != null) {
      final sign = stockBooking.mode == StockBookingMode.issue ? Decimal.fromInt(-1) : Decimal.one;
      final quantities = articleQuantities(
        _items.where((i) => i.documentId == id).map((i) => (articleId: i.articleId, quantity: i.quantity)),
      );
      _bookStockSync(
        companyId,
        [for (final e in quantities.entries) StockDelta(e.key, e.value * sign)],
        StockBookingContext(
          type: stockBooking.mode == StockBookingMode.issue ? 'documentBooking' : 'creditNoteReturn',
          userId: stockBooking.userId,
          now: now,
          referenceLabel: finalized.number,
          documentId: id,
        ),
      );
    }
    return finalized;
  }

  @override
  Future<List<Document>> listConvertedFrom(String companyId, String sourceId) async =>
      _documents.where((d) => d.companyId == companyId && d.convertedFromId == sourceId).toList();

  @override
  Future<Document?> setPaymentInfo({
    required String companyId,
    required String id,
    String? paymentStatus,
    DateTime? Function()? dueDate,
    required DateTime now,
  }) async {
    final index = _documents.indexWhere((d) => d.companyId == companyId && d.id == id);
    if (index == -1) return null;
    final existing = _documents[index];
    if (existing.isDraft) throw const BusinessConflict('Zahlungsangaben gibt es erst für finalisierte Dokumente.');
    final updated = existing.copyWith(
      paymentStatus: paymentStatus,
      paidAt: paymentStatus == null ? null : () => paymentStatus == 'paid' ? now : null,
      dueDate: dueDate,
      updatedAt: now,
      version: existing.version + 1,
    );
    _documents[index] = updated;
    return updated;
  }

  void _checkEditable(Document existing, int expectedVersion) {
    final hasConversions = _documents.any((d) => d.companyId == existing.companyId && d.convertedFromId == existing.id);
    if (!isDocumentEditable(kind: existing.kind, isDraft: existing.isDraft, hasConversions: hasConversions)) {
      throw const BusinessConflict('Dokument ist finalisiert und unveränderlich.');
    }
    _checkVersion(existing, expectedVersion);
  }

  void _checkWritable(Document existing, int expectedVersion) {
    if (!existing.isDraft) throw const BusinessConflict('Dokument ist finalisiert und unveränderlich.');
    _checkVersion(existing, expectedVersion);
  }

  void _checkVersion(Document existing, int expectedVersion) {
    if (existing.version != expectedVersion) {
      throw BusinessConflict(
        'Dokument wurde zwischenzeitlich geändert (Version ${existing.version}, erwartet $expectedVersion).',
      );
    }
  }

  // ---- B4 Umzug -------------------------------------------------------------

  @override
  Future<bool> companyHasBusinessData(String companyId) async {
    bool any<T>(Iterable<T> items, String Function(T) company) => items.any((e) => company(e) == companyId);
    return any(_customers, (c) => c.companyId) ||
        any(_articles, (a) => a.companyId) ||
        any(_documents, (d) => d.companyId) ||
        any(_projects, (p) => p.companyId) ||
        any(_timeEntries, (t) => t.companyId) ||
        any(_suppliers, (s) => s.companyId) ||
        any(_articleGroups, (g) => g.companyId) ||
        any(_vehicles, (v) => v.companyId) ||
        any(_expenses, (e) => e.companyId) ||
        any(_bankTransactions, (b) => b.companyId) ||
        any(_purchaseOrders, (o) => o.companyId) ||
        any(_stockMovements, (m) => m.companyId) ||
        any(_inventoryCounts, (c) => c.companyId) ||
        any(_recurringTemplates, (t) => t.companyId) ||
        any(_timeSheets, (t) => t.companyId);
  }

  /// In-Memory schreibt nur nach vollständiger Prüfung durch den Parser —
  /// hier kann nichts mehr scheitern, daher ohne Rückabwicklung.
  @override
  Future<void> importCompanyData(String companyId, CompanyImportData data) async {
    _staffRoles.removeWhere((r) => r.companyId == companyId);
    _expenseCategories.removeWhere((c) => c.companyId == companyId);
    _customers.addAll([for (final c in data.customers) c.withContacts(const [])]);
    for (final c in data.customers) {
      _contacts.addAll(c.contacts);
    }
    _suppliers.addAll(data.suppliers);
    _articleGroups.addAll(data.articleGroups);
    _articles.addAll(data.articles);
    for (final p in data.articlePrices) {
      _prices[_priceKey(p.articleId, p.supplierId)] = (companyId: companyId, price: p);
    }
    _projects.addAll(data.projects);
    _documents.addAll(data.documents);
    _items.addAll(data.documentItems);
    _vehicles.addAll(data.vehicles);
    _vehicleCosts.addAll(data.vehicleCosts);
    _recurringTemplates.addAll(data.recurringTemplates);
    _recurringItems.addAll(data.recurringItems);
    _expenseCategories.addAll(data.expenseCategories);
    _expenses.addAll(data.expenses);
    _bankTransactions.addAll(data.bankTransactions);
    _purchaseOrders.addAll(data.purchaseOrders);
    _purchaseOrderItems.addAll(data.purchaseOrderItems);
    _stockMovements.addAll(data.stockMovements);
    _inventoryCounts.addAll(data.inventoryCounts);
    _inventoryItems.addAll(data.inventoryItems);
    _staffRoles.addAll(data.staffRoles);
    _timeEntries.addAll(data.timeEntries);
    _timeSheets.addAll(data.timeSheets);
    for (final e in data.timeSheetEntries.entries) {
      for (final entryId in e.value) {
        _sheetByEntry[entryId] = e.key;
      }
    }
    for (final s in data.numberSequences) {
      _sequences['$companyId|${s.documentType}|${s.year}'] = s.lastNumber;
    }
    for (final e in data.settings.entries) {
      _companySettings['$companyId|${e.key}'] = Map.of(e.value);
    }
  }
}
