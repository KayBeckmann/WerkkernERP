import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:werkkernerp/data/database/database.dart';
import 'package:werkkernerp/data/repositories/company_repository.dart';
import 'package:werkkernerp/data/repositories/customer_repository.dart';

void main() {
  late AppDatabase db;
  late CompanyRepository companies;
  late CustomerRepository customers;

  setUp(() {
    db = AppDatabase.forTesting(
      NativeDatabase.memory(setup: (rawDb) => rawDb.execute('PRAGMA foreign_keys = ON;')),
    );
    companies = CompanyRepository(db);
    customers = CustomerRepository(db);
  });

  tearDown(() async => db.close());

  test(
    'A0-Abnahme: fremde Firmen-ID liefert nie einen Kunden zurück, auch bei bekannter echter Kunden-ID',
    () async {
      final companyA = await companies.create(name: 'Elektro Beckmann');
      final companyB = await companies.create(name: 'Bauunternehmen Glogau');

      final customerOfA = await customers.create(companyId: companyA.id, name: 'Kunde von A');

      // Gleicher Kundenname darf in Firma B unabhängig existieren, ohne
      // Vermischung (Roadmap A1-Abnahme).
      final customerOfB = await customers.create(companyId: companyB.id, name: 'Kunde von A');
      expect(customerOfB.id, isNot(customerOfA.id));

      // Direkter Versuch, den Kunden von A über Firma B abzurufen —
      // muss null liefern, nicht etwa den Kunden von A.
      final leaked = await customers.findById(companyId: companyB.id, id: customerOfA.id);
      expect(leaked, isNull);

      // listForCompany(B) enthält niemals den Kunden von A.
      final listB = await customers.listForCompany(companyB.id);
      expect(listB.map((c) => c.id), isNot(contains(customerOfA.id)));

      // Schreibzugriff über eine erratene ID + falsche companyId schlägt fehl.
      final updateAttempt = await customers.update(
        companyId: companyB.id,
        customer: customerOfA.copyWith(name: 'Übernommen'),
      );
      expect(updateAttempt, isFalse);
      final stillOriginal = await customers.findById(companyId: companyA.id, id: customerOfA.id);
      expect(stillOriginal!.name, 'Kunde von A');

      // Löschversuch über die fremde Firma schlägt ebenfalls fehl.
      final deleteAttempt = await customers.delete(companyId: companyB.id, id: customerOfA.id);
      expect(deleteAttempt, isFalse);
      expect(await customers.findById(companyId: companyA.id, id: customerOfA.id), isNotNull);
    },
  );

  test(
    'Kay-Nachtrag 2026-10-16: erweiterte Kontaktfelder (USt-IdNr., Ansprechpartner, Notizen) '
    'werden gespeichert und sind über update() nachträglich änderbar',
    () async {
      final company = await companies.create(name: 'Firma A');
      final customer = await customers.create(
        companyId: company.id,
        name: 'Testkunde',
        vatId: 'DE123456789',
        contactPerson: 'Frau Muster',
        notes: 'Zahlt immer pünktlich.',
      );
      expect(customer.vatId, 'DE123456789');
      expect(customer.contactPerson, 'Frau Muster');
      expect(customer.notes, 'Zahlt immer pünktlich.');

      final updated = await customers.update(
        companyId: company.id,
        customer: customer.copyWith(contactPerson: const Value('Herr Anders')),
      );
      expect(updated, isTrue);
      final reloaded = await customers.findById(companyId: company.id, id: customer.id);
      expect(reloaded!.contactPerson, 'Herr Anders');
      // Unveränderte Felder bleiben erhalten (copyWith betrifft nur das
      // explizit gesetzte Feld).
      expect(reloaded.vatId, 'DE123456789');
    },
  );

  test('Firma löschen entfernt ihre Kunden, lässt andere Firmen unberührt', () async {
    final companyA = await companies.create(name: 'Firma A');
    final companyB = await companies.create(name: 'Firma B');
    await customers.create(companyId: companyA.id, name: 'Kunde A1');
    await customers.create(companyId: companyB.id, name: 'Kunde B1');

    await companies.delete(companyA.id);

    expect(await customers.listForCompany(companyA.id), isEmpty);
    expect(await customers.listForCompany(companyB.id), hasLength(1));
  });
}
