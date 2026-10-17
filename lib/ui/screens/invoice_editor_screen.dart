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
import '../../domain/models/money.dart';
import '../../domain/services/active_company_service.dart';
import '../../domain/services/invoice_totals_service.dart';
import '../../pdf/invoice_pdf_builder.dart';
import '../widgets/invoice_item_dialog.dart';
import 'invoices_screen.dart' show DocumentLabels;

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

    final invoice = widget.invoice;
    _currentInvoice = invoice;
    if (invoice != null) {
      _issueDate = invoice.issueDate;
      _serviceDate = invoice.serviceDate;
      _notesCtrl.text = invoice.notes ?? '';
      _paymentTermsCtrl.text = invoice.paymentTerms ?? '';
      _projectId = invoice.projectId;
      _isAdvancePayment = invoice.isAdvancePayment;
      if (invoice.status == InvoiceStatus.finalized) {
        _hasBeenConverted = (await invoiceRepo.listConvertedFrom(invoice.id)).isNotEmpty;
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
    try {
      final draft = await repo.convertTo(
        companyId: companyId,
        sourceId: invoice.id,
        targetKind: targetKind,
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

    setState(() => _finalizing = true);
    try {
      final companyId = context.read<ActiveCompanyService>().active!.id;
      final repo = context.read<InvoiceRepository>();
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
