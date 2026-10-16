import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:werkkernerp/data/database/database.dart';
import 'package:werkkernerp/data/repositories/company_repository.dart';
import 'package:werkkernerp/data/repositories/supplier_repository.dart';

/// `SupplierRepository.update()` ist neu (Kay-Nachtrag 2026-10-16:
/// Lieferanten waren bisher nicht bearbeitbar) — analoge Isolations-
/// garantie wie `CustomerRepository` (siehe dort für die Begründung).
void main() {
  late AppDatabase db;
  late CompanyRepository companies;
  late SupplierRepository suppliers;

  setUp(() {
    db = AppDatabase.forTesting(
      NativeDatabase.memory(setup: (rawDb) => rawDb.execute('PRAGMA foreign_keys = ON;')),
    );
    companies = CompanyRepository(db);
    suppliers = SupplierRepository(db);
  });

  tearDown(() async => db.close());

  test(
    'A0-Abnahme: fremde Firmen-ID liefert nie einen Lieferanten zurück, auch bei bekannter '
    'echter Lieferanten-ID — update()/delete() über eine fremde Firma schlagen fehl',
    () async {
      final companyA = await companies.create(name: 'Elektro Beckmann');
      final companyB = await companies.create(name: 'Bauunternehmen Glogau');
      final supplierOfA = await suppliers.create(companyId: companyA.id, name: 'Lieferant A');

      final leaked = await suppliers.findById(companyId: companyB.id, id: supplierOfA.id);
      expect(leaked, isNull);

      final updateAttempt = await suppliers.update(
        companyId: companyB.id,
        supplier: supplierOfA.copyWith(name: 'Übernommen'),
      );
      expect(updateAttempt, isFalse);
      final stillOriginal = await suppliers.findById(companyId: companyA.id, id: supplierOfA.id);
      expect(stillOriginal!.name, 'Lieferant A');

      final deleteAttempt = await suppliers.delete(companyId: companyB.id, id: supplierOfA.id);
      expect(deleteAttempt, isFalse);
      expect(await suppliers.findById(companyId: companyA.id, id: supplierOfA.id), isNotNull);
    },
  );

  test(
    'Kay-Nachtrag 2026-10-16: erweiterte Kontaktfelder (Anschrift, USt-IdNr., Ansprechpartner, '
    'Notizen) werden gespeichert und sind über update() nachträglich änderbar',
    () async {
      final company = await companies.create(name: 'Firma A');
      final supplier = await suppliers.create(
        companyId: company.id,
        name: 'Großhändler Nord',
        address: 'Industriestraße 5, 12345 Musterstadt',
        vatId: 'DE987654321',
        contactPerson: 'Herr Weber',
        notes: 'Liefert auch kurzfristig.',
      );
      expect(supplier.address, 'Industriestraße 5, 12345 Musterstadt');
      expect(supplier.vatId, 'DE987654321');
      expect(supplier.contactPerson, 'Herr Weber');
      expect(supplier.notes, 'Liefert auch kurzfristig.');

      final updated = await suppliers.update(
        companyId: company.id,
        supplier: supplier.copyWith(contactPerson: const Value('Frau Weber')),
      );
      expect(updated, isTrue);
      final reloaded = await suppliers.findById(companyId: company.id, id: supplier.id);
      expect(reloaded!.contactPerson, 'Frau Weber');
      expect(reloaded.vatId, 'DE987654321');
    },
  );
}
