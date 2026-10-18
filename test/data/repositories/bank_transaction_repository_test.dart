import 'package:decimal/decimal.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:werkkernerp/data/database/database.dart';
import 'package:werkkernerp/data/database/tables.dart';
import 'package:werkkernerp/data/repositories/bank_transaction_repository.dart';
import 'package:werkkernerp/data/repositories/company_repository.dart';
import 'package:werkkernerp/data/repositories/customer_repository.dart';
import 'package:werkkernerp/data/repositories/invoice_repository.dart';
import 'package:werkkernerp/data/repositories/number_sequence_repository.dart';
import 'package:werkkernerp/domain/services/bank_csv_import_service.dart';

/// C14.4 Bankabgleich (Kay-Priorisierungsentscheidung 2026-10-18).
void main() {
  late AppDatabase db;
  late CompanyRepository companies;
  late BankTransactionRepository transactions;

  setUp(() {
    db = AppDatabase.forTesting(
      NativeDatabase.memory(setup: (rawDb) => rawDb.execute('PRAGMA foreign_keys = ON;')),
    );
    companies = CompanyRepository(db);
    transactions = BankTransactionRepository(db);
  });

  tearDown(() async => db.close());

  ParsedBankTransaction txWith({required int cents, String? purpose}) => ParsedBankTransaction(
        date: DateTime(2026, 10, 15),
        amountCents: cents,
        purpose: purpose,
        counterparty: 'Testkunde',
        importHash: computeBankTransactionHash(
          date: DateTime(2026, 10, 15),
          amountCents: cents,
          purpose: purpose,
          counterparty: 'Testkunde',
        ),
      );

  test('A0-Abnahme: zwei Firmen mit identischen Transaktionen haben keine Vermischung', () async {
    final companyA = await companies.create(name: 'Firma A');
    final companyB = await companies.create(name: 'Firma B');

    await transactions.importParsed(companyId: companyA.id, transactions: [txWith(cents: 100)]);
    await transactions.importParsed(companyId: companyB.id, transactions: [txWith(cents: 100)]);

    expect(await transactions.listForCompany(companyA.id), hasLength(1));
    expect(await transactions.listForCompany(companyB.id), hasLength(1));
  });

  test('importParsed überspringt bereits vorhandene Transaktionen (gleicher importHash)', () async {
    final company = await companies.create(name: 'Firma A');
    final first = await transactions.importParsed(
      companyId: company.id,
      transactions: [txWith(cents: 100), txWith(cents: 200)],
    );
    expect(first.imported, 2);
    expect(first.skippedDuplicates, 0);

    // Erneuter Import derselben zwei Zeilen (z. B. überlappender Export).
    final second = await transactions.importParsed(
      companyId: company.id,
      transactions: [txWith(cents: 100), txWith(cents: 200), txWith(cents: 300)],
    );
    expect(second.imported, 1, reason: 'nur die neue 300er-Zeile ist wirklich neu');
    expect(second.skippedDuplicates, 2);
    expect(await transactions.listForCompany(company.id), hasLength(3));
  });

  test('setMatchedInvoice ordnet zu und entfernt die Zuordnung wieder', () async {
    final company = await companies.create(name: 'Firma A');
    final customer = await CustomerRepository(db).create(companyId: company.id, name: 'Testkunde');
    final invoiceRepo = InvoiceRepository(db, NumberSequenceRepository(db));
    final invoice = await invoiceRepo.createDraft(
      companyId: company.id,
      customerId: customer.id,
      issueDate: DateTime(2026, 10, 1),
      serviceDate: DateTime(2026, 10, 1),
      items: [
        InvoiceItemInput(
          kind: InvoiceItemKind.text,
          description: 'Beratung',
          quantity: Decimal.one,
          unitPriceCents: 10000,
          vatRatePercent: 19,
        ),
      ],
    );

    await transactions.importParsed(companyId: company.id, transactions: [txWith(cents: 100)]);
    final tx = (await transactions.listForCompany(company.id)).single;

    expect(await transactions.listForCompany(company.id, onlyUnmatched: true), hasLength(1));

    await transactions.setMatchedInvoice(companyId: company.id, id: tx.id, invoiceId: invoice.id);
    expect(await transactions.listForCompany(company.id, onlyUnmatched: true), isEmpty);

    await transactions.setMatchedInvoice(companyId: company.id, id: tx.id, invoiceId: null);
    expect(await transactions.listForCompany(company.id, onlyUnmatched: true), hasLength(1));
  });

  test('Fremde Firmen-ID kann keine Transaktion löschen oder zuordnen', () async {
    final companyA = await companies.create(name: 'Firma A');
    final companyB = await companies.create(name: 'Firma B');
    await transactions.importParsed(companyId: companyA.id, transactions: [txWith(cents: 100)]);
    final tx = (await transactions.listForCompany(companyA.id)).single;

    expect(await transactions.delete(companyId: companyB.id, id: tx.id), isFalse);
    expect(
      await transactions.setMatchedInvoice(companyId: companyB.id, id: tx.id, invoiceId: 'x'),
      isFalse,
    );
  });
}
