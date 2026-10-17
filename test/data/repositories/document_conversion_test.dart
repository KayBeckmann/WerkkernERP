import 'package:decimal/decimal.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:werkkernerp/data/database/database.dart';
import 'package:werkkernerp/data/database/tables.dart';
import 'package:werkkernerp/data/repositories/company_repository.dart';
import 'package:werkkernerp/data/repositories/customer_repository.dart';
import 'package:werkkernerp/data/repositories/invoice_repository.dart';
import 'package:werkkernerp/data/repositories/number_sequence_repository.dart';

/// Kay-Nachtrag 2026-10-16: Lieferschein als neue Dokumentart +
/// Dokumentumwandlung (Angebot→Auftrag/Lieferschein/Rechnung, Auftrag→
/// Lieferschein/Rechnung). Lieferscheine dürfen keine Stunden-
/// Positionen enthalten.
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

  InvoiceItemInput textItem(String description, {int price = 10000}) => InvoiceItemInput(
        kind: InvoiceItemKind.text,
        description: description,
        quantity: Decimal.one,
        unitPriceCents: price,
        vatRatePercent: 19,
      );

  InvoiceItemInput hoursItem(String description) => InvoiceItemInput(
        kind: InvoiceItemKind.hours,
        description: description,
        quantity: Decimal.fromInt(3),
        unitPriceCents: 5000,
        vatRatePercent: 19,
      );

  test('Ein Lieferschein mit Stunden-Position kann nicht angelegt werden', () async {
    final company = await companies.create(name: 'Firma A');
    final customer = await customers.create(companyId: company.id, name: 'Kunde');

    expect(
      () => invoices.createDraft(
        companyId: company.id,
        customerId: customer.id,
        issueDate: DateTime.now(),
        serviceDate: DateTime.now(),
        kind: DocumentKind.deliveryNote,
        items: [hoursItem('Montage')],
      ),
      throwsArgumentError,
    );
  });

  test(
    'Ein Lieferschein-Entwurf kann nicht nachträglich via update() eine Stunden-Position '
    'bekommen',
    () async {
      final company = await companies.create(name: 'Firma A');
      final customer = await customers.create(companyId: company.id, name: 'Kunde');
      final draft = await invoices.createDraft(
        companyId: company.id,
        customerId: customer.id,
        issueDate: DateTime.now(),
        serviceDate: DateTime.now(),
        kind: DocumentKind.deliveryNote,
        items: [textItem('Material')],
      );

      expect(
        () => invoices.update(companyId: company.id, id: draft.id, items: [hoursItem('Montage')]),
        throwsArgumentError,
      );
    },
  );

  test(
    'A5-Abnahme (Lieferschein): eigener Nummernkreis mit Präfix LS, unabhängig von R/An/A',
    () async {
      final company = await companies.create(name: 'Firma A');
      final customer = await customers.create(companyId: company.id, name: 'Kunde');
      final yy = (DateTime.now().year % 100).toString().padLeft(2, '0');

      final draft = await invoices.createDraft(
        companyId: company.id,
        customerId: customer.id,
        issueDate: DateTime.now(),
        serviceDate: DateTime.now(),
        kind: DocumentKind.deliveryNote,
        items: [textItem('Material')],
      );
      final finalized = await invoices.finalize(companyId: company.id, id: draft.id);
      expect(finalized!.invoiceNumber, 'LS-$yy' '001');
    },
  );

  test(
    'convertTo(): finalisiertes Angebot wird zu einem neuen Auftrags-Entwurf mit denselben '
    'Positionen, verknüpft über convertedFromId',
    () async {
      final company = await companies.create(name: 'Firma A');
      final customer = await customers.create(companyId: company.id, name: 'Kunde');
      final quoteDraft = await invoices.createDraft(
        companyId: company.id,
        customerId: customer.id,
        issueDate: DateTime.now(),
        serviceDate: DateTime.now(),
        kind: DocumentKind.quote,
        items: [textItem('Beratung'), textItem('Material')],
      );
      final quoteFinal = await invoices.finalize(companyId: company.id, id: quoteDraft.id);

      final order = await invoices.convertTo(
        companyId: company.id,
        sourceId: quoteFinal!.id,
        targetKind: DocumentKind.order,
      );

      expect(order.kind, DocumentKind.order);
      expect(order.status, InvoiceStatus.draft);
      expect(order.invoiceNumber, isNull);
      expect(order.customerId, customer.id);
      expect(order.convertedFromId, quoteFinal.id);

      final orderItems = await invoices.itemsFor(order.id);
      expect(orderItems.map((i) => i.description), ['Beratung', 'Material']);

      final convertedDocs = await invoices.listConvertedFrom(quoteFinal.id);
      expect(convertedDocs.map((i) => i.id), [order.id]);
    },
  );

  test(
    'convertTo(): Angebot mit Stunden-Position in einen Lieferschein wandelt die '
    'Stunden-Position NICHT mit — "Lieferscheine sollen KEINE Stunden enthalten"',
    () async {
      final company = await companies.create(name: 'Firma A');
      final customer = await customers.create(companyId: company.id, name: 'Kunde');
      final quoteDraft = await invoices.createDraft(
        companyId: company.id,
        customerId: customer.id,
        issueDate: DateTime.now(),
        serviceDate: DateTime.now(),
        kind: DocumentKind.quote,
        items: [textItem('Material'), hoursItem('Montage')],
      );
      final quoteFinal = await invoices.finalize(companyId: company.id, id: quoteDraft.id);

      final deliveryNote = await invoices.convertTo(
        companyId: company.id,
        sourceId: quoteFinal!.id,
        targetKind: DocumentKind.deliveryNote,
      );

      final items = await invoices.itemsFor(deliveryNote.id);
      expect(items.map((i) => i.description), ['Material']);
      expect(items.any((i) => i.kind == InvoiceItemKind.hours), isFalse);
    },
  );

  test('convertTo(): Auftrag kann zu Rechnung oder Lieferschein, aber nicht zu Angebot', () async {
    final company = await companies.create(name: 'Firma A');
    final customer = await customers.create(companyId: company.id, name: 'Kunde');
    final orderDraft = await invoices.createDraft(
      companyId: company.id,
      customerId: customer.id,
      issueDate: DateTime.now(),
      serviceDate: DateTime.now(),
      kind: DocumentKind.order,
      items: [textItem('Material')],
    );
    final orderFinal = await invoices.finalize(companyId: company.id, id: orderDraft.id);

    final invoiceDraft = await invoices.convertTo(
      companyId: company.id,
      sourceId: orderFinal!.id,
      targetKind: DocumentKind.invoice,
    );
    expect(invoiceDraft.kind, DocumentKind.invoice);

    expect(
      () => invoices.convertTo(
        companyId: company.id,
        sourceId: orderFinal.id,
        targetKind: DocumentKind.quote,
      ),
      throwsArgumentError,
    );
  });

  test('convertTo(): eine Rechnung kann nicht umgewandelt werden (Ende der Kette)', () async {
    final company = await companies.create(name: 'Firma A');
    final customer = await customers.create(companyId: company.id, name: 'Kunde');
    final draft = await invoices.createDraft(
      companyId: company.id,
      customerId: customer.id,
      issueDate: DateTime.now(),
      serviceDate: DateTime.now(),
      items: [textItem('Material')],
    );
    final finalized = await invoices.finalize(companyId: company.id, id: draft.id);

    expect(
      () => invoices.convertTo(
        companyId: company.id,
        sourceId: finalized!.id,
        targetKind: DocumentKind.deliveryNote,
      ),
      throwsArgumentError,
    );
  });

  test('convertTo(): ein noch nicht finalisiertes (Entwurf-)Dokument kann nicht umgewandelt werden', () async {
    final company = await companies.create(name: 'Firma A');
    final customer = await customers.create(companyId: company.id, name: 'Kunde');
    final quoteDraft = await invoices.createDraft(
      companyId: company.id,
      customerId: customer.id,
      issueDate: DateTime.now(),
      serviceDate: DateTime.now(),
      kind: DocumentKind.quote,
      items: [textItem('Material')],
    );

    expect(
      () => invoices.convertTo(
        companyId: company.id,
        sourceId: quoteDraft.id,
        targetKind: DocumentKind.order,
      ),
      throwsStateError,
    );
  });

  test(
    'convertTo(): ein Angebot kann sowohl in einen Auftrag ALS AUCH separat in einen '
    'Lieferschein umgewandelt werden — beide zeigen auf dasselbe Quelldokument zurück',
    () async {
      final company = await companies.create(name: 'Firma A');
      final customer = await customers.create(companyId: company.id, name: 'Kunde');
      final quoteDraft = await invoices.createDraft(
        companyId: company.id,
        customerId: customer.id,
        issueDate: DateTime.now(),
        serviceDate: DateTime.now(),
        kind: DocumentKind.quote,
        items: [textItem('Material')],
      );
      final quoteFinal = await invoices.finalize(companyId: company.id, id: quoteDraft.id);

      final order = await invoices.convertTo(
        companyId: company.id,
        sourceId: quoteFinal!.id,
        targetKind: DocumentKind.order,
      );
      final deliveryNote = await invoices.convertTo(
        companyId: company.id,
        sourceId: quoteFinal.id,
        targetKind: DocumentKind.deliveryNote,
      );

      final convertedDocs = await invoices.listConvertedFrom(quoteFinal.id);
      expect(convertedDocs.map((i) => i.id).toSet(), {order.id, deliveryNote.id});
    },
  );

  // C10 Proforma-Rechnungen (Kay-Priorisierungsentscheidung 2026-10-17).

  test(
    'C10-Abnahme: Proforma hat eigenen Nummernkreis mit Präfix PF, unabhängig von R/An/A/LS',
    () async {
      final company = await companies.create(name: 'Firma A');
      final customer = await customers.create(companyId: company.id, name: 'Kunde');
      final yy = (DateTime.now().year % 100).toString().padLeft(2, '0');

      final draft = await invoices.createDraft(
        companyId: company.id,
        customerId: customer.id,
        issueDate: DateTime.now(),
        serviceDate: DateTime.now(),
        kind: DocumentKind.proforma,
        items: [textItem('Anzahlung')],
      );
      final finalized = await invoices.finalize(companyId: company.id, id: draft.id);
      expect(finalized!.invoiceNumber, 'PF-$yy' '001');
    },
  );

  test(
    'C10: anders als der Lieferschein darf eine Proforma-Rechnung Stunden-Positionen '
    'enthalten — sie zeigt vollständige Preise/Steuern wie eine Rechnung',
    () async {
      final company = await companies.create(name: 'Firma A');
      final customer = await customers.create(companyId: company.id, name: 'Kunde');

      final draft = await invoices.createDraft(
        companyId: company.id,
        customerId: customer.id,
        issueDate: DateTime.now(),
        serviceDate: DateTime.now(),
        kind: DocumentKind.proforma,
        items: [textItem('Material'), hoursItem('Montage')],
      );
      expect(draft.id, isNotEmpty);
      final items = await invoices.itemsFor(draft.id);
      expect(items, hasLength(2));
    },
  );

  test(
    'convertTo(): finalisierte Proforma wird zu einem neuen Rechnungs-Entwurf, Stunden-'
    'Positionen bleiben dabei (anders als bei der Umwandlung in einen Lieferschein) erhalten',
    () async {
      final company = await companies.create(name: 'Firma A');
      final customer = await customers.create(companyId: company.id, name: 'Kunde');
      final proformaDraft = await invoices.createDraft(
        companyId: company.id,
        customerId: customer.id,
        issueDate: DateTime.now(),
        serviceDate: DateTime.now(),
        kind: DocumentKind.proforma,
        items: [textItem('Material'), hoursItem('Montage')],
      );
      final proformaFinal = await invoices.finalize(companyId: company.id, id: proformaDraft.id);

      final invoiceDraft = await invoices.convertTo(
        companyId: company.id,
        sourceId: proformaFinal!.id,
        targetKind: DocumentKind.invoice,
      );

      expect(invoiceDraft.kind, DocumentKind.invoice);
      expect(invoiceDraft.status, InvoiceStatus.draft);
      expect(invoiceDraft.convertedFromId, proformaFinal.id);
      final items = await invoices.itemsFor(invoiceDraft.id);
      expect(items.map((i) => i.description).toSet(), {'Material', 'Montage'});
    },
  );

  // Kay-Entscheidung 2026-10-17 (Abweichungen.md Abschnitt 1): finalisierte
  // Angebote/Aufträge/Proforma bleiben editierbar, bis sie umgewandelt
  // wurden — erst danach gesperrt. Rechnung/Lieferschein bleiben wie bisher
  // ab Finalisierung sofort unveränderlich.

  test(
    'isEditable(): ein finalisiertes, noch nicht umgewandeltes Angebot ist weiterhin '
    'editierbar — anders als eine finalisierte Rechnung',
    () async {
      final company = await companies.create(name: 'Firma A');
      final customer = await customers.create(companyId: company.id, name: 'Kunde');
      final quoteDraft = await invoices.createDraft(
        companyId: company.id,
        customerId: customer.id,
        issueDate: DateTime.now(),
        serviceDate: DateTime.now(),
        kind: DocumentKind.quote,
        items: [textItem('Beratung')],
      );
      final quoteFinal = await invoices.finalize(companyId: company.id, id: quoteDraft.id);
      expect(await invoices.isEditable(quoteFinal!), isTrue);

      final updated = await invoices.update(
        companyId: company.id,
        id: quoteFinal.id,
        notes: 'Nachträglich ergänzt',
        items: [textItem('Beratung'), textItem('Zusatzleistung')],
      );
      expect(updated, isNotNull);
      expect(updated!.notes, 'Nachträglich ergänzt');
      expect(updated.invoiceNumber, quoteFinal.invoiceNumber, reason: 'Nummer bleibt unverändert');
      expect(await invoices.itemsFor(quoteFinal.id), hasLength(2));
    },
  );

  test(
    'isEditable(): sobald ein Angebot umgewandelt wurde, ist es über update() nicht mehr '
    'änderbar — die Quelle wird gesperrt',
    () async {
      final company = await companies.create(name: 'Firma A');
      final customer = await customers.create(companyId: company.id, name: 'Kunde');
      final quoteDraft = await invoices.createDraft(
        companyId: company.id,
        customerId: customer.id,
        issueDate: DateTime.now(),
        serviceDate: DateTime.now(),
        kind: DocumentKind.quote,
        items: [textItem('Beratung')],
      );
      final quoteFinal = await invoices.finalize(companyId: company.id, id: quoteDraft.id);
      await invoices.convertTo(
        companyId: company.id,
        sourceId: quoteFinal!.id,
        targetKind: DocumentKind.order,
      );

      expect(await invoices.isEditable(quoteFinal), isFalse);
      final result = await invoices.update(
        companyId: company.id,
        id: quoteFinal.id,
        notes: 'Darf nicht mehr ankommen',
      );
      expect(result, isNull);
    },
  );

  test(
    'isEditable(): eine finalisierte Rechnung und ein finalisierter Lieferschein bleiben '
    'wie bisher sofort unveränderlich (keine Umwandlungs-Quellen)',
    () async {
      final company = await companies.create(name: 'Firma A');
      final customer = await customers.create(companyId: company.id, name: 'Kunde');

      final invoiceDraft = await invoices.createDraft(
        companyId: company.id,
        customerId: customer.id,
        issueDate: DateTime.now(),
        serviceDate: DateTime.now(),
        items: [textItem('Material')],
      );
      final invoiceFinal = await invoices.finalize(companyId: company.id, id: invoiceDraft.id);
      expect(await invoices.isEditable(invoiceFinal!), isFalse);

      final deliveryDraft = await invoices.createDraft(
        companyId: company.id,
        customerId: customer.id,
        issueDate: DateTime.now(),
        serviceDate: DateTime.now(),
        kind: DocumentKind.deliveryNote,
        items: [textItem('Material')],
      );
      final deliveryFinal = await invoices.finalize(companyId: company.id, id: deliveryDraft.id);
      expect(await invoices.isEditable(deliveryFinal!), isFalse);
    },
  );

  test(
    'isEditable(): finalisierte Proforma bleibt editierbar, bis sie in eine Rechnung '
    'umgewandelt wurde',
    () async {
      final company = await companies.create(name: 'Firma A');
      final customer = await customers.create(companyId: company.id, name: 'Kunde');
      final proformaDraft = await invoices.createDraft(
        companyId: company.id,
        customerId: customer.id,
        issueDate: DateTime.now(),
        serviceDate: DateTime.now(),
        kind: DocumentKind.proforma,
        items: [textItem('Anzahlung')],
      );
      final proformaFinal = await invoices.finalize(companyId: company.id, id: proformaDraft.id);
      expect(await invoices.isEditable(proformaFinal!), isTrue);

      await invoices.convertTo(
        companyId: company.id,
        sourceId: proformaFinal.id,
        targetKind: DocumentKind.invoice,
      );
      expect(await invoices.isEditable(proformaFinal), isFalse);
    },
  );

  test('convertTo(): eine Proforma-Rechnung selbst ist kein gültiges Umwandlungsziel', () async {
    final company = await companies.create(name: 'Firma A');
    final customer = await customers.create(companyId: company.id, name: 'Kunde');
    final invoiceDraft = await invoices.createDraft(
      companyId: company.id,
      customerId: customer.id,
      issueDate: DateTime.now(),
      serviceDate: DateTime.now(),
      items: [textItem('Material')],
    );
    final invoiceFinal = await invoices.finalize(companyId: company.id, id: invoiceDraft.id);

    expect(
      () => invoices.convertTo(
        companyId: company.id,
        sourceId: invoiceFinal!.id,
        targetKind: DocumentKind.proforma,
      ),
      throwsArgumentError,
    );
  });

  // C13 Abschlagsrechnungen (Kay-Priorisierungsentscheidung 2026-10-17).

  test(
    'C13: sumAdvancePaymentsForOrder() summiert nur finalisierte Abschlagsrechnungen '
    'desselben Auftrags, keine Entwürfe und keine Schlussrechnung selbst',
    () async {
      final company = await companies.create(name: 'Firma A');
      final customer = await customers.create(companyId: company.id, name: 'Kunde');
      final orderDraft = await invoices.createDraft(
        companyId: company.id,
        customerId: customer.id,
        issueDate: DateTime.now(),
        serviceDate: DateTime.now(),
        kind: DocumentKind.order,
        items: [textItem('Komplettauftrag', price: 100000)],
      );
      final orderFinal = await invoices.finalize(companyId: company.id, id: orderDraft.id);

      // Zwei Abschlagsrechnungen zum selben Auftrag ...
      final advance1Draft = await invoices.convertTo(
        companyId: company.id,
        sourceId: orderFinal!.id,
        targetKind: DocumentKind.invoice,
      );
      await invoices.update(
        companyId: company.id,
        id: advance1Draft.id,
        isAdvancePayment: true,
        items: [textItem('Abschlag 1', price: 30000)],
      );
      final advance1Final = await invoices.finalize(companyId: company.id, id: advance1Draft.id);

      final advance2Draft = await invoices.convertTo(
        companyId: company.id,
        sourceId: orderFinal.id,
        targetKind: DocumentKind.invoice,
      );
      await invoices.update(
        companyId: company.id,
        id: advance2Draft.id,
        isAdvancePayment: true,
        items: [textItem('Abschlag 2', price: 20000)],
      );
      final advance2Final = await invoices.finalize(companyId: company.id, id: advance2Draft.id);
      // Entwurf bleibt unfinalisiert -> darf NICHT mitzählen.
      final advance3Draft = await invoices.convertTo(
        companyId: company.id,
        sourceId: orderFinal.id,
        targetKind: DocumentKind.invoice,
      );
      await invoices.update(
        companyId: company.id,
        id: advance3Draft.id,
        isAdvancePayment: true,
        items: [textItem('Nicht finalisierter Abschlag', price: 99999)],
      );

      final sum = await invoices.sumAdvancePaymentsForOrder(orderFinal.id);
      final advance1Gross = (await invoices.totalsFor(advance1Final!.id)).totalGross;
      final advance2Gross = (await invoices.totalsFor(advance2Final!.id)).totalGross;
      expect(sum, advance1Gross + advance2Gross);
    },
  );

  test(
    'C13: isAdvancePayment bleibt über update() und finalize() hinweg erhalten und ist '
    'standardmäßig aus',
    () async {
      final company = await companies.create(name: 'Firma A');
      final customer = await customers.create(companyId: company.id, name: 'Kunde');
      final defaultDraft = await invoices.createDraft(
        companyId: company.id,
        customerId: customer.id,
        issueDate: DateTime.now(),
        serviceDate: DateTime.now(),
        items: [textItem('Material')],
      );
      expect(defaultDraft.isAdvancePayment, isFalse);

      final advanceDraft = await invoices.createDraft(
        companyId: company.id,
        customerId: customer.id,
        issueDate: DateTime.now(),
        serviceDate: DateTime.now(),
        isAdvancePayment: true,
        items: [textItem('Anzahlung')],
      );
      final finalized = await invoices.finalize(companyId: company.id, id: advanceDraft.id);
      expect(finalized!.isAdvancePayment, isTrue);
    },
  );
}
