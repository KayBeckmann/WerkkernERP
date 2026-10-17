import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:werkkernerp/data/database/database.dart';
import 'package:werkkernerp/data/database/tables.dart';
import 'package:werkkernerp/data/repositories/company_repository.dart';
import 'package:werkkernerp/data/repositories/vehicle_repository.dart';

/// C6 Fuhrpark/Auswärtsmontage (Kay-Priorisierungsentscheidung
/// 2026-10-17, C6-Kern).
void main() {
  late AppDatabase db;
  late CompanyRepository companies;
  late VehicleRepository vehicles;

  setUp(() {
    db = AppDatabase.forTesting(
      NativeDatabase.memory(setup: (rawDb) => rawDb.execute('PRAGMA foreign_keys = ON;')),
    );
    companies = CompanyRepository(db);
    vehicles = VehicleRepository(db);
  });

  tearDown(() async => db.close());

  test('A0-Abnahme: zwei Firmen mit gleichnamigen Fahrzeugen haben keine Vermischung', () async {
    final companyA = await companies.create(name: 'Firma A');
    final companyB = await companies.create(name: 'Firma B');
    await vehicles.create(companyId: companyA.id, name: 'Transporter 1');
    await vehicles.create(companyId: companyB.id, name: 'Transporter 1');

    expect(await vehicles.listForCompany(companyA.id), hasLength(1));
    expect(await vehicles.listForCompany(companyB.id), hasLength(1));
  });

  test('Fremde Firmen-ID liefert nie ein Fahrzeug zurück, auch bei bekannter echter ID', () async {
    final companyA = await companies.create(name: 'Firma A');
    final companyB = await companies.create(name: 'Firma B');
    final vehicle = await vehicles.create(companyId: companyA.id, name: 'Transporter 1');

    expect(await vehicles.findById(companyId: companyB.id, id: vehicle.id), isNull);
  });

  test(
    'Deaktivieren blendet ein Fahrzeug aus listForCompany() aus, löscht aber keine '
    'Kostenbuchungen',
    () async {
      final company = await companies.create(name: 'Firma A');
      final vehicle = await vehicles.create(companyId: company.id, name: 'Transporter 1');
      await vehicles.addCostEntry(
        companyId: company.id,
        vehicleId: vehicle.id,
        date: DateTime.now(),
        amountCents: 5000,
        category: VehicleCostCategory.fuel,
      );

      await vehicles.setActive(companyId: company.id, id: vehicle.id, active: false);
      expect(await vehicles.listForCompany(company.id), isEmpty);
      expect(await vehicles.listForCompany(company.id, includeInactive: true), hasLength(1));
      expect(
        await vehicles.listCostsForVehicle(companyId: company.id, vehicleId: vehicle.id),
        hasLength(1),
        reason: 'Deaktivieren darf keine bestehende Kostenbuchung löschen',
      );
    },
  );

  test('Mehrere Kostenbuchungen eines Fahrzeugs werden absteigend nach Datum sortiert', () async {
    final company = await companies.create(name: 'Firma A');
    final vehicle = await vehicles.create(companyId: company.id, name: 'Transporter 1');

    await vehicles.addCostEntry(
      companyId: company.id,
      vehicleId: vehicle.id,
      date: DateTime(2026, 1, 1),
      amountCents: 1000,
      category: VehicleCostCategory.fuel,
    );
    await vehicles.addCostEntry(
      companyId: company.id,
      vehicleId: vehicle.id,
      date: DateTime(2026, 6, 1),
      amountCents: 2000,
      category: VehicleCostCategory.maintenance,
    );

    final costs = await vehicles.listCostsForVehicle(companyId: company.id, vehicleId: vehicle.id);
    expect(costs.map((c) => c.amountCents), [2000, 1000]);
  });
}
