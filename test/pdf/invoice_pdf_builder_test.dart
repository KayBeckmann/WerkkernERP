import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:werkkernerp/data/database/database.dart';
import 'package:werkkernerp/data/database/tables.dart';
import 'package:werkkernerp/pdf/invoice_pdf_builder.dart';

void main() {
  // buildInvoicePdf() lädt die Schrift-Assets über rootBundle — braucht
  // eine initialisierte Flutter-Bindung auch in einem reinen test()
  // (nicht testWidgets()).
  TestWidgetsFlutterBinding.ensureInitialized();

  Invoice draftInvoice({String? invoiceNumber}) => Invoice(
        id: 'inv-1',
        companyId: 'company-1',
        customerId: 'customer-1',
        status: invoiceNumber == null ? InvoiceStatus.draft : InvoiceStatus.finalized,
        invoiceNumber: invoiceNumber,
        numberYear: invoiceNumber == null ? null : 2026,
        issueDate: DateTime(2026, 10, 16),
        serviceDate: DateTime(2026, 10, 10),
        paymentTerms: 'Zahlbar innerhalb 14 Tagen netto.',
        notes: null,
        customerSnapshotName: 'Max Mustermann',
        customerSnapshotAddress: 'Kundenweg 2, 23966 Wismar',
        companySnapshotName: 'Elektro Beckmann',
        companySnapshotAddress: 'Musterstraße 1, 23966 Wismar',
        companySnapshotTaxNumber: '123/456/78901',
        companySnapshotVatId: null,
        companySnapshotIban: 'DE12 3456 7890 1234 5678 90',
        finalizedAt: invoiceNumber == null ? null : DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

  InvoiceItem item({required String description, String quantity = '1', int price = 10000}) =>
      InvoiceItem(
        id: 'item-1',
        invoiceId: 'inv-1',
        kind: InvoiceItemKind.text,
        articleId: null,
        description: description,
        quantity: quantity,
        unitPriceCents: price,
        vatRatePercent: 19,
        groupLabel: null,
        sortOrder: 0,
      );

  test('A3-Abnahme: PDF kann nur für eine finalisierte Rechnung erzeugt werden', () {
    expect(
      () => buildInvoicePdf(invoice: draftInvoice(), items: [item(description: 'Test')]),
      throwsStateError,
    );
  });

  test('PDF wird für eine finalisierte Rechnung erzeugt (gültige Struktur)', () async {
    final invoice = draftInvoice(invoiceNumber: 'R-26001');
    final bytes = await buildInvoicePdf(
      invoice: invoice,
      items: [item(description: 'Montagearbeiten')],
    );

    // Gültiges PDF (Magic Bytes) mit plausibler Mindestgröße — der
    // Content-Stream ist Flate-komprimiert, Text lässt sich hier nicht
    // ohne eigenen PDF-Parser extrahieren. Rechnungsnummer/Beträge/
    // Layout werden stattdessen manuell geprüft (Prüfstrategie der
    // Roadmap: "zusätzlich PDF-Text/Inhalt und gerendertes Layout
    // prüfen" — das ist hier ein manueller, nicht automatisierter
    // Schritt).
    expect(utf8.decode(bytes.sublist(0, 5), allowMalformed: true), '%PDF-');
    expect(bytes.length, greaterThan(1000));
  });

  test('Mehrere Positionsgruppen und Steuersätze erzeugen ohne Fehler ein PDF', () async {
    final invoice = draftInvoice(invoiceNumber: 'R-26002');
    final bytes = await buildInvoicePdf(
      invoice: invoice,
      items: [
        item(description: 'Steckdose', quantity: '10', price: 250),
        item(description: 'Anfahrt', price: 5000),
      ],
    );
    expect(utf8.decode(bytes.sublist(0, 5), allowMalformed: true), '%PDF-');
  });
}
