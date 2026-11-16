import 'dart:convert';
import 'dart:io';

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';
import 'package:werkkern_core/werkkern_core.dart';
import 'package:werkkernerp/data/database/database.dart';
import 'package:werkkernerp/data/database/tables.dart';
import 'package:werkkernerp/data/repositories/company_repository.dart';
import 'package:werkkernerp/data/repositories/customer_repository.dart';
import 'package:werkkernerp/data/repositories/invoice_repository.dart';
import 'package:werkkernerp/data/repositories/number_sequence_repository.dart';
import 'package:werkkernerp/domain/services/einvoice_parties.dart';

/// C15.1 E-Rechnung (Kay 2026-11-15): Schema v35→v36 und der beim
/// Finalisieren eingefrorene Parteien-Schnappschuss.
void main() {
  late Directory dir;
  late String dbPath;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('werkkern-einvoice-');
    dbPath = p.join(dir.path, 'test.sqlite');
  });

  tearDown(() => dir.delete(recursive: true));

  AppDatabase open() =>
      AppDatabase.forTesting(NativeDatabase(File(dbPath), setup: (r) => r.execute('PRAGMA foreign_keys = ON;')));

  test('Migration v35→v36: neue Felder mit Vorgaben, Bestand bleibt, Altdokument ohne Schnappschuss', () async {
    var db = open();
    final company = await CompanyRepository(db).create(name: 'Elektro Beckmann', address: 'Musterstraße 1, 23966 Wismar');
    final customer = await CustomerRepository(db).create(companyId: company.id, name: 'Musterwerk', address: 'Am Markt 1\n23966 Wismar');
    final repo = InvoiceRepository(db, NumberSequenceRepository(db));
    final invoice = await repo.createDraft(
      companyId: company.id,
      customerId: customer.id,
      issueDate: DateTime(2026, 11, 1),
      serviceDate: DateTime(2026, 11, 1),
    );
    await db.close();

    final raw = sqlite3.open(dbPath);
    for (final column in ['street', 'postal_code', 'city', 'country_code', 'bic', 'e_invoice_enabled']) {
      raw.execute('ALTER TABLE companies DROP COLUMN $column;');
    }
    for (final column in ['street', 'postal_code', 'city', 'country_code', 'leitweg_id', 'e_invoice_format']) {
      raw.execute('ALTER TABLE customers DROP COLUMN $column;');
    }
    raw.execute('ALTER TABLE invoices DROP COLUMN e_invoice_snapshot;');
    raw.execute('ALTER TABLE suppliers DROP COLUMN our_customer_number;');
    // v37 -> v38 (A1-Nachtrag: Barcode je Artikel).
    raw.execute('DROP INDEX IF EXISTS articles_company_barcode_idx;');
    raw.execute('ALTER TABLE articles DROP COLUMN barcode;');
    raw.execute('ALTER TABLE purchase_orders DROP COLUMN supplier_snapshot_customer_number;');
    raw.execute('PRAGMA user_version = 35;');
    raw.close();

    db = open();
    try {
      final migratedCompany = (await CompanyRepository(db).findById(company.id))!;
      expect(migratedCompany.countryCode, 'DE');
      expect(migratedCompany.eInvoiceEnabled, isFalse);
      expect(migratedCompany.street, isNull);
      expect(migratedCompany.address, 'Musterstraße 1, 23966 Wismar', reason: 'Freitext bleibt');
      final migratedCustomer = (await CustomerRepository(db).findById(companyId: company.id, id: customer.id))!;
      expect(migratedCustomer.eInvoiceFormat, 'zugferd');
      expect(migratedCustomer.countryCode, 'DE');
      expect(migratedCustomer.leitwegId, isNull);
      final doc = (await InvoiceRepository(db, NumberSequenceRepository(db)).findById(companyId: company.id, id: invoice.id))!;
      expect(doc.eInvoiceSnapshot, isNull);
      expect(decodeEInvoiceSnapshot(doc.eInvoiceSnapshot), isNull);

      // Fallback für Bestandsdaten: Freitext wird zerlegt.
      final seller = sellerPartyFromCompany(migratedCompany);
      expect(seller.address.postalCode, '23966');
      expect(seller.address.street, 'Musterstraße 1');
      final buyer = buyerPartyFromCustomer(migratedCustomer);
      expect(buyer.address.city, 'Wismar');
    } finally {
      await db.close();
    }
  });

  test('Finalisieren friert Verkäufer/Käufer strukturiert ein — nur bei Rechnung/Gutschrift', () async {
    final db = open();
    try {
      final companies = CompanyRepository(db);
      var company = await companies.create(name: 'Elektro Beckmann', address: 'Musterstraße 1, 23966 Wismar', iban: 'DE02120300000000202051', email: 'info@example.org', phone: '03841 1');
      await companies.update(company.copyWith(street: const Value('Musterstraße 1'), postalCode: const Value('23966'), city: const Value('Wismar'), bic: const Value('BYLADEM1001'), eInvoiceEnabled: true, quotesEnabled: true));
      company = (await companies.findById(company.id))!;
      final customers = CustomerRepository(db);
      final customer = await customers.create(
        companyId: company.id,
        name: 'Stadt Wismar',
        address: 'Am Markt 1, 23966 Wismar',
        email: 'post@example.org',
        invoiceEmail: 'rechnung@example.org',
        leitwegId: '04011000-1234512345-06',
        eInvoiceFormat: 'xrechnung',
      );
      final contacts = CustomerContactRepository(db);
      final contact = (await contacts.replaceForCustomer(
        companyId: company.id,
        customerId: customer.id,
        contacts: [(id: null, name: 'Erika Muster', role: 'Buchhaltung', email: 'erika@example.org', phone: null)],
      )).single;
      final repo = InvoiceRepository(db, NumberSequenceRepository(db));
      final draft = await repo.createDraft(
        companyId: company.id,
        customerId: customer.id,
        issueDate: DateTime(2026, 11, 15),
        serviceDate: DateTime(2026, 11, 15),
        contactId: contact.id,
      );
      await repo.update(
        companyId: company.id,
        id: draft.id,
        items: [
          InvoiceItemInput(kind: InvoiceItemKind.text, description: 'Montage', quantity: Decimal.one, unitPriceCents: 10000, vatRatePercent: 19),
        ],
      );
      final finalized = (await repo.finalize(companyId: company.id, id: draft.id))!;
      final snapshot = decodeEInvoiceSnapshot(finalized.eInvoiceSnapshot)!;
      expect(snapshot.format, EInvoiceFormat.xrechnung);
      expect(snapshot.seller.name, 'Elektro Beckmann');
      expect(snapshot.seller.address.postalCode, '23966');
      expect(snapshot.seller.bic, 'BYLADEM1001');
      expect(snapshot.seller.iban, 'DE02120300000000202051');
      expect(snapshot.buyer.leitwegId, '04011000-1234512345-06');
      expect(snapshot.buyer.address.street, 'Am Markt 1', reason: 'aus dem Freitext zerlegt');
      expect(snapshot.buyer.email, 'rechnung@example.org', reason: 'Rechnungs-E-Mail hat Vorrang');
      expect(snapshot.buyer.contactName, 'Erika Muster');
      // Roh-JSON bleibt lesbar (GoBD: nachvollziehbar, nicht nur per Code).
      expect((jsonDecode(finalized.eInvoiceSnapshot!) as Map)['buyer'], isA<Map>());

      // Angebot: keine E-Rechnung, kein Schnappschuss.
      final quote = await repo.createDraft(
        companyId: company.id,
        customerId: customer.id,
        kind: DocumentKind.quote,
        issueDate: DateTime(2026, 11, 15),
        serviceDate: DateTime(2026, 11, 15),
      );
      await repo.update(
        companyId: company.id,
        id: quote.id,
        items: [InvoiceItemInput(kind: InvoiceItemKind.text, description: 'Angebot', quantity: Decimal.one, unitPriceCents: 100, vatRatePercent: 19)],
      );
      final finalizedQuote = (await repo.finalize(companyId: company.id, id: quote.id))!;
      expect(finalizedQuote.eInvoiceSnapshot, isNull);
    } finally {
      await db.close();
    }
  });
}
