part of '../repository_postgres.dart';

mixin _PostgresAccounting implements AccountingStore {
  Future<Result> _q(String sql, [Map<String, Object?> parameters = const {}]);

  ExpenseCategory _toCategory(ResultRow r) => ExpenseCategory(
        id: r[0] as String,
        companyId: r[1] as String,
        label: r[2] as String,
        skr03Account: r[3] as String?,
        createdAt: r[4] as DateTime,
      );

  @override
  Future<List<ExpenseCategory>> listExpenseCategories(String companyId) async {
    final result = await _q(
      'SELECT id, company_id, label, skr03_account, created_at FROM expense_categories WHERE company_id = @companyId '
      'ORDER BY lower(label)',
      {'companyId': companyId},
    );
    return [for (final r in result) _toCategory(r)];
  }

  @override
  Future<ExpenseCategory?> findExpenseCategory(String companyId, String id) async {
    final result = await _q(
      'SELECT id, company_id, label, skr03_account, created_at FROM expense_categories '
      'WHERE company_id = @companyId AND id = @id',
      {'companyId': companyId, 'id': id},
    );
    return result.isEmpty ? null : _toCategory(result.first);
  }

  @override
  Future<void> createExpenseCategory(ExpenseCategory c) async {
    await _q(
      'INSERT INTO expense_categories (id, company_id, label, skr03_account, created_at) '
      'VALUES (@id, @companyId, @label, @account, @createdAt)',
      {'id': c.id, 'companyId': c.companyId, 'label': c.label, 'account': c.skr03Account, 'createdAt': c.createdAt},
    );
  }

  @override
  Future<bool> updateExpenseCategory(ExpenseCategory c) async {
    final result = await _q(
      'UPDATE expense_categories SET label = @label, skr03_account = @account WHERE company_id = @companyId AND id = @id',
      {'id': c.id, 'companyId': c.companyId, 'label': c.label, 'account': c.skr03Account},
    );
    return result.affectedRows > 0;
  }

  @override
  Future<bool> deleteExpenseCategory(String companyId, String id) async {
    final result = await _q('DELETE FROM expense_categories WHERE company_id = @companyId AND id = @id', {
      'companyId': companyId,
      'id': id,
    });
    return result.affectedRows > 0;
  }

  static const _expenseColumns = 'id, company_id, expense_date, description, amount_gross_cents, vat_rate_percent, '
      'category_id, supplier_reference, project_id, purchase_order_id, created_by_user_id, created_at, updated_at';

  Expense _toExpense(ResultRow r) => Expense(
        id: r[0] as String,
        companyId: r[1] as String,
        date: r[2] as DateTime,
        description: r[3] as String,
        amountGrossCents: r[4] as int,
        vatRatePercent: (r[5] as num).toDouble(),
        categoryId: r[6] as String?,
        supplierReference: r[7] as String?,
        projectId: r[8] as String?,
        purchaseOrderId: r[9] as String?,
        createdByUserId: r[10] as String,
        createdAt: r[11] as DateTime,
        updatedAt: r[12] as DateTime,
      );

  Map<String, Object?> _expenseParams(Expense e) => {
        'id': e.id,
        'companyId': e.companyId,
        'date': TypedValue(Type.date, e.date),
        'description': e.description,
        'amount': e.amountGrossCents,
        'vat': e.vatRatePercent,
        'categoryId': e.categoryId,
        'reference': e.supplierReference,
        'projectId': e.projectId,
        'purchaseOrderId': e.purchaseOrderId,
        'createdBy': e.createdByUserId,
        'createdAt': e.createdAt,
        'updatedAt': e.updatedAt,
      };

  @override
  Future<List<Expense>> listExpenses(String companyId, {DateTime? from, DateTime? to, String? projectId}) async {
    final result = await _q(
      'SELECT $_expenseColumns FROM expenses WHERE company_id = @companyId '
      'AND (@from::date IS NULL OR expense_date >= @from) AND (@to::date IS NULL OR expense_date <= @to) '
      'AND (@projectId::text IS NULL OR project_id = @projectId) ORDER BY expense_date DESC, created_at DESC',
      {
        'companyId': companyId,
        'from': TypedValue(Type.date, from),
        'to': TypedValue(Type.date, to),
        'projectId': projectId,
      },
    );
    return [for (final r in result) _toExpense(r)];
  }

  @override
  Future<Expense?> findExpense(String companyId, String id) async {
    final result = await _q('SELECT $_expenseColumns FROM expenses WHERE company_id = @companyId AND id = @id', {
      'companyId': companyId,
      'id': id,
    });
    return result.isEmpty ? null : _toExpense(result.first);
  }

  @override
  Future<void> createExpense(Expense e) async {
    await _q(
      'INSERT INTO expenses ($_expenseColumns) VALUES (@id, @companyId, @date, @description, @amount, @vat, '
      '@categoryId, @reference, @projectId, @purchaseOrderId, @createdBy, @createdAt, @updatedAt)',
      _expenseParams(e),
    );
  }

  @override
  Future<bool> updateExpense(Expense e) async {
    final result = await _q(
      'UPDATE expenses SET expense_date = @date, description = @description, amount_gross_cents = @amount, '
      'vat_rate_percent = @vat, category_id = @categoryId, supplier_reference = @reference, project_id = @projectId, '
      'updated_at = @updatedAt WHERE company_id = @companyId AND id = @id',
      _expenseParams(e)
        ..remove('createdBy')
        ..remove('createdAt')
        ..remove('purchaseOrderId'),
    );
    return result.affectedRows > 0;
  }

  @override
  Future<bool> deleteExpense(String companyId, String id) async {
    final result = await _q('DELETE FROM expenses WHERE company_id = @companyId AND id = @id', {
      'companyId': companyId,
      'id': id,
    });
    return result.affectedRows > 0;
  }

  static const _bankColumns =
      'id, company_id, transaction_date, amount_cents, purpose, counterparty, matched_document_id, import_hash, imported_at';

  BankTransaction _toBank(ResultRow r) => BankTransaction(
        id: r[0] as String,
        companyId: r[1] as String,
        date: r[2] as DateTime,
        amountCents: r[3] as int,
        purpose: r[4] as String?,
        counterparty: r[5] as String?,
        matchedDocumentId: r[6] as String?,
        importHash: r[7] as String,
        importedAt: r[8] as DateTime,
      );

  @override
  Future<List<BankTransaction>> listBankTransactions(String companyId, {bool onlyUnmatched = false}) async {
    final result = await _q(
      'SELECT $_bankColumns FROM bank_transactions WHERE company_id = @companyId '
      'AND (NOT @unmatched OR matched_document_id IS NULL) ORDER BY transaction_date DESC, imported_at DESC',
      {'companyId': companyId, 'unmatched': onlyUnmatched},
    );
    return [for (final r in result) _toBank(r)];
  }

  @override
  Future<BankTransaction?> findBankTransaction(String companyId, String id) async {
    final result = await _q('SELECT $_bankColumns FROM bank_transactions WHERE company_id = @companyId AND id = @id', {
      'companyId': companyId,
      'id': id,
    });
    return result.isEmpty ? null : _toBank(result.first);
  }

  @override
  Future<({int imported, int skippedDuplicates})> importBankTransactions(
    String companyId,
    List<BankTransaction> transactions,
  ) async {
    var imported = 0;
    for (final t in transactions) {
      final result = await _q(
        'INSERT INTO bank_transactions ($_bankColumns) VALUES (@id, @companyId, @date, @amount, @purpose, '
        '@counterparty, NULL, @hash, @importedAt) ON CONFLICT (company_id, import_hash) DO NOTHING',
        {
          'id': t.id,
          'companyId': companyId,
          'date': TypedValue(Type.date, t.date),
          'amount': t.amountCents,
          'purpose': t.purpose,
          'counterparty': t.counterparty,
          'hash': t.importHash,
          'importedAt': t.importedAt,
        },
      );
      imported += result.affectedRows;
    }
    return (imported: imported, skippedDuplicates: transactions.length - imported);
  }

  @override
  Future<bool> setBankTransactionMatch(String companyId, String id, String? documentId) async {
    final result = await _q(
      'UPDATE bank_transactions SET matched_document_id = @documentId WHERE company_id = @companyId AND id = @id',
      {'documentId': documentId, 'companyId': companyId, 'id': id},
    );
    return result.affectedRows > 0;
  }

  @override
  Future<bool> deleteBankTransaction(String companyId, String id) async {
    final result = await _q('DELETE FROM bank_transactions WHERE company_id = @companyId AND id = @id', {
      'companyId': companyId,
      'id': id,
    });
    return result.affectedRows > 0;
  }

  @override
  Future<Map<String, Object?>> getCompanySettings(String companyId, String section) async {
    final result = await _q('SELECT settings FROM company_settings WHERE company_id = @companyId AND section = @section', {
      'companyId': companyId,
      'section': section,
    });
    if (result.isEmpty) return {};
    return (jsonDecode(result.first[0] as String) as Map).cast<String, Object?>();
  }

  @override
  Future<void> setCompanySettings(String companyId, String section, Map<String, Object?> settings) async {
    await _q(
      'INSERT INTO company_settings (company_id, section, settings) VALUES (@companyId, @section, @settings) '
      'ON CONFLICT (company_id, section) DO UPDATE SET settings = EXCLUDED.settings',
      {'companyId': companyId, 'section': section, 'settings': jsonEncode(settings)},
    );
  }
}
