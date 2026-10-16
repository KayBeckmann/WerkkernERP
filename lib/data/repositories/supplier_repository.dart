import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../database/database.dart';

/// Lieferantenstammdaten je Firma — gleiche companyId-Isolation wie
/// [CustomerRepository] (siehe dort für die Begründung).
class SupplierRepository {
  SupplierRepository(this._db);

  final AppDatabase _db;
  static const _uuid = Uuid();

  Future<List<Supplier>> listForCompany(String companyId) =>
      (_db.select(_db.suppliers)..where((s) => s.companyId.equals(companyId))).get();

  Future<Supplier?> findById({required String companyId, required String id}) =>
      (_db.select(_db.suppliers)
            ..where((s) => s.id.equals(id) & s.companyId.equals(companyId)))
          .getSingleOrNull();

  Future<Supplier> create({
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
    await _db.into(_db.suppliers).insert(
          SuppliersCompanion.insert(
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

  /// Aktualisiert nur, wenn der Lieferant tatsächlich zu [companyId]
  /// gehört — sonst betrifft die WHERE-Klausel keine Zeile (kein Cross-
  /// Tenant-Schreibzugriff über eine erratene ID, siehe
  /// [CustomerRepository.update]).
  Future<bool> update({required String companyId, required Supplier supplier}) async {
    if (supplier.companyId != companyId) return false;
    final rows = await (_db.update(_db.suppliers)
          ..where((s) => s.id.equals(supplier.id) & s.companyId.equals(companyId)))
        .write(supplier.toCompanion(false));
    return rows > 0;
  }

  Future<bool> delete({required String companyId, required String id}) async {
    final rows = await (_db.delete(_db.suppliers)
          ..where((s) => s.id.equals(id) & s.companyId.equals(companyId)))
        .go();
    return rows > 0;
  }
}
