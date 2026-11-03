import 'package:decimal/decimal.dart';
import 'package:test/test.dart';
import 'package:werkkern_core/werkkern_core.dart';

Decimal d(String v) => Decimal.parse(v);

void main() {
  const monteur = BillingRole(id: 'm', name: 'Monteur', billingRateCents: 6500);
  const meister = BillingRole(id: 'x', name: 'Meister', billingRateCents: 8500);
  const azubi = BillingRole(id: 'a', name: 'Azubi', billingRateCents: 0);

  test('Verrechnungssatz 0 € gilt als nicht hinterlegt', () {
    expect(resolveHourlyBillingRateCents(roleBillingRateCents: 0), isNull);
    expect(resolveHourlyBillingRateCents(roleBillingRateCents: 6500, customerId: 'c'), 6500);
  });

  test('eine Position je Rolle, Preis aus Auftrags-Position derselben Rolle vor Verrechnungssatz', () {
    final lines = billBookedHoursByRole(
      bookedHoursByRole: {'x': d('2'), 'm': d('6.5'), null: d('1')},
      plannedItems: const [
        PlannedHoursItem(staffRoleId: 'm', unitPriceCents: 6000, vatRatePercent: 19, unit: 'Std.', groupLabel: 'G'),
        PlannedHoursItem(staffRoleId: null, unitPriceCents: 5000, vatRatePercent: 19),
      ],
      roles: const [monteur, meister],
    );
    expect(lines.map((l) => l.staffRoleId), ['m', 'x', null]);
    expect(lines[0].unitPriceCents, 6000); // Angebot gilt
    expect(lines[0].unit, 'Std.');
    expect(lines[0].groupLabel, 'G');
    expect(lines[0].hours, d('6.5'));
    expect(lines[0].description, 'Monteur – geleistete Stunden (Ist-Zeit)');
    expect(lines[1].unitPriceCents, 8500); // keine Auftrags-Position → Satz
    expect(lines[1].unit, 'h');
    expect(lines[2].unitPriceCents, 5000); // ohne Rolle → Position ohne Rolle
    expect(lines[2].description, unassignedHoursDescription);
  });

  test('ohne Rollen: eine Position wie bisher, Rollen ohne Satz fallen auf erste Position zurück', () {
    final legacy = billBookedHoursByRole(
      bookedHoursByRole: {null: d('3')},
      plannedItems: const [PlannedHoursItem(staffRoleId: null, unitPriceCents: 5500, vatRatePercent: 7, unit: 'h')],
      roles: const [],
    );
    expect(legacy.single.unitPriceCents, 5500);
    expect(legacy.single.vatRatePercent, 7);

    final noRate = billBookedHoursByRole(
      bookedHoursByRole: {'a': d('2'), 'geloescht': d('1'), 'm': d('0')},
      plannedItems: const [PlannedHoursItem(staffRoleId: 'm', unitPriceCents: 6000, vatRatePercent: 19)],
      roles: const [monteur, azubi],
    );
    // Monteur ohne Stunden erscheint nicht; gelöschte Rolle zählt als „ohne Rolle“.
    expect(noRate.map((l) => l.staffRoleId), ['a', null]);
    expect(noRate[0].unitPriceCents, 6000);
    expect(noRate[1].hours, d('1'));
  });

  test('nichts gebucht: eine Position mit 0 h bleibt sichtbar', () {
    final lines = billBookedHoursByRole(
      bookedHoursByRole: const {},
      plannedItems: const [PlannedHoursItem(staffRoleId: 'm', unitPriceCents: 6000, vatRatePercent: 19)],
      roles: const [monteur],
    );
    expect(lines.single.staffRoleId, isNull);
    expect(lines.single.hours, Decimal.zero);
  });
}
