import 'package:flutter_test/flutter_test.dart';
import 'package:werkkernerp/data/database/database.dart';
import 'package:werkkernerp/domain/services/datev_export_service.dart';

/// C14.5 DATEV-Export (Kay-Priorisierungsentscheidung 2026-10-18,
/// SKR03, siehe ausführlichen Disclaimer in datev_export_service.dart).
void main() {
  const config = DatevExportConfig(
    beraterNummer: '12345',
    mandantNummer: '6789',
    bankGegenkonto: '1200',
    sachkontenlaenge: 4,
    companyName: 'Elektro Beckmann',
  );

  Expense expenseWith({required String id, int cents = 11900, String? categoryId, String? description}) =>
      Expense(
        id: id,
        companyId: 'company-1',
        date: DateTime(2026, 10, 15),
        description: description ?? 'Testbeleg',
        amountGrossCents: cents,
        vatRatePercent: 19,
        categoryId: categoryId,
        supplierReference: 'Beleg-001',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

  ExpenseCategory categoryWith({required String id, String? skr03Account}) => ExpenseCategory(
        id: id,
        companyId: 'company-1',
        label: 'Material',
        skr03Account: skr03Account,
        createdAt: DateTime.now(),
      );

  test('Header-Zeile hat exakt 31 Felder in der recherchierten DATEV-EXTF-Reihenfolge', () {
    final result = buildDatevBuchungsstapel(
      expenses: const [],
      categoryById: const {},
      config: config,
      periodStart: DateTime(2026, 10, 1),
      periodEnd: DateTime(2026, 10, 31),
      generatedAt: DateTime(2026, 10, 18, 12, 30, 0),
    );
    final lines = result.csvContent.split('\r\n');
    final headerFields = lines[0].split(';');
    expect(headerFields.length, 31);
    expect(headerFields[0], 'EXTF');
    expect(headerFields[2], '21', reason: 'Datenkategorie: 21 = Buchungsstapel');
    expect(headerFields[10], '12345', reason: 'Position 11 (Index 10): Berater');
    expect(headerFields[11], '6789', reason: 'Position 12 (Index 11): Mandant');
    expect(headerFields[12], '20260101', reason: 'WJ-Beginn: yyyyMMdd, NICHT ddMMyyyy');
    expect(headerFields[14], '20261001', reason: 'Datum vom: yyyyMMdd');
    expect(headerFields[15], '20261031', reason: 'Datum bis: yyyyMMdd');
    expect(headerFields[26], '03', reason: 'SKR: SKR03 (Kay-Entscheidung 2026-10-18)');
  });

  test('Spaltenüberschriften-Zeile hat exakt 125 Felder', () {
    final result = buildDatevBuchungsstapel(
      expenses: const [],
      categoryById: const {},
      config: config,
      periodStart: DateTime(2026, 10, 1),
      periodEnd: DateTime(2026, 10, 31),
      generatedAt: DateTime(2026, 10, 18),
    );
    final lines = result.csvContent.split('\r\n');
    final columnHeaders = lines[1].split(';');
    expect(columnHeaders.length, 125);
    expect(columnHeaders[0], 'Umsatz (ohne Soll/Haben-Kz)');
    expect(columnHeaders[6], 'Konto');
    expect(columnHeaders[9], 'Belegdatum');
    expect(columnHeaders[13], 'Buchungstext');
  });

  test('ein Beleg mit zugewiesenem SKR03-Konto wird mit 125 Feldern korrekt exportiert', () {
    final result = buildDatevBuchungsstapel(
      expenses: [expenseWith(id: 'exp-1', categoryId: 'material', description: 'Kabel NYM-J')],
      categoryById: {'material': categoryWith(id: 'material', skr03Account: '4200')},
      config: config,
      periodStart: DateTime(2026, 10, 1),
      periodEnd: DateTime(2026, 10, 31),
      generatedAt: DateTime(2026, 10, 18),
    );

    expect(result.exportedCount, 1);
    expect(result.skippedExpenses, isEmpty);

    final lines = result.csvContent.split('\r\n');
    final row = lines[2].split(';');
    expect(row.length, 125);
    expect(row[0], '119,00', reason: 'Umsatz ohne Vorzeichen, Komma als Dezimaltrenner');
    expect(row[1], 'S', reason: 'Soll/Haben-Kennzeichen');
    expect(row[6], '4200', reason: 'Konto = SKR03-Konto der Kategorie');
    expect(row[7], '1200', reason: 'Gegenkonto = konfiguriertes Bankkonto');
    expect(row[8], '', reason: 'BU-Schlüssel bleibt bewusst leer');
    expect(row[9], '1510', reason: 'Belegdatum TTMM ohne Jahr (15.10.)');
    expect(row[10], 'Beleg-001');
    expect(row[13], 'Kabel NYM-J');
  });

  test('ein Beleg OHNE zugewiesenes SKR03-Konto wird übersprungen, nicht falsch gebucht', () {
    final result = buildDatevBuchungsstapel(
      expenses: [expenseWith(id: 'exp-1', categoryId: 'material')],
      categoryById: {'material': categoryWith(id: 'material', skr03Account: null)},
      config: config,
      periodStart: DateTime(2026, 10, 1),
      periodEnd: DateTime(2026, 10, 31),
      generatedAt: DateTime(2026, 10, 18),
    );

    expect(result.exportedCount, 0);
    expect(result.skippedExpenses, hasLength(1));
    expect(result.csvContent.split('\r\n'), hasLength(3), reason: 'Header + Spaltenzeile + leere Zeile am Ende');
  });

  test('ein Beleg ganz ohne Kategorie wird ebenfalls übersprungen', () {
    final result = buildDatevBuchungsstapel(
      expenses: [expenseWith(id: 'exp-1', categoryId: null)],
      categoryById: const {},
      config: config,
      periodStart: DateTime(2026, 10, 1),
      periodEnd: DateTime(2026, 10, 31),
      generatedAt: DateTime(2026, 10, 18),
    );

    expect(result.exportedCount, 0);
    expect(result.skippedExpenses, hasLength(1));
  });

  test('Buchungstext wird auf 60 Zeichen gekürzt (DATEV-Feldlänge)', () {
    final longDescription = 'A' * 100;
    final result = buildDatevBuchungsstapel(
      expenses: [expenseWith(id: 'exp-1', categoryId: 'material', description: longDescription)],
      categoryById: {'material': categoryWith(id: 'material', skr03Account: '4200')},
      config: config,
      periodStart: DateTime(2026, 10, 1),
      periodEnd: DateTime(2026, 10, 31),
      generatedAt: DateTime(2026, 10, 18),
    );
    final row = result.csvContent.split('\r\n')[2].split(';');
    expect(row[13].length, 60);
  });

  test('DatevExportConfig.isComplete prüft Berater-, Mandant- und Gegenkonto-Nummer', () {
    expect(config.isComplete, isTrue);
    const incomplete = DatevExportConfig(
      beraterNummer: '',
      mandantNummer: '6789',
      bankGegenkonto: '1200',
      sachkontenlaenge: 4,
      companyName: 'Elektro Beckmann',
    );
    expect(incomplete.isComplete, isFalse);
  });
}
