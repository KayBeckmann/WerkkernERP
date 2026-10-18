import 'package:decimal/decimal.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:werkkernerp/data/database/database.dart';
import 'package:werkkernerp/data/database/tables.dart';
import 'package:werkkernerp/data/repositories/company_repository.dart';
import 'package:werkkernerp/data/repositories/customer_repository.dart';
import 'package:werkkernerp/data/repositories/invoice_repository.dart';
import 'package:werkkernerp/data/repositories/number_sequence_repository.dart';

/// Gutschriften (Kay-Entscheidung 2026-10-19: "Gutschriften bekommen einen
/// eigenen Nummernkreis") — Tests für `createCreditNoteDraft()`,
/// `listCreditNotesForInvoice()` und `sumCreditNotesForInvoice()`. Die
/// UI-Flows (Button, FAB-Unterdrückung, PDF-Referenzzeile) sind nicht Teil
/// dieser Datei, siehe statt dessen `invoice_editor_screen` und
/// `invoice_pdf_builder`.
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

  Future<Invoice> finalizedInvoice({
    required String companyId,
    required String customerId,
    int priceCents = 10000,
  }) async {
    final draft = await invoices.createDraft(
      companyId: companyId,
      customerId: customerId,
      issueDate: DateTime(2026, 10, 10),
      serviceDate: DateTime(2026, 10, 10),
      items: [
        InvoiceItemInput(
          kind: InvoiceItemKind.text,
          description: 'Montagearbeiten',
          quantity: Decimal.one,
          unitPriceCents: priceCents,
          vatRatePercent: 19,
        ),
      ],
    );
    return (await invoices.finalize(companyId: companyId, id: draft.id))!;
  }

  test(
    'createCreditNoteDraft(): kopiert Positionen 1:1 als Entwurf ohne eigene Nummer, '
    'referenziert die Quellrechnung über convertedFromId',
    () async {
      final company = await companies.create(name: 'Elektro Beckmann');
      final customer = await customers.create(companyId: company.id, name: 'Max Mustermann');
      final invoice = await finalizedInvoice(companyId: company.id, customerId: customer.id);

      final creditNote = await invoices.createCreditNoteDraft(
        companyId: company.id,
        invoiceId: invoice.id,
      );

      expect(creditNote.kind, DocumentKind.creditNote);
      expect(creditNote.status, InvoiceStatus.draft, reason: 'F3: auch Gutschriften starten nummernlos als Entwurf');
      expect(creditNote.invoiceNumber, isNull);
      expect(creditNote.convertedFromId, invoice.id);
      expect(creditNote.customerId, customer.id);

      final items = await invoices.itemsFor(creditNote.id);
      expect(items, hasLength(1));
      expect(items.single.description, 'Montagearbeiten');
      expect(items.single.unitPriceCents, 10000);
    },
  );

  test(
    'createCreditNoteDraft(): lehnt eine nicht-finalisierte Rechnung als Quelle ab (StateError)',
    () async {
      final company = await companies.create(name: 'Elektro Beckmann');
      final customer = await customers.create(companyId: company.id, name: 'Max Mustermann');
      final draft = await invoices.createDraft(
        companyId: company.id,
        customerId: customer.id,
        issueDate: DateTime(2026, 10, 10),
        serviceDate: DateTime(2026, 10, 10),
        items: [
          InvoiceItemInput(
            kind: InvoiceItemKind.text,
            description: 'Noch nicht finalisiert',
            quantity: Decimal.one,
            unitPriceCents: 5000,
            vatRatePercent: 19,
          ),
        ],
      );

      expect(
        () => invoices.createCreditNoteDraft(companyId: company.id, invoiceId: draft.id),
        throwsStateError,
      );
    },
  );

  test(
    'createCreditNoteDraft(): lehnt eine andere Dokumentart als Quelle ab (ArgumentError), '
    'z. B. ein finalisiertes Angebot',
    () async {
      final company = await companies.create(name: 'Elektro Beckmann');
      final customer = await customers.create(companyId: company.id, name: 'Max Mustermann');
      final quoteDraft = await invoices.createDraft(
        companyId: company.id,
        customerId: customer.id,
        issueDate: DateTime(2026, 10, 10),
        serviceDate: DateTime(2026, 10, 10),
        kind: DocumentKind.quote,
        items: [
          InvoiceItemInput(
            kind: InvoiceItemKind.text,
            description: 'Angebotsposition',
            quantity: Decimal.one,
            unitPriceCents: 5000,
            vatRatePercent: 19,
          ),
        ],
      );
      final quote = await invoices.finalize(companyId: company.id, id: quoteDraft.id);

      expect(
        () => invoices.createCreditNoteDraft(companyId: company.id, invoiceId: quote!.id),
        throwsArgumentError,
      );
    },
  );

  test(
    'createCreditNoteDraft(): eine finalisierte Rechnung bleibt weiterhin gesperrt — '
    'Erstellen einer Gutschrift darf isEditable() NICHT wieder aufschließen '
    '(Doc-Kommentar-Risiko bei isEditable/allowedConversionTargets)',
    () async {
      final company = await companies.create(name: 'Elektro Beckmann');
      final customer = await customers.create(companyId: company.id, name: 'Max Mustermann');
      final invoice = await finalizedInvoice(companyId: company.id, customerId: customer.id);

      await invoices.createCreditNoteDraft(companyId: company.id, invoiceId: invoice.id);

      final stillLocked = await invoices.update(
        companyId: company.id,
        id: invoice.id,
        notes: 'Darf nicht mehr greifen',
      );
      expect(
        stillLocked,
        isNull,
        reason: 'update() gibt null zurück, wenn isEditable() false ist — die Rechnung bleibt gesperrt',
      );
    },
  );

  test(
    'listCreditNotesForInvoice()/sumCreditNotesForInvoice(): nur finalisierte Gutschriften '
    'zählen, ein offener Entwurf wird ignoriert',
    () async {
      final company = await companies.create(name: 'Elektro Beckmann');
      final customer = await customers.create(companyId: company.id, name: 'Max Mustermann');
      final invoice = await finalizedInvoice(
        companyId: company.id,
        customerId: customer.id,
        priceCents: 100000,
      );

      // Noch kein Entwurf finalisiert -> leer.
      expect(await invoices.listCreditNotesForInvoice(invoice.id), isEmpty);
      expect((await invoices.sumCreditNotesForInvoice(invoice.id)).cents, 0);

      final draftCreditNote = await invoices.createCreditNoteDraft(
        companyId: company.id,
        invoiceId: invoice.id,
      );
      // Entwurf (noch nicht finalisiert) darf nicht mitzählen.
      expect(await invoices.listCreditNotesForInvoice(invoice.id), isEmpty);

      final finalizedCreditNote = await invoices.finalize(companyId: company.id, id: draftCreditNote.id);
      expect(finalizedCreditNote!.kind, DocumentKind.creditNote);
      expect(finalizedCreditNote.invoiceNumber, startsWith('G-'), reason: 'eigener Nummernkreis "G"');

      final listed = await invoices.listCreditNotesForInvoice(invoice.id);
      expect(listed, hasLength(1));
      expect(listed.single.id, finalizedCreditNote.id);

      // Volle USt (19% auf 100000 Cent netto-Arbeitsvorgabe hier: Position
      // war bereits brutto gleich dem Nettobetrag der Testposition, siehe
      // finalizedInvoice()) — es kommt auf "volle Brutto-Summe", nicht auf
      // einen konkreten Cent-Wert an, daher Vergleich gegen totalsFor().
      final expectedGross = (await invoices.totalsFor(finalizedCreditNote.id)).totalGross;
      final sum = await invoices.sumCreditNotesForInvoice(invoice.id);
      expect(sum, expectedGross);
      expect(sum.cents, greaterThan(0));
    },
  );
}
