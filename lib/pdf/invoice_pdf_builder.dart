import 'dart:typed_data';

import 'package:decimal/decimal.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../data/database/database.dart';
import '../data/database/tables.dart';
import '../domain/models/money.dart';
import '../domain/services/invoice_totals_service.dart';

/// Eigenständig gestaltetes Rechnungs-PDF — an RechnungsFee orientiert
/// (Gliederung: Firmenkopf, Kunde, Positionsgruppen, Steueraufschlüsselung,
/// Summen), aber keine übernommene Vorlage/Assets. Erzeugt das PDF
/// ausschließlich aus der **festgeschriebenen** (finalisierten) Fassung —
/// eine spätere Stammdatenänderung an Firma/Kunde darf dieses PDF nie
/// verändern (A1/F3: Schnappschuss-Felder, nicht die Live-Stammdaten).
///
/// Wirft [StateError], wenn [invoice] nicht finalisiert ist — ein PDF
/// ohne Rechnungsnummer wäre kein gültiger Beleg (A3 Punkt 4: "PDF-Fehler
/// darf nicht als erfolgreich erstelltes PDF erscheinen").
///
/// Funktioniert seit A5 für alle drei Dokumentarten ([DocumentKind]) —
/// Layout/Positionsgruppen/Steueraufschlüsselung sind identisch, nur
/// Titel und Datumsbeschriftung richten sich nach `invoice.kind`.
Future<Uint8List> buildInvoicePdf({required Invoice invoice, required List<InvoiceItem> items}) async {
  if (invoice.status != InvoiceStatus.finalized || invoice.invoiceNumber == null) {
    throw StateError('PDF kann nur für eine finalisierte Rechnung erzeugt werden.');
  }
  return _buildPdf(invoice: invoice, items: items, isPreview: false);
}

/// Unverbindliche In-App-Vorschau eines **noch nicht finalisierten**
/// Entwurfs (Kay-Nachtrag 2026-10-16: "PDF Vorschau, für Dokumente, die
/// noch nicht finalisiert sind — Online/in App Vorschau"). Anders als
/// [buildInvoicePdf] absichtlich **kein** Fehler bei fehlender Nummer —
/// stattdessen deutlich sichtbares "ENTWURF"-Wasserzeichen statt einer
/// Dokumentnummer, damit es nie mit einem echten Beleg verwechselt
/// werden kann (A3 Punkt 4: "PDF-Fehler darf nicht als erfolgreich
/// erstelltes PDF erscheinen" — hier umgekehrt: eine Vorschau darf nie
/// wie ein echtes Dokument aussehen). Die aufrufende Stelle
/// (`InvoiceEditorScreen`) bindet diese Vorschau bewusst **ohne**
/// Teilen-/Druck-Funktion ein, damit kein unfertiges Dokument versendet
/// werden kann — nur die Vorschau für ein bereits finalisiertes
/// Dokument darf geteilt werden.
Future<Uint8List> buildDraftPreviewPdf({required Invoice invoice, required List<InvoiceItem> items}) {
  return _buildPdf(invoice: invoice, items: items, isPreview: true);
}

Future<Uint8List> _buildPdf({
  required Invoice invoice,
  required List<InvoiceItem> items,
  required bool isPreview,
}) async {
  final totals = calculateInvoiceTotals([
    for (final item in items)
      InvoiceLineInput(
        quantity: Decimal.parse(item.quantity),
        unitPriceCents: item.unitPriceCents,
        vatRatePercent: item.vatRatePercent,
      ),
  ]);

  final groups = <String?, List<InvoiceItem>>{};
  for (final item in items) {
    groups.putIfAbsent(item.groupLabel, () => []).add(item);
  }
  final orderedKeys = groups.keys.toList()
    ..sort((a, b) {
      if (a == null) return 1;
      if (b == null) return -1;
      return a.compareTo(b);
    });

  // Eigene Schrift statt der PDF-Basisschriften (Helvetica & Co.) laden —
  // die haben kein Eurozeichen und keine volle Umlaut-Abdeckung ("Unable
  // to find a font to draw '€'"), was auf einer Rechnung nicht
  // akzeptabel ist. DejaVu Sans deckt beides ab, lizenzrechtlich frei
  // bündelbar (Bitstream-Vera-Lizenz, siehe assets/fonts/LICENSE.dejavu).
  final regularFont = pw.Font.ttf(await rootBundle.load('assets/fonts/DejaVuSans.ttf'));
  final boldFont = pw.Font.ttf(await rootBundle.load('assets/fonts/DejaVuSans-Bold.ttf'));

  final doc = pw.Document(theme: pw.ThemeData.withFont(base: regularFont, bold: boldFont));
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      header: (context) => _buildHeader(invoice, isPreview: isPreview),
      footer: (context) => pw.Align(
        alignment: pw.Alignment.centerRight,
        child: pw.Text(
          'Seite ${context.pageNumber} von ${context.pagesCount}',
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
        ),
      ),
      build: (context) => [
        pw.SizedBox(height: 16),
        for (final key in orderedKeys) ..._buildGroup(key, groups[key]!),
        pw.SizedBox(height: 16),
        _buildTotals(totals),
        if (invoice.paymentTerms != null) ...[
          pw.SizedBox(height: 16),
          pw.Text(invoice.paymentTerms!, style: const pw.TextStyle(fontSize: 10)),
        ],
        if (invoice.notes != null) ...[
          pw.SizedBox(height: 8),
          pw.Text(invoice.notes!, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
        ],
      ],
    ),
  );

  return doc.save();
}

/// Titel je Dokumentart (A5) — "Rechnungsdatum"/"Angebotsdatum"/
/// "Auftragsdatum" bilden sich daraus grammatisch korrekt per
/// Kompositum (`'${_title(kind)}sdatum'`).
String _title(DocumentKind kind) => switch (kind) {
      DocumentKind.invoice => 'Rechnung',
      DocumentKind.quote => 'Angebot',
      DocumentKind.order => 'Auftrag',
    };

pw.Widget _buildHeader(Invoice invoice, {required bool isPreview}) {
  final title = _title(invoice.kind);
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      if (isPreview)
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(vertical: 6),
          margin: const pw.EdgeInsets.only(bottom: 8),
          decoration: const pw.BoxDecoration(color: PdfColors.red100),
          child: pw.Center(
            child: pw.Text(
              'ENTWURF — unverbindliche Vorschau, kein gültiges Dokument',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.red900, fontSize: 11),
            ),
          ),
        ),
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                invoice.companySnapshotName ?? '',
                style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
              ),
              if (invoice.companySnapshotAddress != null) pw.Text(invoice.companySnapshotAddress!),
              if (invoice.companySnapshotTaxNumber != null)
                pw.Text('Steuernummer: ${invoice.companySnapshotTaxNumber}'),
              if (invoice.companySnapshotVatId != null)
                pw.Text('USt-IdNr.: ${invoice.companySnapshotVatId}'),
              if (invoice.companySnapshotIban != null) pw.Text('IBAN: ${invoice.companySnapshotIban}'),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Text(
                isPreview ? '$title (Entwurf)' : '$title ${invoice.invoiceNumber}',
                style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
              ),
              pw.Text('${title}sdatum: ${_formatDate(invoice.issueDate)}'),
              pw.Text('Leistungsdatum: ${_formatDate(invoice.serviceDate)}'),
            ],
          ),
        ],
      ),
      pw.SizedBox(height: 16),
      pw.Text(invoice.customerSnapshotName ?? '', style: const pw.TextStyle(fontSize: 11)),
      if (invoice.customerSnapshotAddress != null)
        pw.Text(invoice.customerSnapshotAddress!, style: const pw.TextStyle(fontSize: 11)),
      if (invoice.customerSnapshotVatId != null)
        pw.Text('USt-IdNr.: ${invoice.customerSnapshotVatId}', style: const pw.TextStyle(fontSize: 11)),
      pw.Divider(),
    ],
  );
}

List<pw.Widget> _buildGroup(String? groupLabel, List<InvoiceItem> items) {
  return [
    if (groupLabel != null)
      pw.Padding(
        padding: const pw.EdgeInsets.only(top: 8, bottom: 4),
        child: pw.Text(groupLabel, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
      ),
    pw.Table(
      border: null,
      columnWidths: const {
        0: pw.FlexColumnWidth(4),
        1: pw.FlexColumnWidth(1.2),
        2: pw.FlexColumnWidth(1.5),
        3: pw.FlexColumnWidth(1),
        4: pw.FlexColumnWidth(1.5),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(width: 0.5))),
          children: [
            _cell('Beschreibung', bold: true),
            _cell('Menge', bold: true, alignRight: true),
            _cell('Einzelpreis', bold: true, alignRight: true),
            _cell('MwSt.', bold: true, alignRight: true),
            _cell('Gesamt', bold: true, alignRight: true),
          ],
        ),
        for (final item in items)
          pw.TableRow(
            children: [
              _cell(item.description),
              _cell(item.quantity, alignRight: true),
              _cell(Money.fromCents(item.unitPriceCents).toString(), alignRight: true),
              _cell('${item.vatRatePercent.toStringAsFixed(0)} %', alignRight: true),
              _cell(
                Money.fromCents(item.unitPriceCents)
                    .multiplyByQuantity(Decimal.parse(item.quantity))
                    .toString(),
                alignRight: true,
              ),
            ],
          ),
      ],
    ),
    // Gruppensumme (Kay-Nachtrag 2026-10-16) — derselbe Rechenkern wie
    // die Gesamtsumme, nur auf diese Gruppe beschränkt.
    pw.Align(
      alignment: pw.Alignment.centerRight,
      child: pw.Padding(
        padding: const pw.EdgeInsets.only(top: 2, bottom: 4),
        child: pw.Text(
          'Gruppensumme: ${_groupTotal(items)}',
          style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
        ),
      ),
    ),
  ];
}

Money _groupTotal(List<InvoiceItem> items) => calculateInvoiceTotals([
      for (final item in items)
        InvoiceLineInput(
          quantity: Decimal.parse(item.quantity),
          unitPriceCents: item.unitPriceCents,
          vatRatePercent: item.vatRatePercent,
        ),
    ]).totalGross;

pw.Widget _buildTotals(InvoiceTotals totals) {
  return pw.Align(
    alignment: pw.Alignment.centerRight,
    child: pw.SizedBox(
      width: 260,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          for (final rate in totals.sortedRates)
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 2),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Netto ${rate.toStringAsFixed(0)} %'),
                  pw.Text(totals.netByRate[rate].toString()),
                ],
              ),
            ),
          for (final rate in totals.sortedRates)
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 2),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('MwSt. ${rate.toStringAsFixed(0)} %'),
                  pw.Text(totals.taxByRate[rate].toString()),
                ],
              ),
            ),
          pw.Divider(),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Gesamtbetrag', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.Text(
                totals.totalGross.toString(),
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

pw.Widget _cell(String text, {bool bold = false, bool alignRight = false}) => pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Text(
        text,
        textAlign: alignRight ? pw.TextAlign.right : pw.TextAlign.left,
        style: pw.TextStyle(fontSize: 10, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal),
      ),
    );

String _formatDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
