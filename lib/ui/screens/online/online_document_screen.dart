import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:werkkern_client/werkkern_client.dart';
import 'package:werkkern_core/werkkern_core.dart';

import '../../../domain/services/online_session.dart';
import '../../../pdf/dunning_letter_pdf_builder.dart';
import '../../../pdf/online_document_pdf.dart';
import 'online_documents_screen.dart' show onlineEditorTitle;
import 'online_dunning_screen.dart';
import 'online_item_dialog.dart';
import 'online_mail.dart';
import 'online_purchasing_screen.dart' show createPurchaseOrdersFromDocument;

/// Detail/Bearbeitung eines Online-Dokuments — Aufbau wie der Offline-
/// Editor (`invoice_editor_screen.dart`): Aktionen in der Titelleiste,
/// Zahlungsbedingungen/Notizen/Projekt, Mahnwesen, Positionen nach
/// Gruppen mit Gruppensumme, Summenkarte. Lokale Änderungen werden
/// erst mit "Speichern" übertragen — immer mit der zuletzt gelesenen
/// Version. Hat ein anderes Gerät inzwischen gespeichert, lehnt der
/// Server ab (409) und die App fragt nach, statt still zu überschreiben
/// (B2-Vorgabe "kein last write wins").
class OnlineDocumentScreen extends StatefulWidget {
  const OnlineDocumentScreen({super.key, required this.session, required this.documentId, this.onChanged, this.onNavigate});
  final OnlineSession session;
  final String documentId;

  /// Breit-Layout (eingebettet neben der Liste): nach jeder gespeicherten
  /// Änderung, damit die Liste nachlädt.
  final VoidCallback? onChanged;

  /// Eingebettet: statt Seitenwechsel das Folgedokument (Umwandlung,
  /// Gutschrift) bzw. nach dem Löschen nichts (`null`) anzeigen.
  final ValueChanged<String?>? onNavigate;

  @override
  State<OnlineDocumentScreen> createState() => _OnlineDocumentScreenState();
}

class _OnlineDocumentScreenState extends State<OnlineDocumentScreen> {
  OnlineDocument? _document;
  List<OnlineDocumentItem> _items = [];
  late final _notes = TextEditingController();
  late final _paymentTerms = TextEditingController();
  String? _projectId;
  List<OnlineProject> _projects = const [];

  /// Fälligkeit im Entwurf — wird mit „Speichern“ übertragen; finalisiert
  /// sofort über die Zahlungs-Route (wie offline).
  DateTime? _dueDate;
  DunningConfig? _dunningConfig;
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
      final session = widget.session;
      if (_projectsEnabled) {
        _client.projects().then((projects) {
          if (mounted) setState(() => _projects = projects);
        }, onError: (Object _) {});
      }
      if (_dunningEnabled && session.can('dunning.read')) {
        _client.dunningSettings().then((s) {
          if (mounted) setState(() => _dunningConfig = _configFrom(s));
        }, onError: (Object _) {});
      }
    }
  }

  bool get _projectsEnabled => widget.session.modules.contains('projects') && widget.session.can('projects.read');
  bool get _dunningEnabled => widget.session.modules.contains('dunning');

  static DunningConfig _configFrom(Map<String, Object?> s) => DunningConfig(
        reminder2AfterDays: s['reminder2AfterDays'] as int? ?? 14,
        reminder3AfterDays: s['reminder3AfterDays'] as int? ?? 28,
        feeLevel1: Money.fromCents(s['feeLevel1Cents'] as int? ?? 0),
        feeLevel2: Money.fromCents(s['feeLevel2Cents'] as int? ?? 0),
        feeLevel3: Money.fromCents(s['feeLevel3Cents'] as int? ?? 0),
        interestRatePercent: (s['interestRatePercent'] as num? ?? 0).toDouble(),
      );

  @override
  void dispose() {
    _notes.dispose();
    _paymentTerms.dispose();
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
    _paymentTerms.text = document.paymentTerms ?? '';
    _projectId = document.projectId;
    _dueDate = document.dueDate;
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
      widget.onChanged?.call();
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
    final document = _document!;
    final version = document.version;
    // Mit Operations-ID senden: geht die Antwort verloren, wird genau
    // diese Änderung später unter derselben ID nachgereicht.
    final opId = _pinned ? OfflineStore.newOpId() : null;
    final notes = _notes.text.trim().isEmpty ? null : _notes.text.trim();
    final paymentTerms = _paymentTerms.text.trim().isEmpty ? null : _paymentTerms.text.trim();
    final dueDate = _dueDate;
    final projectId = _projectId;
    final projectChanged = document.isDraft && _projectsEnabled && projectId != document.projectId;
    try {
      await _run(
        () async {
          var saved = await _client.updateDocument(
            id: widget.documentId,
            version: version,
            items: _items,
            notes: notes,
            paymentTerms: () => paymentTerms,
            dueDate: document.isDraft && document.kind == 'invoice' && _dunningEnabled ? () => dueDate : null,
            idempotencyKey: opId,
            isAdvancePayment: document.kind == 'invoice' ? _isAdvancePayment : null,
            isFixedPrice: {'quote', 'order'}.contains(document.kind) ? _isFixedPrice : null,
          );
          if (projectChanged) {
            saved = await _client.setDocumentProject(saved.id, version: saved.version, projectId: projectId);
          }
          return saved;
        },
        document.isDraft ? 'Entwurf gespeichert.' : 'Änderungen gespeichert.',
        rethrowUnreachable: _pinned,
      );
    } on ApiUnreachable {
      await _saveOffline(sentOpId: opId, sentVersion: version);
    }
  }

  Future<void> _finalize() async {
    final label = onlineDocumentKindLabels[_document!.kind] ?? 'Dokument';
    // C5.1: nicht blockierender Hinweis auf zu geringen Bestand.
    var warnings = const <OnlineStockWarning>[];
    if (widget.session.modules.contains('lagerbestand')) {
      try {
        warnings = (await _client.stockCheck(widget.documentId)).warnings;
      } on Exception {
        // Hinweis ist optional — Finalisieren bleibt möglich.
      }
    }
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$label finalisieren?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${onlineFinalizeConfirmSentence(_document!.kind)} Diese Aktion ist nicht umkehrbar.'),
            for (final w in warnings)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Bestand zu gering: ${w.articleName} — benötigt ${w.requested.replaceAll('.', ',')}, '
                  'vorhanden ${w.available.replaceAll('.', ',')}.',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
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
      if (!mounted) return;
      final navigate = widget.onNavigate;
      navigate == null ? Navigator.of(context).pop() : navigate(null);
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
      await _replaceWith(created.id);
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
      await _replaceWith(created.id);
    } on Exception catch (e) {
      if (mounted) _snack(describeOnlineError(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Folgedokument statt dieses Dokuments zeigen.
  Future<void> _replaceWith(String id) async {
    final navigate = widget.onNavigate;
    if (navigate != null) return navigate(id);
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => OnlineDocumentScreen(session: widget.session, documentId: id)),
    );
  }

  Future<void> _togglePaid() =>
      _run(() => _client.setPaid(widget.documentId, paid: !_document!.isPaid), 'Zahlungsstatus gespeichert.');

  /// Fälligkeit jederzeit änderbar (wie offline): im Entwurf Teil von
  /// „Speichern“, finalisiert sofort über die Zahlungs-Route.
  Future<void> _pickDueDate() async {
    final document = _document!;
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    if (document.isDraft) {
      setState(() {
        _dueDate = picked;
        _dirty = true;
      });
      return;
    }
    await _run(() => _client.setDueDate(widget.documentId, picked), 'Fälligkeit gespeichert.');
  }

  /// Mahnschreiben zur aktuellen Stufe: Mahnung protokollieren (Server
  /// berechnet Gebühr/Zins) und als PDF zeigen bzw. direkt mailen.
  Future<({OnlineDunningNotice notice, OnlineCompanyProfile company})?> _createNotice() async {
    setState(() => _busy = true);
    try {
      final notice = await _client.createDunningNotice(widget.documentId);
      final company = await _client.companyProfile();
      return (notice: notice, company: company);
    } on Exception catch (e) {
      if (mounted) _snack(describeOnlineError(e));
      return null;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _generateDunningLetter() async {
    final created = await _createNotice();
    if (created == null || !mounted) return;
    await showDunningLetter(
      context,
      session: widget.session,
      document: _document!,
      notice: created.notice,
      company: created.company,
    );
  }

  Future<void> _sendDunningLetterByEmail(DunningLevel level) async {
    final created = await _createNotice();
    if (created == null || !mounted) return;
    final data = onlineDunningLetterData(document: _document!, notice: created.notice, company: created.company);
    await sendPdfByMail(
      context,
      session: widget.session,
      title: '${dunningLetterTitle(level)} senden',
      defaultRecipientHint: 'Leer = E-Mail des Kunden',
      buildPdf: () => buildDunningLetterPdfFromData(data),
      send: (pdf, {to, subject, body}) => _client.sendDunningMail(created.notice.id, pdf, to: to),
    );
  }

  Future<List<OnlineArticle>> _loadArticles() async {
    if (!widget.session.can('articles.read') || widget.session.offlineOnly) return const [];
    try {
      return await _client.articles(includeInactive: true);
    } on Exception {
      // Ohne Artikelliste bleiben Stunden/Freitext/manuelle Artikel möglich.
      return const [];
    }
  }

  Future<void> _addItem() async {
    final articles = await _loadArticles();
    if (!mounted) return;
    final item = await showOnlineItemDialog(
      context,
      articles: articles,
      existingGroupLabels: onlineGroupLabels(_items),
      allowHours: _document!.kind != 'deliveryNote',
      forceZeroVat: _smallBusiness,
    );
    if (item == null) return;
    setState(() {
      _items = [..._items, item];
      _dirty = true;
    });
  }

  /// Bestehende Position bearbeiten statt nur löschen + neu anlegen (wie
  /// offline).
  Future<void> _editItem(int index) async {
    final articles = await _loadArticles();
    if (!mounted) return;
    final item = await showOnlineItemDialog(
      context,
      articles: articles,
      existingGroupLabels: onlineGroupLabels(_items),
      existing: _items[index],
      allowHours: _document!.kind != 'deliveryNote',
      forceZeroVat: _smallBusiness,
    );
    if (item == null) return;
    setState(() {
      _items = [..._items]..[index] = item;
      _dirty = true;
    });
  }

  static InvoiceTotals _totalsOf(Iterable<OnlineDocumentItem> items) => calculateInvoiceTotals([
        for (final i in items)
          InvoiceLineInput(
            quantity: Decimal.parse(i.quantity),
            unitPriceCents: i.unitPriceCents,
            vatRatePercent: i.vatRatePercent,
            discountPercent: i.discountPercent,
          ),
      ]);

  InvoiceTotals get _totals => _totalsOf(_items);

  Future<bool> _confirmDiscard() async {
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
    return discard == true;
  }

  @override
  Widget build(BuildContext context) {
    final document = _document;
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmDiscard() && context.mounted) {
          setState(() => _dirty = false);
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(document == null ? 'Dokument' : onlineEditorTitle(document)),
          actions: document == null ? null : _buildActions(document),
        ),
        body: _error != null
            ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!)))
            : document == null
                ? const Center(child: CircularProgressIndicator())
                : _buildBody(document),
        floatingActionButton: document != null && _editable
            ? FloatingActionButton.extended(
                heroTag: 'online-document-editor-fab',
                onPressed: _busy ? null : _addItem,
                icon: const Icon(Icons.add),
                label: const Text('Position hinzufügen'),
              )
            : null,
      ),
    );
  }

  /// Aktionen in der Titelleiste in der Reihenfolge des Offline-Editors;
  /// Offline-Kopie und Entwurf löschen gibt es nur online.
  List<Widget> _buildActions(OnlineDocument document) {
    final session = widget.session;
    final finalized = !document.isDraft;
    // Folgeaktionen nur mit gespeichertem Stand — sonst übernähme die
    // Folgeurkunde nicht das, was auf dem Bildschirm steht.
    final followUps = finalized && _serverActionsAllowed && !_dirty && !_busy;
    final targets = [
      for (final target in documentConversionTargets[document.kind] ?? const <String>{})
        if (onlineDocumentKindModules[target] == null || session.modules.contains(onlineDocumentKindModules[target]))
          target,
    ];
    final canFinalize = document.isDraft && session.can('invoices.finalize');
    return [
      if (_store != null && !session.offlineOnly && !_offlineView)
        IconButton(
          tooltip: _pinned ? 'Nicht mehr offline verfügbar' : 'Offline verfügbar machen',
          icon: Icon(_pinned ? Icons.offline_pin : Icons.download_for_offline_outlined),
          onPressed: _busy ? null : _togglePinned,
        ),
      if (finalized)
        IconButton(
          icon: const Icon(Icons.picture_as_pdf_outlined),
          tooltip: 'PDF teilen',
          onPressed: _busy || _dirty ? null : _showPdf,
        ),
      if (finalized && canSendMail(session) && _serverActionsAllowed)
        IconButton(
          icon: const Icon(Icons.mail_outline),
          tooltip: 'Per E-Mail senden',
          onPressed: _busy || _dirty
              ? null
              : () => sendPdfByMail(
                    context,
                    session: session,
                    title: '${onlineDocumentKindLabels[document.kind] ?? 'Dokument'} ${document.number} senden',
                    defaultRecipientHint: 'Leer = E-Mail des Kunden',
                    customText: true,
                    buildPdf: () => buildOnlineDocumentPdf(document),
                    send: (pdf, {to, subject, body}) =>
                        _client.sendDocumentMail(document.id, pdf, to: to, subject: subject, body: body),
                  ),
        ),
      if (finalized && session.can('invoices.write') && targets.isNotEmpty)
        PopupMenuButton<String>(
          icon: const Icon(Icons.sync_alt_outlined),
          tooltip: 'Umwandeln',
          enabled: followUps,
          itemBuilder: (context) => [
            for (final target in targets)
              PopupMenuItem(value: target, child: Text('In ${onlineDocumentKindLabels[target] ?? target} umwandeln')),
          ],
          onSelected: _convert,
        ),
      if (finalized && document.kind == 'invoice' && session.modules.contains('creditNotes') && session.can('invoices.write'))
        IconButton(
          icon: const Icon(Icons.receipt_long_outlined),
          tooltip: 'Gutschrift erstellen',
          onPressed: followUps ? _createCreditNote : null,
        ),
      if (finalized &&
          document.kind == 'order' &&
          session.modules.contains('bestellwesen') &&
          session.can('purchaseOrders.write'))
        IconButton(
          icon: const Icon(Icons.shopping_cart_outlined),
          tooltip: 'Bestellung erstellen',
          onPressed: followUps ? () => createPurchaseOrdersFromDocument(context, session, document.id) : null,
        ),
      if (!finalized)
        IconButton(
          icon: const Icon(Icons.visibility_outlined),
          tooltip: 'Vorschau (unverbindlich)',
          onPressed: _items.isEmpty || _dirty || _busy ? null : _showPdf,
        ),
      if (_editable)
        IconButton(
          icon: const Icon(Icons.save_outlined),
          tooltip: _offlineView
              ? 'Offline speichern'
              : finalized
                  ? 'Änderungen speichern'
                  : 'Entwurf speichern',
          onPressed: _busy || !_dirty ? null : _save,
        ),
      if (canFinalize)
        IconButton(
          icon: const Icon(Icons.check_circle_outline),
          tooltip: 'Finalisieren',
          // Erst speichern, dann finalisieren — finalisiert wird genau
          // der Stand, den der Server kennt.
          onPressed: _busy || _dirty || _items.isEmpty || !_serverActionsAllowed ? null : _finalize,
        ),
      if (_editable && document.isDraft && _serverActionsAllowed)
        IconButton(tooltip: 'Entwurf löschen', icon: const Icon(Icons.delete_outline), onPressed: _busy ? null : _delete),
    ];
  }

  static IconData _iconFor(OnlineItemKind kind) => switch (kind) {
        OnlineItemKind.article => Icons.inventory_2_outlined,
        OnlineItemKind.hours => Icons.schedule_outlined,
        OnlineItemKind.text => Icons.notes_outlined,
      };

  /// Positionskarte wie offline: Typ-Symbol, Menge × Preis, Steuersatz,
  /// Zeilenbetrag brutto, Rabatt als eigene Zeile.
  Widget _buildItemCard(int index) {
    final item = _items[index];
    final quantity = item.quantity.replaceAll('.', ',');
    final quantityLabel = item.unit == null ? quantity : '$quantity ${item.unit}';
    final line = _totalsOf([item]);
    final undiscounted = _totalsOf([
      OnlineDocumentItem(
        kind: item.kind,
        description: item.description,
        quantity: item.quantity,
        unitPriceCents: item.unitPriceCents,
        vatRatePercent: item.vatRatePercent,
      ),
    ]);
    final editable = _editable;
    return Card(
      child: InkWell(
        onTap: editable ? () => _editItem(index) : null,
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
                  Expanded(child: Text(item.description, style: const TextStyle(fontWeight: FontWeight.w600))),
                  if (editable)
                    IconButton(
                      tooltip: 'Position entfernen',
                      icon: const Icon(Icons.delete_outline, size: 20),
                      visualDensity: VisualDensity.compact,
                      onPressed: () => setState(() {
                        _items = [..._items]..removeAt(index);
                        _dirty = true;
                      }),
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
                    Text(line.totalGross.toString(), style: const TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              if (item.discountPercent > 0)
                Padding(
                  padding: const EdgeInsets.only(left: 26, top: 2),
                  child: Text(
                    '− ${item.discountPercent.toStringAsFixed(0)} % Rabatt: −${undiscounted.totalGross - line.totalGross}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.primary),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(OnlineDocument document) {
    final session = widget.session;
    final theme = Theme.of(context);
    final dateFormat = DateFormat('dd.MM.yyyy');
    final finalized = !document.isDraft;
    final editable = _editable;
    final totals = _totals;

    // Positionen nach Gruppe (ungruppierte zuletzt), wie offline.
    final groups = <String?, List<int>>{};
    for (final (index, item) in _items.indexed) {
      groups.putIfAbsent(item.groupLabel, () => []).add(index);
    }
    final orderedKeys = groups.keys.toList()
      ..sort((a, b) {
        if (a == null) return 1;
        if (b == null) return -1;
        return a.compareTo(b);
      });

    final level = finalized && document.kind == 'invoice' && _dunningConfig != null
        ? dunningLevelForDue(
            isFinalized: true,
            isPaid: document.isPaid,
            dueDate: document.dueDate,
            now: DateTime.now(),
            config: _dunningConfig!,
          )
        : DunningLevel.none;
    final bookedHours = document.rawJson['bookedHours'];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
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
            color: entry.status == OutboxStatus.pending ? null : theme.colorScheme.errorContainer,
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
                  if (entry.status == OutboxStatus.pending && !session.offlineOnly)
                    TextButton(onPressed: _busy ? null : _syncNow, child: const Text('Abgleichen')),
                  TextButton(onPressed: _busy ? null : () => _discardPending(entry), child: const Text('Verwerfen')),
                ],
              ),
            ),
          ),
        if (finalized)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              '${document.finalizedAt == null ? 'Finalisiert' : 'Finalisiert am ${DateFormat('dd.MM.yyyy HH:mm').format(document.finalizedAt!.toLocal())}'} — '
              '${editable ? 'noch bearbeitbar, bis daraus ein Folgedokument erzeugt wird.' : 'nicht mehr änderbar.'}',
              style: TextStyle(color: theme.colorScheme.primary),
            ),
          ),
        if (document.kind == 'creditNote' && document.convertedFromNumber != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text('Gutschrift zu ${document.convertedFromNumber}'),
          ),
        TextField(
          controller: _paymentTerms,
          readOnly: !editable || _offlineView,
          decoration: const InputDecoration(labelText: 'Zahlungsbedingungen'),
          onChanged: (_) => setState(() => _dirty = true),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _notes,
          readOnly: !editable,
          maxLines: 2,
          decoration: const InputDecoration(labelText: 'Notizen'),
          onChanged: (_) => setState(() => _dirty = true),
        ),
        if (_projectsEnabled) ...[
          const SizedBox(height: 8),
          if (!editable || !document.isDraft || _offlineView)
            Text(
              'Projekt: ${_projects.where((p) => p.id == document.projectId).firstOrNull?.name ?? (document.projectId == null ? 'Ohne Projekt' : '…')}',
              style: theme.textTheme.bodyMedium,
            )
          else
            DropdownButtonFormField<String?>(
              key: ValueKey('online-document-project-${_projects.length}'),
              isExpanded: true,
              initialValue: _projects.any((p) => p.id == _projectId) ? _projectId : null,
              decoration: const InputDecoration(labelText: 'Projekt (optional)'),
              items: [
                const DropdownMenuItem<String?>(value: null, child: Text('Ohne Projekt')),
                for (final project in _projects.where((p) => !p.isArchived || p.id == _projectId))
                  DropdownMenuItem<String?>(value: project.id, child: Text(project.name, overflow: TextOverflow.ellipsis)),
              ],
              onChanged: (value) => setState(() {
                _projectId = value;
                _dirty = true;
              }),
            ),
        ],
        if (session.modules.contains('advancePaymentInvoices') && document.kind == 'invoice') ...[
          const SizedBox(height: 4),
          if (!editable || _offlineView)
            if (document.isAdvancePayment) Text('Abschlagsrechnung', style: theme.textTheme.bodyMedium) else const SizedBox.shrink()
          else
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text('Ist eine Abschlagsrechnung'),
              value: _isAdvancePayment,
              onChanged: (value) => setState(() {
                _isAdvancePayment = value ?? false;
                _dirty = true;
              }),
            ),
        ],
        if (session.modules.contains('timeTracking') && {'quote', 'order'}.contains(document.kind)) ...[
          const SizedBox(height: 4),
          if (!editable || _offlineView)
            Text(
              document.isFixedPrice ? 'Festpreis vereinbart' : 'Zeit und Material (keine Festpreis-Vereinbarung)',
              style: theme.textTheme.bodyMedium,
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
              onChanged: (value) => setState(() {
                _isFixedPrice = value ?? false;
                _dirty = true;
              }),
            ),
        ],
        // Geplant laut Angebot vs. tatsächlich gebuchte Ist-Stunden (online
        // auch schon im Entwurf — gebucht werden kann darauf bereits).
        if (session.modules.contains('timeTracking') && document.kind == 'order')
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              'Geplant laut Angebot: ${_items.where((i) => i.kind == OnlineItemKind.hours).fold(Decimal.zero, (sum, i) => sum + Decimal.parse(i.quantity)).toString().replaceAll('.', ',')} Std. · '
              'Gebucht: ${bookedHours is String ? bookedHours.replaceAll('.', ',') : '0'} Std.',
              style: theme.textTheme.bodySmall,
            ),
          ),
        if (_dunningEnabled && document.kind == 'invoice') ...[
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              _dueDate == null ? 'Fälligkeitsdatum (optional)' : 'Fälligkeitsdatum: ${dateFormat.format(_dueDate!)}',
            ),
            trailing: const Icon(Icons.calendar_today_outlined),
            onTap: _busy || _offlineView || (finalized ? !session.can('invoices.payment') : !editable) ? null : _pickDueDate,
          ),
        ],
        if (finalized && document.kind == 'invoice') ...[
          // Wrap statt Row: auf schmalen Handys (~330 px) bricht der Knopf
          // unter den Text, statt über den Rand zu laufen.
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                document.isPaid
                    ? 'Bezahlt am ${document.paidAt == null ? '' : dateFormat.format(document.paidAt!.toLocal())}'
                    : document.dueDate == null
                        ? 'Offen (kein Fälligkeitsdatum gesetzt)'
                        : 'Offen — fällig am ${dateFormat.format(document.dueDate!)}',
              ),
              if (session.can('invoices.payment'))
                TextButton(
                  onPressed: _busy || !_serverActionsAllowed ? null : _togglePaid,
                  child: Text(document.isPaid ? 'Als offen markieren' : 'Als bezahlt markieren'),
                ),
            ],
          ),
          if (level != DunningLevel.none)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(dunningLevelLabel(level), style: TextStyle(color: theme.colorScheme.error)),
                  if (session.can('dunning.write')) ...[
                    TextButton(
                      onPressed: _busy || !_serverActionsAllowed ? null : _generateDunningLetter,
                      child: Text('${dunningLetterTitle(level)} erzeugen'),
                    ),
                    if (canSendMail(session))
                      IconButton(
                        icon: const Icon(Icons.mail_outline),
                        tooltip: '${dunningLetterTitle(level)} per E-Mail senden',
                        onPressed: _busy || !_serverActionsAllowed ? null : () => _sendDunningLetterByEmail(level),
                      ),
                  ],
                ],
              ),
            ),
        ],
        if (finalized && document.creditNotes.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Gutschriften zu diesem Dokument', style: theme.textTheme.titleSmall),
                for (final c in document.creditNotes)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.receipt_long_outlined),
                    title: Text(c.number ?? 'Gutschrift (Entwurf)'),
                    trailing: Text('− ${Money.fromCents(c.grossCents)}'),
                    onTap: () => _openOther(c.id),
                  ),
              ],
            ),
          ),
        // Nur online: Folgedokumente direkt öffnen.
        if (document.convertedTo.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Folgedokumente', style: theme.textTheme.titleSmall),
                for (final c in document.convertedTo)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.subdirectory_arrow_right),
                    title: Text(c.number ?? '${onlineDocumentKindLabels[c.kind] ?? c.kind} (Entwurf)'),
                    subtitle: Text(onlineDocumentKindLabels[c.kind] ?? c.kind),
                    onTap: () => _openOther(c.id),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 16),
        if (_items.isEmpty) const Padding(padding: EdgeInsets.all(8), child: Text('Noch keine Positionen.')),
        for (final key in orderedKeys) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(key ?? 'Ohne Gruppe', style: theme.textTheme.titleSmall),
          ),
          for (final index in groups[key]!) _buildItemCard(index),
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 4, right: 8),
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                'Gruppensumme: ${_totalsOf([for (final i in groups[key]!) _items[i]]).totalGross}',
                style: theme.textTheme.bodySmall,
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        Card(
          color: theme.colorScheme.surfaceContainerHighest,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final rate in totals.sortedRates)
                  Text('Netto ${rate.toStringAsFixed(0)} %: ${totals.netByRate[rate]}   Steuer: ${totals.taxByRate[rate]}'),
                const Divider(),
                Text('Gesamt: ${totals.totalGross}', style: theme.textTheme.titleMedium),
                // Abschlagsrechnungen einzeln mit Nummer (wie offline).
                if (document.advancePayments.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  for (final a in document.advancePayments)
                    Text('Abschlagsrechnung ${a.number ?? ''}: −${Money.fromCents(a.grossCents)}', style: theme.textTheme.bodySmall),
                  if (document.advancePayments.length > 1)
                    Text(
                      'Abschlagszahlungen gesamt: −${Money.fromCents(document.advancePayments.fold(0, (s, a) => s + a.grossCents))}',
                      style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  if (document.remainingCents != null && !_dirty) ...[
                    const Divider(),
                    Text('Restbetrag: ${Money.fromCents(document.remainingCents!)}', style: theme.textTheme.titleMedium),
                  ],
                ],
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

  Future<void> _openOther(String id) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => OnlineDocumentScreen(session: widget.session, documentId: id)),
    );
    if (mounted && !_dirty) await _reload();
  }
}

/// Wie offline `DocumentLabels.finalizeConfirmSentence`.
String onlineFinalizeConfirmSentence(String kind) => switch (kind) {
      'quote' => 'Das Angebot erhält jetzt eine endgültige Nummer und kann danach nicht mehr geändert werden.',
      'order' => 'Der Auftrag erhält jetzt eine endgültige Nummer und kann danach nicht mehr geändert werden.',
      'deliveryNote' =>
        'Der Lieferschein erhält jetzt eine endgültige Nummer und kann danach nicht mehr geändert werden.',
      'proforma' => 'Die Proforma-Rechnung erhält jetzt eine endgültige Nummer (eigener Nummernkreis, keine '
          'umsatzsteuerliche Rechnungsnummer) und kann danach nicht mehr geändert werden.',
      'creditNote' => 'Die Gutschrift erhält jetzt eine endgültige Nummer und kann danach nicht mehr geändert werden.',
      _ => 'Die Rechnung erhält jetzt eine endgültige Nummer und kann danach nicht mehr geändert werden.',
    };
