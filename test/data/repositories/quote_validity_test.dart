import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:werkkernerp/data/database/database.dart';
import 'package:werkkernerp/data/database/tables.dart';
import 'package:werkkernerp/data/repositories/company_repository.dart';
import 'package:werkkernerp/data/repositories/customer_repository.dart';
import 'package:werkkernerp/data/repositories/invoice_repository.dart';
import 'package:werkkernerp/data/repositories/number_sequence_repository.dart';
import 'package:decimal/decimal.dart';
import 'package:werkkernerp/pdf/invoice_pdf_builder.dart';

/// A5-Nachtrag (Kay, 16.11.2026): Angebotsbindefrist — Firmenstandard,
/// Entwurfswert gewinnt, Frist ab Finalisierung, Firmenänderung lässt
/// alte Angebote unverändert, Anpassung nur ausdrücklich.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  late Company company;
  late InvoiceRepository invoices;
  late String customerId;
  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory(setup: (d) => d.execute('PRAGMA foreign_keys = ON;')));
    final companies = CompanyRepository(db);
    company = await companies.create(name: 'Nord-Impuls');
    await companies.update(company.copyWith(quotesEnabled: true, ordersEnabled: true));
    company = (await companies.findById(company.id))!;
    invoices = InvoiceRepository(db, NumberSequenceRepository(db));
    customerId = (await CustomerRepository(db).create(companyId: company.id, name: 'REMONDIS')).id;
  });
  tearDown(() => db.close());

  Future<Invoice> quote({Value<int?> days = const Value.absent(), DocumentKind kind = DocumentKind.quote}) =>
      invoices.createDraft(
        companyId: company.id,
        customerId: customerId,
        kind: kind,
        issueDate: DateTime(2026, 11, 1),
        serviceDate: DateTime(2026, 11, 1),
        quoteValidityDays: days,
        items: [
          InvoiceItemInput(kind: InvoiceItemKind.text, description: 'Montage', quantity: Decimal.one, unitPriceCents: 10000, vatRatePercent: 19),
        ],
      );

  DateTime today() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  test('Firmenstandard 14, Entwurfswert gewinnt, Frist ab Finalisierung, Firmenänderung wirkt nicht zurück', () async {
    expect(company.quoteValidityDays, 14);
    final standard = await quote();
    expect(standard.quoteValidityDays, 14);
    final manual = await quote(days: const Value(30));
    expect(manual.quoteValidityDays, 30);
    // Auftrag bekommt keine Bindefrist.
    expect((await quote(kind: DocumentKind.order)).quoteValidityDays, isNull);
    // Im Entwurf änderbar.
    final changed = (await invoices.update(companyId: company.id, id: standard.id, quoteValidityDays: const Value(21)))!;
    expect(changed.quoteValidityDays, 21);
    expect(changed.quoteValidUntil, isNull, reason: 'Enddatum erst beim Finalisieren');

    final finalized = (await invoices.finalize(companyId: company.id, id: changed.id))!;
    expect(finalized.quoteValidFrom, today(), reason: 'ab Finalisierung, nicht ab Belegdatum 01.11.');
    expect(finalized.quoteValidUntil, DateTime(today().year, today().month, today().day + 21));

    await CompanyRepository(db).update(company.copyWith(quoteValidityDays: const Value(60)));
    final reread = (await invoices.findById(companyId: company.id, id: finalized.id))!;
    expect((reread.quoteValidityDays, reread.quoteValidUntil), (21, finalized.quoteValidUntil));
    // Ohne Bindefrist keine Daten.
    final none = await invoices.finalize(companyId: company.id, id: (await quote(days: const Value(null))).id);
    expect((none!.quoteValidFrom, none.quoteValidUntil), (null, null));

    // PDF: Enddatum steht drin, ohne Frist keine Zeile, Entwurf mit Dauer.
    if ((await Process.run('which', ['pdftotext'])).exitCode != 0) return;
    final freshCompany = (await CompanyRepository(db).findById(company.id))!;
    Future<String> text(Invoice i, {bool preview = false}) async {
      final items = await invoices.itemsFor(i.id);
      final bytes = preview
          ? await buildDraftPreviewPdf(invoice: i, items: items, company: freshCompany)
          : await buildInvoicePdf(invoice: i, items: items, company: freshCompany);
      final dir = await Directory.systemTemp.createTemp('werkkern-qv-');
      try {
        final file = File('${dir.path}/a.pdf')..writeAsBytesSync(bytes);
        return (await Process.run('pdftotext', ['-layout', file.path, '-'])).stdout as String;
      } finally {
        await dir.delete(recursive: true);
      }
    }

    final u = reread.quoteValidUntil!;
    final dd = '${u.day.toString().padLeft(2, '0')}.${u.month.toString().padLeft(2, '0')}.${u.year}';
    expect(await text(reread), contains('Dieses Angebot ist gültig bis $dd.'));
    expect(await text(none), isNot(contains('gültig bis')));
    expect(await text(manual, preview: true), contains('Dieses Angebot ist 30 Tage ab Ausstellung gültig.'));
  });

  test('Finalisiertes Angebot: „Nein“ behält die Frist, „Ja“ übernimmt nur das bestätigte Datum', () async {
    final finalized = (await invoices.finalize(companyId: company.id, id: (await quote()).id))!;
    final until = finalized.quoteValidUntil!;
    // „Nein“ = absent; Dauer-Änderung wird nach Finalisierung ignoriert.
    final kept = (await invoices.update(
      companyId: company.id,
      id: finalized.id,
      notes: 'geändert',
      quoteValidityDays: const Value(99),
    ))!;
    expect((kept.quoteValidUntil, kept.quoteValidityDays, kept.notes), (until, 14, 'geändert'));
    // „Ja“ mit neuem Enddatum: Fristbeginn bleibt, Dauer folgt.
    final later = DateTime(until.year, until.month, until.day + 16);
    final extended = (await invoices.update(companyId: company.id, id: finalized.id, quoteValidUntil: Value(later)))!;
    expect((extended.quoteValidFrom, extended.quoteValidUntil, extended.quoteValidityDays), (finalized.quoteValidFrom, later, 30));
    await expectLater(
      invoices.update(companyId: company.id, id: finalized.id, quoteValidUntil: Value(DateTime(2000))),
      throwsArgumentError,
    );
    // Nach Umwandlung gesperrt.
    await invoices.convertTo(companyId: company.id, sourceId: finalized.id, targetKind: DocumentKind.order);
    expect(await invoices.update(companyId: company.id, id: finalized.id, quoteValidUntil: Value(later)), isNull);
  });
}
