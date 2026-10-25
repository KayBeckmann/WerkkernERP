import 'api_client.dart';
import 'fleet.dart' show onlineDate;

/// Buchhaltung online (C14).
class OnlineExpenseCategory {
  const OnlineExpenseCategory({required this.id, required this.label, this.skr03Account});
  factory OnlineExpenseCategory.fromJson(Map<String, Object?> j) => OnlineExpenseCategory(
        id: j['id'] as String,
        label: j['label'] as String,
        skr03Account: j['skr03Account'] as String?,
      );
  final String id;
  final String label;
  final String? skr03Account;
}

class OnlineExpense {
  const OnlineExpense({
    required this.id,
    required this.date,
    required this.description,
    required this.amountGrossCents,
    required this.vatRatePercent,
    this.categoryId,
    this.supplierReference,
    this.projectId,
    this.purchaseOrderId,
  });
  factory OnlineExpense.fromJson(Map<String, Object?> j) => OnlineExpense(
        id: j['id'] as String,
        date: DateTime.parse(j['date'] as String),
        description: j['description'] as String,
        amountGrossCents: j['amountGrossCents'] as int,
        vatRatePercent: (j['vatRatePercent'] as num).toDouble(),
        categoryId: j['categoryId'] as String?,
        supplierReference: j['supplierReference'] as String?,
        projectId: j['projectId'] as String?,
        purchaseOrderId: j['purchaseOrderId'] as String?,
      );
  final String id;
  final DateTime date;
  final String description;
  final int amountGrossCents;
  final double vatRatePercent;
  final String? categoryId;
  final String? supplierReference;
  final String? projectId;
  final String? purchaseOrderId;

  Map<String, Object?> toWriteJson() => {
        'date': onlineDate(date),
        'description': description,
        'amountGrossCents': amountGrossCents,
        'vatRatePercent': vatRatePercent,
        'categoryId': categoryId,
        'supplierReference': supplierReference,
        'projectId': projectId,
      };
}

class OnlineBankTransaction {
  const OnlineBankTransaction({
    required this.id,
    required this.date,
    required this.amountCents,
    this.purpose,
    this.counterparty,
    this.matchedDocumentId,
  });
  factory OnlineBankTransaction.fromJson(Map<String, Object?> j) => OnlineBankTransaction(
        id: j['id'] as String,
        date: DateTime.parse(j['date'] as String),
        amountCents: j['amountCents'] as int,
        purpose: j['purpose'] as String?,
        counterparty: j['counterparty'] as String?,
        matchedDocumentId: j['matchedDocumentId'] as String?,
      );
  final String id;
  final DateTime date;
  final int amountCents;
  final String? purpose;
  final String? counterparty;
  final String? matchedDocumentId;
}

typedef OnlineOpenItem = ({String documentId, String? number, DateTime issueDate, DateTime? dueDate, int grossCents});
typedef OnlineOpenItemGroup = ({String customerName, int totalCents, List<OnlineOpenItem> items});
typedef OnlineEuer = ({
  int incomeCents,
  int expensesCents,
  int surplusCents,
  List<({String label, String? skr03Account, int totalCents})> expensesByCategory,
});

Map<String, Object?> _map(Object? value) => value as Map<String, Object?>;

extension AccountingApi on WerkkernApiClient {
  Future<List<OnlineExpenseCategory>> expenseCategories() async {
    final j = _map(await request('GET', '/expense-categories'));
    return [for (final c in j['categories'] as List) OnlineExpenseCategory.fromJson(c as Map<String, Object?>)];
  }

  Future<void> saveExpenseCategory({String? id, required String label, String? skr03Account}) {
    final body = {'label': label, 'skr03Account': skr03Account};
    return id == null ? request('POST', '/expense-categories', body: body) : request('PUT', '/expense-categories/$id', body: body);
  }

  Future<void> deleteExpenseCategory(String id) => request('DELETE', '/expense-categories/$id');

  Future<({List<OnlineExpense> expenses, int totalGrossCents})> expenses({DateTime? from, DateTime? to, String? projectId}) async {
    final j = _map(await request('GET', '/expenses', query: {
      if (from != null) 'from': onlineDate(from),
      if (to != null) 'to': onlineDate(to),
      'projectId': ?projectId,
    }));
    return (
      expenses: [for (final e in j['expenses'] as List) OnlineExpense.fromJson(e as Map<String, Object?>)],
      totalGrossCents: j['totalGrossCents'] as int,
    );
  }

  Future<void> saveExpense(OnlineExpense expense) => expense.id.isEmpty
      ? request('POST', '/expenses', body: expense.toWriteJson())
      : request('PUT', '/expenses/${expense.id}', body: expense.toWriteJson());

  Future<void> deleteExpense(String id) => request('DELETE', '/expenses/$id');

  Future<({int totalCents, List<OnlineOpenItemGroup> customers})> openItems() async {
    final j = _map(await request('GET', '/accounting/open-items'));
    return (
      totalCents: j['totalCents'] as int,
      customers: [
        for (final g in (j['customers'] as List).cast<Map<String, Object?>>())
          (
            customerName: g['customerName'] as String,
            totalCents: g['totalCents'] as int,
            items: [
              for (final i in (g['items'] as List).cast<Map<String, Object?>>())
                (
                  documentId: i['id'] as String,
                  number: i['number'] as String?,
                  issueDate: DateTime.parse(i['issueDate'] as String),
                  dueDate: i['dueDate'] == null ? null : DateTime.parse(i['dueDate'] as String),
                  grossCents: i['grossCents'] as int,
                ),
            ],
          ),
      ],
    );
  }

  Future<OnlineEuer> euer({required DateTime from, required DateTime to}) async {
    final j = _map(await request('GET', '/accounting/euer', query: {'from': onlineDate(from), 'to': onlineDate(to)}));
    return (
      incomeCents: j['incomeCents'] as int,
      expensesCents: j['expensesCents'] as int,
      surplusCents: j['surplusCents'] as int,
      expensesByCategory: [
        for (final l in (j['expensesByCategory'] as List).cast<Map<String, Object?>>())
          (label: l['label'] as String, skr03Account: l['skr03Account'] as String?, totalCents: l['totalCents'] as int),
      ],
    );
  }

  /// `{datev: {...}, bankCsv: {...}}` inkl. Vorgaben.
  Future<Map<String, Map<String, Object?>>> accountingSettings() async {
    final j = _map(await request('GET', '/accounting/settings'));
    return {for (final e in j.entries) e.key: (e.value as Map).cast<String, Object?>()};
  }

  Future<void> saveAccountingSettings(Map<String, Map<String, Object?>> settings) =>
      request('PUT', '/accounting/settings', body: settings);

  Future<({String csv, String fileName, int exportedCount, List<String> skipped})> datevExport({
    required DateTime from,
    required DateTime to,
  }) async {
    final j = _map(await request('GET', '/accounting/datev', query: {'from': onlineDate(from), 'to': onlineDate(to)}));
    return (
      csv: j['csv'] as String,
      fileName: j['fileName'] as String,
      exportedCount: j['exportedCount'] as int,
      skipped: [for (final s in (j['skipped'] as List).cast<Map<String, Object?>>()) s['description'] as String],
    );
  }

  Future<List<OnlineBankTransaction>> bankTransactions({bool onlyUnmatched = false}) async {
    final j = _map(await request('GET', '/bank-transactions', query: {if (onlyUnmatched) 'unmatched': 'true'}));
    return [for (final t in j['transactions'] as List) OnlineBankTransaction.fromJson(t as Map<String, Object?>)];
  }

  Future<({int imported, int skippedDuplicates})> importBankTransactions(
    List<({DateTime date, int amountCents, String? purpose, String? counterparty})> transactions,
  ) async {
    final j = _map(await request('POST', '/bank-transactions/import', body: {
      'transactions': [
        for (final t in transactions)
          {'date': onlineDate(t.date), 'amountCents': t.amountCents, 'purpose': t.purpose, 'counterparty': t.counterparty},
      ],
    }));
    return (imported: j['imported'] as int, skippedDuplicates: j['skippedDuplicates'] as int);
  }

  Future<void> matchBankTransaction(String id, {required String? documentId, bool markPaid = false}) =>
      request('PUT', '/bank-transactions/$id/match', body: {'documentId': documentId, 'markPaid': markPaid});

  Future<void> deleteBankTransaction(String id) => request('DELETE', '/bank-transactions/$id');
}
