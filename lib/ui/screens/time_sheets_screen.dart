import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/database/database.dart';
import '../../data/database/tables.dart';
import '../../data/repositories/invoice_repository.dart';
import '../../data/repositories/project_repository.dart';
import '../../data/repositories/time_entry_repository.dart';
import '../../data/repositories/time_sheet_repository.dart';
import '../../domain/services/active_company_service.dart';
import '../widgets/signature_pad.dart';


String _formatDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';

/// Kunden-Stundenzettel (C3-Rest, Nachtrag 2026-10-21) — Liste aller
/// Stundenzettel der aktiven Firma, neuen Entwurf anlegen.
class TimeSheetsScreen extends StatefulWidget {
  const TimeSheetsScreen({super.key});

  @override
  State<TimeSheetsScreen> createState() => _TimeSheetsScreenState();
}

class _TimeSheetsScreenState extends State<TimeSheetsScreen> {
  late Future<_ListData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_ListData> _load() async {
    final companyId = context.read<ActiveCompanyService>().active!.id;
    final sheetRepo = context.read<TimeSheetRepository>();
    final invoiceRepo = context.read<InvoiceRepository>();
    final projectRepo = context.read<ProjectRepository>();

    final sheets = await sheetRepo.listForCompany(companyId);
    final orders = await invoiceRepo.listAllForCompany(companyId, kind: DocumentKind.order);
    final invoices = await invoiceRepo.listAllForCompany(companyId, kind: DocumentKind.invoice);
    final documentLabels = {
      for (final doc in [...orders, ...invoices]) doc.id: doc.invoiceNumber ?? 'Entwurf',
    };
    final projects = await projectRepo.listForCompany(companyId);
    final projectNames = {for (final project in projects) project.id: project.name};
    return _ListData(sheets: sheets, documentLabels: documentLabels, projectNames: projectNames);
  }

  void _reload() => setState(() {
        _future = _load();
      });

  Future<void> _create() async {
    final companyId = context.read<ActiveCompanyService>().active!.id;
    final sheetRepo = context.read<TimeSheetRepository>();
    final invoiceRepo = context.read<InvoiceRepository>();
    final projectRepo = context.read<ProjectRepository>();

    final orders = await invoiceRepo.listAllForCompany(companyId, kind: DocumentKind.order);
    final invoices = await invoiceRepo.listAllForCompany(companyId, kind: DocumentKind.invoice);
    final projects = await projectRepo.listForCompany(companyId);
    if (!mounted) return;

    final result = await showDialog<_TimeSheetFormResult>(
      context: context,
      builder: (_) => _TimeSheetFormDialog(documents: [...orders, ...invoices], projects: projects),
    );
    if (result == null) return;

    await sheetRepo.createDraft(
      companyId: companyId,
      date: result.date,
      invoiceId: result.invoiceId,
      projectId: result.projectId,
    );
    _reload();
  }

  String _referenceLabel(TimeSheet sheet, Map<String, String> documentLabels, Map<String, String> projectNames) {
    if (sheet.invoiceId != null) return documentLabels[sheet.invoiceId] ?? 'Unbekanntes Dokument';
    if (sheet.projectId != null) return projectNames[sheet.projectId] ?? 'Unbekanntes Projekt';
    return '—';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Stundenzettel')),
      body: FutureBuilder<_ListData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data!;
          if (data.sheets.isEmpty) {
            return const Center(child: Text('Noch keine Stundenzettel.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
            itemCount: data.sheets.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final sheet = data.sheets[index];
              return Card(
                child: ListTile(
                  leading: Icon(
                    sheet.status == TimeSheetStatus.signed
                        ? Icons.verified_outlined
                        : Icons.edit_note_outlined,
                  ),
                  title: Text(_referenceLabel(sheet, data.documentLabels, data.projectNames)),
                  subtitle: Text(
                    '${_formatDate(sheet.date)} · '
                    '${sheet.status == TimeSheetStatus.signed ? "Unterschrieben" : "Entwurf"}'
                    '${sheet.supersedesId != null ? " · Korrektur" : ""}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => TimeSheetDetailScreen(timeSheetId: sheet.id)),
                    );
                    if (mounted) _reload();
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'time-sheets-fab',
        onPressed: _create,
        icon: const Icon(Icons.add),
        label: const Text('Stundenzettel erstellen'),
      ),
    );
  }
}

class _ListData {
  const _ListData({required this.sheets, required this.documentLabels, required this.projectNames});
  final List<TimeSheet> sheets;
  final Map<String, String> documentLabels;
  final Map<String, String> projectNames;
}

enum _ReferenceKind { document, project }

class _TimeSheetFormResult {
  const _TimeSheetFormResult({required this.date, this.invoiceId, this.projectId});
  final DateTime date;
  final String? invoiceId;
  final String? projectId;
}

class _TimeSheetFormDialog extends StatefulWidget {
  const _TimeSheetFormDialog({required this.documents, required this.projects});
  final List<Invoice> documents;
  final List<Project> projects;

  @override
  State<_TimeSheetFormDialog> createState() => _TimeSheetFormDialogState();
}

class _TimeSheetFormDialogState extends State<_TimeSheetFormDialog> {
  _ReferenceKind _referenceKind = _ReferenceKind.document;
  String? _invoiceId;
  String? _projectId;
  DateTime _date = DateTime.now();

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Stundenzettel erstellen'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(_formatDate(_date)),
                trailing: const Icon(Icons.edit_calendar_outlined),
                onTap: _pickDate,
              ),
              SegmentedButton<_ReferenceKind>(
                segments: const [
                  ButtonSegment(value: _ReferenceKind.document, label: Text('Auftrag/Rechnung')),
                  ButtonSegment(value: _ReferenceKind.project, label: Text('Projekt')),
                ],
                selected: {_referenceKind},
                onSelectionChanged: (selection) => setState(() => _referenceKind = selection.first),
              ),
              const SizedBox(height: 8),
              if (_referenceKind == _ReferenceKind.document)
                DropdownButtonFormField<String?>(
                  isExpanded: true,
                  initialValue: _invoiceId,
                  decoration: const InputDecoration(labelText: 'Auftrag/Rechnung *'),
                  items: [
                    for (final document in widget.documents)
                      DropdownMenuItem(
                        value: document.id,
                        child: Text(document.invoiceNumber ?? 'Entwurf (${document.kind.name})'),
                      ),
                  ],
                  onChanged: (value) => setState(() => _invoiceId = value),
                )
              else
                DropdownButtonFormField<String?>(
                  isExpanded: true,
                  initialValue: _projectId,
                  decoration: const InputDecoration(labelText: 'Projekt *'),
                  items: [
                    for (final project in widget.projects)
                      DropdownMenuItem(value: project.id, child: Text(project.name)),
                  ],
                  onChanged: (value) => setState(() => _projectId = value),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
        FilledButton(
          onPressed: () {
            final referenceId =
                _referenceKind == _ReferenceKind.document ? _invoiceId : _projectId;
            if (referenceId == null) return;
            Navigator.pop(
              context,
              _TimeSheetFormResult(
                date: _date,
                invoiceId: _referenceKind == _ReferenceKind.document ? _invoiceId : null,
                projectId: _referenceKind == _ReferenceKind.project ? _projectId : null,
              ),
            );
          },
          child: const Text('Anlegen'),
        ),
      ],
    );
  }
}

/// Detailansicht eines Stundenzettels — im Entwurf: Zeitbuchungen
/// zuordnen/entfernen und unterschreiben; nach dem Unterschreiben:
/// nur noch lesen, mit Unterschrift-Bild + Korrektur-Option.
class TimeSheetDetailScreen extends StatefulWidget {
  const TimeSheetDetailScreen({super.key, required this.timeSheetId});
  final String timeSheetId;

  @override
  State<TimeSheetDetailScreen> createState() => _TimeSheetDetailScreenState();
}

class _TimeSheetDetailScreenState extends State<TimeSheetDetailScreen> {
  late Future<_DetailData> _future;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_DetailData> _load() async {
    final companyId = context.read<ActiveCompanyService>().active!.id;
    final sheetRepo = context.read<TimeSheetRepository>();
    final timeEntryRepo = context.read<TimeEntryRepository>();
    final sheet = (await sheetRepo.findById(companyId: companyId, id: widget.timeSheetId))!;
    final assigned = await sheetRepo.entriesFor(sheet.id);

    List<TimeEntry> candidates = const [];
    if (sheet.status == TimeSheetStatus.draft) {
      final allEntries = await timeEntryRepo.listForCompany(companyId);
      candidates = allEntries
          .where((e) => e.timeSheetId == null)
          .where((e) => sheet.invoiceId != null ? e.invoiceId == sheet.invoiceId : e.projectId == sheet.projectId)
          .toList();
    }
    return _DetailData(sheet: sheet, assigned: assigned, candidates: candidates);
  }

  void _reload() {
    setState(() {
      _future = _load();
    });
  }

  Future<void> _addEntry(TimeEntry entry) async {
    final companyId = context.read<ActiveCompanyService>().active!.id;
    await context.read<TimeSheetRepository>().addEntries(
          companyId: companyId,
          timeSheetId: widget.timeSheetId,
          entryIds: {entry.id},
        );
    _reload();
  }

  Future<void> _removeEntry(TimeEntry entry) async {
    final companyId = context.read<ActiveCompanyService>().active!.id;
    await context.read<TimeSheetRepository>().removeEntry(companyId: companyId, entryId: entry.id);
    _reload();
  }

  Future<void> _sign() async {
    final signatureBytes = await showSignatureDialog(context);
    if (signatureBytes == null || !mounted) return;

    setState(() => _busy = true);
    try {
      final companyId = context.read<ActiveCompanyService>().active!.id;
      await context.read<TimeSheetRepository>().sign(
            companyId: companyId,
            id: widget.timeSheetId,
            signatureImage: signatureBytes,
          );
      _reload();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _createCorrection() async {
    final companyId = context.read<ActiveCompanyService>().active!.id;
    final correction = await context.read<TimeSheetRepository>().createCorrectionDraft(
          companyId: companyId,
          supersedesId: widget.timeSheetId,
        );
    if (!mounted) return;
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => TimeSheetDetailScreen(timeSheetId: correction.id)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Stundenzettel')),
      body: FutureBuilder<_DetailData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data!;
          final sheet = data.sheet;
          final totalHours = data.assigned.fold<double>(0, (sum, e) => sum + e.hours);
          final isSigned = sheet.status == TimeSheetStatus.signed;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(_formatDate(sheet.date), style: Theme.of(context).textTheme.titleMedium),
              Text(isSigned ? 'Unterschrieben am ${_formatDate(sheet.signedAt!)}' : 'Entwurf'),
              if (sheet.supersedesId != null)
                const Text('Korrektur eines früheren Stundenzettels', style: TextStyle(fontStyle: FontStyle.italic)),
              const SizedBox(height: 16),
              Text('Zugeordnete Zeitbuchungen (${totalHours.toStringAsFixed(1)} Std.)',
                  style: Theme.of(context).textTheme.titleSmall),
              if (data.assigned.isEmpty) const Text('Keine Zeitbuchungen zugeordnet.'),
              for (final entry in data.assigned)
                ListTile(
                  title: Text('${entry.hours.toStringAsFixed(1)} Std.'),
                  subtitle: entry.note != null ? Text(entry.note!) : null,
                  trailing: isSigned
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => _removeEntry(entry),
                        ),
                ),
              if (!isSigned && data.candidates.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('Weitere Zeitbuchungen hinzufügen', style: Theme.of(context).textTheme.titleSmall),
                for (final entry in data.candidates)
                  ListTile(
                    title: Text('${entry.hours.toStringAsFixed(1)} Std.'),
                    subtitle: entry.note != null ? Text(entry.note!) : null,
                    trailing: IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: () => _addEntry(entry),
                    ),
                  ),
              ],
              const SizedBox(height: 24),
              if (isSigned) ...[
                if (sheet.signatureImage != null)
                  DecoratedBox(
                    decoration: BoxDecoration(border: Border.all(color: Colors.grey)),
                    child: Image.memory(sheet.signatureImage!, height: 120),
                  ),
                const SizedBox(height: 8),
                const Text(signatureDisclaimer, style: TextStyle(fontSize: 11)),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _createCorrection,
                  icon: const Icon(Icons.edit_note_outlined),
                  label: const Text('Korrektur erstellen'),
                ),
              ] else
                FilledButton.icon(
                  onPressed: _busy || data.assigned.isEmpty ? null : _sign,
                  icon: const Icon(Icons.draw_outlined),
                  label: const Text('Unterschreiben'),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _DetailData {
  const _DetailData({required this.sheet, required this.assigned, required this.candidates});
  final TimeSheet sheet;
  final List<TimeEntry> assigned;
  final List<TimeEntry> candidates;
}
