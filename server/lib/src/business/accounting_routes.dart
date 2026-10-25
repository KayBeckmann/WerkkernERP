import 'package:decimal/decimal.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:uuid/uuid.dart';
import 'package:werkkern_core/werkkern_core.dart';

import '../auth.dart';
import '../repository.dart';
import '../util/responses.dart';
import 'accounting.dart';
import 'models.dart';
import 'repository.dart';
import 'request_util.dart';

/// Bruttosumme eines Dokuments (gleiche Rechnung wie überall: Steuer auf
/// die Netto-Summe je Satz).
int documentGrossCents(List<DocumentItem> items) => calculateInvoiceTotals([
      for (final i in items)
        InvoiceLineInput(
          quantity: Decimal.parse(i.quantity),
          unitPriceCents: i.unitPriceCents,
          vatRatePercent: i.vatRatePercent,
          discountPercent: i.discountPercent,
        ),
    ]).totalGross.cents;

/// Buchhaltung (C14) — `accounting.read`/`accounting.write`, Modul
/// `buchhaltung`. Zahlungseingang an Rechnungen bleibt beim Recht
/// `invoices.payment`.
class AccountingRoutes {
  AccountingRoutes({required this.repository, required this.business, required this.auth});

  final PhaseBRepository repository;
  final BusinessRepository business;
  final SessionAuthenticator auth;
  static const _uuid = Uuid();

  void mount(Router router) {
    router.get('/expense-categories', _listCategories);
    router.post('/expense-categories', _createCategory);
    router.put('/expense-categories/<id>', _updateCategory);
    router.delete('/expense-categories/<id>', _deleteCategory);

    router.get('/expenses', _listExpenses);
    router.post('/expenses', _createExpense);
    router.put('/expenses/<id>', _updateExpense);
    router.delete('/expenses/<id>', _deleteExpense);

    router.get('/accounting/open-items', _openItems);
    router.get('/accounting/euer', _euer);
    router.get('/accounting/settings', _getSettings);
    router.put('/accounting/settings', _setSettings);
    router.get('/accounting/datev', _datev);

    router.get('/bank-transactions', _listBank);
    router.post('/bank-transactions/import', _importBank);
    router.put('/bank-transactions/<id>/match', _matchBank);
    router.delete('/bank-transactions/<id>', _deleteBank);
  }

  // ---- Kategorien ---------------------------------------------------------------

  /// Legt beim ersten Abruf die Standardkategorien an (wie offline beim
  /// ersten Öffnen der Belege), sofern der Aufrufer schreiben darf.
  Future<Response> _listCategories(Request request) async {
    final check = await auth.requirePermission(request, 'accounting.read');
    if (check.error != null) return check.error!;
    final companyId = check.auth!.session.companyId;
    var categories = await business.listExpenseCategories(companyId);
    if (categories.isEmpty && await auth.isGranted(check.auth!, 'accounting.write')) {
      final now = DateTime.now().toUtc();
      for (final label in defaultExpenseCategoryLabels) {
        await business.createExpenseCategory(ExpenseCategory(id: _uuid.v4(), companyId: companyId, label: label, createdAt: now));
      }
      categories = await business.listExpenseCategories(companyId);
    }
    return jsonOk({'categories': [for (final c in categories) c.toJson()]});
  }

  Future<Response> _createCategory(Request request) async {
    final check = await auth.requirePermission(request, 'accounting.write');
    if (check.error != null) return check.error!;
    final body = await readJsonBody(request);
    final label = trimmedOrNull(body['label']);
    if (label == null) return jsonError('label ist Pflicht.');
    final category = ExpenseCategory(
      id: _uuid.v4(),
      companyId: check.auth!.session.companyId,
      label: label,
      skr03Account: trimmedOrNull(body['skr03Account']),
      createdAt: DateTime.now().toUtc(),
    );
    await business.createExpenseCategory(category);
    await auth.audit(check.auth!, 'expenseCategory.create', 'expenseCategory', category.id);
    return jsonOk(category.toJson(), status: 201);
  }

  Future<Response> _updateCategory(Request request, String id) async {
    final check = await auth.requirePermission(request, 'accounting.write');
    if (check.error != null) return check.error!;
    final companyId = check.auth!.session.companyId;
    final existing = await business.findExpenseCategory(companyId, id);
    if (existing == null) return jsonError('Kategorie nicht gefunden.', status: 404);
    final body = await readJsonBody(request);
    final label = trimmedOrNull(body['label']);
    if (label == null) return jsonError('label ist Pflicht.');
    final category = ExpenseCategory(
      id: id,
      companyId: companyId,
      label: label,
      skr03Account: trimmedOrNull(body['skr03Account']),
      createdAt: existing.createdAt,
    );
    await business.updateExpenseCategory(category);
    await auth.audit(check.auth!, 'expenseCategory.update', 'expenseCategory', id);
    return jsonOk(category.toJson());
  }

  Future<Response> _deleteCategory(Request request, String id) async {
    final check = await auth.requirePermission(request, 'accounting.write');
    if (check.error != null) return check.error!;
    if (!await business.deleteExpenseCategory(check.auth!.session.companyId, id)) {
      return jsonError('Kategorie nicht gefunden.', status: 404);
    }
    await auth.audit(check.auth!, 'expenseCategory.delete', 'expenseCategory', id);
    return Response(204);
  }

  // ---- Belege -------------------------------------------------------------------

  Future<({Expense? expense, Response? error})> _expenseFromBody(
    Map<String, Object?> body, {
    required String id,
    required String companyId,
    required String userId,
    required DateTime createdAt,
    String? purchaseOrderId,
  }) async {
    final date = dateOrNull(body['date']);
    final description = trimmedOrNull(body['description']);
    final amount = body['amountGrossCents'];
    final vat = body['vatRatePercent'];
    if (date == null || description == null || amount is! int || amount < 0 || vat is! num || vat < 0) {
      return (
        expense: null,
        error: jsonError('date (JJJJ-MM-TT), description, amountGrossCents (>= 0) und vatRatePercent (>= 0) sind Pflicht.'),
      );
    }
    final categoryId = trimmedOrNull(body['categoryId']);
    if (categoryId != null && await business.findExpenseCategory(companyId, categoryId) == null) {
      return (expense: null, error: jsonError('Kategorie nicht gefunden.', status: 404));
    }
    final projectId = trimmedOrNull(body['projectId']);
    if (projectId != null && await business.findProject(companyId, projectId) == null) {
      return (expense: null, error: jsonError('Projekt nicht gefunden.', status: 404));
    }
    return (
      expense: Expense(
        id: id,
        companyId: companyId,
        date: date,
        description: description,
        amountGrossCents: amount,
        vatRatePercent: vat.toDouble(),
        categoryId: categoryId,
        supplierReference: trimmedOrNull(body['supplierReference']),
        projectId: projectId,
        purchaseOrderId: purchaseOrderId,
        createdByUserId: userId,
        createdAt: createdAt,
        updatedAt: DateTime.now().toUtc(),
      ),
      error: null,
    );
  }

  Future<Response> _listExpenses(Request request) async {
    final check = await auth.requirePermission(request, 'accounting.read');
    if (check.error != null) return check.error!;
    final params = request.url.queryParameters;
    final expenses = await business.listExpenses(
      check.auth!.session.companyId,
      from: dateOrNull(params['from']),
      to: dateOrNull(params['to']),
      projectId: trimmedOrNull(params['projectId']),
    );
    return jsonOk({
      'expenses': [for (final e in expenses) e.toJson()],
      'totalGrossCents': expenses.fold<int>(0, (sum, e) => sum + e.amountGrossCents),
    });
  }

  Future<Response> _createExpense(Request request) async {
    final check = await auth.requirePermission(request, 'accounting.write');
    if (check.error != null) return check.error!;
    final now = DateTime.now().toUtc();
    final result = await _expenseFromBody(
      await readJsonBody(request),
      id: _uuid.v4(),
      companyId: check.auth!.session.companyId,
      userId: check.auth!.session.userId,
      createdAt: now,
    );
    if (result.error != null) return result.error!;
    await business.createExpense(result.expense!);
    await auth.audit(check.auth!, 'expense.create', 'expense', result.expense!.id);
    return jsonOk(result.expense!.toJson(), status: 201);
  }

  Future<Response> _updateExpense(Request request, String id) async {
    final check = await auth.requirePermission(request, 'accounting.write');
    if (check.error != null) return check.error!;
    final companyId = check.auth!.session.companyId;
    final existing = await business.findExpense(companyId, id);
    if (existing == null) return jsonError('Beleg nicht gefunden.', status: 404);
    final result = await _expenseFromBody(
      await readJsonBody(request),
      id: id,
      companyId: companyId,
      userId: existing.createdByUserId,
      createdAt: existing.createdAt,
      purchaseOrderId: existing.purchaseOrderId,
    );
    if (result.error != null) return result.error!;
    await business.updateExpense(result.expense!);
    await auth.audit(check.auth!, 'expense.update', 'expense', id);
    return jsonOk(result.expense!.toJson());
  }

  Future<Response> _deleteExpense(Request request, String id) async {
    final check = await auth.requirePermission(request, 'accounting.write');
    if (check.error != null) return check.error!;
    if (!await business.deleteExpense(check.auth!.session.companyId, id)) {
      return jsonError('Beleg nicht gefunden.', status: 404);
    }
    await auth.audit(check.auth!, 'expense.delete', 'expense', id);
    return Response(204);
  }

  // ---- Auswertungen -------------------------------------------------------------

  /// Finalisierte, unbezahlte Rechnungen je Kunde, größte Summe zuerst.
  Future<Response> _openItems(Request request) async {
    final check = await auth.requirePermission(request, 'accounting.read');
    if (check.error != null) return check.error!;
    final companyId = check.auth!.session.companyId;
    final byCustomer = <String, ({String name, List<Map<String, Object?>> items, int total})>{};
    for (final d in await business.listDocuments(companyId, kind: 'invoice', status: 'finalized')) {
      if (!hasPaymentStatusKind(d.kind) || d.paymentStatus != 'open') continue;
      final gross = documentGrossCents(await business.itemsFor(companyId, d.id));
      final entry = byCustomer[d.customerId] ??
          (name: d.customerSnapshotName ?? (await business.findCustomer(companyId, d.customerId))?.name ?? '', items: <Map<String, Object?>>[], total: 0);
      entry.items.add({...d.toJson(), 'grossCents': gross});
      byCustomer[d.customerId] = (name: entry.name, items: entry.items, total: entry.total + gross);
    }
    final groups = byCustomer.entries.toList()..sort((a, b) => b.value.total.compareTo(a.value.total));
    return jsonOk({
      'customers': [
        for (final g in groups) {'customerId': g.key, 'customerName': g.value.name, 'totalCents': g.value.total, 'items': g.value.items},
      ],
      'totalCents': groups.fold<int>(0, (sum, g) => sum + g.value.total),
    });
  }

  /// Interne EÜR-Übersicht (keine steuerliche EÜR, wie offline): Einnahmen
  /// aus Rechnungen abzüglich Gutschriften nach Rechnungsdatum, Ausgaben
  /// aus Belegen je Kategorie und — bei aktivem Fuhrpark — Fahrzeugkosten
  /// als Gemeinkosten.
  Future<Response> _euer(Request request) async {
    final check = await auth.requirePermission(request, 'accounting.read');
    if (check.error != null) return check.error!;
    final companyId = check.auth!.session.companyId;
    final params = request.url.queryParameters;
    final from = dateOrNull(params['from']);
    final to = dateOrNull(params['to']);
    if (from == null || to == null || to.isBefore(from)) return jsonError('from und to (JJJJ-MM-TT) sind Pflicht.');
    bool within(DateTime d) => !d.isBefore(from) && !d.isAfter(to);

    var income = 0;
    for (final d in await business.listDocuments(companyId, status: 'finalized')) {
      final sign = revenueSignForKind(d.kind);
      if (sign == 0 || !within(d.issueDate)) continue;
      income += documentGrossCents(await business.itemsFor(companyId, d.id)) * sign;
    }
    final categories = {for (final c in await business.listExpenseCategories(companyId)) c.id: c};
    final byCategory = <String, int>{};
    for (final e in await business.listExpenses(companyId, from: from, to: to)) {
      byCategory[e.categoryId ?? ''] = (byCategory[e.categoryId ?? ''] ?? 0) + e.amountGrossCents;
    }
    final lines = [
      for (final entry in byCategory.entries)
        {
          'categoryId': entry.key.isEmpty ? null : entry.key,
          'label': entry.key.isEmpty ? 'Ohne Kategorie' : categories[entry.key]?.label ?? 'Ohne Kategorie',
          'skr03Account': categories[entry.key]?.skr03Account,
          'totalCents': entry.value,
        },
    ];
    final modules = (await repository.findCompanyById(companyId))?.enabledModules ?? const {};
    if (modules.contains('fleet')) {
      final fleet = (await business.listVehicleCosts(companyId, from: from, to: to)).fold<int>(0, (s, c) => s + c.amountCents);
      if (fleet != 0) {
        lines.add({'categoryId': null, 'label': 'Fuhrpark (Gemeinkosten)', 'skr03Account': null, 'totalCents': fleet});
      }
    }
    lines.sort((a, b) => (b['totalCents'] as int).compareTo(a['totalCents'] as int));
    final expenses = lines.fold<int>(0, (sum, l) => sum + (l['totalCents'] as int));
    return jsonOk({
      'from': dateJson(from),
      'to': dateJson(to),
      'incomeCents': income,
      'expensesCents': expenses,
      'surplusCents': income - expenses,
      'expensesByCategory': lines,
    });
  }

  // ---- Einstellungen + DATEV ----------------------------------------------------

  static const _settingsKeys = {
    'datev': {'beraterNummer', 'mandantNummer', 'bankGegenkonto', 'sachkontenlaenge'},
    'bankCsv': {
      'delimiter', 'hasHeaderRow', 'dateColumn', 'amountColumn', 'purposeColumn', 'counterpartyColumn',
      'dateFormat', 'decimalSeparator',
    },
  };

  static const _settingsDefaults = {
    'datev': {'sachkontenlaenge': 4},
    'bankCsv': {'delimiter': ';', 'hasHeaderRow': true, 'dateFormat': 'dd.MM.yyyy', 'decimalSeparator': ','},
  };

  Future<Map<String, Object?>> _settings(String companyId) async => {
        for (final section in _settingsKeys.keys)
          section: {..._settingsDefaults[section]!, ...await business.getCompanySettings(companyId, section)},
      };

  Future<Response> _getSettings(Request request) async {
    final check = await auth.requirePermission(request, 'accounting.read');
    if (check.error != null) return check.error!;
    return jsonOk(await _settings(check.auth!.session.companyId));
  }

  /// Nur bekannte Schlüssel je Bereich; Werte sind Text/Zahl/Bool.
  Future<Response> _setSettings(Request request) async {
    final check = await auth.requirePermission(request, 'accounting.write');
    if (check.error != null) return check.error!;
    final companyId = check.auth!.session.companyId;
    final body = await readJsonBody(request);
    for (final entry in body.entries) {
      final keys = _settingsKeys[entry.key];
      final value = entry.value;
      if (keys == null || value is! Map) return jsonError('Unbekannter Bereich: ${entry.key}');
      final cleaned = <String, Object?>{};
      for (final field in value.entries) {
        if (!keys.contains(field.key)) return jsonError('Unbekanntes Feld: ${entry.key}.${field.key}');
        final v = field.value;
        if (v != null && v is! String && v is! num && v is! bool) return jsonError('Ungültiger Wert: ${field.key}');
        cleaned[field.key as String] = v is String ? v.trim() : v;
      }
      final length = cleaned['sachkontenlaenge'];
      if (entry.key == 'datev' && length != null && (length is! int || length < 4 || length > 8)) {
        return jsonError('sachkontenlaenge muss zwischen 4 und 8 liegen.');
      }
      await business.setCompanySettings(companyId, entry.key, cleaned);
    }
    await auth.audit(check.auth!, 'accounting.settings', 'company', companyId);
    return jsonOk(await _settings(companyId));
  }

  /// DATEV-EXTF-Buchungsstapel der Belege im Zeitraum (Kern in
  /// `werkkern_core`, identisch zur Offline-App).
  Future<Response> _datev(Request request) async {
    final check = await auth.requirePermission(request, 'accounting.read');
    if (check.error != null) return check.error!;
    final companyId = check.auth!.session.companyId;
    final params = request.url.queryParameters;
    final from = dateOrNull(params['from']);
    final to = dateOrNull(params['to']);
    if (from == null || to == null || to.isBefore(from)) return jsonError('from und to (JJJJ-MM-TT) sind Pflicht.');
    final datev = (await _settings(companyId))['datev']! as Map<String, Object?>;
    final config = DatevExportConfig(
      beraterNummer: datev['beraterNummer'] as String? ?? '',
      mandantNummer: datev['mandantNummer'] as String? ?? '',
      bankGegenkonto: datev['bankGegenkonto'] as String? ?? '',
      sachkontenlaenge: datev['sachkontenlaenge'] as int? ?? 4,
      companyName: (await repository.findCompanyById(companyId))?.name ?? '',
    );
    if (!config.isComplete) {
      return jsonError('DATEV-Einstellungen unvollständig (Berater-, Mandantennummer, Bank-Gegenkonto).', status: 409);
    }
    final categories = {for (final c in await business.listExpenseCategories(companyId)) c.id: c};
    final expenses = await business.listExpenses(companyId, from: from, to: to);
    final export = buildDatevExport<Expense>(
      expenses: [
        for (final e in expenses.reversed)
          DatevExpenseInput(
            source: e,
            date: e.date,
            amountGrossCents: e.amountGrossCents,
            description: e.description,
            account: e.categoryId == null ? null : categories[e.categoryId]?.skr03Account,
            supplierReference: e.supplierReference,
          ),
      ],
      config: config,
      periodStart: from,
      periodEnd: to,
      generatedAt: DateTime.now(),
    );
    await auth.audit(check.auth!, 'accounting.datev', 'company', companyId);
    return jsonOk({
      'csv': export.csvContent,
      'fileName': 'EXTF_Buchungsstapel_${dateJson(from)}_${dateJson(to)}.csv',
      'exportedCount': export.exportedCount,
      'skipped': [for (final e in export.skipped) {'id': e.id, 'description': e.description, 'date': dateJson(e.date)}],
    });
  }

  // ---- Bankabgleich -------------------------------------------------------------

  Future<Response> _listBank(Request request) async {
    final check = await auth.requirePermission(request, 'accounting.read');
    if (check.error != null) return check.error!;
    final transactions = await business.listBankTransactions(
      check.auth!.session.companyId,
      onlyUnmatched: request.url.queryParameters['unmatched'] == 'true',
    );
    return jsonOk({'transactions': [for (final t in transactions) t.toJson()]});
  }

  /// Bereits geparste Umsätze (die App parst die CSV mit der Spalten-
  /// zuordnung aus den Einstellungen); Duplikate werden übersprungen.
  Future<Response> _importBank(Request request) async {
    final check = await auth.requirePermission(request, 'accounting.write');
    if (check.error != null) return check.error!;
    final companyId = check.auth!.session.companyId;
    final raw = (await readJsonBody(request))['transactions'];
    if (raw is! List) return jsonError('transactions (Liste) ist Pflicht.');
    final now = DateTime.now().toUtc();
    final transactions = <BankTransaction>[];
    for (final (index, entry) in raw.indexed) {
      if (entry is! Map) return jsonError('Zeile ${index + 1}: Objekt erwartet.');
      final date = dateOrNull(entry['date']);
      final amount = entry['amountCents'];
      if (date == null || amount is! int) return jsonError('Zeile ${index + 1}: date und amountCents sind Pflicht.');
      final purpose = trimmedOrNull(entry['purpose']);
      final counterparty = trimmedOrNull(entry['counterparty']);
      transactions.add(BankTransaction(
        id: _uuid.v4(),
        companyId: companyId,
        date: date,
        amountCents: amount,
        purpose: purpose,
        counterparty: counterparty,
        importHash: bankTransactionHash(date: date, amountCents: amount, purpose: purpose, counterparty: counterparty),
        importedAt: now,
      ));
    }
    final result = await business.importBankTransactions(companyId, transactions);
    await auth.audit(check.auth!, 'bank.import', 'company', companyId);
    return jsonOk({'imported': result.imported, 'skippedDuplicates': result.skippedDuplicates});
  }

  /// Ordnet einen Umsatz einer finalisierten Rechnung zu (oder löst die
  /// Zuordnung mit `documentId: null`). `markPaid: true` setzt zusätzlich
  /// den Zahlungseingang — braucht dann auch `invoices.payment`.
  Future<Response> _matchBank(Request request, String id) async {
    final check = await auth.requirePermission(request, 'accounting.write');
    if (check.error != null) return check.error!;
    final companyId = check.auth!.session.companyId;
    final transaction = await business.findBankTransaction(companyId, id);
    if (transaction == null) return jsonError('Bankumsatz nicht gefunden.', status: 404);
    final body = await readJsonBody(request);
    final documentId = trimmedOrNull(body['documentId']);
    final markPaid = body['markPaid'] == true;
    Document? document;
    if (documentId != null) {
      document = await business.findDocument(companyId, documentId);
      if (document == null) return jsonError('Dokument nicht gefunden.', status: 404);
      if (document.isDraft || !hasPaymentStatusKind(document.kind)) {
        return jsonError('Nur finalisierte Rechnungen können zugeordnet werden.', status: 409);
      }
    }
    if (markPaid && document != null && !await auth.isGranted(check.auth!, 'invoices.payment')) {
      return jsonError('Keine Berechtigung: invoices.payment', status: 403);
    }
    await business.setBankTransactionMatch(companyId, id, documentId);
    if (markPaid && document != null && document.paymentStatus != 'paid') {
      await business.setPaymentInfo(companyId: companyId, id: document.id, paymentStatus: 'paid', now: DateTime.now().toUtc());
    }
    await auth.audit(check.auth!, documentId == null ? 'bank.unmatch' : 'bank.match', 'bankTransaction', id);
    return jsonOk((await business.findBankTransaction(companyId, id))!.toJson());
  }

  Future<Response> _deleteBank(Request request, String id) async {
    final check = await auth.requirePermission(request, 'accounting.write');
    if (check.error != null) return check.error!;
    if (!await business.deleteBankTransaction(check.auth!.session.companyId, id)) {
      return jsonError('Bankumsatz nicht gefunden.', status: 404);
    }
    await auth.audit(check.auth!, 'bank.delete', 'bankTransaction', id);
    return Response(204);
  }
}
