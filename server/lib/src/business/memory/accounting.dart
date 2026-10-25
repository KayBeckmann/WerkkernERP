part of '../repository_memory.dart';

mixin _InMemoryAccounting implements AccountingStore {
  final List<ExpenseCategory> _expenseCategories = [];
  final List<Expense> _expenses = [];
  final List<BankTransaction> _bankTransactions = [];
  final Map<String, Map<String, Object?>> _companySettings = {};

  @override
  Future<List<ExpenseCategory>> listExpenseCategories(String companyId) async =>
      _expenseCategories.where((c) => c.companyId == companyId).toList()
        ..sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));

  @override
  Future<ExpenseCategory?> findExpenseCategory(String companyId, String id) async =>
      _expenseCategories.where((c) => c.companyId == companyId && c.id == id).firstOrNull;

  @override
  Future<void> createExpenseCategory(ExpenseCategory category) async => _expenseCategories.add(category);

  @override
  Future<bool> updateExpenseCategory(ExpenseCategory category) async {
    final index = _expenseCategories.indexWhere((c) => c.companyId == category.companyId && c.id == category.id);
    if (index == -1) return false;
    _expenseCategories[index] = category;
    return true;
  }

  @override
  Future<bool> deleteExpenseCategory(String companyId, String id) async {
    final before = _expenseCategories.length;
    _expenseCategories.removeWhere((c) => c.companyId == companyId && c.id == id);
    if (_expenseCategories.length == before) return false;
    for (var i = 0; i < _expenses.length; i++) {
      final e = _expenses[i];
      if (e.companyId == companyId && e.categoryId == id) {
        _expenses[i] = Expense(
          id: e.id,
          companyId: e.companyId,
          date: e.date,
          description: e.description,
          amountGrossCents: e.amountGrossCents,
          vatRatePercent: e.vatRatePercent,
          supplierReference: e.supplierReference,
          projectId: e.projectId,
          purchaseOrderId: e.purchaseOrderId,
          createdByUserId: e.createdByUserId,
          createdAt: e.createdAt,
          updatedAt: e.updatedAt,
        );
      }
    }
    return true;
  }

  @override
  Future<List<Expense>> listExpenses(String companyId, {DateTime? from, DateTime? to, String? projectId}) async =>
      _expenses
          .where((e) =>
              e.companyId == companyId &&
              (from == null || !e.date.isBefore(from)) &&
              (to == null || !e.date.isAfter(to)) &&
              (projectId == null || e.projectId == projectId))
          .toList()
        ..sort((a, b) => b.date.compareTo(a.date));

  @override
  Future<Expense?> findExpense(String companyId, String id) async =>
      _expenses.where((e) => e.companyId == companyId && e.id == id).firstOrNull;

  @override
  Future<void> createExpense(Expense expense) async => _expenses.add(expense);

  @override
  Future<bool> updateExpense(Expense expense) async {
    final index = _expenses.indexWhere((e) => e.companyId == expense.companyId && e.id == expense.id);
    if (index == -1) return false;
    _expenses[index] = expense;
    return true;
  }

  @override
  Future<bool> deleteExpense(String companyId, String id) async {
    final before = _expenses.length;
    _expenses.removeWhere((e) => e.companyId == companyId && e.id == id);
    return _expenses.length != before;
  }

  @override
  Future<List<BankTransaction>> listBankTransactions(String companyId, {bool onlyUnmatched = false}) async =>
      _bankTransactions
          .where((t) => t.companyId == companyId && (!onlyUnmatched || t.matchedDocumentId == null))
          .toList()
        ..sort((a, b) => b.date.compareTo(a.date));

  @override
  Future<BankTransaction?> findBankTransaction(String companyId, String id) async =>
      _bankTransactions.where((t) => t.companyId == companyId && t.id == id).firstOrNull;

  @override
  Future<({int imported, int skippedDuplicates})> importBankTransactions(
    String companyId,
    List<BankTransaction> transactions,
  ) async {
    var imported = 0;
    var skipped = 0;
    for (final t in transactions) {
      if (_bankTransactions.any((e) => e.companyId == companyId && e.importHash == t.importHash)) {
        skipped++;
      } else {
        _bankTransactions.add(t);
        imported++;
      }
    }
    return (imported: imported, skippedDuplicates: skipped);
  }

  @override
  Future<bool> setBankTransactionMatch(String companyId, String id, String? documentId) async {
    final index = _bankTransactions.indexWhere((t) => t.companyId == companyId && t.id == id);
    if (index == -1) return false;
    final t = _bankTransactions[index];
    _bankTransactions[index] = BankTransaction(
      id: t.id,
      companyId: t.companyId,
      date: t.date,
      amountCents: t.amountCents,
      purpose: t.purpose,
      counterparty: t.counterparty,
      matchedDocumentId: documentId,
      importHash: t.importHash,
      importedAt: t.importedAt,
    );
    return true;
  }

  @override
  Future<bool> deleteBankTransaction(String companyId, String id) async {
    final before = _bankTransactions.length;
    _bankTransactions.removeWhere((t) => t.companyId == companyId && t.id == id);
    return _bankTransactions.length != before;
  }

  @override
  Future<Map<String, Object?>> getCompanySettings(String companyId, String section) async =>
      Map.of(_companySettings['$companyId|$section'] ?? const {});

  @override
  Future<void> setCompanySettings(String companyId, String section, Map<String, Object?> settings) async =>
      _companySettings['$companyId|$section'] = Map.of(settings);
}
