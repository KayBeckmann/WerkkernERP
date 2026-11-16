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
import 'package:werkkernerp/data/repositories/payment_term_repository.dart';

/// A2-Nachtrag (Kay, 15./16.11.2026): Abnahme der Zahlungsbedingungen
/// offline — Firmenstandard, Kundenstandard, manuelle Wahl, Skonto,
/// Auftrag → Rechnung, Schnappschuss.
void main() {
  late AppDatabase db;
  late Company company;
  late PaymentTermRepository terms;
  late InvoiceRepository invoices;
  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory(setup: (d) => d.execute('PRAGMA foreign_keys = ON;')));
    company = await CompanyRepository(db).create(name: 'Nord-Impuls');
    terms = PaymentTermRepository(db);
    invoices = InvoiceRepository(db, NumberSequenceRepository(db));
  });
  tearDown(() => db.close());

  Future<Invoice> draft(String customerId, {DocumentKind kind = DocumentKind.invoice, DocumentTermsInput? t}) =>
      invoices.createDraft(
        companyId: company.id,
        customerId: customerId,
        kind: kind,
        issueDate: DateTime(2026, 11, 16),
        serviceDate: DateTime(2026, 11, 16),
        terms: t,
        items: [
          InvoiceItemInput(kind: InvoiceItemKind.text, description: 'Montage', quantity: Decimal.one, unitPriceCents: 10000, vatRatePercent: 19),
        ],
      );

  test('Vorgaben, Firmenstandard, Kundenstandard, manuelle Wahl hat Vorrang', () async {
    final list = await terms.listForCompany(company.id);
    expect([for (final t in list) (t.label, t.netDays, t.isDefault)], [
      ('Sofort netto', 0, false),
      ('7 Tage', 7, false),
      ('14 Tage', 14, true),
      ('30 Tage', 30, false),
    ]);
    final customers = CustomerRepository(db);
    final plain = await customers.create(companyId: company.id, name: 'Ohne Abweichung');
    final own = await customers.create(
      companyId: company.id,
      name: 'Mit eigenem Standard',
      paymentTermId: list.firstWhere((t) => t.netDays == 30).id,
    );

    final a = await draft(plain.id);
    expect((a.paymentTermLabel, a.paymentNetDays, a.dueDate), ('14 Tage', 14, DateTime(2026, 11, 30)));
    final b = await draft(own.id);
    expect((b.paymentTermLabel, b.paymentNetDays), ('30 Tage', 30));
    final manual = await draft(own.id, t: (termId: list.first.id, label: 'Sofort netto', netDays: 0, skontoPercent: null, skontoDays: null));
    expect(manual.paymentTermLabel, 'Sofort netto');
    expect(manual.dueDate, DateTime(2026, 11, 16));

    // Angebote bekommen keine Vorbelegung.
    final quote = await draft(plain.id, kind: DocumentKind.quote);
    expect(quote.paymentTermLabel, isNull);
  });

  test('Skonto: Firmenvorgabe, Kunde „kein“ und „eigen“; ohne Vorgabe kein Skonto', () async {
    final customers = CustomerRepository(db);
    final c = await customers.create(companyId: company.id, name: 'Kunde');
    expect((await draft(c.id)).skontoPercent, isNull, reason: 'ohne Konfiguration kein Abzug');
    await CompanyRepository(db).update(company.copyWith(skontoPercent: const Value(2), skontoDays: const Value(7)));
    final withCompany = await draft(c.id);
    expect((withCompany.skontoPercent, withCompany.skontoDays), (2.0, 7));
    final none = await customers.create(companyId: company.id, name: 'Kein Skonto', skontoMode: 'none');
    expect((await draft(none.id)).skontoPercent, isNull);
    final custom = await customers.create(companyId: company.id, name: 'Eigen', skontoMode: 'custom', skontoPercent: 3, skontoDays: 10);
    final d = await draft(custom.id);
    expect((d.skontoPercent, d.skontoDays), (3.0, 10));
  });

  test('Auftrag → Rechnung übernimmt die Bedingung; Stammdatenänderung lässt finalisierte Belege unverändert', () async {
    await CompanyRepository(db).update(company.copyWith(ordersEnabled: true, skontoPercent: const Value(2), skontoDays: const Value(7)));
    final c = await CustomerRepository(db).create(companyId: company.id, name: 'Kunde');
    final order = await draft(c.id, kind: DocumentKind.order);
    final finalizedOrder = (await invoices.finalize(companyId: company.id, id: order.id))!;
    final invoice = (await invoices.convertTo(companyId: company.id, sourceId: finalizedOrder.id, targetKind: DocumentKind.invoice));
    expect((invoice.paymentTermLabel, invoice.paymentNetDays, invoice.skontoPercent), ('14 Tage', 14, 2.0));
    final finalized = (await invoices.finalize(companyId: company.id, id: invoice.id))!;
    final days = finalized.paymentNetDays!;
    expect(finalized.dueDate, DateTime(finalized.issueDate.year, finalized.issueDate.month, finalized.issueDate.day + days));

    final list = await terms.listForCompany(company.id);
    final fourteen = list.firstWhere((t) => t.netDays == 14);
    await terms.update(companyId: company.id, id: fourteen.id, label: '21 Tage', netDays: 21);
    await CompanyRepository(db).update((await CompanyRepository(db).findById(company.id))!.copyWith(skontoPercent: const Value(5)));
    final reread = (await invoices.findById(companyId: company.id, id: finalized.id))!;
    expect((reread.paymentTermLabel, reread.paymentNetDays, reread.skontoPercent), ('14 Tage', 14, 2.0));
  });

  test('Standard umsetzen, letzte Bedingung bleibt, gelöschte Kundenzuordnung fällt auf Firmenstandard', () async {
    final list = await terms.listForCompany(company.id);
    await terms.setDefault(companyId: company.id, id: list.first.id);
    expect((await terms.defaultFor(company.id))!.label, 'Sofort netto');
    final c = await CustomerRepository(db).create(companyId: company.id, name: 'K', paymentTermId: list.last.id);
    await terms.delete(companyId: company.id, id: list.last.id);
    expect((await CustomerRepository(db).findById(companyId: company.id, id: c.id))!.paymentTermId, isNull);
    expect((await draft(c.id)).paymentTermLabel, 'Sofort netto');
    for (final t in (await terms.listForCompany(company.id)).skip(1)) {
      await terms.delete(companyId: company.id, id: t.id);
    }
    expect(() => terms.delete(companyId: company.id, id: list.first.id), throwsStateError);
  });
}
