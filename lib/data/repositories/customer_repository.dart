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
    String? invoiceEmail,
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
            invoiceEmail: Value(invoiceEmail),
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

/// Eingabe für eine Kontaktperson; [id] `null` = neu.
typedef ContactInput = ({String? id, String name, String? role, String? email, String? phone});

/// Kontaktpersonen je Kunde (Kay 2026-11-09) — wie [CustomerRepository]
/// zwingend firmengebunden.
class CustomerContactRepository {
  CustomerContactRepository(this._db);

  final AppDatabase _db;
  static const _uuid = Uuid();

  Future<List<CustomerContact>> listForCustomer({required String companyId, required String customerId}) =>
      (_db.select(_db.customerContacts)
            ..where((c) => c.companyId.equals(companyId) & c.customerId.equals(customerId))
            ..orderBy([(c) => OrderingTerm.asc(c.sortOrder), (c) => OrderingTerm.asc(c.name)]))
          .get();

  Future<CustomerContact?> findById({required String companyId, required String id}) =>
      (_db.select(_db.customerContacts)..where((c) => c.id.equals(id) & c.companyId.equals(companyId)))
          .getSingleOrNull();

  /// Ersetzt die Kontaktpersonen des Kunden in [contacts]-Reihenfolge:
  /// bekannte IDs werden aktualisiert, neue angelegt, fehlende gelöscht
  /// (Dokumente verlieren dann nur die Zuordnung, `onDelete: setNull`).
  /// Fremde oder unbekannte IDs werden wie neue behandelt.
  Future<List<CustomerContact>> replaceForCustomer({
    required String companyId,
    required String customerId,
    required List<ContactInput> contacts,
  }) =>
      _db.transaction(() async {
        final existing = {
          for (final c in await listForCustomer(companyId: companyId, customerId: customerId)) c.id,
        };
        final keep = {for (final c in contacts) if (c.id != null && existing.contains(c.id)) c.id!};
        await (_db.delete(_db.customerContacts)
              ..where((c) =>
                  c.companyId.equals(companyId) & c.customerId.equals(customerId) & c.id.isNotIn(keep)))
            .go();
        for (final (index, c) in contacts.indexed) {
          final companion = CustomerContactsCompanion(
            name: Value(c.name),
            role: Value(c.role),
            email: Value(c.email),
            phone: Value(c.phone),
            sortOrder: Value(index),
          );
          if (c.id != null && keep.contains(c.id)) {
            await (_db.update(_db.customerContacts)..where((x) => x.id.equals(c.id!))).write(companion);
          } else {
            await _db.into(_db.customerContacts).insert(
                  companion.copyWith(
                    id: Value(_uuid.v4()),
                    companyId: Value(companyId),
                    customerId: Value(customerId),
                  ),
                );
          }
        }
        return listForCustomer(companyId: companyId, customerId: customerId);
      });
}
