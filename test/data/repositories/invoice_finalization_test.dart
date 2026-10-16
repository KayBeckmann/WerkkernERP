import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:werkkernerp/data/database/database.dart';
import 'package:werkkernerp/data/database/tables.dart';
import 'package:werkkernerp/data/repositories/company_repository.dart';
import 'package:werkkernerp/data/repositories/customer_repository.dart';
import 'package:werkkernerp/data/repositories/invoice_repository.dart';
import 'package:werkkernerp/data/repositories/number_sequence_repository.dart';

void main() {
  late AppDatabase db;
  late CompanyRepository companies;
  late CustomerRepository customers;
  late InvoiceRepository invoices;

  setUp(() {
    db = AppDatabase.forTesting(
      NativeDatabase.memory(setup: (rawDb) => rawDb.execute('PRAGMA foreign_keys = ON;')),
    );
    companies = CompanyRepository(db);
    customers = CustomerRepository(db);
    invoices = InvoiceRepository(db, NumberSequenceRepository(db));
  });

  tearDown(() async => db.close());

  Future<Invoice> draftWithOneItem(String companyId, String customerId) => invoices.createDraft(
        companyId: companyId,
        customerId: customerId,
        issueDate: DateTime.now(),
        serviceDate: DateTime.now(),
        items: [
          InvoiceItemInput(
            kind: InvoiceItemKind.text,
            description: 'Testposition',
            quantity: Decimal.one,
            unitPriceCents: 10000,
            vatRatePercent: 19,
          ),
        ],
      );

  test(
    'A3-Abnahme: zwei Firmen finalisieren unabhängig R-JJxxx-Rechnungen, '
    'identische Zählerwerte sind nur getrennt je Firma zulässig',
    () async {
      final companyA = await companies.create(name: 'Elektro Beckmann');
      final companyB = await companies.create(name: 'Bauunternehmen Glogau');
      final customerA = await customers.create(companyId: companyA.id, name: 'Kunde A');
      final customerB = await customers.create(companyId: companyB.id, name: 'Kunde B');

      final draftA = await draftWithOneItem(companyA.id, customerA.id);
      final draftB = await draftWithOneItem(companyB.id, customerB.id);

      final finalizedA = await invoices.finalize(companyId: companyA.id, id: draftA.id);
      final finalizedB = await invoices.finalize(companyId: companyB.id, id: draftB.id);

      expect(finalizedA, isNotNull);
      expect(finalizedB, isNotNull);
      expect(finalizedA!.status, InvoiceStatus.finalized);
      expect(finalizedB!.status, InvoiceStatus.finalized);

      final year = DateTime.now().year % 100;
      // Beide sind die jeweils erste Rechnung ihrer Firma -> gleicher
      // Zählerwert 001 in BEIDEN Firmen zulässig, da getrennte Kreise.
      expect(finalizedA.invoiceNumber, 'R-${year.toString().padLeft(2, '0')}001');
      expect(finalizedB.invoiceNumber, 'R-${year.toString().padLeft(2, '0')}001');
      expect(finalizedA.numberYear, DateTime.now().year);
    },
  );

  test('Nummern innerhalb derselben Firma sind niemals doppelt, auch bei mehreren Rechnungen', () async {
    final company = await companies.create(name: 'Firma A');
    final customer = await customers.create(companyId: company.id, name: 'Kunde');

    final numbers = <String>[];
    for (var i = 0; i < 5; i++) {
      final draft = await draftWithOneItem(company.id, customer.id);
      final finalized = await invoices.finalize(companyId: company.id, id: draft.id);
      numbers.add(finalized!.invoiceNumber!);
    }
    expect(numbers.toSet(), hasLength(5)); // keine Duplikate
    final year = DateTime.now().year % 100;
    final yy = year.toString().padLeft(2, '0');
    expect(numbers, ['R-${yy}001', 'R-${yy}002', 'R-${yy}003', 'R-${yy}004', 'R-${yy}005']);
  });

  test(
    'Doppeltes/gleichzeitiges Finalisieren derselben Rechnung vergibt nie zwei Nummern '
    '(F3: kein Prozessabbruch/erneutes Antippen erzeugt eine Dublette)',
    () async {
      final company = await companies.create(name: 'Firma A');
      final customer = await customers.create(companyId: company.id, name: 'Kunde');
      final draft = await draftWithOneItem(company.id, customer.id);

      // Zwei "gleichzeitige" Finalisierungsversuche derselben Rechnung.
      final results = await Future.wait([
        invoices.finalize(companyId: company.id, id: draft.id),
        invoices.finalize(companyId: company.id, id: draft.id),
      ]);

      final succeeded = results.where((r) => r != null).toList();
      expect(succeeded, hasLength(1)); // nur einer der beiden Versuche gewinnt

      // Es wurde nur EINE Nummer verbraucht, keine zweite Rechnung bekam
      // versehentlich auch eine.
      final otherDraft = await draftWithOneItem(company.id, customer.id);
      final otherFinalized = await invoices.finalize(companyId: company.id, id: otherDraft.id);
      final year = DateTime.now().year % 100;
      expect(otherFinalized!.invoiceNumber, 'R-${year.toString().padLeft(2, '0')}002');
    },
  );

  test('Finalisierte Rechnung ist über update() nicht mehr änderbar; Entwurf bleibt es', () async {
    final company = await companies.create(name: 'Firma A');
    final customer = await customers.create(companyId: company.id, name: 'Kunde');
    final draft = await draftWithOneItem(company.id, customer.id);
    await invoices.finalize(companyId: company.id, id: draft.id);

    final updateAttempt = await invoices.update(
      companyId: company.id,
      id: draft.id,
      notes: 'nachträglich geändert',
    );
    expect(updateAttempt, isNull);

    final stillFinalized = await invoices.findById(companyId: company.id, id: draft.id);
    expect(stillFinalized!.notes, isNull);
  });

  test('Kunden- und Firmendaten werden beim Finalisieren eingefroren (Snapshot)', () async {
    final company = await companies.create(
      name: 'Elektro Beckmann',
      address: 'Musterstraße 1, 23966 Wismar',
      taxNumber: '123/456/78901',
    );
    final customer = await customers.create(
      companyId: company.id,
      name: 'Max Mustermann',
      address: 'Kundenweg 2',
      vatId: 'DE111222333',
    );
    final draft = await draftWithOneItem(company.id, customer.id);
    final finalized = await invoices.finalize(companyId: company.id, id: draft.id);

    expect(finalized!.customerSnapshotName, 'Max Mustermann');
    expect(finalized.customerSnapshotAddress, 'Kundenweg 2');
    expect(finalized.customerSnapshotVatId, 'DE111222333');
    expect(finalized.companySnapshotName, 'Elektro Beckmann');
    expect(finalized.companySnapshotTaxNumber, '123/456/78901');

    // Stammdatenänderung NACH Finalisierung darf den Schnappschuss nicht
    // verändern (A1: "spätere Stammdatenänderungen alte PDFs nicht
    // verändern").
    await customers.update(
      companyId: company.id,
      customer: customer.copyWith(
        name: 'Neuer Name',
        address: const Value('Neue Adresse'),
        vatId: const Value('DE999888777'),
      ),
    );
    final reloaded = await invoices.findById(companyId: company.id, id: draft.id);
    expect(reloaded!.customerSnapshotName, 'Max Mustermann');
    expect(reloaded.customerSnapshotVatId, 'DE111222333');
  });

  test('Rechnung ohne Positionen kann nicht finalisiert werden', () async {
    final company = await companies.create(name: 'Firma A');
    final customer = await customers.create(companyId: company.id, name: 'Kunde');
    final draft = await invoices.createDraft(
      companyId: company.id,
      customerId: customer.id,
      issueDate: DateTime.now(),
      serviceDate: DateTime.now(),
    );

    expect(
      () => invoices.finalize(companyId: company.id, id: draft.id),
      throwsStateError,
    );
  });
}
