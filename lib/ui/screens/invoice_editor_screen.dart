import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../../data/database/database.dart';
import '../../data/database/tables.dart';
import '../../data/repositories/article_repository.dart';
import '../../data/repositories/invoice_repository.dart';
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
  });

  final Customer customer;

  /// `null` = neues Dokument.
  final Invoice? invoice;

  /// Dokumentart für ein **neues** Dokument. Existiert bereits
  /// [invoice], gilt stattdessen dessen eigene `kind` (eine Dokumentart
  /// ist nach dem Anlegen nicht mehr wechselbar, siehe [_kind]).
  final DocumentKind kind;

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
    this.groupLabel,
    this.existingId,
  });

  final InvoiceItemKind kind;
  final String? articleId;
  final String description;
  final Decimal quantity;
  final int unitPriceCents;
  final double vatRatePercent;
  final String? groupLabel;
  final String? existingId;

  /// Für den Bearbeiten-Dialog (Kay-Nachtrag 2026-10-16) — exakt die
  /// Felder, die [InvoiceItemInputResult] ohnehin schon trägt.
  InvoiceItemInputResult toResult() => InvoiceItemInputResult(
        kind: kind,
        articleId: articleId,
        description: description,
        quantity: quantity,
        unitPriceCents: unitPriceCents,
        vatRatePercent: vatRatePercent,
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

  bool get _isFinalized => _currentInvoice?.status == InvoiceStatus.finalized;
  DocumentKind get _kind => _currentInvoice?.kind ?? widget.kind;

  @override
  void initState() {
    super.initState();
    _issueDate = DateTime.now();
    _serviceDate = DateTime.now();
    _init();
  }

  Future<void> _init() async {
    final companyId = context.read<ActiveCompanyService>().active!.id;
    final articleRepo = context.read<ArticleRepository>();
    final invoiceRepo = context.read<InvoiceRepository>();
    _articles = await articleRepo.listForCompany(companyId);

    final invoice = widget.invoice;
    _currentInvoice = invoice;
    if (invoice != null) {
      _issueDate = invoice.issueDate;
      _serviceDate = invoice.serviceDate;
      _notesCtrl.text = invoice.notes ?? '';
      _paymentTermsCtrl.text = invoice.paymentTerms ?? '';
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
          items: items,
        );
      }
      if (mounted) {
        setState(() => _currentInvoice = saved);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Entwurf gespeichert.')),
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
      final bytes = await buildInvoicePdf(invoice: invoice, items: items, company: company);
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
          if (!isFinalized) ...[
            IconButton(
              icon: const Icon(Icons.visibility_outlined),
              tooltip: 'Vorschau (unverbindlich)',
              onPressed: _items.isEmpty ? null : _previewDraft,
            ),
            IconButton(
              icon: _saving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.save_outlined),
              tooltip: 'Entwurf speichern',
              onPressed: _saving ? null : _save,
            ),
            if (_currentInvoice != null)
              IconButton(
                icon: _finalizing
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.check_circle_outline),
                tooltip: 'Finalisieren',
                onPressed: _finalizing ? null : _finalize,
              ),
          ],
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
                'nicht mehr änderbar.',
                style: TextStyle(color: Theme.of(context).colorScheme.primary),
              ),
            ),
          TextField(
            controller: _paymentTermsCtrl,
            readOnly: isFinalized,
            decoration: const InputDecoration(labelText: 'Zahlungsbedingungen'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _notesCtrl,
            readOnly: isFinalized,
            decoration: const InputDecoration(labelText: 'Notizen'),
            maxLines: 2,
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
            for (final item in groups[key]!)
              Card(
                child: ListTile(
                  title: Text(item.description),
                  subtitle: Text(
                    '${item.quantity} × ${Money.fromCents(item.unitPriceCents)} '
                    '(${item.vatRatePercent.toStringAsFixed(0)} %)',
                  ),
                  onTap: isFinalized ? null : () => _editItem(item),
                  trailing: isFinalized
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => setState(() => _items.remove(item)),
                        ),
                ),
              ),
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
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: isFinalized
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
