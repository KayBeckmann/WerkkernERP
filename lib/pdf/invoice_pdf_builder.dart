import 'dart:typed_data';
import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:werkkern_core/werkkern_core.dart'
    show
        DocumentPaymentTerms,
        quoteValidityText,
        EInvoiceData,
        EInvoiceProfile,
        buildEInvoiceXml,
        eInvoiceProblems,
        facturXAttachmentName,
        paymentTermsText,
        summarizePaymentTerms;

import '../data/database/database.dart';
import '../data/database/tables.dart';
import '../data/repositories/invoice_repository.dart' show AdvancePaymentEntry;
import '../domain/models/money.dart';
import '../domain/services/document_text_resolver.dart';
import '../domain/services/einvoice_builder.dart';
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
Future<Uint8List> buildInvoicePdf({
  required Invoice invoice,
  required List<InvoiceItem> items,
  required Company company,
  PdfLayout layout = PdfLayout.classic,
  // C13 Abschlagsrechnungen, aufgeschlüsselt seit Nachtrag 2026-10-21
  // ("Diese müssen aufgeschlüsselt werden und die Rechnungsnummern der
  // Teilzahlungen müssen aufgelistet werden") — eine Zeile je
  // finalisierter Abschlagsrechnung zum selben Quelldokument (siehe
  // `InvoiceRepository.listAdvancePaymentsForOrder`), leer = keine
  // Abzugszeile. Arbeitsvorgabe statt Rechtsprüfung: jeder Betrag
  // enthält die volle USt der jeweiligen Abschlagsrechnung.
  List<AdvancePaymentEntry> priorAdvancePayments = const [],
  // Gutschriften (Kay-Entscheidung 2026-10-19): Nummer der Rechnung, auf
  // die sich eine Gutschrift bezieht — `null` bei allen übrigen
  // Dokumentarten. Reiner Anzeigetext, keine eigene Berechnung.
  String? referencedDocumentNumber,
  // C15 E-Rechnung: Datum der korrigierten Rechnung (BT-26) und der Kunde
  // als Fallback für Dokumente ohne Parteien-Schnappschuss (vor v36).
  DateTime? referencedDocumentDate,
  Customer? customer,
}) async {
  if (invoice.status != InvoiceStatus.finalized || invoice.invoiceNumber == null) {
    throw StateError('PDF kann nur für eine finalisierte Rechnung erzeugt werden.');
  }
  return _buildPdf(
    invoice: invoice,
    items: items,
    company: company,
    isPreview: false,
    layout: layout,
    priorAdvancePayments: priorAdvancePayments,
    referencedDocumentNumber: referencedDocumentNumber,
    referencedDocumentDate: referencedDocumentDate,
    customer: customer,
  );
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
Future<Uint8List> buildDraftPreviewPdf({
  required Invoice invoice,
  required List<InvoiceItem> items,
  required Company company,
  PdfLayout layout = PdfLayout.classic,
  List<AdvancePaymentEntry> priorAdvancePayments = const [],
}) {
  return _buildPdf(
    invoice: invoice,
    items: items,
    company: company,
    isPreview: true,
    layout: layout,
    priorAdvancePayments: priorAdvancePayments,
  );
}

/// Neutrales Eingabemodell des PDF-Generators — entkoppelt das Layout
/// von den Drift-Zeilen, damit Offline-Dokumente und Online-Dokumente
/// (Phase B, `buildOnlineDocumentPdf`) exakt dasselbe PDF erzeugen.
/// Feldnamen bewusst wie in [Invoice], damit das Layout unverändert
/// bleibt.
class PdfDocumentData {
  const PdfDocumentData({
    required this.kind,
    this.isAdvancePayment = false,
    this.invoiceNumber,
    required this.issueDate,
    required this.serviceDate,
    this.companySnapshotName,
    this.companySnapshotAddress,
    this.companySnapshotTaxNumber,
    this.companySnapshotVatId,
    this.companySnapshotIban,
    this.pdfLogoBase64,
    this.customerSnapshotName,
    this.customerSnapshotAddress,
    this.customerSnapshotVatId,
    this.paymentTerms,
    this.notes,
    this.introText,
    this.closingText,
    this.footerText,
    this.footerColumns,
    this.isSmallBusinessExempt = false,
    required this.lines,
    this.eInvoice,
    this.terms,
    this.quoteValidity,
  });

  final DocumentKind kind;
  final bool isAdvancePayment;
  final String? invoiceNumber;
  final DateTime issueDate;
  final DateTime serviceDate;
  final String? companySnapshotName;
  final String? companySnapshotAddress;
  final String? companySnapshotTaxNumber;
  final String? companySnapshotVatId;
  final String? companySnapshotIban;
  final String? pdfLogoBase64;
  final String? customerSnapshotName;
  final String? customerSnapshotAddress;
  final String? customerSnapshotVatId;
  final String? paymentTerms;
  final String? notes;
  final String? introText;
  final String? closingText;
  final String? footerText;
  /// Null means historical/legacy footer. A present map replaces the
  /// structured Nord footer, including when all three columns are empty.
  final Map<String, String?>? footerColumns;
  final bool isSmallBusinessExempt;
  final List<PdfLine> lines;

  /// C15 E-Rechnung: liegt hier eine vollständige [EInvoiceData] (Modul
  /// aktiv, Rechnung/Gutschrift, finalisiert), wird das PDF als
  /// ZUGFeRD-Hybrid (PDF/A-3b mit `factur-x.xml`) erzeugt. Entwürfe und
  /// unvollständige Daten ergeben weiterhin ein reines PDF.
  final EInvoiceData? eInvoice;

  /// A2-Nachtrag: Zahlungsbedingung mit optionalem Skonto (Schnappschuss
  /// am Beleg) — ergibt den Zahlungstext über dem Freitext.
  final DocumentPaymentTerms? terms;

  /// A5-Nachtrag: Bindefrist-Satz eines Angebots (siehe
  /// `quoteValidityText`), `null` = keine Zeile.
  final String? quoteValidity;
}

/// Zahlungsbedingung eines Offline-Belegs (`null` ohne Auswahl oder bei
/// Gutschriften/Lieferscheinen).
DocumentPaymentTerms? documentTermsOf(Invoice invoice) =>
    invoice.paymentTermLabel == null || invoice.paymentNetDays == null || invoice.kind == DocumentKind.creditNote
        ? null
        : DocumentPaymentTerms(
            label: invoice.paymentTermLabel!,
            netDays: invoice.paymentNetDays!,
            skontoPercent: invoice.skontoPercent,
            skontoDays: invoice.skontoDays,
          );

/// Ob [renderDocumentPdf] für [data] eine XML einbettet (für die
/// Anzeige „E-Rechnung“ und die Dateinamen in der Bedienoberfläche).
bool pdfEmbedsEInvoice(PdfDocumentData data, {required bool isPreview}) {
  final e = data.eInvoice;
  return e != null && !isPreview && eInvoiceProblems(e).isEmpty;
}

/// Eine Position im PDF (Feldnamen wie [InvoiceItem]).
class PdfLine {
  const PdfLine({
    required this.description,
    required this.quantity,
    this.unit,
    required this.unitPriceCents,
    required this.vatRatePercent,
    this.discountPercent = 0,
    this.groupLabel,
  });

  factory PdfLine.fromItem(InvoiceItem item) => PdfLine(
        description: item.description,
        quantity: item.quantity,
        unit: item.unit,
        unitPriceCents: item.unitPriceCents,
        vatRatePercent: item.vatRatePercent,
        discountPercent: item.discountPercent,
        groupLabel: item.groupLabel,
      );

  final String description;
  final String quantity;
  final String? unit;
  final int unitPriceCents;
  final double vatRatePercent;
  final double discountPercent;
  final String? groupLabel;
}

Future<Uint8List> _buildPdf({
  required Invoice invoice,
  required List<InvoiceItem> items,
  required Company company,
  required bool isPreview,
  PdfLayout layout = PdfLayout.classic,
  List<AdvancePaymentEntry> priorAdvancePayments = const [],
  String? referencedDocumentNumber,
  DateTime? referencedDocumentDate,
  Customer? customer,
}) {
  // Audit-Befund 2026-10-17 (Abweichungen.md Abschnitt 2.1): Für ein
  // bereits finalisiertes Dokument wird NIE aus den aktuellen (live)
  // Firmeneinstellungen gelesen — nur aus dem beim Finalisieren
  // eingefrorenen Schnappschuss. Sonst könnte ein später geänderter
  // Text beim erneuten Teilen eine andere PDF-Fassung derselben
  // Rechnung erzeugen. Eine Vorschau (noch kein Schnappschuss
  // vorhanden) liest weiterhin live, wie bisher.
  return renderDocumentPdf(
    PdfDocumentData(
      kind: invoice.kind,
      isAdvancePayment: invoice.isAdvancePayment,
      invoiceNumber: invoice.invoiceNumber,
      issueDate: invoice.issueDate,
      serviceDate: invoice.serviceDate,
      companySnapshotName: invoice.companySnapshotName,
      companySnapshotAddress: invoice.companySnapshotAddress,
      companySnapshotTaxNumber: invoice.companySnapshotTaxNumber,
      companySnapshotVatId: invoice.companySnapshotVatId,
      companySnapshotIban: invoice.companySnapshotIban,
      customerSnapshotName: invoice.customerSnapshotName,
      customerSnapshotAddress: invoice.customerSnapshotAddress,
      customerSnapshotVatId: invoice.customerSnapshotVatId,
      paymentTerms: invoice.paymentTerms,
      notes: invoice.notes,
      introText: isPreview ? introTextFor(company, invoice.kind) : invoice.pdfIntroTextSnapshot,
      closingText: isPreview ? closingTextFor(company, invoice.kind) : invoice.pdfClosingTextSnapshot,
      footerText: isPreview ? company.pdfFooterText : invoice.pdfFooterTextSnapshot,
      isSmallBusinessExempt: company.isSmallBusinessExempt,
      lines: [for (final item in items) PdfLine.fromItem(item)],
      terms: documentTermsOf(invoice),
      quoteValidity: invoice.kind == DocumentKind.quote
          ? quoteValidityText(days: invoice.quoteValidityDays, validUntil: invoice.quoteValidUntil)
          : null,
      // C15: nur finalisierte Rechnungen/Gutschriften werden Hybrid-PDF.
      eInvoice: isPreview
          ? null
          : eInvoiceDataForInvoice(
              invoice: invoice,
              items: items,
              company: company,
              customer: customer,
              priorAdvancePayments: priorAdvancePayments,
              referencedInvoiceNumber: referencedDocumentNumber,
              referencedInvoiceDate: referencedDocumentDate,
            ),
    ),
    isPreview: isPreview,
    layout: layout,
    priorAdvancePayments: priorAdvancePayments,
    referencedDocumentNumber: referencedDocumentNumber,
  );
}

/// Rendert [data] — gemeinsamer Kern für Offline- und Online-Dokumente.
/// Explicit opt-in: legacy documents keep their historical renderer.
enum PdfLayout { classic, nordLetterhead }

Future<Uint8List> renderDocumentPdf(
  PdfDocumentData data, {
  required bool isPreview,
  PdfLayout layout = PdfLayout.classic,
  List<AdvancePaymentEntry> priorAdvancePayments = const [],
  String? referencedDocumentNumber,
}) async {
  final invoice = data;
  final logo = data.pdfLogoBase64 == null ? null : pw.MemoryImage(base64Decode(data.pdfLogoBase64!));
  final items = data.lines;
  // Ein §19-Beleg darf vorhandene steuerpflichtige Positionen nicht als Bruttopreise tarnen.
  if (data.isSmallBusinessExempt &&
      data.kind != DocumentKind.deliveryNote &&
      items.any((item) => item.vatRatePercent != 0)) {
    throw StateError('Kleinunternehmerbeleg enthält einen Umsatzsteuersatz; Positionen prüfen.');
  }
  final totals = calculateInvoiceTotals([
    for (final item in items)
      InvoiceLineInput(
        quantity: Decimal.parse(item.quantity),
        unitPriceCents: item.unitPriceCents,
        vatRatePercent: item.vatRatePercent,
        discountPercent: item.discountPercent,
      ),
  ]);

  // Consecutive chapters stay in document order. A repeated chapter label
  // later in the document starts a new chapter rather than moving its lines.
  final chapters = <({String? label, List<PdfLine> lines})>[];
  for (final item in items) {
    if (chapters.isEmpty || chapters.last.label != item.groupLabel) {
      chapters.add((label: item.groupLabel, lines: [item]));
    } else {
      chapters.last.lines.add(item);
    }
  }
  // Preserve the previous rendering order for tenants that have not opted
  // into the letterhead. Only the new chapter layout follows item order.
  if (layout == PdfLayout.classic) {
    final oldGroups = <String?, List<PdfLine>>{};
    for (final item in items) {
      oldGroups.putIfAbsent(item.groupLabel, () => []).add(item);
    }
    final keys = oldGroups.keys.toList()..sort((a, b) {
      if (a == null) return 1;
      if (b == null) return -1;
      return a.compareTo(b);
    });
    chapters
      ..clear()
      ..addAll([for (final key in keys) (label: key, lines: oldGroups[key]!) ]);
  }

  // Eigene Schrift statt der PDF-Basisschriften (Helvetica & Co.) laden —
  // die haben kein Eurozeichen und keine volle Umlaut-Abdeckung ("Unable
  // to find a font to draw '€'"), was auf einer Rechnung nicht
  // akzeptabel ist. DejaVu Sans deckt beides ab, lizenzrechtlich frei
  // bündelbar (Bitstream-Vera-Lizenz, siehe assets/fonts/LICENSE.dejavu).
  final regularFont = pw.Font.ttf(await rootBundle.load('assets/fonts/DejaVuSans.ttf'));
  final boldFont = pw.Font.ttf(await rootBundle.load('assets/fonts/DejaVuSans-Bold.ttf'));

  final introText = data.introText;
  final closingText = data.closingText;
  final footerText = data.footerText;

  // C15 E-Rechnung: ZUGFeRD-Hybrid = PDF/A-3b (XMP-Metadaten mit
  // Factur-X-Schema, sRGB-Ausgabeprofil, eingebettete Schriften) plus
  // eingebettete `factur-x.xml`. Die XML entsteht VOR dem Dokument, weil
  // die Metadaten im Konstruktor mitgegeben werden.
  final terms = invoice.kind == DocumentKind.deliveryNote ? null : data.terms;
  final advanceGross = priorAdvancePayments.fold<int>(0, (sum, e) => sum + e.amountGross.cents);
  final paymentText = terms == null
      ? null
      : paymentTermsText(
          terms,
          summarizePaymentTerms(
            terms: terms,
            issueDate: invoice.issueDate,
            net: totals.totalNet,
            gross: totals.totalGross,
            payable: Money.fromCents(totals.totalGross.cents - advanceGross),
            smallBusinessExempt: data.isSmallBusinessExempt,
          ),
        );
  final eInvoice = data.eInvoice;
  final embed = pdfEmbedsEInvoice(data, isPreview: isPreview);
  final eInvoiceXml = embed ? buildEInvoiceXml(eInvoice!) : null;
  final title = '${invoice.isAdvancePayment ? 'Abschlagsrechnung' : _title(invoice.kind)} ${invoice.invoiceNumber ?? ''}'.trim();
  final author = invoice.companySnapshotName ?? 'WerkkernERP';
  final doc = pw.Document(
    theme: pw.ThemeData.withFont(base: regularFont, bold: boldFont),
    // Info-Wörterbuch nur beim ZUGFeRD-PDF (PDF/A verlangt es passend zu
    // XMP). Es enthält `/CreationDate` = jetzt — normale PDFs bleiben
    // dadurch wie bisher inhaltsgleich reproduzierbar (Offline-/Online-
    // Vergleich im Umzugstest).
    title: embed ? title : null,
    author: embed ? author : null,
    creator: embed ? 'WerkkernERP' : null,
    producer: embed ? 'WerkkernERP' : null,
    metadata: embed
        ? PdfaRdf(
            title: title,
            author: author,
            creator: 'WerkkernERP',
            producer: 'WerkkernERP',
            subject: title,
            keywords: eInvoice!.profile == EInvoiceProfile.xrechnung ? 'XRechnung, EN 16931' : 'ZUGFeRD, EN 16931',
            invoiceRdf: PdfaFacturxRdf().create(
              filename: facturXAttachmentName,
              namespace: 'urn:factur-x:pdfa:CrossIndustryDocument:invoice:1p0#',
              conformanceLevel: 'EN 16931',
              version: '1.0',
            ),
          ).create()
        : null,
  );
  if (embed) {
    PdfaColorProfile(doc.document, (await rootBundle.load('assets/sRGB2014.icc')).buffer.asUint8List());
    PdfaAttachedFiles(doc.document, [
      PdfaAttachedFile(name: facturXAttachmentName, data: eInvoiceXml!, afRelationship: '/Alternative'),
    ]);
  }
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: layout == PdfLayout.nordLetterhead
          ? pw.EdgeInsets.fromLTRB(40, 34, 40, invoice.footerColumns == null ? 120 : 40)
          : const pw.EdgeInsets.all(32),
      header: (context) => layout == PdfLayout.nordLetterhead
          ? _buildLetterhead(invoice, context.pageNumber == 1, logo: logo,
              isPreview: isPreview, referencedDocumentNumber: referencedDocumentNumber)
          : _buildHeader(invoice, isPreview: isPreview, referencedDocumentNumber: referencedDocumentNumber, logo: logo),
      // Fußzeile (Kay-Nachtrag 2026-10-16: "Fußzeile ... in Dokumenten
      // anpassbar machen") — Firmentext oberhalb, Seitenzahl bleibt
      // immer zusätzlich sichtbar.
      footer: (context) => layout == PdfLayout.nordLetterhead
          ? _buildLetterFooter(invoice, footerText, context.pageNumber, context.pagesCount)
          : invoice.footerColumns != null
          ? _buildConfiguredFooter(invoice, context.pageNumber, context.pagesCount)
          : pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          if (footerText != null) ...[
            pw.Divider(color: PdfColors.grey400),
            pw.Text(
              footerText,
              textAlign: pw.TextAlign.center,
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
            ),
            pw.SizedBox(height: 4),
          ],
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              'Seite ${context.pageNumber} von ${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
            ),
          ),
        ],
      ),
      build: (context) => [
        // Einleitungstext (Kay-Nachtrag 2026-10-16, je Dokumentart seit
        // zweitem Nachtrag) — vor der Positionstabelle, z.B. ein
        // Rechtstext/freundliche Anrede oder bei einem Angebot der
        // Hinweis auf die Bindefrist.
        if (introText != null) ...[
          pw.Text(introText, style: const pw.TextStyle(fontSize: 10)),
          pw.SizedBox(height: 12),
        ],
        pw.SizedBox(height: 16),
        for (final chapter in chapters)
          ..._buildGroup(chapter.label, chapter.lines,
              showPrices: invoice.kind != DocumentKind.deliveryNote,
              isSmallBusinessExempt: data.isSmallBusinessExempt,
              letterhead: layout == PdfLayout.nordLetterhead),
        pw.SizedBox(height: 16),
        if (invoice.kind != DocumentKind.deliveryNote && layout == PdfLayout.nordLetterhead)
          pw.Inseparable(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            _buildTotals(totals,
                isSmallBusinessExempt: data.isSmallBusinessExempt,
                priorAdvancePayments: priorAdvancePayments),
            if (data.isSmallBusinessExempt) ...[
              pw.SizedBox(height: 8),
              pw.Text('Gemäß § 19 Abs. 1 UStG wird keine Umsatzsteuer berechnet.',
                  style: const pw.TextStyle(fontSize: 9)),
            ],
          ])),
        if (invoice.kind != DocumentKind.deliveryNote && layout == PdfLayout.classic)
          _buildTotals(totals,
              isSmallBusinessExempt: data.isSmallBusinessExempt,
              priorAdvancePayments: priorAdvancePayments),
        // Nachtrag 2026-10-18: Kleinunternehmerregelung (§19 UStG) —
        // bewusst ein fester, nicht editierbarer Hinweis statt im frei
        // änderbaren Schlusstext, damit er beim Bearbeiten des
        // Schlusstexts nicht versehentlich verschwindet. Arbeitsvorgabe
        // (F1: keine Rechtsprüfung) — Kay bestätigt mit seinem
        // Steuerberater, dass die Regelung tatsächlich zutrifft.
        if (data.isSmallBusinessExempt && invoice.kind != DocumentKind.deliveryNote &&
            layout == PdfLayout.classic) ...[
          pw.SizedBox(height: 8),
          pw.Text(
            'Gemäß § 19 Abs. 1 UStG wird keine Umsatzsteuer berechnet.',
            style: const pw.TextStyle(fontSize: 9),
          ),
        ],
        // A5-Nachtrag: Bindefrist des Angebots.
        if (data.quoteValidity != null) ...[
          pw.SizedBox(height: 16),
          pw.Text(data.quoteValidity!, style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
        ],
        // A2-Nachtrag: Zahlungsbedingung/Skonto (nicht beim Lieferschein).
        if (paymentText != null) ...[
          pw.SizedBox(height: 16),
          pw.Text(paymentText, style: const pw.TextStyle(fontSize: 10)),
        ],
        if (invoice.paymentTerms != null) ...[
          pw.SizedBox(height: paymentText == null ? 16 : 4),
          pw.Text(invoice.paymentTerms!, style: const pw.TextStyle(fontSize: 10)),
        ],
        if (invoice.notes != null) ...[
          pw.SizedBox(height: 8),
          pw.Text(invoice.notes!, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
        ],
        // Schlusstext (Kay-Nachtrag 2026-10-16, je Dokumentart) — z.B.
        // Dank, Rechtstext, Hinweis auf AGB oder bei einer Rechnung das
        // Zahlungsziel.
        if (closingText != null) ...[
          pw.SizedBox(height: 16),
          pw.Text(closingText, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
        ],
      ],
    ),
  );

  return doc.save();
}

/// Titel je Dokumentart.
String _title(DocumentKind kind) => switch (kind) {
      DocumentKind.invoice => 'Rechnung',
      DocumentKind.quote => 'Angebot',
      DocumentKind.order => 'Auftragsbestätigung',
      DocumentKind.deliveryNote => 'Lieferschein',
      DocumentKind.proforma => 'Proforma-Rechnung',
      DocumentKind.creditNote => 'Gutschrift',
    };

/// "Rechnungsdatum"/"Angebotsdatum"/"Auftragsdatum"/"Lieferscheindatum"
/// — kein einheitliches Kompositum-Muster (Lieferschein nimmt kein
/// Fugen-s), daher eine eigene Funktion statt `'${_title(kind)}sdatum'`.
String _dateLabel(DocumentKind kind) => switch (kind) {
      DocumentKind.order => 'Auftragsdatum',
      DocumentKind.deliveryNote => 'Lieferscheindatum',
      DocumentKind.proforma => 'Datum',
      _ => '${_title(kind)}sdatum',
    };

// All content is derived from the captured document, never a live tenant.
pw.Widget _buildLetterhead(PdfDocumentData data, bool firstPage,
    {required bool isPreview, String? referencedDocumentNumber, pw.MemoryImage? logo}) {
  final title = data.isAdvancePayment ? 'Abschlagsrechnung' : _title(data.kind);
  return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
    if (isPreview) pw.Container(
      width: double.infinity,
      color: PdfColors.red100,
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text('ENTWURF — unverbindliche Vorschau, kein gültiges Dokument',
          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
    ),
    if (data.kind == DocumentKind.proforma) pw.Text(
      'Diese Proforma-Rechnung ist keine Rechnung im umsatzsteuerrechtlichen Sinne '
      'und keine Zahlungsaufforderung mit eigenem, umsatzsteuerlich relevantem Nummernkreis.',
      style: const pw.TextStyle(fontSize: 8)),
    if (logo != null) pw.Align(alignment: pw.Alignment.centerRight,
      child: pw.Container(height: 55, width: 215, alignment: pw.Alignment.centerRight,
        child: pw.Image(logo, fit: pw.BoxFit.contain))),
    if (logo != null) pw.SizedBox(height: 8),
    pw.Align(alignment: pw.Alignment.centerRight,
      child: pw.SizedBox(width: 215, child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
          pw.Text(data.companySnapshotName ?? '', textAlign: pw.TextAlign.right,
              style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
          if (data.companySnapshotAddress?.trim().isNotEmpty ?? false)
            pw.Text(data.companySnapshotAddress!.trim(), textAlign: pw.TextAlign.right,
                style: const pw.TextStyle(fontSize: 9)),
        ],
      )),
    ),
    if (firstPage) ...[
      pw.SizedBox(height: 28),
      pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text(data.customerSnapshotName ?? '', style: const pw.TextStyle(fontSize: 10)),
          if (data.customerSnapshotAddress?.trim().isNotEmpty ?? false)
            pw.Text(data.customerSnapshotAddress!.trim(), style: const pw.TextStyle(fontSize: 10)),
          if (data.customerSnapshotVatId != null)
            pw.Text('USt-IdNr.: ${data.customerSnapshotVatId}', style: const pw.TextStyle(fontSize: 9)),
        ])),
        pw.SizedBox(width: 175, child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
          pw.Text('${_dateLabel(data.kind)}: ${_formatDate(data.issueDate)}', textAlign: pw.TextAlign.right,
              style: const pw.TextStyle(fontSize: 9)),
          pw.Text('Leistungsdatum: ${_formatDate(data.serviceDate)}', textAlign: pw.TextAlign.right,
              style: const pw.TextStyle(fontSize: 9)),
        ])),
      ]),
      pw.SizedBox(height: 25),
      pw.Text(isPreview ? '$title (Entwurf)' : '$title ${data.invoiceNumber ?? ''}',
          style: pw.TextStyle(fontSize: 17, fontWeight: pw.FontWeight.bold)),
      if (referencedDocumentNumber != null)
        pw.Text('Gutschrift zur Rechnung $referencedDocumentNumber', style: const pw.TextStyle(fontSize: 9)),
      pw.SizedBox(height: 14),
    ] else pw.SizedBox(height: 12),
  ]);
}

String interpolateFooter(String template, PdfDocumentData data) {
  final values = {
    'companyName': data.companySnapshotName,
    'address': data.companySnapshotAddress,
    'taxNumber': data.companySnapshotTaxNumber,
    'vatId': data.companySnapshotVatId,
    'iban': data.companySnapshotIban,
    'customerName': data.customerSnapshotName,
    'customerAddress': data.customerSnapshotAddress,
    'documentNumber': data.invoiceNumber,
  };
  // Drop a complete line when all of its dynamic values are missing, so
  // defaults such as "IBAN: {{iban}}" never print an orphan label.
  final token = RegExp(r'\{\{([a-zA-Z]+)\}\}');
  return template.split('\n').where((line) {
    final matches = token.allMatches(line).toList();
    return matches.isEmpty || matches.any((m) =>
        !values.containsKey(m[1]) || (values[m[1]]?.trim().isNotEmpty ?? false));
  }).map((line) => line.replaceAllMapped(token,
      (match) => values.containsKey(match[1]) ? (values[match[1]] ?? '') : match[0]!)).join('\n');
}

bool configuredFooterHasContent(PdfDocumentData data) =>
    data.footerColumns?.values.any((template) =>
        interpolateFooter(template ?? '', data).trim().isNotEmpty) ?? false;

pw.Widget _buildLetterFooter(PdfDocumentData data, String? footerText, int page, int pages) =>
    pw.Column(children: [
      if (data.footerColumns == null || configuredFooterHasContent(data))
        pw.Divider(color: PdfColors.grey400, thickness: 0.4),
      if (data.footerColumns != null)
        _footerRow(data)
      else ...[
      pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Expanded(child: pw.Text([
          data.companySnapshotName, data.companySnapshotAddress,
        ].whereType<String>().where((s) => s.trim().isNotEmpty).join('\n'),
            style: const pw.TextStyle(fontSize: 7))),
        pw.SizedBox(width: 10),
        pw.Expanded(child: pw.Text(data.companySnapshotIban?.trim().isNotEmpty ?? false
            ? 'IBAN: ${data.companySnapshotIban}' : '',
            style: const pw.TextStyle(fontSize: 7))),
        pw.SizedBox(width: 10),
        pw.Expanded(child: pw.Text([
          if (data.companySnapshotTaxNumber?.trim().isNotEmpty ?? false)
            'Steuernummer: ${data.companySnapshotTaxNumber}',
          if (data.companySnapshotVatId?.trim().isNotEmpty ?? false)
            'USt-IdNr.: ${data.companySnapshotVatId}',
        ].join('\n'), style: const pw.TextStyle(fontSize: 7))),
      ]),
      if (footerText?.trim().isNotEmpty ?? false)
        pw.SizedBox(height: 12),
      if (footerText?.trim().isNotEmpty ?? false)
        pw.Text(footerText!, textAlign: pw.TextAlign.center,
            style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700)),
      ],
      pw.SizedBox(height: 4),
      pw.Text('Seite $page von $pages', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
    ]);

pw.Widget _footerRow(PdfDocumentData data) => pw.Row(
  crossAxisAlignment: pw.CrossAxisAlignment.start,
  children: [
    for (final side in ['left', 'center', 'right']) ...[
      if (side != 'left') pw.SizedBox(width: 10),
      pw.Expanded(child: pw.Text(
        interpolateFooter(data.footerColumns![side] ?? '', data),
        textAlign: side == 'left' ? pw.TextAlign.left : side == 'right' ? pw.TextAlign.right : pw.TextAlign.center,
        style: const pw.TextStyle(fontSize: 7),
      )),
    ],
  ],
);

pw.Widget _buildConfiguredFooter(PdfDocumentData data, int page, int pages) => pw.Column(children: [
  if (configuredFooterHasContent(data))
    pw.Divider(color: PdfColors.grey400, thickness: 0.4),
  _footerRow(data),
  pw.SizedBox(height: 4),
  pw.Align(alignment: pw.Alignment.centerRight,
      child: pw.Text('Seite $page von $pages', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600))),
]);

pw.Widget _buildHeader(
  PdfDocumentData invoice, {
  required bool isPreview,
  String? referencedDocumentNumber,
  pw.MemoryImage? logo,
}) {
  // C13 Abschlagsrechnungen: eigener Titel statt "Rechnung", damit sie
  // optisch klar von einer regulären (Schluss-)Rechnung unterscheidbar
  // ist — bleibt trotzdem derselbe DocumentKind/Nummernkreis.
  final title = invoice.isAdvancePayment ? 'Abschlagsrechnung' : _title(invoice.kind);
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      if (logo != null) pw.Container(height: 55, width: 180, alignment: pw.Alignment.centerLeft,
        child: pw.Image(logo, fit: pw.BoxFit.contain)),
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
      // C10 (Kay-Priorisierungsentscheidung 2026-10-17): fester, nicht
      // entfernbarer Rechtshinweis zusätzlich zum normalen editierbaren
      // Einleitungstext — der Hinweis darf nicht versehentlich durch
      // einen frei editierten Text verdrängt werden können (siehe
      // Roadmap-Begründung bei C10). Keine Rechtsprüfung, nur üblicher
      // Marktstandard für Proforma-Dokumente.
      if (invoice.kind == DocumentKind.proforma)
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(vertical: 4),
          margin: const pw.EdgeInsets.only(bottom: 8),
          decoration: const pw.BoxDecoration(color: PdfColors.amber100),
          child: pw.Center(
            child: pw.Text(
              'Diese Proforma-Rechnung ist keine Rechnung im umsatzsteuerrechtlichen Sinne '
              'und keine Zahlungsaufforderung mit eigenem, umsatzsteuerlich relevantem Nummernkreis.',
              textAlign: pw.TextAlign.center,
              style: const pw.TextStyle(color: PdfColors.brown800, fontSize: 8),
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
              pw.Text('${_dateLabel(invoice.kind)}: ${_formatDate(invoice.issueDate)}'),
              pw.Text('Leistungsdatum: ${_formatDate(invoice.serviceDate)}'),
              // Gutschriften (Kay-Entscheidung 2026-10-19): Bezug zur
              // korrigierten Rechnung direkt sichtbar, auf jeder Seite
              // (Teil des wiederholten Seitenkopfs).
              if (referencedDocumentNumber != null)
                pw.Text(
                  'Gutschrift zur Rechnung $referencedDocumentNumber',
                  style: const pw.TextStyle(fontSize: 9),
                ),
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

List<pw.Widget> _buildGroup(String? groupLabel, List<PdfLine> items,
    {required bool showPrices, required bool isSmallBusinessExempt, bool letterhead = false}) {
  return [
    if (groupLabel != null)
      pw.Padding(
        padding: const pw.EdgeInsets.only(top: 8, bottom: 4),
        child: pw.Text(groupLabel, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
      ),
    pw.Table(
      border: null,
      // Lieferschein (Kay-Nachtrag 2026-10-16) zeigt bewusst keine
      // Preise/Steuersätze — nur Beschreibung und Menge, wie bei einem
      // Lieferschein üblich (Kunde bekommt keinen Preis auf dem Beleg,
      // mit dem die Ware/Leistung übergeben wird).
      columnWidths: showPrices && isSmallBusinessExempt
          ? const {
              0: pw.FlexColumnWidth(4),
              1: pw.FlexColumnWidth(1.2),
              2: pw.FlexColumnWidth(1.5),
              3: pw.FlexColumnWidth(1.5),
            }
          : showPrices
          ? const {
              0: pw.FlexColumnWidth(4),
              1: pw.FlexColumnWidth(1.2),
              2: pw.FlexColumnWidth(1.5),
              3: pw.FlexColumnWidth(1),
              4: pw.FlexColumnWidth(1.5),
            }
          : const {0: pw.FlexColumnWidth(5), 1: pw.FlexColumnWidth(1.2)},
      children: [
        pw.TableRow(
          repeat: letterhead,
          decoration: pw.BoxDecoration(
            color: letterhead ? PdfColors.grey200 : null,
            border: pw.Border(
              top: letterhead ? const pw.BorderSide(width: 0.7) : pw.BorderSide.none,
              bottom: const pw.BorderSide(width: 0.5))),
          children: showPrices
              ? [
                  _cell('Beschreibung', bold: true),
                  _cell('Menge', bold: true, alignRight: true),
                  _cell(isSmallBusinessExempt ? 'Bruttopreis' : 'Einzelpreis', bold: true, alignRight: true),
                  if (!isSmallBusinessExempt) _cell('MwSt.', bold: true, alignRight: true),
                  _cell('Gesamt', bold: true, alignRight: true),
                ]
              : [_cell('Beschreibung', bold: true), _cell('Menge', bold: true, alignRight: true)],
        ),
        for (final item in items)
          ..._buildItemRows(item, showPrices: showPrices, isSmallBusinessExempt: isSmallBusinessExempt),
      ],
    ),
    // Gruppensumme (Kay-Nachtrag 2026-10-16) — derselbe Rechenkern wie
    // die Gesamtsumme, nur auf diese Gruppe beschränkt. Entfällt beim
    // Lieferschein zusammen mit den übrigen Preisangaben.
    if (showPrices)
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

/// Eine Positionszeile (+ optionale Rabatt-Detailzeile darunter, analog
/// zu RechnungsFees Darstellung — nur als Layout-Anregung angeschaut,
/// keine Code-/Text-Übernahme). Menge und Einheit werden in einer
/// Zelle zusammengefasst ("10 Stk"), um keine zusätzliche, auf A4 eng
/// werdende Spalte zu brauchen.
List<pw.TableRow> _buildItemRows(PdfLine item,
    {required bool showPrices, required bool isSmallBusinessExempt}) {
  final quantityLabel = item.unit == null ? item.quantity : '${item.quantity} ${item.unit}';
  final grossBeforeDiscount =
      Money.fromCents(item.unitPriceCents).multiplyByQuantity(Decimal.parse(item.quantity));
  final netAfterDiscount = item.discountPercent == 0
      ? grossBeforeDiscount
      : grossBeforeDiscount - grossBeforeDiscount.applyPercent(item.discountPercent);
  final lineGrossWithTax = netAfterDiscount + netAfterDiscount.applyPercent(item.vatRatePercent);

  return [
    pw.TableRow(
      children: showPrices
          ? [
              _cell(item.description),
              _cell(quantityLabel, alignRight: true),
              _cell(Money.fromCents(item.unitPriceCents).toString(), alignRight: true),
              if (!isSmallBusinessExempt) _cell('${item.vatRatePercent.toStringAsFixed(0)} %', alignRight: true),
              _cell(lineGrossWithTax.toString(), alignRight: true),
            ]
          : [_cell(item.description), _cell(quantityLabel, alignRight: true)],
    ),
    // Rabatt-Detailzeile (Kay-Nachtrag 2026-10-16) — nur wenn gesetzt,
    // zeigt Prozentsatz und den tatsächlich abgezogenen Betrag.
    if (showPrices && item.discountPercent > 0)
      pw.TableRow(
        children: [
          pw.Padding(
            padding: const pw.EdgeInsets.only(left: 8, bottom: 3),
            child: pw.Text(
              '${item.discountPercent.toStringAsFixed(0)} % Rabatt',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
            ),
          ),
          pw.Container(),
          pw.Container(),
          if (!isSmallBusinessExempt) pw.Container(),
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 3),
            child: pw.Text(
              '− ${(grossBeforeDiscount + grossBeforeDiscount.applyPercent(item.vatRatePercent) - lineGrossWithTax)}',
              textAlign: pw.TextAlign.right,
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
            ),
          ),
        ],
      ),
  ];
}

Money _groupTotal(List<PdfLine> items) => calculateInvoiceTotals([
      for (final item in items)
        InvoiceLineInput(
          quantity: Decimal.parse(item.quantity),
          unitPriceCents: item.unitPriceCents,
          vatRatePercent: item.vatRatePercent,
          discountPercent: item.discountPercent,
        ),
    ]).totalGross;

pw.Widget _buildTotals(InvoiceTotals totals,
    {required bool isSmallBusinessExempt, List<AdvancePaymentEntry> priorAdvancePayments = const []}) {
  // C13 Abschlagsrechnungen: nur Abzugszeilen zeigen, wenn tatsächlich
  // etwas abzuziehen ist — sonst bleibt das Layout wie bisher.
  final hasAdvancePayments = priorAdvancePayments.isNotEmpty;
  final totalAdvancePaymentsGross =
      priorAdvancePayments.fold<Money>(Money.zero(), (sum, e) => sum + e.amountGross);
  final remaining = hasAdvancePayments ? totals.totalGross - totalAdvancePaymentsGross : null;

  return pw.Align(
    alignment: pw.Alignment.centerRight,
    child: pw.SizedBox(
      width: 260,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          if (!isSmallBusinessExempt) for (final rate in totals.sortedRates)
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
          if (!isSmallBusinessExempt) for (final rate in totals.sortedRates)
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
          if (hasAdvancePayments) ...[
            // Kay-Nachtrag 2026-10-21: "Diese müssen aufgeschlüsselt
            // werden und die Rechnungsnummern der Teilzahlungen müssen
            // aufgelistet werden" — eine Zeile je Abschlagsrechnung
            // statt nur einer Summe ohne Herkunft.
            for (final entry in priorAdvancePayments)
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 2),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Abschlagsrechnung ${entry.invoiceNumber}',
                      style: const pw.TextStyle(fontSize: 9),
                    ),
                    pw.Text('− ${entry.amountGross}', style: const pw.TextStyle(fontSize: 9)),
                  ],
                ),
              ),
            if (priorAdvancePayments.length > 1)
              pw.Padding(
                padding: const pw.EdgeInsets.symmetric(vertical: 2),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Abschlagszahlungen gesamt',
                      style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
                    ),
                    pw.Text(
                      '− $totalAdvancePaymentsGross',
                      style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
                    ),
                  ],
                ),
              ),
            pw.Divider(),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Restbetrag', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.Text(remaining!.toString(), style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              ],
            ),
          ],
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
