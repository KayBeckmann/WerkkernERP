import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:werkkern_client/werkkern_client.dart';

import '../../../domain/services/online_session.dart';

/// Zeiterfassung online (C3, Nachtrag 20.10.: "Der Monteur muss seine
/// Zeiten buchen können") — Aufbau wie offline (`time_entries_screen.dart`).
/// Jeder bucht eigene Zeiten auf Auftrag/Rechnung oder Projekt, optional
/// mit Rolle; mit `timeTracking.read` sind die Buchungen aller sichtbar.
class OnlineTimeScreen extends StatefulWidget {
  const OnlineTimeScreen({super.key, required this.session});
  final OnlineSession session;

  @override
  State<OnlineTimeScreen> createState() => _OnlineTimeScreenState();
}

class _OnlineTimeScreenState extends State<OnlineTimeScreen> {
  late Future<({List<OnlineTimeEntry> entries, String totalHours, bool companyScope})> _future = _load();
  final Map<String, String> _documentLabels = {};
  final Map<String, String> _projectNames = {};
  final Map<String, String> _roleNames = {};
  List<OnlineStaffRole> _roles = const [];

  OnlineSession get _session => widget.session;

  Future<({List<OnlineTimeEntry> entries, String totalHours, bool companyScope})> _load() async {
    final result = await _session.client.timeEntries();
    // Bezüge und Rollen nur für die Anzeige — fehlen Rechte, bleibt „–“.
    if (_session.can('invoices.read')) {
      try {
        for (final d in await _session.client.documents()) {
          _documentLabels[d.id] = _label(d);
        }
      } on Exception {
        // siehe oben
      }
    }
    if (_session.modules.contains('projects') && _session.can('projects.read')) {
      try {
        for (final p in await _session.client.projects(includeArchived: true)) {
          _projectNames[p.id] = '${p.displayNumber} · ${p.name}';
        }
      } on Exception {
        // siehe oben
      }
    }
    try {
      _roles = await _session.client.staffRoles();
      _roleNames
        ..clear()
        ..addEntries(_roles.map((r) => MapEntry(r.id, r.name)));
    } on Exception {
      _roles = const [];
    }
    return result;
  }

  String _label(OnlineDocument d) =>
      '${d.number ?? '${onlineDocumentKindLabels[d.kind] ?? d.kind} (Entwurf)'} · ${d.displayCustomerName ?? ''}';

  /// Bezug wie offline: Auftrag/Rechnung, sonst Projekt.
  String _reference(OnlineTimeEntry e) => e.documentId != null
      ? _documentLabels[e.documentId] ?? '(unbekanntes Dokument)'
      : e.projectId != null
          ? _projectNames[e.projectId] ?? '(unbekanntes Projekt)'
          : '–';

  void _reload() => setState(() {
        _future = _load();
      });

  Future<void> _edit([OnlineTimeEntry? existing]) async {
    final List<OnlineDocument> documents;
    try {
      documents = [
        for (final d in await _session.client.documents())
          if (d.kind == 'order' || d.kind == 'invoice') d,
      ];
    } on Exception catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(describeOnlineError(e))));
      return;
    }
    var projects = const <OnlineProject>[];
    if (_session.modules.contains('projects') && _session.can('projects.read')) {
      try {
        projects = await _session.client.projects();
      } on Exception {
        // Dann nur Buchung auf Auftrag/Rechnung.
      }
    }
    if (!mounted) return;
    final result = await showDialog<_TimeResult>(
      context: context,
      builder: (_) => _TimeEntryDialog(documents: documents, projects: projects, roles: _roles, existing: existing, label: _label),
    );
    if (result == null) return;
    try {
      await _session.client.saveTimeEntry(
        id: existing?.id,
        date: result.date,
        hours: result.hours,
        documentId: result.documentId,
        projectId: result.projectId,
        note: result.note,
        staffRoleId: () => result.staffRoleId,
      );
      _reload();
    } on Exception catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(describeOnlineError(e))));
    }
  }

  Future<void> _delete(OnlineTimeEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Zeitbuchung löschen?'),
        content: const Text('Diese Aktion ist nicht umkehrbar.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Abbrechen')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Löschen')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await _session.client.deleteTimeEntry(entry.id);
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
    final canBook = _session.can('timeTracking.write');
    return Scaffold(
      body: FutureBuilder(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text(describeOnlineError(snapshot.error!)));
          if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          final data = snapshot.data!;
          if (data.entries.isEmpty) return const Center(child: Text('Noch keine Zeiten gebucht.'));
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
              children: [
                // Nur online: Summe und Sicht (eigene bzw. alle Mitarbeiter).
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.timer_outlined),
                    title: Text('${data.totalHours.replaceAll('.', ',')} Std.'),
                    subtitle: Text(data.companyScope ? 'Buchungen aller Mitarbeiter' : 'Deine Buchungen'),
                  ),
                ),
                for (final e in data.entries)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.schedule_outlined),
                      title: Text('${e.hours.replaceAll('.', ',')} Std. · ${_reference(e)}'),
                      subtitle: Text([
                        dateFormat.format(e.date),
                        if (e.staffRoleId != null && _roleNames[e.staffRoleId] != null) _roleNames[e.staffRoleId]!,
                        if (data.companyScope && e.userEmail != null) e.userEmail!,
                        if (e.note != null) e.note!,
                      ].join(' · ')),
                      trailing: canBook
                          ? IconButton(tooltip: 'Löschen', icon: const Icon(Icons.delete_outline), onPressed: () => _delete(e))
                          : null,
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
              icon: const Icon(Icons.add),
              label: const Text('Zeit buchen'),
            )
          : null,
    );
  }
}

enum _ReferenceKind { document, project }

class _TimeResult {
  const _TimeResult({
    required this.date,
    required this.hours,
    this.documentId,
    this.projectId,
    this.staffRoleId,
    this.note,
  });
  final DateTime date;
  final String hours;
  final String? documentId;
  final String? projectId;
  final String? staffRoleId;
  final String? note;
}

/// Zeitbuchung wie offline: Bezug entweder Auftrag/Rechnung oder Projekt
/// (Umschalter), Rolle optional — ihr Stundensatz wird eingefroren.
class _TimeEntryDialog extends StatefulWidget {
  const _TimeEntryDialog({
    required this.documents,
    required this.label,
    this.projects = const [],
    this.roles = const [],
    this.existing,
  });
  final List<OnlineDocument> documents;
  final List<OnlineProject> projects;
  final List<OnlineStaffRole> roles;
  final String Function(OnlineDocument) label;
  final OnlineTimeEntry? existing;

  @override
  State<_TimeEntryDialog> createState() => _TimeEntryDialogState();
}

class _TimeEntryDialogState extends State<_TimeEntryDialog> {
  late DateTime _date = widget.existing?.date ?? DateTime.now();
  late _ReferenceKind _referenceKind =
      widget.existing != null && widget.existing!.documentId == null && widget.existing!.projectId != null
          ? _ReferenceKind.project
          : widget.documents.isEmpty && widget.projects.isNotEmpty
              ? _ReferenceKind.project
              : _ReferenceKind.document;
  late String? _documentId = widget.documents.any((d) => d.id == widget.existing?.documentId) ? widget.existing?.documentId : null;
  late String? _projectId = widget.projects.any((p) => p.id == widget.existing?.projectId) ? widget.existing?.projectId : null;
  late String? _staffRoleId = widget.roles.any((r) => r.id == widget.existing?.staffRoleId) ? widget.existing?.staffRoleId : null;
  late final _hours = TextEditingController(text: widget.existing?.hours.replaceAll('.', ',') ?? '1');
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
    final reference = _referenceKind == _ReferenceKind.document ? _documentId : _projectId;
    if (reference == null || hours == null || hours <= Decimal.zero || hours > Decimal.fromInt(24)) {
      setState(() => _error = 'Auftrag/Rechnung bzw. Projekt wählen und Stunden zwischen 0 und 24 angeben.');
      return;
    }
    Navigator.pop(
      context,
      _TimeResult(
        date: _date,
        hours: hours.toString(),
        documentId: _referenceKind == _ReferenceKind.document ? _documentId : null,
        projectId: _referenceKind == _ReferenceKind.project ? _projectId : null,
        staffRoleId: _staffRoleId,
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
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(dateFormat.format(_date)),
                trailing: const Icon(Icons.edit_calendar_outlined),
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
                decoration: const InputDecoration(labelText: 'Stunden *'),
              ),
              const SizedBox(height: 8),
              if (widget.documents.isEmpty && widget.projects.isEmpty)
                const Text('Keine Aufträge/Rechnungen oder Projekte sichtbar — Zeiten brauchen immer einen Bezug.'),
              if (widget.projects.isNotEmpty)
                SegmentedButton<_ReferenceKind>(
                  segments: const [
                    ButtonSegment(value: _ReferenceKind.document, label: Text('Auftrag/Rechnung')),
                    ButtonSegment(value: _ReferenceKind.project, label: Text('Projekt')),
                  ],
                  selected: {_referenceKind},
                  onSelectionChanged: (selection) => setState(() => _referenceKind = selection.first),
                ),
              const SizedBox(height: 8),
              if (_referenceKind == _ReferenceKind.document && widget.documents.isNotEmpty)
                DropdownButtonFormField<String?>(
                  key: const Key('online-time-document'),
                  initialValue: _documentId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Auftrag/Rechnung *'),
                  items: [
                    for (final d in widget.documents)
                      DropdownMenuItem<String?>(value: d.id, child: Text(widget.label(d), overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged: (v) => setState(() => _documentId = v),
                ),
              if (_referenceKind == _ReferenceKind.project)
                DropdownButtonFormField<String?>(
                  key: const Key('online-time-project'),
                  initialValue: _projectId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Projekt *'),
                  items: [
                    for (final p in widget.projects)
                      DropdownMenuItem<String?>(value: p.id, child: Text('${p.displayNumber} · ${p.name}', overflow: TextOverflow.ellipsis)),
                  ],
                  onChanged: (v) => setState(() => _projectId = v),
                ),
              if (widget.roles.isNotEmpty)
                DropdownButtonFormField<String?>(
                  key: const Key('online-time-role'),
                  initialValue: _staffRoleId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Rolle (optional)',
                    helperText: 'Ohne Rolle gilt dein Stundensatz.',
                  ),
                  items: [
                    const DropdownMenuItem<String?>(value: null, child: Text('— ohne Rolle —')),
                    for (final r in widget.roles) DropdownMenuItem<String?>(value: r.id, child: Text(r.name)),
                  ],
                  onChanged: (v) => setState(() => _staffRoleId = v),
                ),
              TextField(controller: _note, decoration: const InputDecoration(labelText: 'Notiz (optional)')),
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
        FilledButton(onPressed: _submit, child: Text(widget.existing == null ? 'Buchen' : 'Speichern')),
      ],
    );
  }
}
