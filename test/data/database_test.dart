import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:werkkernerp/data/database/database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(
      NativeDatabase.memory(setup: (rawDb) => rawDb.execute('PRAGMA foreign_keys = ON;')),
    );
  });

  tearDown(() async {
    await db.close();
  });

  test('Schema legt alle Tabellen an und erlaubt einen einfachen Rundtrip', () async {
    final companyId = 'company-1';
    await db.into(db.companies).insert(
          CompaniesCompanion.insert(id: companyId, name: 'Testfirma', createdAt: DateTime.now()),
        );

    final customerId = 'customer-1';
    await db.into(db.customers).insert(
          CustomersCompanion.insert(
            id: customerId,
            companyId: companyId,
            name: 'Max Mustermann',
            createdAt: DateTime.now(),
          ),
        );

    final customers = await db.select(db.customers).get();
    expect(customers, hasLength(1));
    expect(customers.single.companyId, companyId);
  });

  test('Firmen-Löschung löscht abhängige Daten per Cascade (A0-Isolation)', () async {
    final companyA = 'company-a';
    final companyB = 'company-b';
    await db.batch((batch) {
      batch.insertAll(db.companies, [
        CompaniesCompanion.insert(id: companyA, name: 'Firma A', createdAt: DateTime.now()),
        CompaniesCompanion.insert(id: companyB, name: 'Firma B', createdAt: DateTime.now()),
      ]);
      batch.insertAll(db.customers, [
        CustomersCompanion.insert(
          id: 'ca-1',
          companyId: companyA,
          name: 'Kunde A',
          createdAt: DateTime.now(),
        ),
        CustomersCompanion.insert(
          id: 'cb-1',
          companyId: companyB,
          name: 'Kunde B',
          createdAt: DateTime.now(),
        ),
      ]);
    });

    await (db.delete(db.companies)..where((c) => c.id.equals(companyA))).go();

    final remaining = await db.select(db.customers).get();
    expect(remaining, hasLength(1));
    expect(remaining.single.companyId, companyB);
  });
}
