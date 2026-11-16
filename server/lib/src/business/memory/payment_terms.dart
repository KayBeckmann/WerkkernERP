part of '../repository_memory.dart';

mixin _InMemoryPaymentTerms implements PaymentTermStore {
  final List<PaymentTerm> _paymentTerms = [];
  List<Customer> get _customers;

  @override
  Future<List<PaymentTerm>> listPaymentTerms(String companyId) async =>
      _paymentTerms.where((t) => t.companyId == companyId).toList()
        ..sort((a, b) => a.sortOrder != b.sortOrder ? a.sortOrder.compareTo(b.sortOrder) : a.netDays.compareTo(b.netDays));

  @override
  Future<void> savePaymentTerm(PaymentTerm term) async {
    final index = _paymentTerms.indexWhere((t) => t.companyId == term.companyId && t.id == term.id);
    index == -1 ? _paymentTerms.add(term) : _paymentTerms[index] = term;
  }

  @override
  Future<void> setDefaultPaymentTerm(String companyId, String id) async {
    for (var i = 0; i < _paymentTerms.length; i++) {
      final t = _paymentTerms[i];
      if (t.companyId == companyId) _paymentTerms[i] = t.copyWith(isDefault: t.id == id);
    }
  }

  @override
  Future<bool> deletePaymentTerm(String companyId, String id) async {
    final before = _paymentTerms.length;
    _paymentTerms.removeWhere((t) => t.companyId == companyId && t.id == id);
    if (_paymentTerms.length == before) return false;
    for (var i = 0; i < _customers.length; i++) {
      final c = _customers[i];
      if (c.companyId == companyId && c.paymentTermId == id) _customers[i] = c.copyWithPaymentTerm(null);
    }
    return true;
  }
}
