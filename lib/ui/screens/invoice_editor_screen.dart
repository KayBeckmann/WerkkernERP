import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../../data/database/database.dart';
import '../../data/database/tables.dart';
import '../../data/repositories/article_repository.dart';
import '../../data/repositories/invoice_repository.dart';
import '../../data/repositories/project_repository.dart';
import '../../data/repositories/purchase_order_repository.dart';
import '../../data/repositories/supplier_repository.dart';
import '../../data/repositories/time_entry_repository.dart';
import '../../domain/models/money.dart';
import '../../domain/services/active_company_service.dart';
import '../../domain/services/dunning_service.dart';
import '../../domain/services/invoice_totals_service.dart';
import '../../domain/services/smtp_config.dart';
import '../../domain/services/smtp_credential_store.dart';
import '../../domain/services/stock_change_notifier.dart';
import '../../pdf/dunning_letter_pdf_builder.dart';
import '../../pdf/invoice_pdf_builder.dart';
import '../widgets/email_send_dialog.dart';
import '../widgets/invoice_item_dialog.dart';
import 'invoices_screen.dart' show DocumentLabels;
import 'purchase_order_detail_screen.dart';

/// Editiert einen Dokument-Entwurf (Rechnung/Angebot/Auftrag, A2/A5)
/// und finalisiert ihn (A3) — ab Finalisierung sind Felder/Positionen
/// nicht mehr änderbar (F3). Layout/Logik sind für alle drei
/// [DocumentKind]s identisch, nur Beschriftungen unterscheiden sich
/// (siehe [DocumentLabels]).
class InvoiceEditorScreen extends StatefulWidget {
  const InvoiceEditorScreen({
    super.key,
    required this.customer,
    this.invoice,
    this.kind = DocumentKind.invoice,
    this.onChanged,
  });

  final Customer customer;

  /// `null` = neues Dokument.
  final Invoice? invoice;

  /// Dokumentart für ein **neues** Dokument. Existiert bereits
  /// [invoice], gilt stattdessen dessen eigene `kind` (eine Dokumentart
  /// ist nach dem Anlegen nicht mehr wechselbar, siehe [_kind]).
  final DocumentKind kind;

  /// Audit-Befund 2026-10-17 (Abweichungen.md Abschnitt 3, Breit-Layout):
  /// wird mit dem gespeicherten/finalisierten Dokument aufgerufen. Im
  /// schmalen Layout (Push-Navigation) ist das nicht nötig — dort löst
  /// `Navigator.pop` mit Rückgabewert das Neuladen der Liste aus. Im
  /// breiten Layout ist dieser Editor dagegen direkt **eingebettet**
  /// (kein Push/Pop); die Liste übernimmt das übergebene Dokument auch
  /// gleich als neue Auswahl, damit ein frisch angelegter Entwurf nach
  /// dem ersten Speichern sofort als ausgewählt markiert erscheint.
  final ValueChanged<Invoice>? onChanged;

  @override
  State<InvoiceEditorScreen> createState() => _InvoiceEditorScreenState();
}

class _EditableItem {
  _EditableItem({
    required this.kind,
    this.articleId,
    required this.description,
    required this.quantity,
    required this.unitPriceCents,
    required this.vatRatePercent,
    this.unit,
    this.discountPercent = 0,
    this.groupLabel,
    this.existingId,
  });

  final InvoiceItemKind kind;
  final String? articleId;
  final String description;
  final Decimal quantity;
  final int unitPriceCents;
  final double vatRatePercent;

  /// Einheit (z. B. "Stk", "h", "m") — Kay-Nachtrag 2026-10-16.
  final String? unit;

  /// Rabatt in Prozent auf diese Position — Kay-Nachtrag 2026-10-16.
  final double discountPercent;
  final String? groupLabel;
  final String? existingId;

  Money get grossBeforeDiscount => Money.fromCents(unitPriceCents).multiplyByQuantity(quantity);

  /// Nettobetrag dieser Position **nach** Rabatt (vor Steuer) — derselbe
  /// Rechenkern wie [InvoiceLineInput.lineNet], hier nur direkt am
  /// Editier-Modell für die Listenanzeige verfügbar.
  Money get netAfterDiscount => discountPercent == 0
      ? grossBeforeDiscount
      : grossBeforeDiscount - grossBeforeDiscount.applyPercent(discountPercent);

  /// Positionsbetrag **inkl. Steuer, nach Rabatt** — für die
  /// "Gesamt"-Spalte in der Listendarstellung (Kay-Nachtrag 2026-10-16:
  /// "Es fehlen Details").
  Money get lineGrossWithTax => netAfterDiscount + netAfterDiscount.applyPercent(vatRatePercent);

  /// Wie viel der Rabatt in Euro (inkl. Steuer) tatsächlich ausmacht —
  /// für die Detailzeile "− X % Rabatt: −Y €" unter der Position.
  Money get discountAmountGross {
    if (discountPercent == 0) return Money.zero();
    final grossBeforeTax = grossBeforeDiscount + grossBeforeDiscount.applyPercent(vatRatePercent);
    return grossBeforeTax - lineGrossWithTax;
  }

  /// Für den Bearbeiten-Dialog (Kay-Nachtrag 2026-10-16) — exakt die
  /// Felder, die [InvoiceItemInputResult] ohnehin schon trägt.
  InvoiceItemInputResult toResult() => InvoiceItemInputResult(
        kind: kind,
        articleId: articleId,
        description: description,
        quantity: quantity,
        unitPriceCents: unitPriceCents,
        vatRatePercent: vatRatePercent,
        unit: unit,
        discountPercent: discountPercent,
        groupLabel: groupLabel,
      );

  InvoiceItemInput toInput() => InvoiceItemInput(
        id: existingId,
        kind: kind,
        articleId: articleId,
        description: description,
        quantity: quantity,
        unitPriceCents: unitPriceCents,
        vatRatePercent: vatRatePercent,
        unit: unit,
        discountPercent: discountPercent,
        groupLabel: groupLabel,
      );
}

class _InvoiceEditorScreenState extends State<InvoiceEditorScreen> {
  final List<_EditableItem> _items = [];
  late DateTime _issueDate;
  late DateTime _serviceDate;
  final _notesCtrl = TextEditingController();
  final _paymentTermsCtrl = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  bool _finalizing = false;
  List<Article> _articles = [];
  Invoice? _currentInvoice;

  // C1 Projekte (Kay-Priorisierungsentscheidung 2026-10-17): optionale
  // Zuordnung, nur sichtbar wenn die Firma das Modul aktiviert hat.
  List<Project> _projects = [];
  String? _projectId;
  bool _projectsEnabled = false;

  // Kay-Entscheidung 2026-10-17 (Abweichungen.md Abschnitt 1): ein
  // finalisiertes Angebot/Auftrag/Proforma bleibt bearbeitbar, bis
  // daraus eine Umwandlung entstanden ist — erst DANACH gesperrt.
  // Rechnung/Lieferschein sind keine Umwandlungs-Quellen und bleiben
  // wie bisher ab Finalisierung sofort gesperrt (siehe `_isLocked`).
  bool _hasBeenConverted = false;

  // C13 Abschlagsrechnungen (Kay-Priorisierungsentscheidung 2026-10-17):
  // nur bei kind == invoice relevant und nur sichtbar, wenn die Firma das
  // Modul aktiviert hat.
  bool _advancePaymentInvoicesEnabled = false;
  bool _isAdvancePayment = false;
  Money _priorAdvancePaymentsGross = Money.zero();

  // C3.2 Festpreis-Kennzeichen (Nachtrag 2026-10-20) — nur bei
  // kind == quote/order sinnvoll, siehe Doc-Kommentar bei
  // `Invoices.isFixedPrice`.
  bool _isFixedPrice = false;
  bool _timeTrackingEnabled = false;

  // C12 Mahnwesen (Kay-Priorisierungsentscheidung 2026-10-17): nur bei
  // kind == invoice relevant und nur sichtbar, wenn die Firma das Modul
  // aktiviert hat. Fälligkeitsdatum ist nur im Entwurf änderbar; Status
  // "bezahlt" nur für finalisierte Dokumente (siehe
  // `InvoiceRepository.markPaid`).
  bool _dunningEnabled = false;
  DateTime? _dueDate;
  bool _markingPaid = false;
  DunningConfig _dunningConfig = const DunningConfig(
    reminder2AfterDays: 14,
    reminder3AfterDays: 28,
    feeLevel1: Money.fromCents(0),
    feeLevel2: Money.fromCents(0),
    feeLevel3: Money.fromCents(0),
    interestRatePercent: 0,
  );
  bool _generatingDunningLetter = false;

  // Gutschriften (Kay-Entscheidung 2026-10-19): nur bei kind == invoice
  // relevant und nur sichtbar, wenn die Firma das Modul aktiviert hat.
  bool _creditNotesEnabled = false;
  List<Invoice> _creditNotes = [];

  // C5.2 Bestellwesen (Nachtrag 2026-10-19): nur bei kind == order
  // relevant und nur sichtbar, wenn die Firma das Modul aktiviert hat
  // (gleiches Prinzip wie die Gutschriften oben).
  bool _bestellwesenEnabled = false;

  // Kleinunternehmerregelung §19 UStG (Nachtrag 2026-10-18) — erzwingt
  // 0 % USt im Positions-Dialog, siehe `invoice_item_dialog.dart`.
  bool _isSmallBusinessExempt = false;

  // C7a SMTP-Versand (Kay-Nachfrage 2026-10-17): nur sichtbar, wenn die
  // Firma das Modul aktiviert hat — genau wie bei den übrigen
  // optionalen Bereichen.
  bool _smtpEnabled = false;
  SmtpConfig _smtpConfig = const SmtpConfig(
    host: null,
    port: 587,
    username: null,
    fromAddress: null,
    fromName: null,
    useTls: true,
  );

  bool get _isFinalized => _currentInvoice?.status == InvoiceStatus.finalized;
  DocumentKind get _kind => _currentInvoice?.kind ?? widget.kind;

  /// Echte Bearbeitungssperre — anders als [_isFinalized] (zeigt nur,
  /// ob eine Nummer existiert) entscheidet dies, ob Felder/Positionen
  /// noch geändert werden dürfen. Siehe `InvoiceRepository.isEditable`
  /// für dieselbe Regel auf Repository-Ebene.
  bool get _isLocked =>
      _isFinalized && (!allowedConversionTargets.containsKey(_kind) || _hasBeenConverted);

  @override
  void initState() {
    super.initState();
    _issueDate = DateTime.now();
    _serviceDate = DateTime.now();
    _init();
  }

  Future<void> _init() async {
    final company = context.read<ActiveCompanyService>().active!;
    final companyId = company.id;
    final articleRepo = context.read<ArticleRepository>();
    final invoiceRepo = context.read<InvoiceRepository>();
    final projectRepo = context.read<ProjectRepository>();
    _articles = await articleRepo.listForCompany(companyId);
    _projectsEnabled = company.projectsEnabled;
    if (_projectsEnabled) {
      _projects = await projectRepo.listForCompany(companyId);
    }
    _advancePaymentInvoicesEnabled = company.advancePaymentInvoicesEnabled;
    _dunningEnabled = company.dunningEnabled;
    _dunningConfig = DunningConfig.fromCompany(company);
    _smtpEnabled = company.smtpEnabled;
    _smtpConfig = SmtpConfig.fromCompany(company);
    _creditNotesEnabled = company.creditNotesEnabled;
    _bestellwesenEnabled = company.bestellwesenEnabled;
    _isSmallBusinessExempt = company.isSmallBusinessExempt;
    _timeTrackingEnabled = company.timeTrackingEnabled;

    final invoice = widget.invoice;
    _currentInvoice = invoice;
    if (invoice != null) {
      _issueDate = invoice.issueDate;
      _serviceDate = invoice.serviceDate;
      _notesCtrl.text = invoice.notes ?? '';
      _paymentTermsCtrl.text = invoice.paymentTerms ?? '';
      _projectId = invoice.projectId;
      _isFixedPrice = invoice.isFixedPrice;
      _isAdvancePayment = invoice.isAdvancePayment;
      _dueDate = invoice.dueDate;
      if (invoice.status == InvoiceStatus.finalized) {
        _hasBeenConverted = (await invoiceRepo.listConvertedFrom(invoice.id)).isNotEmpty;
        if (invoice.kind == DocumentKind.invoice && _creditNotesEnabled) {
          _creditNotes = await invoiceRepo.listCreditNotesForInvoice(invoice.id);
        }
      }
      // C13: eine Rechnung, die aus einem Angebot/Auftrag umgewandelt
      // wurde, könnte eine Schlussrechnung sein — bereits gestellte
      // Abschläge zum selben Quelldokument abziehen (siehe Doc-Kommentar
      // bei `InvoiceRepository.sumAdvancePaymentsForOrder`).
      if (_advancePaymentInvoicesEnabled &&
          invoice.kind == DocumentKind.invoice &&
          !invoice.isAdvancePayment &&
          invoice.convertedFromId != null) {
        _priorAdvancePaymentsGross =
            await invoiceRepo.sumAdvancePaymentsForOrder(invoice.convertedFromId!);
      }
      final items = await invoiceRepo.itemsFor(invoice.id);
      _items.addAll([
        for (final item in items)
          _EditableItem(
            existingId: item.id,
            kind: item.kind,
            articleId: item.articleId,
            description: item.description,
            quantity: Decimal.parse(item.quantity),
            unitPriceCents: item.unitPriceCents,
            vatRatePercent: item.vatRatePercent,
            unit: item.unit,
            discountPercent: item.discountPercent,
            groupLabel: item.groupLabel,
          ),
      ]);
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    _paymentTermsCtrl.dispose();
    super.dispose();
  }

  InvoiceTotals get _totals => calculateInvoiceTotals([
        for (final item in _items)
          InvoiceLineInput(
            quantity: item.quantity,
            unitPriceCents: item.unitPriceCents,
            vatRatePercent: item.vatRatePercent,
            discountPercent: item.discountPercent,
          ),
      ]);

  /// Summe nur der übergebenen (einer Gruppe zugehörigen) Positionen —
  /// derselbe Rechenkern wie [_totals], nur auf eine Teilmenge
  /// angewendet (Kay-Nachtrag 2026-10-16: "Summen pro Gruppe").
  InvoiceTotals _groupTotals(List<_EditableItem> items) => calculateInvoiceTotals([
        for (final item in items)
          InvoiceLineInput(
            quantity: item.quantity,
            unitPriceCents: item.unitPriceCents,
            vatRatePercent: item.vatRatePercent,
            discountPercent: item.discountPercent,
          ),
      ]);

  /// Bereits im Dokument verwendete Gruppen, für den Autocomplete-
  /// Vorschlag im Positions-Dialog (Kay-Nachtrag 2026-10-16).
  List<String> get _existingGroupLabels =>
      {for (final item in _items) if (item.groupLabel != null) item.groupLabel!}.toList()..sort();

  Future<void> _addItem() async {
    final result = await showInvoiceItemDialog(
      context: context,
      articles: _articles,
      existingGroupLabels: _existingGroupLabels,
      allowHours: _kind != DocumentKind.deliveryNote,
      forceZeroVat: _isSmallBusinessExempt,
    );
    if (result == null) return;
    setState(() {
      _items.add(
        _EditableItem(
          kind: result.kind,
          articleId: result.articleId,
          description: result.description,
          quantity: result.quantity,
          unitPriceCents: result.unitPriceCents,
          vatRatePercent: result.vatRatePercent,
          unit: result.unit,
          discountPercent: result.discountPercent,
          groupLabel: result.groupLabel,
        ),
      );
    });
  }

  /// Bestehende Position bearbeiten statt nur löschen+neu-anlegen zu
  /// können (Kay-Nachtrag 2026-10-16). `existingId` bleibt erhalten,
  /// damit `update()` dieselbe Zeile ersetzt statt eine neue anzulegen.
  Future<void> _editItem(_EditableItem item) async {
    final result = await showInvoiceItemDialog(
      context: context,
      articles: _articles,
      existingGroupLabels: _existingGroupLabels,
      existing: item.toResult(),
      allowHours: _kind != DocumentKind.deliveryNote,
      forceZeroVat: _isSmallBusinessExempt,
    );
    if (result == null) return;
    setState(() {
      final index = _items.indexOf(item);
      _items[index] = _EditableItem(
        existingId: item.existingId,
        kind: result.kind,
        articleId: result.articleId,
        description: result.description,
        quantity: result.quantity,
        unitPriceCents: result.unitPriceCents,
        vatRatePercent: result.vatRatePercent,
        unit: result.unit,
        discountPercent: result.discountPercent,
        groupLabel: result.groupLabel,
      );
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final companyId = context.read<ActiveCompanyService>().active!.id;
      final repo = context.read<InvoiceRepository>();
      final items = [for (final item in _items) item.toInput()];
      final existing = _currentInvoice;
      final Invoice? saved;
      if (existing == null) {
        saved = await repo.createDraft(
          companyId: companyId,
          customerId: widget.customer.id,
          kind: widget.kind,
          issueDate: _issueDate,
          serviceDate: _serviceDate,
          paymentTerms: _paymentTermsCtrl.text.trim().isEmpty ? null : _paymentTermsCtrl.text.trim(),
          notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
          projectId: _projectId,
          isAdvancePayment: _isAdvancePayment,
          dueDate: _dueDate,
          isFixedPrice: _isFixedPrice,
          items: items,
        );
      } else {
        saved = await repo.update(
          companyId: companyId,
          id: existing.id,
          issueDate: _issueDate,
          serviceDate: _serviceDate,
          paymentTerms: _paymentTermsCtrl.text.trim().isEmpty ? null : _paymentTermsCtrl.text.trim(),
          notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
          projectId: Value(_projectId),
          isAdvancePayment: _isAdvancePayment,
          dueDate: Value(_dueDate),
          isFixedPrice: _isFixedPrice,
          items: items,
        );
      }
      if (mounted) {
        if (saved == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Speichern nicht möglich (bereits umgewandelt?).')),
          );
          return;
        }
        setState(() => _currentInvoice = saved);
        widget.onChanged?.call(saved);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isFinalized ? 'Änderungen gespeichert.' : 'Entwurf gespeichert.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// C12 Mahnwesen — Nachbesserung (Kay-Feedback 2026-10-17): das
  /// Fälligkeitsdatum ist jetzt **jederzeit** änderbar, nicht nur im
  /// Entwurf (siehe Doc-Kommentar bei `InvoiceRepository.setDueDate`).
  /// Im Entwurf bleibt es wie bisher Teil von [_save] (kein zusätzlicher
  /// Persistierungsweg nötig); bei einer bereits finalisierten/
  /// gesperrten Rechnung wird sofort direkt gespeichert, analog zu
  /// "Als bezahlt markieren".
  Future<void> _pickDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    setState(() => _dueDate = picked);
    if (_isLocked) {
      final companyId = context.read<ActiveCompanyService>().active!.id;
      final repo = context.read<InvoiceRepository>();
      final updated = await repo.setDueDate(companyId: companyId, id: _currentInvoice!.id, dueDate: picked);
      if (updated != null && mounted) setState(() => _currentInvoice = updated);
    }
  }

  /// C12 Mahnwesen — manuell "als bezahlt"/"als offen" markieren, sofort
  /// persistiert (kein separater Speichern-Schritt nötig, anders als die
  /// übrigen Entwurfsfelder — der Zahlungsstatus existiert nur bei
  /// finalisierten Dokumenten).
  Future<void> _togglePaid() async {
    final invoice = _currentInvoice;
    if (invoice == null) return;
    setState(() => _markingPaid = true);
    try {
      final companyId = context.read<ActiveCompanyService>().active!.id;
      final repo = context.read<InvoiceRepository>();
      final updated = invoice.paymentStatus == PaymentStatus.paid
          ? await repo.markOpen(companyId: companyId, id: invoice.id)
          : await repo.markPaid(companyId: companyId, id: invoice.id);
      if (updated != null && mounted) {
        setState(() => _currentInvoice = updated);
      }
    } finally {
      if (mounted) setState(() => _markingPaid = false);
    }
  }

  /// C12 Mahnwesen — Nachbesserung (Kay-Feedback 2026-10-17: "Mahngebühren
  /// und Mahnschreiben-PDF bitte umsetzen"). Erzeugt und teilt ein
  /// Mahnschreiben für die aktuelle Mahnstufe. Rein lesend — löst **kein**
  /// Fortschreiten der Mahnstufe o. Ä. aus, da die Stufe ausschließlich
  /// aus dem Fälligkeitsdatum berechnet wird (siehe `dunningLevelFor`);
  /// wiederholtes Erzeugen ist absichtlich jederzeit möglich.
  Future<void> _generateDunningLetter(DunningLevel level) async {
    final invoice = _currentInvoice;
    if (invoice == null) return;
    setState(() => _generatingDunningLetter = true);
    try {
      final repo = context.read<InvoiceRepository>();
      final company = context.read<ActiveCompanyService>().active!;
      final invoiceGross = (await repo.totalsFor(invoice.id)).totalGross;
      if (!mounted) return;
      final bytes = await buildDunningLetterPdf(
        invoice: invoice,
        company: company,
        level: level,
        config: _dunningConfig,
        invoiceGross: invoiceGross,
      );
      await Printing.sharePdf(
        bytes: bytes,
        filename: '${invoice.invoiceNumber}-${dunningLetterTitle(level)}.pdf',
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mahnschreiben konnte nicht erstellt/geteilt werden.')),
        );
      }
    } finally {
      if (mounted) setState(() => _generatingDunningLetter = false);
    }
  }

  /// C7a SMTP-Versand fürs Mahnschreiben — gleiches Muster wie
  /// [_sendInvoiceByEmail], eigenes Platzhalter-Textpaar
  /// (`smtpDunningSubjectTemplate`/`...BodyTemplate`), weil ein
  /// Mahnschreiben einen anderen Ton braucht als eine normale
  /// Rechnungs-Mail.
  Future<void> _sendDunningLetterByEmail(DunningLevel level) async {
    final invoice = _currentInvoice;
    if (invoice == null) return;
    final company = context.read<ActiveCompanyService>().active!;
    final repo = context.read<InvoiceRepository>();
    final credentialStore = context.read<SmtpCredentialStore>();
    final subjectTemplate =
        company.smtpDunningSubjectTemplate ?? '${dunningLetterTitle(level)}: {{nummer}}';
    final bodyTemplate = company.smtpDunningBodyTemplate ??
        'Guten Tag {{kunde}},\n\nanbei erhalten Sie unser Mahnschreiben zur Rechnung '
            '{{nummer}}.\n\nMit freundlichen Grüßen\n{{firma}}';
    await showEmailSendDialog(
      context: context,
      config: _smtpConfig,
      credentialStore: credentialStore,
      companyId: company.id,
      initialTo: widget.customer.email ?? '',
      initialSubject: applyEmailTemplatePlaceholders(
        template: subjectTemplate,
        customerName: widget.customer.name,
        documentNumber: invoice.invoiceNumber ?? '',
        companyName: company.name,
      ),
      initialBody: applyEmailTemplatePlaceholders(
        template: bodyTemplate,
        customerName: widget.customer.name,
        documentNumber: invoice.invoiceNumber ?? '',
        companyName: company.name,
      ),
      attachmentFilename: '${invoice.invoiceNumber}-${dunningLetterTitle(level)}.pdf',
      buildAttachment: () async {
        final invoiceGross = (await repo.totalsFor(invoice.id)).totalGross;
        return buildDunningLetterPdf(
          invoice: invoice,
          company: company,
          level: level,
          config: _dunningConfig,
          invoiceGross: invoiceGross,
        );
      },
    );
  }

  /// Wandelt das aktuelle (finalisierte) Dokument in einen neuen Entwurf
  /// einer anderen Dokumentart um (Kay-Nachtrag 2026-10-16) und öffnet
  /// diesen sofort zur Durchsicht — bewusst **kein** automatisches
  /// Finalisieren, der Nutzer prüft/ergänzt erst wie bei jedem anderen
  /// neuen Dokument (siehe Doc-Kommentar bei `InvoiceRepository.convertTo`).
  Future<void> _convertTo(DocumentKind targetKind) async {
    final invoice = _currentInvoice;
    if (invoice == null) return;
    final companyId = context.read<ActiveCompanyService>().active!.id;
    final repo = context.read<InvoiceRepository>();
    // C3.2 (Nachtrag 2026-10-20) — nur übergeben, wenn das Modul aktiv
    // ist; `convertTo()` nutzt es nur für Auftrag->Rechnung ohne
    // Festpreis, ignoriert es sonst folgenlos.
    final timeEntryRepo = _timeTrackingEnabled ? context.read<TimeEntryRepository>() : null;
    try {
      final draft = await repo.convertTo(
        companyId: companyId,
        sourceId: invoice.id,
        targetKind: targetKind,
        timeEntryRepository: timeEntryRepo,
      );
      // Kay-Entscheidung 2026-10-17: ab der ersten Umwandlung ist DIESES
      // Dokument gesperrt — sofort hier setzen, kein erneutes Nachladen
      // nötig.
      if (mounted) setState(() => _hasBeenConverted = true);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => InvoiceEditorScreen(customer: widget.customer, invoice: draft),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Umwandeln nicht möglich: $e')),
        );
      }
    }
  }

  /// Gutschriften (Kay-Entscheidung 2026-10-19: "Gutschriften bekommen
  /// einen eigenen Nummernkreis"). Anders als [_convertTo] setzt dies
  /// **keine** `_hasBeenConverted`-Sperre auf DIESEM Dokument — eine
  /// finalisierte Rechnung ist ohnehin schon sofort unveränderlich
  /// (siehe Doc-Kommentar bei `createCreditNoteDraft`), eine Gutschrift
  /// ändert daran nichts.
  Future<void> _createCreditNote() async {
    final invoice = _currentInvoice;
    if (invoice == null) return;
    final companyId = context.read<ActiveCompanyService>().active!.id;
    final repo = context.read<InvoiceRepository>();
    try {
      final draft = await repo.createCreditNoteDraft(companyId: companyId, invoiceId: invoice.id);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => InvoiceEditorScreen(customer: widget.customer, invoice: draft),
        ),
      );
      // Nach Rückkehr (ggf. inzwischen finalisiert) neu laden, damit sie
      // sofort in "Gutschriften zu diesem Dokument" auftaucht.
      if (mounted) {
        setState(() {});
        final reloaded = await repo.listCreditNotesForInvoice(invoice.id);
        if (mounted) setState(() => _creditNotes = reloaded);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gutschrift konnte nicht erstellt werden: $e')),
        );
      }
    }
  }

  /// C5.2 Bestellwesen, Weg (a) der Roadmap: Bestellungen aus diesem
  /// finalisierten Auftrag erstellen. Fragt zuerst den Modus ab (alles
  /// über einen Lieferanten, oder je Artikel automatisch der
  /// günstigste), bei "einen Lieferanten" zusätzlich welcher — danach
  /// übernimmt `PurchaseOrderRepository.createDraftsFromOrder()` die
  /// eigentliche Gruppierung (siehe dort).
  Future<void> _createPurchaseOrdersFromOrder() async {
    final invoice = _currentInvoice;
    if (invoice == null) return;
    final companyId = context.read<ActiveCompanyService>().active!.id;
    final suppliers = await context.read<SupplierRepository>().listForCompany(companyId);
    if (!mounted) return;
    if (suppliers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bitte zuerst einen Lieferanten anlegen.')),
      );
      return;
    }
    final choice = await showDialog<_PurchaseOrderFromOrderChoice>(
      context: context,
      builder: (context) => _PurchaseOrderFromOrderDialog(suppliers: suppliers),
    );
    if (choice == null || !mounted) return;
    try {
      final result = await context.read<PurchaseOrderRepository>().createDraftsFromOrder(
            companyId: companyId,
            sourceOrderId: invoice.id,
            mode: choice.mode,
            supplierId: choice.supplierId,
          );
      if (!mounted) return;
      if (result.drafts.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Keine Bestellung erzeugt (keine Artikel-Positionen zuordenbar).')),
        );
        return;
      }
      if (result.unassignable.isNotEmpty) {
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Nicht zuordenbare Artikel'),
            content: Text(
              'Für diese Artikel ist beim gewählten Lieferanten kein Einkaufspreis hinterlegt, sie '
              'wurden nicht in eine Bestellung übernommen:\n\n'
              '${result.unassignable.map((a) => '${a.articleName}: ${a.quantity}').join('\n')}',
            ),
            actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
          ),
        );
      }
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PurchaseOrderDetailScreen(purchaseOrderId: result.drafts.first.id),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Bestellung konnte nicht erstellt werden: $e')),
        );
      }
    }
  }

  /// C3.2 Materialabschlagsrechnung (Nachtrag 2026-10-20) — fragt die
  /// Auswahl ab (alle Artikel / ausgewählte Freitexte) und übergibt sie
  /// an `InvoiceRepository.createMaterialAdvanceDraft()`.
  Future<void> _createMaterialAdvance() async {
    final invoice = _currentInvoice;
    if (invoice == null) return;
    final freetextItems =
        _items.where((i) => i.kind == InvoiceItemKind.text && i.existingId != null).toList();

    final result = await showDialog<_MaterialAdvanceSelection>(
      context: context,
      builder: (context) => _MaterialAdvanceDialog(freetextItems: freetextItems),
    );
    if (result == null || !mounted) return;
    final companyId = context.read<ActiveCompanyService>().active!.id;
    try {
      final draft = await context.read<InvoiceRepository>().createMaterialAdvanceDraft(
            companyId: companyId,
            sourceOrderId: invoice.id,
            includeAllArticles: result.includeAllArticles,
            selectedFreetextItemIds: result.selectedFreetextItemIds,
          );
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => InvoiceEditorScreen(customer: widget.customer, invoice: draft),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Materialabschlag konnte nicht erstellt werden: $e')),
        );
      }
    }
  }

  Future<void> _finalize() async {
    final invoice = _currentInvoice;
    if (invoice == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${DocumentLabels.title(_kind)} finalisieren?'),
        content: Text(
          '${DocumentLabels.finalizeConfirmSentence(_kind)} Diese Aktion ist nicht umkehrbar.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Abbrechen')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Finalisieren'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final companyId = context.read<ActiveCompanyService>().active!.id;
    final repo = context.read<InvoiceRepository>();

    // C5.1 Lagerbestand (Nachtrag 2026-10-19, Kay-Entscheidung: "Nur
    // warnen, trotzdem erlauben") — Warnhinweis VOR dem eigentlichen
    // Finalisieren, blockiert aber nichts.
    final warnings = await repo.checkStockBeforeFinalize(companyId: companyId, id: invoice.id);
    if (!mounted) return;
    if (warnings.isNotEmpty) {
      final proceedDespiteWarning = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Lagerbestand reicht nicht aus'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final warning in warnings)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '${warning.articleName}: ${warning.requestedQuantity} benötigt, '
                    'nur ${warning.availableQuantity} verfügbar',
                  ),
                ),
              const SizedBox(height: 8),
              const Text('Finalisieren ist trotzdem möglich — der Lagerbestand wird negativ.'),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Abbrechen')),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Trotzdem finalisieren'),
            ),
          ],
        ),
      );
      if (proceedDespiteWarning != true || !mounted) return;
    }

    setState(() => _finalizing = true);
    try {
      final finalized = await repo.finalize(companyId: companyId, id: invoice.id);
      if (!mounted) return;
      if (finalized == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Finalisierung nicht möglich (bereits finalisiert?).')),
        );
        return;
      }
      setState(() => _currentInvoice = finalized);
      widget.onChanged?.call(finalized);
      // Bugfix 2026-10-19 (Kay: "Wenn ich den Bestand aus einer
      // Bestellung buche, wird dieser nicht angezeigt") — dasselbe
      // Staleness-Problem betrifft auch die Lagerbuchung beim
      // Finalisieren (C5.1). Ping ist harmlos, auch wenn das Modul aus
      // ist oder gar kein Artikel betroffen war (siehe Doc-Kommentar
      // bei `StockChangeNotifier`).
      context.read<StockChangeNotifier>().notifyStockChanged();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Finalisiert als ${finalized.invoiceNumber}.')),
      );
    } on StateError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _finalizing = false);
    }
  }

  /// Gutschriften (Kay-Entscheidung 2026-10-19): Nummer der Rechnung,
  /// auf die sich [invoice] bezieht — `null` bei allen anderen
  /// Dokumentarten oder wenn die Quelle nicht (mehr) gefunden wird.
  Future<String?> _referencedInvoiceNumber(Invoice invoice, InvoiceRepository repo) async {
    if (invoice.kind != DocumentKind.creditNote || invoice.convertedFromId == null) return null;
    final company = context.read<ActiveCompanyService>().active!;
    final source = await repo.findById(companyId: company.id, id: invoice.convertedFromId!);
    return source?.invoiceNumber;
  }

  Future<void> _sharePdf() async {
    final invoice = _currentInvoice;
    if (invoice == null || invoice.status != InvoiceStatus.finalized) return;
    final repo = context.read<InvoiceRepository>();
    try {
      final items = await repo.itemsFor(invoice.id);
      if (!mounted) return;
      final company = context.read<ActiveCompanyService>().active!;
      final bytes = await buildInvoicePdf(
        invoice: invoice,
        items: items,
        company: company,
        priorAdvancePaymentsGross: _priorAdvancePaymentsGross,
        referencedDocumentNumber: await _referencedInvoiceNumber(invoice, repo),
      );
      await Printing.sharePdf(bytes: bytes, filename: '${invoice.invoiceNumber}.pdf');
    } catch (_) {
      // A3 Punkt 4: ein PDF-Fehler darf nie wie ein erfolgreich erstelltes
      // PDF aussehen — die Rechnung selbst bleibt dabei unverändert
      // finalisiert, nur die PDF-Erzeugung/der Teilen-Dialog ist
      // gescheitert. Erneuter Versuch (Button bleibt bedienbar) ist der
      // "verständliche Wiederanlauf".
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PDF konnte nicht erstellt/geteilt werden. Bitte erneut versuchen.'),
          ),
        );
      }
    }
  }

  /// C7a SMTP-Versand (Kay-Nachfrage 2026-10-17): öffnet den Versand-
  /// dialog mit vorausgefülltem, aber frei editierbarem Empfänger/
  /// Betreff/Text — das eigentliche PDF wird erst beim tatsächlichen
  /// Versand-Klick im Dialog gebaut (`buildAttachment`), nicht schon
  /// hier, damit ein Abbrechen keine unnötige PDF-Erzeugung auslöst.
  Future<void> _sendInvoiceByEmail() async {
    final invoice = _currentInvoice;
    if (invoice == null || invoice.status != InvoiceStatus.finalized) return;
    final company = context.read<ActiveCompanyService>().active!;
    final repo = context.read<InvoiceRepository>();
    final credentialStore = context.read<SmtpCredentialStore>();
    final subjectTemplate = company.smtpInvoiceSubjectTemplate ?? '{{firma}}: {{nummer}}';
    final bodyTemplate = company.smtpInvoiceBodyTemplate ??
        'Guten Tag {{kunde}},\n\nanbei erhalten Sie das Dokument {{nummer}}.\n\n'
            'Mit freundlichen Grüßen\n{{firma}}';
    await showEmailSendDialog(
      context: context,
      config: _smtpConfig,
      credentialStore: credentialStore,
      companyId: company.id,
      initialTo: widget.customer.email ?? '',
      initialSubject: applyEmailTemplatePlaceholders(
        template: subjectTemplate,
        customerName: widget.customer.name,
        documentNumber: invoice.invoiceNumber ?? '',
        companyName: company.name,
      ),
      initialBody: applyEmailTemplatePlaceholders(
        template: bodyTemplate,
        customerName: widget.customer.name,
        documentNumber: invoice.invoiceNumber ?? '',
        companyName: company.name,
      ),
      attachmentFilename: '${invoice.invoiceNumber}.pdf',
      buildAttachment: () async {
        final items = await repo.itemsFor(invoice.id);
        return buildInvoicePdf(
          invoice: invoice,
          items: items,
          company: company,
          priorAdvancePaymentsGross: _priorAdvancePaymentsGross,
          referencedDocumentNumber: await _referencedInvoiceNumber(invoice, repo),
        );
      },
    );
  }

  /// Unverbindliche In-App-Vorschau des aktuellen Entwurfs — direkt aus
  /// dem Bearbeitungsstand im Speicher, auch für noch nie gespeicherte
  /// Positionen (Kay-Nachtrag 2026-10-16: "PDF Vorschau, für Dokumente,
  /// die noch nicht finalisiert sind — Online/in App Vorschau"). Nutzt
  /// die Live-Stammdaten von Kunde/Firma statt eines Schnappschusses,
  /// da vor der Finalisierung noch keiner existiert — absichtlich kein
  /// Teilen/Drucken aus dieser Ansicht heraus (siehe Doc-Kommentar bei
  /// `buildDraftPreviewPdf`).
  Future<void> _previewDraft() async {
    final service = context.read<ActiveCompanyService>();
    final company = service.active!;
    final now = DateTime.now();
    final previewInvoiceId = _currentInvoice?.id ?? 'preview';
    final previewInvoice = Invoice(
      id: previewInvoiceId,
      companyId: company.id,
      customerId: widget.customer.id,
      kind: _kind,
      status: InvoiceStatus.draft,
      invoiceNumber: null,
      numberYear: null,
      issueDate: _issueDate,
      serviceDate: _serviceDate,
      paymentTerms: _paymentTermsCtrl.text.trim().isEmpty ? null : _paymentTermsCtrl.text.trim(),
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      customerSnapshotName: widget.customer.name,
      customerSnapshotAddress: widget.customer.address,
      customerSnapshotVatId: widget.customer.vatId,
      companySnapshotName: company.name,
      companySnapshotAddress: company.address,
      companySnapshotTaxNumber: company.taxNumber,
      companySnapshotVatId: company.vatId,
      companySnapshotIban: company.iban,
      finalizedAt: null,
      createdAt: now,
      updatedAt: now,
      isAdvancePayment: _isAdvancePayment,
      dueDate: _dueDate,
      isFixedPrice: _isFixedPrice,
      paymentStatus: PaymentStatus.open,
      paidAt: null,
    );
    final previewItems = [
      for (var i = 0; i < _items.length; i++)
        InvoiceItem(
          id: _items[i].existingId ?? 'preview-$i',
          invoiceId: previewInvoiceId,
          kind: _items[i].kind,
          articleId: _items[i].articleId,
          description: _items[i].description,
          quantity: _items[i].quantity.toString(),
          unitPriceCents: _items[i].unitPriceCents,
          vatRatePercent: _items[i].vatRatePercent,
          unit: _items[i].unit,
          discountPercent: _items[i].discountPercent,
          groupLabel: _items[i].groupLabel,
          sortOrder: i,
        ),
    ];

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Vorschau (Entwurf, nicht final)')),
          body: PdfPreview(
            build: (format) =>
                buildDraftPreviewPdf(invoice: previewInvoice, items: previewItems, company: company),
            canChangeOrientation: false,
            canChangePageFormat: false,
            allowSharing: false,
            allowPrinting: false,
          ),
        ),
      ),
    );
  }

  static IconData _iconFor(InvoiceItemKind kind) => switch (kind) {
        InvoiceItemKind.article => Icons.inventory_2_outlined,
        InvoiceItemKind.hours => Icons.schedule_outlined,
        InvoiceItemKind.text => Icons.notes_outlined,
      };

  /// Positionszeile mit mehr Details statt einer einzigen Subtitle-Zeile
  /// (Kay-Nachtrag 2026-10-16: Vergleich mit RechnungsFee, "Es fehlen
  /// Details") — Einheit neben der Menge, Steuersatz und Gesamtbetrag
  /// klar als eigene Zeile, Rabatt als eigene Detailzeile wenn gesetzt.
  Widget _buildItemCard(_EditableItem item, bool isLocked) {
    final quantityLabel = item.unit == null ? '${item.quantity}' : '${item.quantity} ${item.unit}';
    return Card(
      child: InkWell(
        onTap: isLocked ? null : () => _editItem(item),
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(_iconFor(item.kind), size: 18, color: Theme.of(context).colorScheme.outline),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(item.description, style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  if (!isLocked)
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 20),
                      onPressed: () => setState(() => _items.remove(item)),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
              const SizedBox(height: 2),
              Padding(
                padding: const EdgeInsets.only(left: 26),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        '$quantityLabel × ${Money.fromCents(item.unitPriceCents)} · '
                        '${item.vatRatePercent.toStringAsFixed(0)} % MwSt.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    Text(
                      item.lineGrossWithTax.toString(),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              if (item.discountPercent > 0)
                Padding(
                  padding: const EdgeInsets.only(left: 26, top: 2),
                  child: Text(
                    '− ${item.discountPercent.toStringAsFixed(0)} % Rabatt: −${item.discountAmountGross}',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Theme.of(context).colorScheme.primary),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Positionen nach Gruppe sortiert anzeigen (ungruppierte zuletzt).
    final groups = <String?, List<_EditableItem>>{};
    for (final item in _items) {
      groups.putIfAbsent(item.groupLabel, () => []).add(item);
    }
    final orderedKeys = groups.keys.toList()
      ..sort((a, b) {
        if (a == null) return 1;
        if (b == null) return -1;
        return a.compareTo(b);
      });

    final totals = _totals;

    final isFinalized = _isFinalized;
    final isLocked = _isLocked;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isFinalized
              ? '${DocumentLabels.title(_kind)} ${_currentInvoice!.invoiceNumber} — ${widget.customer.name}'
              : '${DocumentLabels.editorDraftTitle(_kind)} — ${widget.customer.name}',
        ),
        actions: [
          if (isFinalized)
            IconButton(
              icon: const Icon(Icons.picture_as_pdf_outlined),
              tooltip: 'PDF teilen',
              onPressed: _sharePdf,
            ),
          if (isFinalized && _smtpEnabled)
            IconButton(
              icon: const Icon(Icons.mail_outline),
              tooltip: 'Per E-Mail senden',
              onPressed: _sendInvoiceByEmail,
            ),
          if (isFinalized && (allowedConversionTargets[_kind]?.isNotEmpty ?? false))
            PopupMenuButton<DocumentKind>(
              icon: const Icon(Icons.sync_alt_outlined),
              tooltip: 'Umwandeln',
              itemBuilder: (context) => [
                for (final target in allowedConversionTargets[_kind]!)
                  PopupMenuItem(
                    value: target,
                    child: Text('In ${DocumentLabels.title(target)} umwandeln'),
                  ),
              ],
              onSelected: _convertTo,
            ),
          if (isFinalized && _kind == DocumentKind.invoice && _creditNotesEnabled)
            IconButton(
              icon: const Icon(Icons.receipt_long_outlined),
              tooltip: 'Gutschrift erstellen',
              onPressed: _createCreditNote,
            ),
          if (isFinalized && _kind == DocumentKind.order && _bestellwesenEnabled)
            IconButton(
              icon: const Icon(Icons.shopping_cart_outlined),
              tooltip: 'Bestellung erstellen',
              onPressed: _createPurchaseOrdersFromOrder,
            ),
          if (isFinalized && _kind == DocumentKind.order && _advancePaymentInvoicesEnabled)
            IconButton(
              icon: const Icon(Icons.request_quote_outlined),
              tooltip: 'Materialabschlag erstellen',
              onPressed: _createMaterialAdvance,
            ),
          // Vorschau (ENTWURF-Wasserzeichen) macht nur vor der ersten
          // Finalisierung Sinn — danach existiert bereits ein echtes PDF
          // über "PDF teilen".
          if (!isFinalized)
            IconButton(
              icon: const Icon(Icons.visibility_outlined),
              tooltip: 'Vorschau (unverbindlich)',
              onPressed: _items.isEmpty ? null : _previewDraft,
            ),
          // Speichern bleibt verfügbar, solange das Dokument laut
          // Kay-Entscheidung 2026-10-17 editierbar ist — das schließt ein
          // finalisiertes, noch nicht umgewandeltes Angebot/Auftrag/
          // Proforma ein, nicht nur echte Entwürfe.
          if (!isLocked)
            IconButton(
              icon: _saving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.save_outlined),
              tooltip: isFinalized ? 'Änderungen speichern' : 'Entwurf speichern',
              onPressed: _saving ? null : _save,
            ),
          if (!isFinalized && _currentInvoice != null)
            IconButton(
              icon: _finalizing
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.check_circle_outline),
              tooltip: 'Finalisieren',
              onPressed: _finalizing ? null : _finalize,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (isFinalized)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Text(
                'Finalisiert am ${_currentInvoice!.finalizedAt!.toLocal().toString().split('.').first} — '
                '${isLocked ? 'nicht mehr änderbar.' : 'noch bearbeitbar, bis daraus ein Folgedokument erzeugt wird.'}',
                style: TextStyle(color: Theme.of(context).colorScheme.primary),
              ),
            ),
          TextField(
            controller: _paymentTermsCtrl,
            readOnly: isLocked,
            decoration: const InputDecoration(labelText: 'Zahlungsbedingungen'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _notesCtrl,
            readOnly: isLocked,
            decoration: const InputDecoration(labelText: 'Notizen'),
            maxLines: 2,
          ),
          if (_projectsEnabled) ...[
            const SizedBox(height: 8),
            if (isLocked)
              Text(
                'Projekt: ${_projects.where((p) => p.id == _projectId).firstOrNull?.name ?? 'Ohne Projekt'}',
                style: Theme.of(context).textTheme.bodyMedium,
              )
            else
              DropdownButtonFormField<String?>(
                isExpanded: true,
                initialValue: _projectId,
                decoration: const InputDecoration(labelText: 'Projekt (optional)'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Ohne Projekt')),
                  for (final project in _projects)
                    DropdownMenuItem(value: project.id, child: Text(project.name)),
                ],
                onChanged: (value) => setState(() => _projectId = value),
              ),
          ],
          // C13 Abschlagsrechnungen (Kay-Priorisierungsentscheidung
          // 2026-10-17) — nur bei Rechnungen sinnvoll, nur im Entwurf
          // umschaltbar.
          if (_advancePaymentInvoicesEnabled && _kind == DocumentKind.invoice) ...[
            const SizedBox(height: 4),
            if (isLocked)
              if (_isAdvancePayment)
                Text('Abschlagsrechnung', style: Theme.of(context).textTheme.bodyMedium)
              else
                const SizedBox.shrink()
            else
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text('Ist eine Abschlagsrechnung'),
                value: _isAdvancePayment,
                onChanged: (value) => setState(() => _isAdvancePayment = value ?? false),
              ),
          ],
          // C3.2 Festpreis-Kennzeichen (Nachtrag 2026-10-20) — nur bei
          // Angebot/Auftrag sinnvoll (wandert beim Umwandeln mit, siehe
          // `InvoiceRepository.convertTo()`), nur im Entwurf umschaltbar.
          if (_timeTrackingEnabled &&
              (_kind == DocumentKind.quote || _kind == DocumentKind.order)) ...[
            const SizedBox(height: 4),
            if (isLocked)
              Text(
                _isFixedPrice ? 'Festpreis vereinbart' : 'Zeit und Material (keine Festpreis-Vereinbarung)',
                style: Theme.of(context).textTheme.bodyMedium,
              )
            else
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text('Festpreis vereinbart'),
                subtitle: const Text(
                  'Ohne Festpreis werden beim Umwandeln in eine Rechnung die tatsächlich '
                  'gebuchten Ist-Stunden statt der geplanten Mengen übernommen.',
                ),
                value: _isFixedPrice,
                onChanged: (value) => setState(() => _isFixedPrice = value ?? false),
              ),
          ],
          // "Geplant vs. Gebucht" (Nachtrag 2026-10-20: "Die Zeiten aus
          // dem Angebot brauchen wir im Auftrag als Referenz") — braucht
          // kein eigenes Feld: `convertTo()` kopiert die Angebots-
          // Stunden-Positionen bereits unverändert in den Auftrag
          // (bestehendes Verhalten), hier nur gegenübergestellt mit den
          // tatsächlich gebuchten Ist-Stunden.
          if (_timeTrackingEnabled && _kind == DocumentKind.order && isFinalized)
            FutureBuilder<double>(
              future: context.read<TimeEntryRepository>().totalHoursForInvoice(_currentInvoice!.id),
              builder: (context, snapshot) {
                final plannedHours = _items
                    .where((i) => i.kind == InvoiceItemKind.hours)
                    .fold(Decimal.zero, (sum, i) => sum + i.quantity);
                final bookedHours = snapshot.data;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    'Geplant laut Angebot: $plannedHours Std. · Gebucht: '
                    '${bookedHours == null ? '…' : bookedHours.toStringAsFixed(1)} Std.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                );
              },
            ),
          // C12 Mahnwesen (Kay-Priorisierungsentscheidung 2026-10-17,
          // Nachbesserung nach Kay-Feedback 2026-10-17) — nur bei
          // Rechnungen sinnvoll. Fälligkeitsdatum ist **jederzeit**
          // änderbar (auch nach Finalisierung, siehe `_pickDueDate`);
          // Zahlungsstatus/Mahnstufe nur bei finalisierten Dokumenten
          // (ein Entwurf hat fachlich keinen Zahlungsstatus).
          if (_dunningEnabled && _kind == DocumentKind.invoice) ...[
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                _dueDate == null
                    ? 'Fälligkeitsdatum (optional)'
                    : 'Fälligkeitsdatum: ${_dueDate!.toLocal().toString().split(' ').first}',
              ),
              trailing: const Icon(Icons.calendar_today_outlined),
              onTap: _pickDueDate,
            ),
            if (isFinalized) ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _currentInvoice!.paymentStatus == PaymentStatus.paid
                          ? 'Bezahlt am ${_currentInvoice!.paidAt?.toLocal().toString().split(' ').first}'
                          : _dueDate == null
                              ? 'Offen (kein Fälligkeitsdatum gesetzt)'
                              : 'Offen — fällig am ${_dueDate!.toLocal().toString().split(' ').first}',
                    ),
                  ),
                  TextButton(
                    onPressed: _markingPaid ? null : _togglePaid,
                    child: Text(
                      _currentInvoice!.paymentStatus == PaymentStatus.paid
                          ? 'Als offen markieren'
                          : 'Als bezahlt markieren',
                    ),
                  ),
                ],
              ),
              // Mahnstufe weiterhin rein datumsbasiert (siehe
              // `dunningLevelFor`); Gebühr/Zins kommen jetzt aber aus den
              // Firmen-Einstellungen statt gar nicht berechnet zu werden.
              Builder(
                builder: (context) {
                  final level = dunningLevelFor(_currentInvoice!, DateTime.now(), _dunningConfig);
                  if (level == DunningLevel.none) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            dunningLevelLabel(level),
                            style: TextStyle(color: Theme.of(context).colorScheme.error),
                          ),
                        ),
                        TextButton(
                          onPressed: _generatingDunningLetter ? null : () => _generateDunningLetter(level),
                          child: Text('${dunningLetterTitle(level)} erzeugen'),
                        ),
                        if (_smtpEnabled)
                          IconButton(
                            icon: const Icon(Icons.mail_outline),
                            tooltip: '${dunningLetterTitle(level)} per E-Mail senden',
                            onPressed: () => _sendDunningLetterByEmail(level),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ],
          // Gutschriften (Kay-Entscheidung 2026-10-19): Übersicht bereits
          // erstellter, finalisierter Gutschriften zu dieser Rechnung —
          // es gibt bewusst keine eigene "Neue Gutschrift"-Liste (siehe
          // Doc-Kommentar bei `createCreditNoteDraft`), daher ist das
          // hier der einzige Weg, eine bereits erstellte Gutschrift
          // wiederzufinden.
          if (isFinalized && _kind == DocumentKind.invoice && _creditNotesEnabled && _creditNotes.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Gutschriften zu diesem Dokument', style: Theme.of(context).textTheme.titleSmall),
                  for (final creditNote in _creditNotes)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.receipt_long_outlined),
                      title: Text(creditNote.invoiceNumber ?? ''),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              InvoiceEditorScreen(customer: widget.customer, invoice: creditNote),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          for (final key in orderedKeys) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                key ?? 'Ohne Gruppe',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            for (final item in groups[key]!) _buildItemCard(item, isLocked),
            // Summe pro Gruppe (Kay-Nachtrag 2026-10-16) — derselbe
            // Rechenkern wie die Gesamtsumme, nur auf die Positionen
            // dieser Gruppe beschränkt statt eine eigene Berechnung
            // parallel zu pflegen.
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 4, right: 8),
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'Gruppensumme: ${_groupTotals(groups[key]!).totalGross}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Card(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final rate in totals.sortedRates)
                    Text(
                      'Netto ${rate.toStringAsFixed(0)} %: ${totals.netByRate[rate]}   '
                      'Steuer: ${totals.taxByRate[rate]}',
                    ),
                  const Divider(),
                  Text(
                    'Gesamt: ${totals.totalGross}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  // C13 Abschlagsrechnungen: Abzugszeile nur, wenn diese
                  // Rechnung aus einem Angebot/Auftrag entstanden ist UND
                  // bereits finalisierte Abschlagsrechnungen dazu existieren
                  // (siehe `InvoiceRepository.sumAdvancePaymentsForOrder`).
                  if (_priorAdvancePaymentsGross.cents > 0) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Bereits erhaltene Abschlagszahlungen: −$_priorAdvancePaymentsGross',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const Divider(),
                    Text(
                      'Restbetrag: ${totals.totalGross - _priorAdvancePaymentsGross}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: isLocked
          ? null
          : FloatingActionButton.extended(
              heroTag: 'invoice-editor-fab',
              onPressed: _addItem,
              icon: const Icon(Icons.add),
              label: const Text('Position hinzufügen'),
            ),
    );
  }
}

/// Ergebnis von [_PurchaseOrderFromOrderDialog] — [supplierId] ist nur
/// bei [PurchaseOrderCreationMode.oneSupplierForAll] gesetzt.
class _PurchaseOrderFromOrderChoice {
  const _PurchaseOrderFromOrderChoice({required this.mode, this.supplierId});
  final PurchaseOrderCreationMode mode;
  final String? supplierId;
}

/// C5.2 Bestellwesen (Nachtrag 2026-10-19) — fragt den Erzeugungsmodus
/// ab (siehe Doc-Kommentar bei [PurchaseOrderCreationMode]), bei "einen
/// Lieferanten" direkt im selben Dialog zusätzlich welcher.
class _PurchaseOrderFromOrderDialog extends StatefulWidget {
  const _PurchaseOrderFromOrderDialog({required this.suppliers});
  final List<Supplier> suppliers;

  @override
  State<_PurchaseOrderFromOrderDialog> createState() => _PurchaseOrderFromOrderDialogState();
}

class _PurchaseOrderFromOrderDialogState extends State<_PurchaseOrderFromOrderDialog> {
  PurchaseOrderCreationMode _mode = PurchaseOrderCreationMode.cheapestPerSupplier;
  String? _supplierId;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Bestellung erstellen'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SegmentedButton<PurchaseOrderCreationMode>(
            segments: const [
              ButtonSegment(
                value: PurchaseOrderCreationMode.cheapestPerSupplier,
                label: Text('Billigster Lieferant pro Artikel'),
              ),
              ButtonSegment(
                value: PurchaseOrderCreationMode.oneSupplierForAll,
                label: Text('Alles über einen Lieferanten'),
              ),
            ],
            selected: {_mode},
            onSelectionChanged: (selection) => setState(() => _mode = selection.first),
          ),
          const SizedBox(height: 12),
          if (_mode == PurchaseOrderCreationMode.oneSupplierForAll)
            DropdownButtonFormField<String?>(
              isExpanded: true,
              initialValue: _supplierId,
              decoration: const InputDecoration(labelText: 'Lieferant'),
              items: [
                for (final supplier in widget.suppliers)
                  DropdownMenuItem(value: supplier.id, child: Text(supplier.name)),
              ],
              onChanged: (value) => setState(() => _supplierId = value),
            ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
        FilledButton(
          onPressed: _mode == PurchaseOrderCreationMode.oneSupplierForAll && _supplierId == null
              ? null
              : () => Navigator.pop(
                    context,
                    _PurchaseOrderFromOrderChoice(mode: _mode, supplierId: _supplierId),
                  ),
          child: const Text('Erstellen'),
        ),
      ],
    );
  }
}

class _MaterialAdvanceSelection {
  const _MaterialAdvanceSelection({required this.includeAllArticles, required this.selectedFreetextItemIds});
  final bool includeAllArticles;
  final Set<String> selectedFreetextItemIds;
}

/// C3.2 Materialabschlagsrechnung (Nachtrag 2026-10-20: "Alle Artikel /
/// Ausgewählte Freitexte") — zwei unabhängige Auswahlen in einem
/// Dialog.
class _MaterialAdvanceDialog extends StatefulWidget {
  const _MaterialAdvanceDialog({required this.freetextItems});
  final List<_EditableItem> freetextItems;

  @override
  State<_MaterialAdvanceDialog> createState() => _MaterialAdvanceDialogState();
}

class _MaterialAdvanceDialogState extends State<_MaterialAdvanceDialog> {
  bool _includeAllArticles = true;
  final Set<String> _selectedFreetextIds = {};

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Materialabschlag erstellen'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text('Alle Artikel-Positionen'),
              value: _includeAllArticles,
              onChanged: (value) => setState(() => _includeAllArticles = value ?? false),
            ),
            if (widget.freetextItems.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('Freitext-Positionen auswählen:'),
              ),
              for (final item in widget.freetextItems)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: Text(item.description),
                  value: _selectedFreetextIds.contains(item.existingId),
                  onChanged: (checked) => setState(() {
                    if (checked ?? false) {
                      _selectedFreetextIds.add(item.existingId!);
                    } else {
                      _selectedFreetextIds.remove(item.existingId);
                    }
                  }),
                ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
        FilledButton(
          onPressed: () => Navigator.pop(
            context,
            _MaterialAdvanceSelection(
              includeAllArticles: _includeAllArticles,
              selectedFreetextItemIds: _selectedFreetextIds,
            ),
          ),
          child: const Text('Erstellen'),
        ),
      ],
    );
  }
}
