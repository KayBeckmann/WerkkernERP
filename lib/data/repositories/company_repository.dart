import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../database/database.dart';

/// Verwaltung der lokal geführten Firmen. Es gibt hier bewusst keine
/// companyId-Filterung — Firmen sind die oberste Ebene, auf der die
/// Isolation aller anderen Tabellen aufbaut (Roadmap A0).
class CompanyRepository {
  CompanyRepository(this._db);

  final AppDatabase _db;
  static const _uuid = Uuid();

  Future<List<Company>> listAll() => _db.select(_db.companies).get();

  Future<Company?> findById(String id) =>
      (_db.select(_db.companies)..where((c) => c.id.equals(id))).getSingleOrNull();

  Future<Company> create({
    required String name,
    String? address,
    String? taxNumber,
    String? vatId,
    String? iban,
    String? email,
    String? phone,
  }) async {
    final id = _uuid.v4();
    await _db.into(_db.companies).insert(
          CompaniesCompanion.insert(
            id: id,
            name: name,
            address: Value(address),
            taxNumber: Value(taxNumber),
            vatId: Value(vatId),
            iban: Value(iban),
            email: Value(email),
            phone: Value(phone),
            createdAt: DateTime.now(),
          ),
        );
    return (await findById(id))!;
  }

  Future<void> update(Company company) => _db.update(_db.companies).replace(company);

  /// A5: Angebot/Auftrag pro Firma ein-/ausblenden. Schaltet nur die
  /// Sichtbarkeit in der Navigation — bereits vorhandene Angebots-/
  /// Auftragsdaten bleiben beim Deaktivieren unverändert in der
  /// Datenbank (Abnahme A5: "erhält sämtliche Modul-Daten").
  Future<Company> setModules({
    required String companyId,
    required bool quotesEnabled,
    required bool ordersEnabled,
    required bool deliveryNotesEnabled,
    required bool proformaEnabled,
    required bool projectsEnabled,
    required bool fleetEnabled,
    required bool recurringInvoicesEnabled,
    required bool advancePaymentInvoicesEnabled,
    required bool dunningEnabled,
    required bool smtpEnabled,
    required bool buchhaltungEnabled,
    required bool creditNotesEnabled,
    required bool lagerbestandEnabled,
  }) async {
    final company = await findById(companyId);
    if (company == null) {
      throw ArgumentError('Firma $companyId existiert nicht.');
    }
    final updated = company.copyWith(
      quotesEnabled: quotesEnabled,
      ordersEnabled: ordersEnabled,
      deliveryNotesEnabled: deliveryNotesEnabled,
      proformaEnabled: proformaEnabled,
      projectsEnabled: projectsEnabled,
      fleetEnabled: fleetEnabled,
      recurringInvoicesEnabled: recurringInvoicesEnabled,
      advancePaymentInvoicesEnabled: advancePaymentInvoicesEnabled,
      dunningEnabled: dunningEnabled,
      smtpEnabled: smtpEnabled,
      buchhaltungEnabled: buchhaltungEnabled,
      creditNotesEnabled: creditNotesEnabled,
      lagerbestandEnabled: lagerbestandEnabled,
    );
    await update(updated);
    return updated;
  }

  /// Löscht die Firma samt aller abhängigen Daten (Kunden, Artikel,
  /// Rechnungen, ...) per ON DELETE CASCADE.
  Future<void> delete(String id) =>
      (_db.delete(_db.companies)..where((c) => c.id.equals(id))).go();
}
