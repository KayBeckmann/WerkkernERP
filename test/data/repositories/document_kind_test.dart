import 'package:decimal/decimal.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:werkkernerp/data/database/database.dart';
import 'package:werkkernerp/data/database/tables.dart';
import 'package:werkkernerp/data/repositories/company_repository.dart';
import 'package:werkkernerp/data/repositories/customer_repository.dart';
import 'package:werkkernerp/data/repositories/invoice_repository.dart';
import 'package:werkkernerp/data/repositories/number_sequence_repository.dart';

/// A5: Angebot/Auftrag als eigene Dokumentarten derselben Tabelle —
/// eigene Nummernkreise, eigene Listen, Modul-Umschaltung ohne
/// Datenverlust (Roadmap-Abnahme A5).
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

  Future<Invoice> draftWithOneItem(
    String companyId,
    String customerId, {
    DocumentKind kind = DocumentKind.invoice,
  }) =>
      invoices.createDraft(
        companyId: companyId,
        customerId: customerId,
        issueDate: DateTime.now(),
        serviceDate: DateTime.now(),
        kind: kind,
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
    'A5-Abnahme: Rechnung/Angebot/Auftrag derselben Firma im selben Jahr führen eigene '
    'Nummernkreise mit den Präfixen R/An/A — niemals vermischt',
    () async {
      final company = await companies.create(name: 'Elektro Beckmann');
      final customer = await customers.create(companyId: company.id, name: 'Kunde');
      final yy = (DateTime.now().year % 100).toString().padLeft(2, '0');

      final invoiceDraft = await draftWithOneItem(company.id, customer.id, kind: DocumentKind.invoice);
      final quoteDraft = await draftWithOneItem(company.id, customer.id, kind: DocumentKind.quote);
      final orderDraft = await draftWithOneItem(company.id, customer.id, kind: DocumentKind.order);

      final invoiceFinal = await invoices.finalize(companyId: company.id, id: invoiceDraft.id);
      final quoteFinal = await invoices.finalize(companyId: company.id, id: quoteDraft.id);
      final orderFinal = await invoices.finalize(companyId: company.id, id: orderDraft.id);

      // Jede Dokumentart ist die jeweils erste ihrer Art -> alle "001",
      // nur mit unterschiedlichem Präfix — das belegt getrennte Kreise.
      expect(invoiceFinal!.invoiceNumber, 'R-$yy' '001');
      expect(quoteFinal!.invoiceNumber, 'An-$yy' '001');
      expect(orderFinal!.invoiceNumber, 'A-$yy' '001');

      // Eine zweite Rechnung bekommt 002, Angebot/Auftrag bleiben bei 001
      // unberührt (kein gemeinsamer Zähler).
      final secondInvoiceDraft =
          await draftWithOneItem(company.id, customer.id, kind: DocumentKind.invoice);
      final secondInvoiceFinal =
          await invoices.finalize(companyId: company.id, id: secondInvoiceDraft.id);
      expect(secondInvoiceFinal!.invoiceNumber, 'R-$yy' '002');
    },
  );

  test(
    'listAllForCompany()/listDraftsForCompany() filtern nach Dokumentart — Angebote '
    'erscheinen nie in der Rechnungsliste und umgekehrt',
    () async {
      final company = await companies.create(name: 'Firma A');
      final customer = await customers.create(companyId: company.id, name: 'Kunde');

      await draftWithOneItem(company.id, customer.id, kind: DocumentKind.invoice);
      await draftWithOneItem(company.id, customer.id, kind: DocumentKind.quote);
      await draftWithOneItem(company.id, customer.id, kind: DocumentKind.quote);
      await draftWithOneItem(company.id, customer.id, kind: DocumentKind.order);

      final invoiceList = await invoices.listAllForCompany(company.id);
      final quoteList = await invoices.listAllForCompany(company.id, kind: DocumentKind.quote);
      final orderList = await invoices.listAllForCompany(company.id, kind: DocumentKind.order);

      expect(invoiceList, hasLength(1));
      expect(invoiceList.every((i) => i.kind == DocumentKind.invoice), isTrue);
      expect(quoteList, hasLength(2));
      expect(quoteList.every((i) => i.kind == DocumentKind.quote), isTrue);
      expect(orderList, hasLength(1));
      expect(orderList.every((i) => i.kind == DocumentKind.order), isTrue);

      final draftQuotes = await invoices.listDraftsForCompany(company.id, kind: DocumentKind.quote);
      expect(draftQuotes, hasLength(2));
    },
  );

  test(
    'A5-Abnahme: Modul deaktivieren löscht keine vorhandenen Angebots-/Auftragsdaten — '
    'der Schalter steuert nur die Sichtbarkeit, nicht den Datenzugriff',
    () async {
      final company = await companies.create(name: 'Firma A');
      final customer = await customers.create(companyId: company.id, name: 'Kunde');

      await companies.setModules(
        companyId: company.id,
        quotesEnabled: true,
        ordersEnabled: true,
        deliveryNotesEnabled: false,
        proformaEnabled: false,
        projectsEnabled: false,
      );
      final quoteDraft = await draftWithOneItem(company.id, customer.id, kind: DocumentKind.quote);
      await invoices.finalize(companyId: company.id, id: quoteDraft.id);

      // Modul wieder ausschalten ...
      final disabled = await companies.setModules(
        companyId: company.id,
        quotesEnabled: false,
        ordersEnabled: false,
        deliveryNotesEnabled: false,
        proformaEnabled: false,
        projectsEnabled: false,
      );
      expect(disabled.quotesEnabled, isFalse);

      // ... die Daten sind trotzdem weiterhin da (Abnahme A5: "erhält
      // sämtliche Modul-Daten"), nur die UI würde sie ausblenden.
      final quotesStillThere = await invoices.listAllForCompany(company.id, kind: DocumentKind.quote);
      expect(quotesStillThere, hasLength(1));
      expect(quotesStillThere.single.invoiceNumber, isNotNull);
    },
  );

  test('Deaktiviertes Modul blockiert keine Rechnung (Abnahme A5)', () async {
    final company = await companies.create(name: 'Firma A');
    final customer = await customers.create(companyId: company.id, name: 'Kunde');
    // Module bleiben auf Default (aus).
    final draft = await draftWithOneItem(company.id, customer.id, kind: DocumentKind.invoice);
    final finalized = await invoices.finalize(companyId: company.id, id: draft.id);
    expect(finalized!.status, InvoiceStatus.finalized);
  });

  test('Neu angelegte Firma hat Angebot/Auftrag standardmäßig deaktiviert', () async {
    final company = await companies.create(name: 'Firma A');
    expect(company.quotesEnabled, isFalse);
    expect(company.ordersEnabled, isFalse);
  });
}
