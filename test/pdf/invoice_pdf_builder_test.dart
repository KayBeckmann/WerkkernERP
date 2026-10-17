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

  Invoice draftInvoice({String? invoiceNumber, DocumentKind kind = DocumentKind.invoice}) => Invoice(
        id: 'inv-1',
        companyId: 'company-1',
        customerId: 'customer-1',
        kind: kind,
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
        convertedFromId: null,
      );

  Company testCompany({String? pdfIntroText, String? pdfClosingText, String? pdfFooterText}) => Company(
        id: 'company-1',
        name: 'Elektro Beckmann',
        address: 'Musterstraße 1, 23966 Wismar',
        taxNumber: '123/456/78901',
        vatId: null,
        iban: 'DE12 3456 7890 1234 5678 90',
        email: null,
        phone: null,
        createdAt: DateTime.now(),
        quotesEnabled: false,
        ordersEnabled: false,
        deliveryNotesEnabled: false,
        proformaEnabled: false,
        pdfIntroText: pdfIntroText,
        pdfClosingText: pdfClosingText,
        pdfFooterText: pdfFooterText,
      );

  InvoiceItem item({
    required String description,
    String quantity = '1',
    int price = 10000,
    String? unit,
    double discountPercent = 0,
  }) =>
      InvoiceItem(
        id: 'item-1',
        invoiceId: 'inv-1',
        kind: InvoiceItemKind.text,
        articleId: null,
        description: description,
        quantity: quantity,
        unitPriceCents: price,
        vatRatePercent: 19,
        unit: unit,
        discountPercent: discountPercent,
        groupLabel: null,
        sortOrder: 0,
      );

  test('A3-Abnahme: PDF kann nur für eine finalisierte Rechnung erzeugt werden', () {
    expect(
      () => buildInvoicePdf(
        invoice: draftInvoice(),
        items: [item(description: 'Test')],
        company: testCompany(),
      ),
      throwsStateError,
    );
  });

  test('PDF wird für eine finalisierte Rechnung erzeugt (gültige Struktur)', () async {
    final invoice = draftInvoice(invoiceNumber: 'R-26001');
    final bytes = await buildInvoicePdf(
      invoice: invoice,
      items: [item(description: 'Montagearbeiten')],
      company: testCompany(),
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
      company: testCompany(),
    );
    expect(utf8.decode(bytes.sublist(0, 5), allowMalformed: true), '%PDF-');
  });

  test(
    'Kay-Nachtrag 2026-10-16: buildDraftPreviewPdf() funktioniert gerade für einen NICHT '
    'finalisierten Entwurf (kein Fehler, kein echte Nummer)',
    () async {
      final draft = draftInvoice(); // kein invoiceNumber -> Status draft
      final bytes = await buildDraftPreviewPdf(
        invoice: draft,
        items: [item(description: 'Noch nicht gespeicherte Position')],
        company: testCompany(),
      );
      expect(utf8.decode(bytes.sublist(0, 5), allowMalformed: true), '%PDF-');
      expect(bytes.length, greaterThan(1000));
    },
  );

  test(
    'Kay-Nachtrag 2026-10-16: Einleitungs-, Schluss- und Fußzeilentext der Firma werden ohne '
    'Fehler ins PDF übernommen',
    () async {
      final invoice = draftInvoice(invoiceNumber: 'R-26003');
      final bytes = await buildInvoicePdf(
        invoice: invoice,
        items: [item(description: 'Testposition')],
        company: testCompany(
          pdfIntroText: 'Vielen Dank für Ihren Auftrag.',
          pdfClosingText: 'Es gelten unsere AGB, einsehbar unter example.test/agb.',
          pdfFooterText: 'Elektro Beckmann — Musterstraße 1 — 23966 Wismar',
        ),
      );
      expect(utf8.decode(bytes.sublist(0, 5), allowMalformed: true), '%PDF-');
      expect(bytes.length, greaterThan(1000));
    },
  );

  for (final kind in [DocumentKind.quote, DocumentKind.order]) {
    test(
      'A5-Abnahme: ${kind.name}-PDF wird ohne Fehler erzeugt (gleiches Layout wie Rechnung)',
      () async {
        final invoice = draftInvoice(invoiceNumber: 'An-26001', kind: kind);
        final bytes = await buildInvoicePdf(
          invoice: invoice,
          items: [item(description: 'Testposition')],
          company: testCompany(),
        );
        expect(utf8.decode(bytes.sublist(0, 5), allowMalformed: true), '%PDF-');
        expect(bytes.length, greaterThan(1000));
      },
    );
  }

  test(
    'Kay-Nachtrag 2026-10-16: Lieferschein-PDF wird ohne Fehler erzeugt, auch mit mehreren '
    'Positionen/Gruppen (Preise/Summen werden intern weggelassen, hier nur auf Fehlerfreiheit '
    'geprüft — Sichtprüfung des Layouts bleibt Teil der manuellen Prüfstrategie)',
    () async {
      final invoice = draftInvoice(invoiceNumber: 'LS-26001', kind: DocumentKind.deliveryNote);
      final bytes = await buildInvoicePdf(
        invoice: invoice,
        items: [
          item(description: 'Kabel NYM-J 3x1,5', quantity: '50', price: 150),
          item(description: 'Steckdose', quantity: '4', price: 850),
        ],
        company: testCompany(),
      );
      expect(utf8.decode(bytes.sublist(0, 5), allowMalformed: true), '%PDF-');
      expect(bytes.length, greaterThan(1000));
    },
  );

  test(
    'C10: Proforma-PDF wird ohne Fehler erzeugt, inklusive Stunden-Position (anders als '
    'Lieferschein) und mit vollständigen Preisen/Summen wie eine Rechnung',
    () async {
      final invoice = draftInvoice(invoiceNumber: 'PF-26001', kind: DocumentKind.proforma);
      final bytes = await buildInvoicePdf(
        invoice: invoice,
        items: [
          item(description: 'Anzahlung Material'),
          item(description: 'Vorbereitung', quantity: '2', unit: 'h'),
        ],
        company: testCompany(),
      );
      expect(utf8.decode(bytes.sublist(0, 5), allowMalformed: true), '%PDF-');
      expect(bytes.length, greaterThan(1000));
    },
  );
}
