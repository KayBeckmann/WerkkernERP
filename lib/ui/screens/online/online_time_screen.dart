import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:werkkern_client/werkkern_client.dart';

import '../../../domain/services/online_session.dart';

/// Zeiterfassung online (C3, Nachtrag 20.10.: "Der Monteur muss seine
/// Zeiten buchen können"). Jeder bucht eigene Zeiten auf Auftrag oder
/// Rechnung; mit `timeTracking.read` sind die Buchungen aller sichtbar.
class OnlineTimeScreen extends StatefulWidget {
  const OnlineTimeScreen({super.key, required this.session});
  final OnlineSession session;

  @override
  State<OnlineTimeScreen> createState() => _OnlineTimeScreenState();
}

class _OnlineTimeScreenState extends State<OnlineTimeScreen> {
  late Future<({List<OnlineTimeEntry> entries, String totalHours, bool companyScope})> _future = _load();
  final Map<String, String> _documentLabels = {};

  Future<({List<OnlineTimeEntry> entries, String totalHours, bool companyScope})> _load() async {
    final result = await widget.session.client.timeEntries();
    if (widget.session.can('invoices.read')) {
      try {
        for (final d in await widget.session.client.documents()) {
          _documentLabels[d.id] = _label(d);
        }
      } on Exception {
        // Ohne Dokumentliste zeigen wir nur die Buchungen.
      }
    }
    return result;
  }

  String _label(OnlineDocument d) =>
      '${d.number ?? '${onlineDocumentKindLabels[d.kind] ?? d.kind} (Entwurf)'} · ${d.displayCustomerName ?? ''}';

  void _reload() => setState(() {
        _future = _load();
      });

  Future<void> _edit([OnlineTimeEntry? existing]) async {
    final List<OnlineDocument> documents;
    try {
      documents = [
        for (final d in await widget.session.client.documents())
          if (d.kind == 'order' || d.kind == 'invoice') d,
      ];
    } on Exception catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(describeOnlineError(e))));
      return;
    }
    if (!mounted) return;
    final result = await showDialog<_TimeResult>(
      context: context,
      builder: (_) => _TimeEntryDialog(documents: documents, existing: existing, label: _label),
    );
    if (result == null) return;
    try {
      if (result.delete) {
        await widget.session.client.deleteTimeEntry(existing!.id);
      } else {
        await widget.session.client.saveTimeEntry(
          id: existing?.id,
          date: result.date,
          hours: result.hours,
          documentId: result.documentId,
          note: result.note,
        );
      }
      _reload();
    } on Exception catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(describeOnlineError(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    // Fremde Buchungen (Firmensicht) lehnt der Server beim Speichern mit
    // 403 ab — die App muss dafür die eigene Nutzer-ID nicht kennen.
    final dateFormat = DateFormat('dd.MM.yyyy');
    final canBook = widget.session.can('timeTracking.write');
    return Scaffold(
      body: FutureBuilder(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text(describeOnlineError(snapshot.error!)));
          if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          final data = snapshot.data!;
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
              children: [
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.timer_outlined),
                    title: Text('${data.totalHours.replaceAll('.', ',')} Std.'),
                    subtitle: Text(data.companyScope ? 'Buchungen aller Mitarbeiter' : 'Deine Buchungen'),
                  ),
                ),
                if (data.entries.isEmpty) const Padding(padding: EdgeInsets.all(16), child: Text('Noch keine Zeiten gebucht.')),
                for (final e in data.entries)
                  Card(
                    child: ListTile(
                      title: Text('${e.hours.replaceAll('.', ',')} Std. · ${_documentLabels[e.documentId] ?? 'Auftrag/Rechnung'}'),
                      subtitle: Text([
                        dateFormat.format(e.date),
                        if (data.companyScope && e.userEmail != null) e.userEmail!,
                        if (e.note != null) e.note!,
                      ].join(' · ')),
                      trailing: canBook ? const Icon(Icons.edit_outlined) : null,
                      onTap: canBook ? () => _edit(e) : null,
                    ),
                  ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: canBook
          ? FloatingActionButton.extended(
              heroTag: 'online-time-fab',
              onPressed: _edit,
              icon: const Icon(Icons.add_alarm),
              label: const Text('Zeit buchen'),
            )
          : null,
    );
  }
}

class _TimeResult {
  const _TimeResult({required this.date, required this.hours, required this.documentId, this.note, this.delete = false});
  final DateTime date;
  final String hours;
  final String documentId;
  final String? note;
  final bool delete;
}

class _TimeEntryDialog extends StatefulWidget {
  const _TimeEntryDialog({required this.documents, required this.label, this.existing});
  final List<OnlineDocument> documents;
  final String Function(OnlineDocument) label;
  final OnlineTimeEntry? existing;

  @override
  State<_TimeEntryDialog> createState() => _TimeEntryDialogState();
}

class _TimeEntryDialogState extends State<_TimeEntryDialog> {
  late DateTime _date = widget.existing?.date ?? DateTime.now();
  late String? _documentId = widget.existing?.documentId;
  late final _hours = TextEditingController(text: widget.existing?.hours.replaceAll('.', ','));
  late final _note = TextEditingController(text: widget.existing?.note);
  String? _error;

  @override
  void dispose() {
    _hours.dispose();
    _note.dispose();
    super.dispose();
  }

  void _submit() {
    final hours = Decimal.tryParse(_hours.text.trim().replaceAll(',', '.'));
    if (_documentId == null || hours == null || hours <= Decimal.zero || hours > Decimal.fromInt(24)) {
      setState(() => _error = 'Auftrag/Rechnung wählen und Stunden zwischen 0 und 24 angeben.');
      return;
    }
    Navigator.pop(
      context,
      _TimeResult(
        date: _date,
        hours: hours.toString(),
        documentId: _documentId!,
        note: _note.text.trim().isEmpty ? null : _note.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd.MM.yyyy');
    return AlertDialog(
      title: Text(widget.existing == null ? 'Zeit buchen' : 'Buchung bearbeiten'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.documents.isEmpty)
              const Text('Keine Aufträge/Rechnungen sichtbar — Zeiten werden immer auf einen Vorgang gebucht.')
            else
              DropdownButtonFormField<String>(
                key: const Key('online-time-document'),
                initialValue: _documentId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Auftrag/Rechnung'),
                items: [
                  for (final d in widget.documents)
                    DropdownMenuItem(value: d.id, child: Text(widget.label(d), overflow: TextOverflow.ellipsis)),
                ],
                onChanged: (v) => setState(() => _documentId = v),
              ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event),
              title: Text(dateFormat.format(_date)),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime(2000),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (picked != null) setState(() => _date = picked);
              },
            ),
            TextField(
              key: const Key('online-time-hours'),
              controller: _hours,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Stunden (z. B. 1,5)'),
            ),
            TextField(controller: _note, decoration: const InputDecoration(labelText: 'Notiz')),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
          ],
        ),
      ),
      actions: [
        if (widget.existing != null)
          TextButton(
            onPressed: () => Navigator.pop(
              context,
              _TimeResult(date: _date, hours: '0', documentId: _documentId ?? '', delete: true),
            ),
            child: const Text('Löschen'),
          ),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
        FilledButton(onPressed: _submit, child: const Text('Speichern')),
      ],
    );
  }
}
