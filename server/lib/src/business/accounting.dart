/// Buchhaltung online (C14): Beleg-Kategorien mit SKR03-Konto, Belege,
/// Bankumsätze (CSV-Import, Zuordnung) und Firmen-Einstellungen für
/// DATEV-Export und CSV-Spaltenzuordnung. Wie offline **keine
/// Steuerberatung** — interne Übersicht und Arbeitsgrundlage.
library;

import 'request_util.dart';

/// Typische Kategorien eines Elektro-Kleingewerbes — nur Labels, die
/// SKR03-Nummer trägt Kay selbst ein (wie offline).
const defaultExpenseCategoryLabels = [
  'Material/Wareneinkauf',
  'Fahrzeugkosten',
  'Versicherungen',
  'Miete/Nebenkosten',
  'Bürokosten/Porto',
  'Werbung/Marketing',
  'Sonstiges',
];

class ExpenseCategory {
  const ExpenseCategory({
    required this.id,
    required this.companyId,
    required this.label,
    this.skr03Account,
    required this.createdAt,
  });
  final String id;
  final String companyId;
  final String label;
  final String? skr03Account;
  final DateTime createdAt;

  Map<String, Object?> toJson() => {
        'id': id,
        'label': label,
        'skr03Account': skr03Account,
        'createdAt': createdAt.toIso8601String(),
      };
}

class Expense {
  const Expense({
    required this.id,
    required this.companyId,
    required this.date,
    required this.description,
    required this.amountGrossCents,
    required this.vatRatePercent,
    this.categoryId,
    this.supplierReference,
    this.projectId,
    this.purchaseOrderId,
    required this.createdByUserId,
    required this.createdAt,
    required this.updatedAt,
  });
  final String id;
  final String companyId;
  final DateTime date;
  final String description;

  /// Brutto + Steuersatz (F2-Muster wie offline).
  final int amountGrossCents;
  final double vatRatePercent;
  final String? categoryId;
  final String? supplierReference;

  /// Fließt in die Projekt-Ergebnisrechnung ein (anders als Fuhrpark).
  final String? projectId;

  /// Automatisch aus einem Wareneingang erzeugt (Bestellwesen).
  final String? purchaseOrderId;
  final String createdByUserId;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, Object?> toJson() => {
        'id': id,
        'date': dateJson(date),
        'description': description,
        'amountGrossCents': amountGrossCents,
        'vatRatePercent': vatRatePercent,
        'categoryId': categoryId,
        'supplierReference': supplierReference,
        'projectId': projectId,
        'purchaseOrderId': purchaseOrderId,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };
}

class BankTransaction {
  const BankTransaction({
    required this.id,
    required this.companyId,
    required this.date,
    required this.amountCents,
    this.purpose,
    this.counterparty,
    this.matchedDocumentId,
    required this.importHash,
    required this.importedAt,
  });
  final String id;
  final String companyId;
  final DateTime date;

  /// Vorzeichenbehaftet (Eingang positiv).
  final int amountCents;
  final String? purpose;
  final String? counterparty;
  final String? matchedDocumentId;
  final String importHash;
  final DateTime importedAt;

  Map<String, Object?> toJson() => {
        'id': id,
        'date': dateJson(date),
        'amountCents': amountCents,
        'purpose': purpose,
        'counterparty': counterparty,
        'matchedDocumentId': matchedDocumentId,
        'importedAt': importedAt.toIso8601String(),
      };
}

/// Wie offline `computeBankTransactionHash` — Grundlage der Duplikat-
/// Erkennung beim wiederholten Import derselben Exportdatei.
String bankTransactionHash({required DateTime date, required int amountCents, String? purpose, String? counterparty}) =>
    '${dateJson(date)}|$amountCents|${purpose ?? ''}|${counterparty ?? ''}';

abstract interface class AccountingStore {
  Future<List<ExpenseCategory>> listExpenseCategories(String companyId);
  Future<ExpenseCategory?> findExpenseCategory(String companyId, String id);
  Future<void> createExpenseCategory(ExpenseCategory category);
  Future<bool> updateExpenseCategory(ExpenseCategory category);

  /// Belege behalten ihren Betrag, verlieren nur die Kategorie.
  Future<bool> deleteExpenseCategory(String companyId, String id);

  Future<List<Expense>> listExpenses(String companyId, {DateTime? from, DateTime? to, String? projectId});
  Future<Expense?> findExpense(String companyId, String id);
  Future<void> createExpense(Expense expense);
  Future<bool> updateExpense(Expense expense);
  Future<bool> deleteExpense(String companyId, String id);

  Future<List<BankTransaction>> listBankTransactions(String companyId, {bool onlyUnmatched = false});
  Future<BankTransaction?> findBankTransaction(String companyId, String id);

  /// Legt nur Umsätze mit neuem `importHash` an (je Firma eindeutig).
  Future<({int imported, int skippedDuplicates})> importBankTransactions(String companyId, List<BankTransaction> transactions);
  Future<bool> setBankTransactionMatch(String companyId, String id, String? documentId);
  Future<bool> deleteBankTransaction(String companyId, String id);

  /// Firmen-Einstellungen je Bereich (z. B. `datev`, `bankCsv`) als JSON.
  Future<Map<String, Object?>> getCompanySettings(String companyId, String section);
  Future<void> setCompanySettings(String companyId, String section, Map<String, Object?> settings);
}
