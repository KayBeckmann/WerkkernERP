import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:werkkernerp/data/database/database.dart';
import 'package:werkkernerp/data/database/tables.dart';
import 'package:werkkernerp/data/repositories/company_repository.dart';
import 'package:werkkernerp/data/repositories/customer_repository.dart';
import 'package:werkkernerp/data/repositories/invoice_repository.dart';
import 'package:werkkernerp/data/repositories/number_sequence_repository.dart';

/// Kontaktpersonen je Kunde (Kay 2026-11-09).
void main() {
  late AppDatabase db;
  late CustomerContactRepository contacts;
  late InvoiceRepository invoices;
  late Company company;
  late Customer musterwerk;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory(setup: (r) => r.execute('PRAGMA foreign_keys = ON;')));
    contacts = CustomerContactRepository(db);
    invoices = InvoiceRepository(db, NumberSequenceRepository(db));
    final companies = CompanyRepository(db);
    company = await companies.create(name: 'Elektro Beckmann');
    await companies.update(company.copyWith(quotesEnabled: true, ordersEnabled: true));
    musterwerk = await CustomerRepository(db).create(
      companyId: company.id,
      name: 'Musterwerk',
      invoiceEmail: 'rechnung@musterwerk.example',
    );
  });
  tearDown(() => db.close());

  ContactInput input(String name, {String? id, String? role}) =>
      (id: id, name: name, role: role, email: null, phone: null);

  test('Ersetzen: IDs bleiben, Reihenfolge folgt der Eingabe, fehlende entfallen', () async {
    final first = await contacts.replaceForCustomer(
      companyId: company.id,
      customerId: musterwerk.id,
      contacts: [input('Max', role: 'Betriebstechniker'), input('Erika', role: 'Buchhaltung')],
    );
    final max = first.first;
    final second = await contacts.replaceForCustomer(
      companyId: company.id,
      customerId: musterwerk.id,
      contacts: [input('Jonas'), input('Max', id: max.id, role: 'Betriebsleiter')],
    );
    expect([for (final c in second) (c.name, c.role)], [('Jonas', null), ('Max', 'Betriebsleiter')]);
    expect(second.last.id, max.id);
    expect((await CustomerRepository(db).findById(companyId: company.id, id: musterwerk.id))!.invoiceEmail,
        'rechnung@musterwerk.example');
  });

  test('Fremde Firma sieht keine Kontaktpersonen, fremde IDs werden nicht übernommen', () async {
    final other = await CompanyRepository(db).create(name: 'Andere Firma');
    final otherCustomer = await CustomerRepository(db).create(companyId: other.id, name: 'Fremdkunde');
    final fremd = (await contacts.replaceForCustomer(
      companyId: other.id,
      customerId: otherCustomer.id,
      contacts: [input('Fremd')],
    )).single;
    final mine = await contacts.replaceForCustomer(
      companyId: company.id,
      customerId: musterwerk.id,
      contacts: [input('Übernahme', id: fremd.id)],
    );
    expect(mine.single.id, isNot(fremd.id));
    expect(await contacts.findById(companyId: company.id, id: fremd.id), isNull);
    expect((await contacts.findById(companyId: other.id, id: fremd.id))!.name, 'Fremd');
  });

  test('Kontaktperson am Dokument: gespeichert, bei Umwandlung übernommen, beim Entfernen gelöst', () async {
    final max = (await contacts.replaceForCustomer(
      companyId: company.id,
      customerId: musterwerk.id,
      contacts: [input('Max')],
    )).single;
    final quote = await invoices.createDraft(
      companyId: company.id,
      customerId: musterwerk.id,
      kind: DocumentKind.quote,
      issueDate: DateTime(2026, 11, 9),
      serviceDate: DateTime(2026, 11, 9),
      contactId: max.id,
      items: [
        InvoiceItemInput(
          kind: InvoiceItemKind.text,
          description: 'Wartung',
          quantity: Decimal.one,
          unitPriceCents: 10000,
          vatRatePercent: 19,
        ),
      ],
    );
    expect(quote.contactId, max.id);
    final cleared = await invoices.update(companyId: company.id, id: quote.id, contactId: const Value(null));
    expect(cleared!.contactId, isNull);
    await invoices.update(companyId: company.id, id: quote.id, contactId: Value(max.id));
    await invoices.finalize(companyId: company.id, id: quote.id);
    final order = await invoices.convertTo(companyId: company.id, sourceId: quote.id, targetKind: DocumentKind.order);
    expect(order.contactId, max.id);

    await contacts.replaceForCustomer(companyId: company.id, customerId: musterwerk.id, contacts: const []);
    expect((await invoices.findById(companyId: company.id, id: order.id))!.contactId, isNull);
    expect((await invoices.findById(companyId: company.id, id: quote.id))!.contactId, isNull);
  });
}
