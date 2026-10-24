import 'package:postgres/postgres.dart';
import 'package:werkkern_core/werkkern_core.dart';

import 'models.dart';
import 'repository.dart';

/// Postgres-Fassung. Nimmt einen [SessionExecutor] (im Betrieb ein
/// `Pool`, in Tests eine einzelne `Connection`), damit Finalisierung
/// und Entwurfs-Update echte Transaktionen mit Zeilensperre bekommen.
class PostgresBusinessRepository implements BusinessRepository {
  PostgresBusinessRepository(this._db);
  final SessionExecutor _db;

  Future<Result> _q(String sql, [Map<String, Object?> parameters = const {}]) =>
      _db.run((s) => s.execute(Sql.named(sql), parameters: parameters));

  // ---- Kunden -------------------------------------------------------------

  static const _customerColumns = 'id, company_id, name, address, email, phone, vat_id, contact_person, notes, created_at';

  Customer _toCustomer(ResultRow r) => Customer(
        id: r[0] as String,
        companyId: r[1] as String,
        name: r[2] as String,
        address: r[3] as String?,
        email: r[4] as String?,
        phone: r[5] as String?,
        vatId: r[6] as String?,
        contactPerson: r[7] as String?,
        notes: r[8] as String?,
        createdAt: r[9] as DateTime,
      );

  @override
  Future<List<Customer>> listCustomers(String companyId, {String? query}) async {
    // position() statt LIKE: Nutzereingaben mit % oder _ werden nicht
    // als Platzhalter interpretiert.
    final result = await _q(
      'SELECT $_customerColumns FROM customers WHERE company_id = @companyId '
      "AND (@q = '' OR position(lower(@q) in lower(name)) > 0) ORDER BY lower(name)",
      {'companyId': companyId, 'q': query ?? ''},
    );
    return [for (final r in result) _toCustomer(r)];
  }

  @override
  Future<Customer?> findCustomer(String companyId, String id) async {
    final result = await _q(
      'SELECT $_customerColumns FROM customers WHERE company_id = @companyId AND id = @id',
      {'companyId': companyId, 'id': id},
    );
    return result.isEmpty ? null : _toCustomer(result.first);
  }

  Map<String, Object?> _customerParams(Customer c) => {
        'id': c.id,
        'companyId': c.companyId,
        'name': c.name,
        'address': c.address,
        'email': c.email,
        'phone': c.phone,
        'vatId': c.vatId,
        'contactPerson': c.contactPerson,
        'notes': c.notes,
        'createdAt': c.createdAt,
      };

  @override
  Future<void> createCustomer(Customer customer) async {
    await _q(
      'INSERT INTO customers ($_customerColumns) VALUES '
      '(@id, @companyId, @name, @address, @email, @phone, @vatId, @contactPerson, @notes, @createdAt)',
      _customerParams(customer),
    );
  }

  @override
  Future<bool> updateCustomer(Customer customer) async {
    final result = await _q(
      'UPDATE customers SET name = @name, address = @address, email = @email, phone = @phone, vat_id = @vatId, '
      'contact_person = @contactPerson, notes = @notes WHERE company_id = @companyId AND id = @id',
      // createdAt ist unveränderlich — der Treiber lehnt überzählige
      // Parameter ab, daher explizit entfernen.
      _customerParams(customer)..remove('createdAt'),
    );
    return result.affectedRows > 0;
  }

  @override
  Future<bool> deleteCustomer(String companyId, String id) async {
    if (await findCustomer(companyId, id) == null) return false;
    final referenced = await _q(
      'SELECT 1 FROM documents WHERE company_id = @companyId AND customer_id = @id LIMIT 1',
      {'companyId': companyId, 'id': id},
    );
    if (referenced.isNotEmpty) {
      throw const BusinessConflict('Kunde ist noch Dokumenten zugeordnet und kann nicht gelöscht werden.');
    }
    final result = await _q('DELETE FROM customers WHERE company_id = @companyId AND id = @id', {
      'companyId': companyId,
      'id': id,
    });
    return result.affectedRows > 0;
  }

  // ---- Artikel --------------------------------------------------------------

  static const _articleColumns = 'id, company_id, name, unit, sale_price_cents, active, created_at';

  Article _toArticle(ResultRow r) => Article(
        id: r[0] as String,
        companyId: r[1] as String,
        name: r[2] as String,
        unit: r[3] as String?,
        salePriceCents: r[4] as int?,
        active: r[5] as bool,
        createdAt: r[6] as DateTime,
      );

  @override
  Future<List<Article>> listArticles(String companyId, {String? query, bool includeInactive = false}) async {
    final result = await _q(
      'SELECT $_articleColumns FROM articles WHERE company_id = @companyId AND (@all OR active) '
      "AND (@q = '' OR position(lower(@q) in lower(name)) > 0) ORDER BY lower(name)",
      {'companyId': companyId, 'q': query ?? '', 'all': includeInactive},
    );
    return [for (final r in result) _toArticle(r)];
  }

  @override
  Future<Article?> findArticle(String companyId, String id) async {
    final result = await _q(
      'SELECT $_articleColumns FROM articles WHERE company_id = @companyId AND id = @id',
      {'companyId': companyId, 'id': id},
    );
    return result.isEmpty ? null : _toArticle(result.first);
  }

  Map<String, Object?> _articleParams(Article a) => {
        'id': a.id,
        'companyId': a.companyId,
        'name': a.name,
        'unit': a.unit,
        'price': a.salePriceCents,
        'active': a.active,
        'createdAt': a.createdAt,
      };

  @override
  Future<void> createArticle(Article article) async {
    await _q(
      'INSERT INTO articles ($_articleColumns) VALUES (@id, @companyId, @name, @unit, @price, @active, @createdAt)',
      _articleParams(article),
    );
  }

  @override
  Future<bool> updateArticle(Article article) async {
    final result = await _q(
      'UPDATE articles SET name = @name, unit = @unit, sale_price_cents = @price, active = @active '
      'WHERE company_id = @companyId AND id = @id',
      _articleParams(article)..remove('createdAt'),
    );
    return result.affectedRows > 0;
  }

  // ---- Dokumente --------------------------------------------------------------

  static const _documentColumns =
      'd.id, d.company_id, d.customer_id, d.kind, d.status, d.number, d.number_year, d.issue_date, d.service_date, '
      'd.payment_terms, d.notes, d.customer_snapshot_name, d.customer_snapshot_address, d.customer_snapshot_vat_id, '
      'd.company_snapshot_name, d.created_by_user_id, d.created_at, d.updated_at, d.finalized_at, d.version, '
      'd.company_snapshot_address, d.company_snapshot_tax_number, d.company_snapshot_vat_id, d.company_snapshot_iban, '
      'd.converted_from_id, d.payment_status, d.paid_at, d.due_date, d.project_id, d.is_advance_payment, d.is_fixed_price, '
      'd.intro_text_snapshot, d.closing_text_snapshot, d.footer_text_snapshot, d.small_business_exempt_snapshot';

  Document _toDocument(ResultRow r) => Document(
        id: r[0] as String,
        companyId: r[1] as String,
        customerId: r[2] as String,
        kind: r[3] as String,
        status: r[4] as String,
        number: r[5] as String?,
        numberYear: r[6] as int?,
        issueDate: r[7] as DateTime,
        serviceDate: r[8] as DateTime,
        paymentTerms: r[9] as String?,
        notes: r[10] as String?,
        customerSnapshotName: r[11] as String?,
        customerSnapshotAddress: r[12] as String?,
        customerSnapshotVatId: r[13] as String?,
        companySnapshotName: r[14] as String?,
        createdByUserId: r[15] as String,
        createdAt: r[16] as DateTime,
        updatedAt: r[17] as DateTime,
        finalizedAt: r[18] as DateTime?,
        version: r[19] as int,
        companySnapshotAddress: r[20] as String?,
        companySnapshotTaxNumber: r[21] as String?,
        companySnapshotVatId: r[22] as String?,
        companySnapshotIban: r[23] as String?,
        convertedFromId: r[24] as String?,
        paymentStatus: r[25] as String,
        paidAt: r[26] as DateTime?,
        dueDate: r[27] as DateTime?,
        projectId: r[28] as String?,
        isAdvancePayment: r[29] as bool,
        isFixedPrice: r[30] as bool,
        introTextSnapshot: r[31] as String?,
        closingTextSnapshot: r[32] as String?,
        footerTextSnapshot: r[33] as String?,
        smallBusinessExemptSnapshot: r[34] as bool,
      );

  @override
  Future<List<Document>> listDocuments(String companyId, {String? kind, String? status, String? query}) async {
    final result = await _q(
      'SELECT $_documentColumns FROM documents d JOIN customers c ON c.id = d.customer_id '
      'WHERE d.company_id = @companyId AND (@kind = \'\' OR d.kind = @kind) AND (@status = \'\' OR d.status = @status) '
      "AND (@q = '' OR position(lower(@q) in lower(coalesce(d.number, ''))) > 0 "
      'OR position(lower(@q) in lower(c.name)) > 0) ORDER BY d.created_at DESC',
      {'companyId': companyId, 'kind': kind ?? '', 'status': status ?? '', 'q': query ?? ''},
    );
    return [for (final r in result) _toDocument(r)];
  }

  @override
  Future<Document?> findDocument(String companyId, String id) async {
    final result = await _q(
      'SELECT $_documentColumns FROM documents d WHERE d.company_id = @companyId AND d.id = @id',
      {'companyId': companyId, 'id': id},
    );
    return result.isEmpty ? null : _toDocument(result.first);
  }

  static const _itemColumns =
      'i.id, i.document_id, i.kind, i.article_id, i.description, i.quantity, i.unit_price_cents, i.vat_rate_percent, '
      'i.unit, i.discount_percent, i.group_label, i.sort_order';

  DocumentItem _toItem(ResultRow r) => DocumentItem(
        id: r[0] as String,
        documentId: r[1] as String,
        kind: r[2] as String,
        articleId: r[3] as String?,
        description: r[4] as String,
        quantity: r[5] as String,
        unitPriceCents: r[6] as int,
        vatRatePercent: r[7] as double,
        unit: r[8] as String?,
        discountPercent: r[9] as double,
        groupLabel: r[10] as String?,
        sortOrder: r[11] as int,
      );

  @override
  Future<List<DocumentItem>> itemsFor(String companyId, String documentId) async {
    // JOIN auf documents erzwingt die Firmenbindung auch für Positionen.
    final result = await _q(
      'SELECT $_itemColumns FROM document_items i JOIN documents d ON d.id = i.document_id '
      'WHERE d.company_id = @companyId AND d.id = @documentId ORDER BY i.sort_order',
      {'companyId': companyId, 'documentId': documentId},
    );
    return [for (final r in result) _toItem(r)];
  }

  Future<void> _insertItems(Session s, List<DocumentItem> items) async {
    for (final i in items) {
      await s.execute(
        Sql.named(
          'INSERT INTO document_items (id, document_id, kind, article_id, description, quantity, unit_price_cents, '
          'vat_rate_percent, unit, discount_percent, group_label, sort_order) VALUES (@id, @documentId, @kind, '
          '@articleId, @description, @quantity, @price, @vat, @unit, @discount, @groupLabel, @sortOrder)',
        ),
        parameters: {
          'id': i.id,
          'documentId': i.documentId,
          'kind': i.kind,
          'articleId': i.articleId,
          'description': i.description,
          'quantity': i.quantity,
          'price': i.unitPriceCents,
          'vat': i.vatRatePercent,
          'unit': i.unit,
          'discount': i.discountPercent,
          'groupLabel': i.groupLabel,
          'sortOrder': i.sortOrder,
        },
      );
    }
  }

  @override
  Future<void> createDocument(Document d, List<DocumentItem> items, {int? expectedSourceVersion}) async {
    await _db.runTx((s) async {
      if (expectedSourceVersion != null) {
        final source = await s.execute(
          Sql.named('SELECT version FROM documents WHERE company_id = @companyId AND id = @id FOR UPDATE'),
          parameters: {'companyId': d.companyId, 'id': d.convertedFromId},
        );
        if (source.isEmpty || source.first[0] != expectedSourceVersion) {
          throw const BusinessConflict('Quelle wurde zwischenzeitlich geändert — bitte neu laden.');
        }
      }
      await s.execute(
        Sql.named(
          'INSERT INTO documents (id, company_id, customer_id, kind, status, issue_date, service_date, payment_terms, '
          'notes, created_by_user_id, created_at, updated_at, version, converted_from_id, project_id, '
          'is_advance_payment, is_fixed_price) VALUES (@id, @companyId, @customerId, @kind, @status, @issueDate, '
          '@serviceDate, @paymentTerms, @notes, @createdBy, @createdAt, @updatedAt, @version, @convertedFromId, '
          '@projectId, @advance, @fixed)',
        ),
        parameters: {
          'id': d.id,
          'companyId': d.companyId,
          'customerId': d.customerId,
          'kind': d.kind,
          'status': d.status,
          'issueDate': TypedValue(Type.date, d.issueDate),
          'serviceDate': TypedValue(Type.date, d.serviceDate),
          'paymentTerms': d.paymentTerms,
          'notes': d.notes,
          'createdBy': d.createdByUserId,
          'createdAt': d.createdAt,
          'updatedAt': d.updatedAt,
          'version': d.version,
          'convertedFromId': d.convertedFromId,
          'projectId': d.projectId,
          'advance': d.isAdvancePayment,
          'fixed': d.isFixedPrice,
        },
      );
      await _insertItems(s, items);
    });
  }

  /// Sperrt die Dokumentzeile bis Transaktionsende (`FOR UPDATE`) und
  /// prüft Entwurfsstatus + Version — gemeinsamer Schutz für Update und
  /// Finalisierung gegen parallele Änderungen.
  Future<ResultRow?> _lockDraft(TxSession s, String companyId, String id, int expectedVersion) async {
    final result = await s.execute(
      Sql.named('SELECT status, version, kind, customer_id FROM documents WHERE company_id = @companyId AND id = @id FOR UPDATE'),
      parameters: {'companyId': companyId, 'id': id},
    );
    if (result.isEmpty) return null;
    final row = result.first;
    if (row[0] != 'draft') throw const BusinessConflict('Dokument ist finalisiert und unveränderlich.');
    if (row[1] != expectedVersion) {
      throw BusinessConflict('Dokument wurde zwischenzeitlich geändert (Version ${row[1]}, erwartet $expectedVersion).');
    }
    return row;
  }

  /// Wie [_lockDraft], lässt aber zusätzlich ein finalisiertes
  /// Angebot/Auftrag/Proforma ohne Umwandlung zu (`isDocumentEditable`).
  /// Die Umwandlung sperrt dieselbe Zeile (siehe [createDocument]), daher
  /// kann zwischen Prüfung und Schreiben keine Umwandlung entstehen.
  Future<bool> _lockEditable(TxSession s, String companyId, String id, int expectedVersion) async {
    final result = await s.execute(
      Sql.named(
        'SELECT status, version, kind, EXISTS (SELECT 1 FROM documents c WHERE c.company_id = @companyId '
        'AND c.converted_from_id = @id) FROM documents WHERE company_id = @companyId AND id = @id FOR UPDATE',
      ),
      parameters: {'companyId': companyId, 'id': id},
    );
    if (result.isEmpty) return false;
    final row = result.first;
    if (!isDocumentEditable(kind: row[2] as String, isDraft: row[0] == 'draft', hasConversions: row[3] as bool)) {
      throw const BusinessConflict('Dokument ist finalisiert und unveränderlich.');
    }
    if (row[1] != expectedVersion) {
      throw BusinessConflict('Dokument wurde zwischenzeitlich geändert (Version ${row[1]}, erwartet $expectedVersion).');
    }
    return true;
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
  }) async {
    final updated = await _db.runTx((s) async {
      if (!await _lockEditable(s, companyId, id, expectedVersion)) return false;
      await s.execute(
        Sql.named(
          'UPDATE documents SET customer_id = @customerId, issue_date = @issueDate, service_date = @serviceDate, '
          'payment_terms = @paymentTerms, notes = @notes, updated_at = @now, version = version + 1, '
          'is_advance_payment = coalesce(@advance, is_advance_payment), '
          'is_fixed_price = coalesce(@fixed, is_fixed_price) WHERE company_id = @companyId AND id = @id',
        ),
        parameters: {
          'customerId': customerId,
          'issueDate': TypedValue(Type.date, issueDate),
          'serviceDate': TypedValue(Type.date, serviceDate),
          'paymentTerms': paymentTerms,
          'notes': notes,
          'now': now,
          'companyId': companyId,
          'id': id,
          'advance': TypedValue(Type.boolean, isAdvancePayment),
          'fixed': TypedValue(Type.boolean, isFixedPrice),
        },
      );
      await s.execute(Sql.named('DELETE FROM document_items WHERE document_id = @id'), parameters: {'id': id});
      await _insertItems(s, items);
      return true;
    });
    return updated ? findDocument(companyId, id) : null;
  }

  @override
  Future<bool> deleteDraft(String companyId, String id) async {
    final existing = await findDocument(companyId, id);
    if (existing == null) return false;
    final booked = await _q('SELECT 1 FROM time_entries WHERE document_id = @id LIMIT 1', {'id': id});
    if (booked.isNotEmpty) {
      throw const BusinessConflict('Auf diesen Entwurf sind Zeiten gebucht — erst umbuchen oder löschen.');
    }
    // Status in der WHERE-Klausel: ein zwischenzeitlich finalisiertes
    // Dokument wird nie gelöscht, auch nicht bei einem Wettlauf.
    final result = await _q("DELETE FROM documents WHERE company_id = @companyId AND id = @id AND status = 'draft'", {
      'companyId': companyId,
      'id': id,
    });
    if (result.affectedRows == 0) throw const BusinessConflict('Finalisierte Dokumente können nicht gelöscht werden.');
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
    final finalized = await _db.runTx((s) async {
      final row = await _lockDraft(s, companyId, id, expectedVersion);
      if (row == null) return false;
      final kind = row[2] as String;
      // C2: projektbezogen -> JJ = Gründungsjahr + PP (wie offline).
      final projectRow = await s.execute(
        Sql.named(
          'SELECT p.founding_year, p.project_number FROM documents d JOIN projects p ON p.id = d.project_id '
          'WHERE d.id = @id',
        ),
        parameters: {'id': id},
      );
      final year = projectRow.isEmpty ? now.year : projectRow.first[0] as int;
      final projectNumber = projectRow.isEmpty ? null : projectRow.first[1] as int;
      final sequence = await s.execute(
        Sql.named(
          'INSERT INTO number_sequences (company_id, document_type, year, last_number) VALUES (@companyId, @kind, @year, 1) '
          'ON CONFLICT (company_id, document_type, year) DO UPDATE SET last_number = number_sequences.last_number + 1 '
          'RETURNING last_number',
        ),
        parameters: {'companyId': companyId, 'kind': kind, 'year': year},
      );
      final number = formatNumberWithPrefix(
        prefix: documentNumberPrefixes[kind]!,
        year: year,
        number: sequence.first.first as int,
        projectNumber: projectNumber,
      );
      await s.execute(
        Sql.named(
          "UPDATE documents d SET status = 'finalized', number = @number, number_year = @year, finalized_at = @now, "
          'updated_at = @now, version = d.version + 1, company_snapshot_name = @companyName, '
          'company_snapshot_address = @companyAddress, company_snapshot_tax_number = @companyTaxNumber, '
          'company_snapshot_vat_id = @companyVatId, company_snapshot_iban = @companyIban, '
          'intro_text_snapshot = @intro, closing_text_snapshot = @closing, footer_text_snapshot = @footer, '
          'small_business_exempt_snapshot = @exempt, '
          'customer_snapshot_name = c.name, customer_snapshot_address = c.address, customer_snapshot_vat_id = c.vat_id '
          'FROM customers c WHERE c.id = d.customer_id AND d.company_id = @companyId AND d.id = @id',
        ),
        parameters: {
          'number': number,
          'year': year,
          'now': now,
          'companyName': company.name,
          'companyAddress': company.address,
          'companyTaxNumber': company.taxNumber,
          'companyVatId': company.vatId,
          'companyIban': company.iban,
          'intro': company.introText,
          'closing': company.closingText,
          'footer': company.footerText,
          'exempt': company.smallBusinessExempt,
          'companyId': companyId,
          'id': id,
        },
      );
      return true;
    });
    return finalized ? findDocument(companyId, id) : null;
  }

  @override
  Future<List<Document>> listConvertedFrom(String companyId, String sourceId) async {
    final result = await _q(
      'SELECT $_documentColumns FROM documents d WHERE d.company_id = @companyId AND d.converted_from_id = @sourceId '
      'ORDER BY d.created_at',
      {'companyId': companyId, 'sourceId': sourceId},
    );
    return [for (final r in result) _toDocument(r)];
  }

  @override
  Future<Document?> setPaymentInfo({
    required String companyId,
    required String id,
    String? paymentStatus,
    DateTime? Function()? dueDate,
    required DateTime now,
  }) async {
    final existing = await findDocument(companyId, id);
    if (existing == null) return null;
    if (existing.isDraft) throw const BusinessConflict('Zahlungsangaben gibt es erst für finalisierte Dokumente.');
    final newDue = dueDate != null ? dueDate() : existing.dueDate;
    final newStatus = paymentStatus ?? existing.paymentStatus;
    final newPaidAt = paymentStatus == null ? existing.paidAt : (paymentStatus == 'paid' ? now : null);
    // Status in der WHERE-Klausel: nur finalisierte Dokumente.
    await _q(
      'UPDATE documents SET payment_status = @status, paid_at = @paidAt, due_date = @due, updated_at = @now, '
      "version = version + 1 WHERE company_id = @companyId AND id = @id AND status = 'finalized'",
      {
        'status': newStatus,
        'paidAt': newPaidAt,
        'due': TypedValue(Type.date, newDue),
        'now': now,
        'companyId': companyId,
        'id': id,
      },
    );
    return findDocument(companyId, id);
  }

  // ---- Zeiterfassung ------------------------------------------------------

  static const _timeColumns =
      'id, company_id, user_id, document_id, work_date, hours, note, hourly_cost_cents, created_at, updated_at, project_id';

  TimeEntry _toTimeEntry(ResultRow r) => TimeEntry(
        id: r[0] as String,
        companyId: r[1] as String,
        userId: r[2] as String,
        documentId: r[3] as String?,
        workDate: r[4] as DateTime,
        hours: r[5] as String,
        note: r[6] as String?,
        hourlyCostCents: r[7] as int?,
        createdAt: r[8] as DateTime,
        updatedAt: r[9] as DateTime,
        projectId: r[10] as String?,
      );

  @override
  Future<List<TimeEntry>> listTimeEntries(
    String companyId, {
    String? userId,
    String? documentId,
    String? projectId,
    DateTime? from,
    DateTime? to,
  }) async {
    final result = await _q(
      'SELECT $_timeColumns FROM time_entries WHERE company_id = @companyId '
      "AND (@userId = '' OR user_id = @userId) AND (@documentId = '' OR document_id = @documentId) "
      "AND (@projectId = '' OR project_id = @projectId) "
      'AND (@from::date IS NULL OR work_date >= @from::date) AND (@to::date IS NULL OR work_date <= @to::date) '
      'ORDER BY work_date DESC, created_at DESC',
      {
        'companyId': companyId,
        'userId': userId ?? '',
        'documentId': documentId ?? '',
        'projectId': projectId ?? '',
        'from': TypedValue(Type.date, from),
        'to': TypedValue(Type.date, to),
      },
    );
    return [for (final r in result) _toTimeEntry(r)];
  }

  @override
  Future<TimeEntry?> findTimeEntry(String companyId, String id) async {
    final result = await _q(
      'SELECT $_timeColumns FROM time_entries WHERE company_id = @companyId AND id = @id',
      {'companyId': companyId, 'id': id},
    );
    return result.isEmpty ? null : _toTimeEntry(result.first);
  }

  Map<String, Object?> _timeParams(TimeEntry t) => {
        'id': t.id,
        'companyId': t.companyId,
        'userId': t.userId,
        'documentId': t.documentId,
        'projectId': t.projectId,
        'workDate': TypedValue(Type.date, t.workDate),
        'hours': t.hours,
        'note': t.note,
        'rate': t.hourlyCostCents,
        'createdAt': t.createdAt,
        'updatedAt': t.updatedAt,
      };

  @override
  Future<void> createTimeEntry(TimeEntry entry) async {
    await _q(
      'INSERT INTO time_entries ($_timeColumns) VALUES (@id, @companyId, @userId, @documentId, @workDate, @hours, '
      '@note, @rate, @createdAt, @updatedAt, @projectId)',
      _timeParams(entry),
    );
  }

  @override
  Future<bool> updateTimeEntry(TimeEntry entry) async {
    final result = await _q(
      'UPDATE time_entries SET document_id = @documentId, project_id = @projectId, work_date = @workDate, '
      'hours = @hours, note = @note, updated_at = @updatedAt WHERE company_id = @companyId AND id = @id',
      _timeParams(entry)
        ..remove('userId')
        ..remove('rate')
        ..remove('createdAt'),
    );
    return result.affectedRows > 0;
  }

  @override
  Future<bool> deleteTimeEntry(String companyId, String id) async {
    final result = await _q('DELETE FROM time_entries WHERE company_id = @companyId AND id = @id', {
      'companyId': companyId,
      'id': id,
    });
    return result.affectedRows > 0;
  }

  // ---- Projekte -------------------------------------------------------------

  static const _projectColumns = 'id, company_id, name, customer_id, status, founding_year, project_number, created_at';

  Project _toProject(ResultRow r) => Project(
        id: r[0] as String,
        companyId: r[1] as String,
        name: r[2] as String,
        customerId: r[3] as String?,
        status: r[4] as String,
        foundingYear: r[5] as int,
        projectNumber: r[6] as int,
        createdAt: r[7] as DateTime,
      );

  @override
  Future<List<Project>> listProjects(String companyId, {bool includeArchived = false}) async {
    final result = await _q(
      "SELECT $_projectColumns FROM projects WHERE company_id = @companyId AND (@all OR status = 'active') "
      'ORDER BY founding_year DESC, project_number DESC',
      {'companyId': companyId, 'all': includeArchived},
    );
    return [for (final r in result) _toProject(r)];
  }

  @override
  Future<Project?> findProject(String companyId, String id) async {
    final result = await _q(
      'SELECT $_projectColumns FROM projects WHERE company_id = @companyId AND id = @id',
      {'companyId': companyId, 'id': id},
    );
    return result.isEmpty ? null : _toProject(result.first);
  }

  @override
  Future<Project> createProject({
    required String id,
    required String companyId,
    required String name,
    String? customerId,
    required DateTime now,
  }) =>
      _db.runTx((s) async {
        final sequence = await s.execute(
          Sql.named(
            "INSERT INTO number_sequences (company_id, document_type, year, last_number) VALUES (@companyId, 'project', "
            '@year, 1) ON CONFLICT (company_id, document_type, year) DO UPDATE SET last_number = '
            'number_sequences.last_number + 1 RETURNING last_number',
          ),
          parameters: {'companyId': companyId, 'year': now.year},
        );
        final project = Project(
          id: id,
          companyId: companyId,
          name: name,
          customerId: customerId,
          status: 'active',
          foundingYear: now.year,
          projectNumber: sequence.first.first as int,
          createdAt: now,
        );
        await s.execute(
          Sql.named(
            'INSERT INTO projects ($_projectColumns) VALUES (@id, @companyId, @name, @customerId, @status, @year, '
            '@number, @createdAt)',
          ),
          parameters: {
            'id': id,
            'companyId': companyId,
            'name': name,
            'customerId': customerId,
            'status': 'active',
            'year': project.foundingYear,
            'number': project.projectNumber,
            'createdAt': now,
          },
        );
        return project;
      });

  @override
  Future<bool> updateProject(Project p) async {
    final result = await _q(
      'UPDATE projects SET name = @name, customer_id = @customerId, status = @status '
      'WHERE company_id = @companyId AND id = @id',
      {'name': p.name, 'customerId': p.customerId, 'status': p.status, 'companyId': p.companyId, 'id': p.id},
    );
    return result.affectedRows > 0;
  }

  @override
  Future<bool> deleteProject(String companyId, String id) async {
    if (await findProject(companyId, id) == null) return false;
    final used = await _q(
      'SELECT 1 FROM documents WHERE project_id = @id UNION ALL SELECT 1 FROM time_entries WHERE project_id = @id LIMIT 1',
      {'id': id},
    );
    if (used.isNotEmpty) {
      throw const BusinessConflict('Dem Projekt sind noch Dokumente oder Zeiten zugeordnet — archivieren statt löschen.');
    }
    final result = await _q('DELETE FROM projects WHERE company_id = @companyId AND id = @id', {'companyId': companyId, 'id': id});
    return result.affectedRows > 0;
  }

  @override
  Future<List<Document>> listDocumentsForProject(String companyId, String projectId) async {
    final result = await _q(
      'SELECT $_documentColumns FROM documents d WHERE d.company_id = @companyId AND d.project_id = @projectId '
      'ORDER BY d.created_at DESC',
      {'companyId': companyId, 'projectId': projectId},
    );
    return [for (final r in result) _toDocument(r)];
  }

  @override
  Future<Document?> setDocumentProject({
    required String companyId,
    required String id,
    required int expectedVersion,
    required String? projectId,
    required DateTime now,
  }) async {
    final updated = await _db.runTx((s) async {
      if (await _lockDraft(s, companyId, id, expectedVersion) == null) return false;
      await s.execute(
        Sql.named(
          'UPDATE documents SET project_id = @projectId, updated_at = @now, version = version + 1 '
          'WHERE company_id = @companyId AND id = @id',
        ),
        parameters: {'projectId': projectId, 'now': now, 'companyId': companyId, 'id': id},
      );
      return true;
    });
    return updated ? findDocument(companyId, id) : null;
  }
}
