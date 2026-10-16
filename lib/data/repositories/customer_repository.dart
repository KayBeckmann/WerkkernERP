import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../database/database.dart';

/// Kundenstammdaten je Firma. **Jede** Lesemethode filtert zwingend auf
/// [companyId] — es gibt keinen Pfad, der einen Kunden ohne passende
/// companyId zurückgibt, selbst wenn die ID einer anderen Firma bekannt
/// ist (Roadmap A0: "Tests versuchen ausdrücklich, Datensatz-IDs einer
/// anderen Firma aufzurufen").
class CustomerRepository {
  CustomerRepository(this._db);

  final AppDatabase _db;
  static const _uuid = Uuid();

  Future<List<Customer>> listForCompany(String companyId) =>
      (_db.select(_db.customers)..where((c) => c.companyId.equals(companyId))).get();

  /// `null`, wenn kein Kunde mit [id] existiert **oder** er einer anderen
  /// Firma gehört — beide Fälle sind von außen ununterscheidbar (deny-by-
  /// default, kein Informationsleck über Existenz in fremder Firma).
  Future<Customer?> findById({required String companyId, required String id}) =>
      (_db.select(_db.customers)
            ..where((c) => c.id.equals(id) & c.companyId.equals(companyId)))
          .getSingleOrNull();

  Future<Customer> create({
    required String companyId,
    required String name,
    String? address,
    String? email,
    String? phone,
    String? vatId,
    String? contactPerson,
    String? notes,
  }) async {
    final id = _uuid.v4();
    await _db.into(_db.customers).insert(
          CustomersCompanion.insert(
            id: id,
            companyId: companyId,
            name: name,
            address: Value(address),
            email: Value(email),
            phone: Value(phone),
            vatId: Value(vatId),
            contactPerson: Value(contactPerson),
            notes: Value(notes),
            createdAt: DateTime.now(),
          ),
        );
    return (await findById(companyId: companyId, id: id))!;
  }

  /// Aktualisiert nur, wenn der Kunde tatsächlich zu [companyId] gehört —
  /// sonst betrifft die WHERE-Klausel keine Zeile (kein Cross-Tenant-
  /// Schreibzugriff über eine erratene ID).
  Future<bool> update({required String companyId, required Customer customer}) async {
    if (customer.companyId != companyId) return false;
    final rows = await (_db.update(_db.customers)
          ..where((c) => c.id.equals(customer.id) & c.companyId.equals(companyId)))
        .write(customer.toCompanion(false));
    return rows > 0;
  }

  Future<bool> delete({required String companyId, required String id}) async {
    final rows = await (_db.delete(_db.customers)
          ..where((c) => c.id.equals(id) & c.companyId.equals(companyId)))
        .go();
    return rows > 0;
  }
}
