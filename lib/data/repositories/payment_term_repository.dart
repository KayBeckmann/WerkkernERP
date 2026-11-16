import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';
import 'package:werkkern_core/werkkern_core.dart' show defaultPaymentTermPresets;

import '../database/database.dart';

/// A2-Nachtrag (Kay, 15.11.2026): Zahlungsbedingungen je Firma —
/// firmengebunden wie alle Stammdaten. Beim ersten Lesen einer Firma ohne
/// Einträge entstehen die Vorgaben „Sofort netto“, „7 Tage“, „14 Tage“
/// (Standard) und „30 Tage“.
class PaymentTermRepository {
  PaymentTermRepository(this._db);

  final AppDatabase _db;
  static const _uuid = Uuid();

  Future<List<PaymentTerm>> listForCompany(String companyId) async {
    final existing = await _list(companyId);
    if (existing.isNotEmpty) return existing;
    await _db.transaction(() async {
      if ((await _list(companyId)).isNotEmpty) return;
      for (final (index, preset) in defaultPaymentTermPresets.indexed) {
        await _db.into(_db.paymentTerms).insert(PaymentTermsCompanion.insert(
              id: _uuid.v4(),
              companyId: companyId,
              label: preset.label,
              netDays: preset.netDays,
              isDefault: Value(preset.isDefault),
              sortOrder: Value(index),
            ));
      }
    });
    return _list(companyId);
  }

  Future<List<PaymentTerm>> _list(String companyId) => (_db.select(_db.paymentTerms)
        ..where((t) => t.companyId.equals(companyId))
        ..orderBy([(t) => OrderingTerm.asc(t.sortOrder), (t) => OrderingTerm.asc(t.netDays)]))
      .get();

  Future<PaymentTerm?> findById({required String companyId, required String id}) =>
      (_db.select(_db.paymentTerms)..where((t) => t.id.equals(id) & t.companyId.equals(companyId))).getSingleOrNull();

  Future<PaymentTerm?> defaultFor(String companyId) async =>
      (await listForCompany(companyId)).where((t) => t.isDefault).firstOrNull;

  Future<PaymentTerm> create({required String companyId, required String label, required int netDays, bool isDefault = false}) async {
    final existing = await listForCompany(companyId);
    final id = _uuid.v4();
    await _db.transaction(() async {
      if (isDefault) await _clearDefault(companyId);
      await _db.into(_db.paymentTerms).insert(PaymentTermsCompanion.insert(
            id: id,
            companyId: companyId,
            label: label,
            netDays: netDays,
            isDefault: Value(isDefault),
            sortOrder: Value(existing.length),
          ));
    });
    return (await findById(companyId: companyId, id: id))!;
  }

  Future<void> update({required String companyId, required String id, required String label, required int netDays}) =>
      (_db.update(_db.paymentTerms)..where((t) => t.id.equals(id) & t.companyId.equals(companyId)))
          .write(PaymentTermsCompanion(label: Value(label), netDays: Value(netDays)));

  /// Genau eine Bedingung ist Firmenstandard.
  Future<void> setDefault({required String companyId, required String id}) => _db.transaction(() async {
        await _clearDefault(companyId);
        await (_db.update(_db.paymentTerms)..where((t) => t.id.equals(id) & t.companyId.equals(companyId)))
            .write(const PaymentTermsCompanion(isDefault: Value(true)));
      });

  /// Die letzte Bedingung bleibt; ein gelöschter Standard geht auf die
  /// erste verbleibende über. Kunden verlieren nur die Zuordnung, Belege
  /// behalten ihren Schnappschuss.
  Future<void> delete({required String companyId, required String id}) => _db.transaction(() async {
        final all = await _list(companyId);
        if (all.length <= 1) throw StateError('Mindestens eine Zahlungsbedingung muss bleiben.');
        final removed = all.where((t) => t.id == id).firstOrNull;
        if (removed == null) return;
        await (_db.delete(_db.paymentTerms)..where((t) => t.id.equals(id) & t.companyId.equals(companyId))).go();
        await (_db.update(_db.customers)..where((c) => c.companyId.equals(companyId) & c.paymentTermId.equals(id)))
            .write(const CustomersCompanion(paymentTermId: Value(null)));
        if (removed.isDefault) {
          final next = all.firstWhere((t) => t.id != id);
          await (_db.update(_db.paymentTerms)..where((t) => t.id.equals(next.id)))
              .write(const PaymentTermsCompanion(isDefault: Value(true)));
        }
      });

  Future<void> _clearDefault(String companyId) => (_db.update(_db.paymentTerms)
        ..where((t) => t.companyId.equals(companyId)))
      .write(const PaymentTermsCompanion(isDefault: Value(false)));
}
