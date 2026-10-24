import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:werkkern_client/werkkern_client.dart';
import 'package:werkkern_core/werkkern_core.dart';

import '../../../domain/services/online_session.dart';
import '../../../pdf/online_document_pdf.dart';

/// Detail/Bearbeitung eines Online-Dokuments. Lokale Änderungen werden
/// erst mit "Speichern" übertragen — immer mit der zuletzt gelesenen
/// Version. Hat ein anderes Gerät inzwischen gespeichert, lehnt der
/// Server ab (409) und die App fragt nach, statt still zu überschreiben
/// (B2-Vorgabe "kein last write wins").
class OnlineDocumentScreen extends StatefulWidget {
  const OnlineDocumentScreen({super.key, required this.session, required this.documentId});
  final OnlineSession session;
  final String documentId;

  @override
  State<OnlineDocumentScreen> createState() => _OnlineDocumentScreenState();
}

class _OnlineDocumentScreenState extends State<OnlineDocumentScreen> {
  OnlineDocument? _document;
  List<OnlineDocumentItem> _items = [];
  late final _notes = TextEditingController();
  bool _dirty = false;
  bool _busy = true;
  bool _isAdvancePayment = false;
  bool _isFixedPrice = false;

  /// § 19 UStG der Firma — neue Positionen dann fest 0 % USt.
  bool _smallBusiness = false;
  String? _error;

  WerkkernApiClient get _client => widget.session.client;
  OfflineStore? get _store => widget.session.offline;

  /// Aus dem Offline-Bestand geladen (keine Verbindung) — Speichern
  /// landet in der Outbox, serverpflichtige Aktionen sind gesperrt.
  bool _offlineView = false;

  /// Entwurf, oder finalisiertes Angebot/Auftrag/Proforma ohne Umwandlung
  /// (Server-Feld `editable`, Regel wie offline). Finalisierte nur online —
  /// offline lassen sich ausschließlich Entwürfe bearbeiten (B2).
  bool get _editable {
    final document = _document;
    if (document == null || !document.editable || !widget.session.can('invoices.write')) return false;
    return document.isDraft || !_offlineView;
  }

  bool get _pinned => _store?.isPinned(widget.documentId) ?? false;
  List<OutboxEntry> get _pending => _store?.pendingFor(widget.documentId) ?? const [];

  /// Finalisieren/Umwandeln/Zahlung/Löschen brauchen den Server und einen
  /// abgeglichenen Stand.
  bool get _serverActionsAllowed => !_offlineView && _pending.isEmpty;

  @override
  void initState() {
    super.initState();
    _reload();
    if (!widget.session.offlineOnly) {
      _client.companyProfile().then((p) {
        if (mounted) setState(() => _smallBusiness = p.smallBusinessExempt);
      }, onError: (Object _) {});
    }
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (widget.session.offlineOnly) {
        _loadFromStore();
        return;
      }
      final json = await _client.documentJson(widget.documentId);
      final store = _store;
      // Markierte Kopie aktuell halten — aber nie über noch nicht
      // übertragene Offline-Änderungen hinweg.
      if (store != null && store.isPinned(widget.documentId) && _pending.isEmpty) {
        await store.pin(json, store.customer(json['customerId'] as String));
      }
      if (!mounted) return;
      setState(() {
        _offlineView = false;
        _apply(OnlineDocument.fromJson(json));
      });
    } on ApiUnreachable catch (e) {
      if (_pinned) {
        _loadFromStore();
      } else if (mounted) {
        setState(() => _error = describeOnlineError(e));
      }
    } on Exception catch (e) {
      if (mounted) setState(() => _error = describeOnlineError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _loadFromStore() {
    final cached = _store?.document(widget.documentId);
    setState(() {
      if (cached == null) {
        _error = 'Dieses Dokument ist nicht offline verfügbar.';
      } else {
        _offlineView = true;
        _apply(cached);
      }
    });
  }

  Future<void> _togglePinned() async {
    final store = _store!;
    final document = _document!;
    try {
      if (store.isPinned(document.id)) {
        await store.unpin(document.id);
        _snack('Nicht mehr offline verfügbar — vom Gerät entfernt.');
      } else {
        OnlineCustomer? customer;
        if (widget.session.can('customers.read')) {
          customer = (await _client.customers()).where((c) => c.id == document.customerId).firstOrNull;
        }
        await store.pin(await _client.documentJson(document.id), customer);
        _snack('Offline verfügbar — verschlüsselt auf diesem Gerät.');
      }
      widget.session.offlineChanged();
      if (mounted) setState(() {});
    } on StateError catch (e) {
      _snack(e.message);
    } on Exception catch (e) {
      _snack(describeOnlineError(e));
    }
  }

  /// Änderung in die Outbox (offline). [sentOpId]/[sentVersion]: online
  /// bereits gesendet, Antwort verloren — unter derselben ID nachreichen.
  Future<void> _saveOffline({String? sentOpId, int? sentVersion}) async {
    final notes = _notes.text.trim().isEmpty ? null : _notes.text.trim();
    await _store!.enqueueUpdate(
      widget.documentId,
      items: _items,
      notes: notes,
      sentOpId: sentOpId,
      sentVersion: sentVersion,
    );
    widget.session.offlineChanged();
    if (!mounted) return;
    setState(() {
      _offlineView = sentOpId == null ? _offlineView : true;
      _dirty = false;
    });
    _snack('Offline gespeichert — wird beim nächsten Abgleich übertragen.');
  }

  Future<void> _discardPending(OutboxEntry entry) async {
    await _store!.discard(entry.opId);
    widget.session.offlineChanged();
    if (widget.session.offlineOnly) {
      _snack('Änderung verworfen. Der Serverstand wird beim nächsten Abgleich geladen.');
      if (mounted) setState(() {});
    } else {
      await _reload();
    }
  }

  Future<void> _syncNow() async {
    setState(() => _busy = true);
    try {
      final result = await widget.session.sync();
      if (mounted) _snack(describeSyncResult(result));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    await _reload();
  }

  void _apply(OnlineDocument document) {
    _document = document;
    _items = [...document.items];
    _notes.text = document.notes ?? '';
    _isAdvancePayment = document.isAdvancePayment;
    _isFixedPrice = document.isFixedPrice;
    _dirty = false;
  }

  /// Neue Statusmeldung ersetzt eine noch sichtbare/wartende ältere.
  void _snack(String message) => ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(SnackBar(content: Text(message)));

  /// 409 -> Nutzer entscheidet ausdrücklich; nichts wird überschrieben.
  Future<void> _handleConflict(ApiException e) async {
    final reload = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Zwischenzeitlich geändert'),
        content: Text(
          '${e.message}\n\nDeine Änderungen wurden NICHT gespeichert. Neu laden zeigt den aktuellen Stand vom '
          'Server und verwirft deine lokalen Änderungen.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Abbrechen')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Neu laden')),
        ],
      ),
    );
    if (reload == true) await _reload();
  }

  Future<void> _run(
    Future<OnlineDocument> Function() action,
    String success, {
    bool rethrowUnreachable = false,
  }) async {
    setState(() => _busy = true);
    Object? failure;
    try {
      final document = await action();
      if (!mounted) return;
      final store = _store;
      if (store != null && store.isPinned(document.id) && _pending.isEmpty) {
        await store.pin(document.rawJson, store.customer(document.customerId));
      }
      if (!mounted) return;
      setState(() => _apply(document));
      _snack(success);
    } on ApiUnreachable {
      if (rethrowUnreachable) {
        if (mounted) setState(() => _busy = false);
        rethrow;
      }
      failure = const ApiUnreachable('keine Verbindung');
    } on Exception catch (e) {
      failure = e;
    } finally {
      // Vor einem Konflikt-Dialog beenden — sonst läuft der Ladebalken
      // hinter dem Dialog endlos weiter.
      if (mounted) setState(() => _busy = false);
    }
    if (failure == null || !mounted) return;
    if (failure is ApiException && failure.isConflict) {
      await _handleConflict(failure);
    } else {
      _snack(describeOnlineError(failure));
    }
  }

  Future<void> _save() async {
    if (_offlineView) return _saveOffline();
    final version = _document!.version;
    // Mit Operations-ID senden: geht die Antwort verloren, wird genau
    // diese Änderung später unter derselben ID nachgereicht.
    final opId = _pinned ? OfflineStore.newOpId() : null;
    final notes = _notes.text.trim().isEmpty ? null : _notes.text.trim();
    try {
      await _run(
        () => _client.updateDocument(
          id: widget.documentId,
          version: version,
          items: _items,
          notes: notes,
          idempotencyKey: opId,
          isAdvancePayment: _document!.kind == 'invoice' ? _isAdvancePayment : null,
          isFixedPrice: {'quote', 'order'}.contains(_document!.kind) ? _isFixedPrice : null,
        ),
        'Gespeichert.',
        rethrowUnreachable: _pinned,
      );
    } on ApiUnreachable {
      await _saveOffline(sentOpId: opId, sentVersion: version);
    }
  }

  Future<void> _finalize() async {
    final label = onlineDocumentKindLabels[_document!.kind] ?? 'Dokument';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$label finalisieren?'),
        content: const Text(
          'Vergibt die nächste Nummer und macht das Dokument unveränderlich. Kunden- und Firmendaten werden '
          'zum jetzigen Stand eingefroren.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Abbrechen')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Finalisieren')),
        ],
      ),
    );
    if (confirmed != true) return;
    await _run(() => _client.finalizeDocument(widget.documentId, version: _document!.version), 'Finalisiert.');
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Entwurf löschen?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Abbrechen')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Löschen')),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _client.deleteDocument(widget.documentId);
      if (mounted) Navigator.of(context).pop();
    } on Exception catch (e) {
      if (mounted) _snack(describeOnlineError(e));
    }
  }

  /// PDF aus dem gespeicherten Serverstand. Finalisierte Dokumente
  /// dürfen geteilt/gedruckt werden, Entwürfe nur angesehen (wie
  /// offline: kein unfertiges Dokument verschicken).
  Future<void> _showPdf() async {
    final document = _document!;
    OnlineCompanyProfile? company;
    OnlineCustomer? customer;
    if (document.isDraft) {
      try {
        company = await _client.companyProfile();
        if (widget.session.can('customers.read')) {
          customer = (await _client.customers()).where((c) => c.id == document.customerId).firstOrNull;
        }
      } on Exception catch (e) {
        if (mounted) _snack(describeOnlineError(e));
        return;
      }
    }
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(title: Text(document.isDraft ? 'Vorschau (Entwurf, nicht final)' : document.number!)),
          body: PdfPreview(
            build: (_) => buildOnlineDocumentPdf(document, liveCompany: company, liveCustomer: customer),
            canChangeOrientation: false,
            canChangePageFormat: false,
            allowSharing: !document.isDraft,
            allowPrinting: !document.isDraft,
            pdfFileName: '${document.number ?? 'entwurf'}.pdf',
          ),
        ),
      ),
    );
  }

  Future<void> _convert(String targetKind) async {
    final label = onlineDocumentKindLabels[targetKind] ?? targetKind;
    setState(() => _busy = true);
    try {
      final created = await _client.convertDocument(widget.documentId, targetKind);
      if (!mounted) return;
      _snack('$label als Entwurf angelegt.');
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => OnlineDocumentScreen(session: widget.session, documentId: created.id)),
      );
    } on Exception catch (e) {
      if (mounted) _snack(describeOnlineError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _createCreditNote() async {
    setState(() => _busy = true);
    try {
      final created = await _client.createCreditNote(widget.documentId);
      if (!mounted) return;
      _snack('Gutschrift als Entwurf angelegt — vor dem Finalisieren ggf. kürzen.');
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => OnlineDocumentScreen(session: widget.session, documentId: created.id)),
      );
    } on Exception catch (e) {
      if (mounted) _snack(describeOnlineError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _togglePaid() =>
      _run(() => _client.setPaid(widget.documentId, paid: !_document!.isPaid), 'Zahlungsstatus gespeichert.');

  Future<void> _pickDueDate() async {
    final current = _document!.dueDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now().add(const Duration(days: 14)),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    await _run(() => _client.setDueDate(widget.documentId, picked), 'Fälligkeit gespeichert.');
  }

  /// Folgeaktionen eines finalisierten Dokuments: Umwandlung und —
  /// bei Rechnungen — Zahlungsstatus/Fälligkeit.
  Widget _buildFinalizedSection(OnlineDocument document) {
    final session = widget.session;
    final dateFormat = DateFormat('dd.MM.yyyy');
    final targets = [
      for (final target in documentConversionTargets[document.kind] ?? const <String>{})
        if (onlineDocumentKindModules[target] == null || session.modules.contains(onlineDocumentKindModules[target]))
          target,
    ];
    final canConvert = session.can('invoices.write') && targets.isNotEmpty;
    final canPay = session.can('invoices.payment');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (document.kind == 'invoice')
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Text über den Aktionen statt daneben — auf schmalen
                  // Handys (~330 px) liefe eine Zeile sonst über.
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(document.isPaid ? Icons.check_circle_outline : Icons.schedule),
                    title: Text(
                      document.isPaid
                          ? 'Bezahlt${document.paidAt == null ? '' : ' am ${dateFormat.format(document.paidAt!.toLocal())}'}'
                          : 'Offen',
                    ),
                    subtitle: Text(
                      document.dueDate == null ? 'Keine Fälligkeit' : 'Fällig am ${dateFormat.format(document.dueDate!)}',
                    ),
                  ),
                  if (canPay)
                    Wrap(
                      spacing: 8,
                      children: [
                        TextButton(
                          onPressed: _busy ? null : _togglePaid,
                          child: Text(document.isPaid ? 'Als offen markieren' : 'Als bezahlt markieren'),
                        ),
                        TextButton(onPressed: _busy ? null : _pickDueDate, child: const Text('Fälligkeit setzen')),
                      ],
                    ),
                ],
              ),
            ),
          ),
        if (document.convertedTo.isNotEmpty)
          Card(
            child: Column(
              children: [
                for (final c in document.convertedTo)
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.subdirectory_arrow_right),
                    title: Text(c.number ?? '${onlineDocumentKindLabels[c.kind] ?? c.kind} (Entwurf)'),
                    subtitle: Text('Folgedokument · ${onlineDocumentKindLabels[c.kind] ?? c.kind}'),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => OnlineDocumentScreen(session: session, documentId: c.id),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        if (document.creditNotes.isNotEmpty)
          Card(
            child: Column(
              children: [
                for (final c in document.creditNotes)
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.undo),
                    title: Text('Gutschrift ${c.number ?? ''}'),
                    trailing: Text('− ${Money.fromCents(c.grossCents)}'),
                  ),
              ],
            ),
          ),
        if (document.kind == 'invoice' && session.modules.contains('creditNotes') && session.can('invoices.write'))
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: _busy ? null : _createCreditNote,
              icon: const Icon(Icons.undo),
              label: const Text('Gutschrift erstellen'),
            ),
          ),
        if (canConvert)
          Wrap(
            spacing: 8,
            children: [
              for (final target in targets)
                OutlinedButton.icon(
                  onPressed: _busy ? null : () => _convert(target),
                  icon: const Icon(Icons.transform),
                  label: Text('In ${onlineDocumentKindLabels[target] ?? target} umwandeln'),
                ),
            ],
          ),
      ],
    );
  }

  Future<void> _addItem() async {
    List<OnlineArticle> articles = const [];
    if (widget.session.can('articles.read')) {
      try {
        articles = await _client.articles();
      } on Exception {
        // Ohne Artikelliste bleiben Stunden/Freitext/manuelle Artikel möglich.
      }
    }
    if (!mounted) return;
    final item = await showDialog<OnlineDocumentItem>(
      context: context,
      builder: (_) => _ItemDialog(articles: articles, forceZeroVat: _smallBusiness),
    );
    if (item == null) return;
    setState(() {
      _items = [..._items, item];
      _dirty = true;
    });
  }

  InvoiceTotals get _totals => calculateInvoiceTotals([
        for (final i in _items)
          InvoiceLineInput(
            quantity: Decimal.parse(i.quantity),
            unitPriceCents: i.unitPriceCents,
            vatRatePercent: i.vatRatePercent,
            discountPercent: i.discountPercent,
          ),
      ]);

  @override
  Widget build(BuildContext context) {
    final document = _document;
    final label = document == null ? 'Dokument' : (onlineDocumentKindLabels[document.kind] ?? document.kind);
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final discard = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Ungespeicherte Änderungen verwerfen?'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Weiter bearbeiten')),
              FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Verwerfen')),
            ],
          ),
        );
        if (discard == true && context.mounted) {
          setState(() => _dirty = false);
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(document?.number ?? '$label (Entwurf)'),
          actions: [
            if (document != null && _store != null && !widget.session.offlineOnly && !_offlineView)
              IconButton(
                tooltip: _pinned ? 'Nicht mehr offline verfügbar' : 'Offline verfügbar machen',
                icon: Icon(_pinned ? Icons.offline_pin : Icons.download_for_offline_outlined),
                onPressed: _busy ? null : _togglePinned,
              ),
            if (document != null && !_dirty)
              IconButton(
                tooltip: document.isDraft ? 'PDF-Vorschau (Entwurf)' : 'PDF',
                icon: const Icon(Icons.picture_as_pdf_outlined),
                onPressed: _busy ? null : _showPdf,
              ),
            if (_editable && document!.isDraft && _serverActionsAllowed)
              IconButton(tooltip: 'Entwurf löschen', icon: const Icon(Icons.delete_outline), onPressed: _busy ? null : _delete),
          ],
        ),
        body: _error != null
            ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!)))
            : document == null
                ? const Center(child: CircularProgressIndicator())
                : _buildBody(document, label),
        bottomNavigationBar: document == null ? null : _buildActions(document),
      ),
    );
  }

  Widget _buildBody(OnlineDocument document, String label) {
    final totals = _totals;
    final dateFormat = DateFormat('dd.MM.yyyy');
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        if (_busy) const LinearProgressIndicator(),
        if (_offlineView)
          const Card(
            child: ListTile(
              leading: Icon(Icons.cloud_off_outlined),
              title: Text('Offline-Kopie'),
              subtitle: Text('Bearbeiten möglich; Finalisieren, Umwandeln und Zahlungen erst mit Verbindung.'),
            ),
          ),
        for (final entry in _pending)
          Card(
            color: entry.status == OutboxStatus.pending ? null : Theme.of(context).colorScheme.errorContainer,
            child: ListTile(
              leading: Icon(entry.status == OutboxStatus.pending ? Icons.sync : Icons.sync_problem),
              title: Text(switch (entry.status) {
                OutboxStatus.pending => 'Offline-Änderung, noch nicht übertragen',
                OutboxStatus.conflict => 'Konflikt: inzwischen anders gespeichert',
                OutboxStatus.rejected => 'Vom Server abgewiesen',
              }),
              subtitle: entry.message == null ? null : Text(entry.message!),
              trailing: Wrap(
                children: [
                  if (entry.status == OutboxStatus.pending && !widget.session.offlineOnly)
                    TextButton(onPressed: _busy ? null : _syncNow, child: const Text('Abgleichen')),
                  TextButton(
                    onPressed: _busy ? null : () => _discardPending(entry),
                    child: const Text('Verwerfen'),
                  ),
                ],
              ),
            ),
          ),
        Card(
          child: ListTile(
            title: Text(
              '${document.isAdvancePayment ? 'Abschlagsrechnung' : label} · ${document.isDraft ? 'Entwurf' : 'finalisiert'}'
              '${document.kind == 'creditNote' && document.convertedFromNumber != null ? ' · zu ${document.convertedFromNumber}' : ''}',
            ),
            subtitle: Text(
              [
                'Datum ${dateFormat.format(document.issueDate)}',
                if (document.displayCustomerName != null) 'Kunde ${document.displayCustomerName}',
                // C3: gebuchte Ist-Stunden neben den geplanten Positionen.
                if (document.rawJson['bookedHours'] is String && document.rawJson['bookedHours'] != '0')
                  'Gebucht ${(document.rawJson['bookedHours'] as String).replaceAll('.', ',')} Std.',
                'Version ${document.version}',
              ].join(' · '),
            ),
          ),
        ),
        // Umwandeln erst mit gespeichertem Stand — sonst übernähme die
        // Folgeurkunde nicht das, was auf dem Bildschirm steht.
        if (!document.isDraft && _serverActionsAllowed && !_dirty) _buildFinalizedSection(document),
        const SizedBox(height: 8),
        Text('Positionen', style: Theme.of(context).textTheme.titleMedium),
        if (_items.isEmpty) const Padding(padding: EdgeInsets.all(8), child: Text('Noch keine Positionen.')),
        for (final (index, item) in _items.indexed)
          Card(
            child: ListTile(
              title: Text(item.description),
              subtitle: Text(
                '${item.quantity.replaceAll('.', ',')} ${item.unit ?? ''} × ${Money.fromCents(item.unitPriceCents)}'
                ' · ${item.vatRatePercent.toStringAsFixed(0)} %${item.groupLabel != null ? ' · ${item.groupLabel}' : ''}',
              ),
              trailing: _editable
                  ? IconButton(
                      tooltip: 'Position entfernen',
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: () => setState(() {
                        _items = [..._items]..removeAt(index);
                        _dirty = true;
                      }),
                    )
                  : null,
            ),
          ),
        if (_editable)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(onPressed: _addItem, icon: const Icon(Icons.add), label: const Text('Position hinzufügen')),
          ),
        if (_editable && document.kind == 'invoice' && widget.session.modules.contains('advancePaymentInvoices'))
          SwitchListTile(
            title: const Text('Abschlagsrechnung'),
            subtitle: const Text('Eine spätere Schlussrechnung aus demselben Auftrag zieht sie einzeln ab.'),
            value: _isAdvancePayment,
            onChanged: _offlineView
                ? null
                : (v) => setState(() {
                      _isAdvancePayment = v;
                      _dirty = true;
                    }),
          ),
        if (_editable && {'quote', 'order'}.contains(document.kind))
          SwitchListTile(
            title: const Text('Festpreis vereinbart'),
            subtitle: const Text('Ohne Festpreis übernimmt die Rechnung die gebuchten Ist-Stunden.'),
            value: _isFixedPrice,
            onChanged: _offlineView
                ? null
                : (v) => setState(() {
                      _isFixedPrice = v;
                      _dirty = true;
                    }),
          ),
        const SizedBox(height: 8),
        TextField(
          controller: _notes,
          enabled: _editable,
          maxLines: 2,
          decoration: const InputDecoration(labelText: 'Notizen'),
          onChanged: (_) => setState(() => _dirty = true),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                for (final rate in totals.sortedRates)
                  _row('Netto ${rate.toStringAsFixed(0)} % / USt', '${totals.netByRate[rate]} / ${totals.taxByRate[rate]}'),
                const Divider(),
                _row('Netto', totals.totalNet.toString()),
                _row('USt', totals.totalTax.toString()),
                _row('Brutto', totals.totalGross.toString(), bold: true),
                // C13: jede Abschlagsrechnung einzeln mit Nummer (wie offline).
                for (final a in document.advancePayments)
                  _row('Abschlagsrechnung ${a.number ?? ''}', '− ${Money.fromCents(a.grossCents)}'),
                if (document.remainingCents != null && !_dirty)
                  _row('Restbetrag', Money.fromCents(document.remainingCents!).toString(), bold: true),
              ],
            ),
          ),
        ),
        if (_dirty)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('Ungespeicherte Änderungen — erst nach "Speichern" auf dem Server.'),
          ),
      ],
    );
  }

  Widget _row(String label, String value, {bool bold = false}) {
    final style = bold ? const TextStyle(fontWeight: FontWeight.bold) : null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(children: [Expanded(child: Text(label, style: style)), Text(value, style: style)]),
    );
  }

  Widget? _buildActions(OnlineDocument document) {
    if (!document.isDraft && !_editable) return null;
    final canFinalize = document.isDraft && widget.session.can('invoices.finalize');
    if (!_editable && !canFinalize) return null;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            if (_editable)
              Expanded(
                child: OutlinedButton(
                  onPressed: _busy || !_dirty ? null : _save,
                  child: Text(_offlineView ? 'Offline speichern' : 'Speichern'),
                ),
              ),
            if (_editable && canFinalize) const SizedBox(width: 12),
            if (canFinalize)
              Expanded(
                child: FilledButton(
                  // Erst speichern, dann finalisieren — finalisiert wird
                  // genau der Stand, den der Server kennt.
                  onPressed: _busy || _dirty || _items.isEmpty || !_serverActionsAllowed ? null : _finalize,
                  child: const Text('Finalisieren'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ItemDialog extends StatefulWidget {
  const _ItemDialog({required this.articles, this.forceZeroVat = false});
  final List<OnlineArticle> articles;

  /// Kleinunternehmerregelung: USt fest 0 % (der Server erzwingt es ohnehin).
  final bool forceZeroVat;

  @override
  State<_ItemDialog> createState() => _ItemDialogState();
}

class _ItemDialogState extends State<_ItemDialog> {
  OnlineItemKind _kind = OnlineItemKind.hours;
  OnlineArticle? _article;
  final _description = TextEditingController();
  final _quantity = TextEditingController(text: '1');
  final _price = TextEditingController();
  final _unit = TextEditingController();
  final _group = TextEditingController();
  late double _vat = widget.forceZeroVat ? 0 : 19;
  String? _error;

  @override
  void dispose() {
    for (final c in [_description, _quantity, _price, _unit, _group]) {
      c.dispose();
    }
    super.dispose();
  }

  void _pickArticle(OnlineArticle? article) {
    setState(() {
      _article = article;
      if (article != null) {
        _description.text = article.name;
        _unit.text = article.unit ?? '';
        if (article.salePriceCents != null) _price.text = Money.fromCents(article.salePriceCents!).formatEuro();
      }
    });
  }

  void _submit() {
    final quantity = Decimal.tryParse(_quantity.text.trim().replaceAll(',', '.'));
    if (_description.text.trim().isEmpty || quantity == null || _price.text.trim().isEmpty) {
      setState(() => _error = 'Beschreibung, Menge und Einzelpreis sind Pflicht.');
      return;
    }
    final Money price;
    try {
      price = Money.fromEuroString(_price.text);
    } on FormatException {
      setState(() => _error = 'Einzelpreis ist keine gültige Zahl.');
      return;
    }
    Navigator.pop(
      context,
      OnlineDocumentItem(
        kind: _kind,
        articleId: _kind == OnlineItemKind.article ? _article?.id : null,
        description: _description.text.trim(),
        quantity: quantity.toString(),
        unitPriceCents: price.cents,
        vatRatePercent: _vat,
        unit: _unit.text.trim().isEmpty ? null : _unit.text.trim(),
        groupLabel: _group.text.trim().isEmpty ? null : _group.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Position'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SegmentedButton<OnlineItemKind>(
                segments: const [
                  ButtonSegment(value: OnlineItemKind.article, label: Text('Artikel')),
                  ButtonSegment(value: OnlineItemKind.hours, label: Text('Stunden')),
                  ButtonSegment(value: OnlineItemKind.text, label: Text('Freitext')),
                ],
                selected: {_kind},
                onSelectionChanged: (s) => setState(() => _kind = s.first),
              ),
              if (_kind == OnlineItemKind.article && widget.articles.isNotEmpty)
                DropdownButtonFormField<OnlineArticle>(
                  initialValue: _article,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Artikel aus Stamm (optional)'),
                  items: [
                    for (final a in widget.articles.where((a) => a.active))
                      DropdownMenuItem(value: a, child: Text(a.name, overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged: _pickArticle,
                ),
              TextField(key: const Key('online-item-description'), controller: _description, decoration: const InputDecoration(labelText: 'Beschreibung *')),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const Key('online-item-quantity'),
                      controller: _quantity,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Menge *'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: TextField(controller: _unit, decoration: const InputDecoration(labelText: 'Einheit'))),
                ],
              ),
              TextField(
                key: const Key('online-item-price'),
                controller: _price,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Einzelpreis netto (€) *'),
              ),
              DropdownButtonFormField<double>(
                initialValue: _vat,
                decoration: const InputDecoration(labelText: 'USt-Satz'),
                items: const [
                  DropdownMenuItem(value: 19, child: Text('19 %')),
                  DropdownMenuItem(value: 7, child: Text('7 %')),
                  DropdownMenuItem(value: 0, child: Text('0 %')),
                ],
                onChanged: widget.forceZeroVat ? null : (v) => setState(() => _vat = v!),
              ),
              if (widget.forceZeroVat)
                const Text('Kleinunternehmerregelung (§ 19 UStG): keine Umsatzsteuer.', style: TextStyle(fontSize: 12)),
              TextField(controller: _group, decoration: const InputDecoration(labelText: 'Positionsgruppe (optional)')),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
        FilledButton(onPressed: _submit, child: const Text('Übernehmen')),
      ],
    );
  }
}
