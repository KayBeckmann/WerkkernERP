import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/database/database.dart';
import '../../data/database/tables.dart';
import '../../data/repositories/invoice_repository.dart';
import '../../data/repositories/project_repository.dart';
import '../../data/repositories/staff_role_repository.dart';
import '../../data/repositories/time_entry_repository.dart';
import '../../domain/services/active_company_service.dart';

/// Zeiterfassung (C3.1, Nachtrag 2026-10-20: "Der Monteur muss seine
/// Zeiten buchen können: Auftrag / Rechnung / Projekt") — Übersicht
/// aller Zeitbuchungen der aktiven Firma, neue Buchung anlegen.
class TimeEntriesScreen extends StatefulWidget {
  const TimeEntriesScreen({super.key});

  @override
  State<TimeEntriesScreen> createState() => _TimeEntriesScreenState();
}

class _TimeEntriesScreenState extends State<TimeEntriesScreen> {
  late Future<_ListData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_ListData> _load() async {
    final companyId = context.read<ActiveCompanyService>().active!.id;
    final timeEntryRepo = context.read<TimeEntryRepository>();
    final staffRoleRepo = context.read<StaffRoleRepository>();
    final invoiceRepo = context.read<InvoiceRepository>();
    final projectRepo = context.read<ProjectRepository>();

    final entries = await timeEntryRepo.listForCompany(companyId);
    final roles = await staffRoleRepo.listForCompany(companyId);
    final roleNames = {for (final role in roles) role.id: role.name};

    final orders = await invoiceRepo.listAllForCompany(companyId, kind: DocumentKind.order);
    final invoices = await invoiceRepo.listAllForCompany(companyId, kind: DocumentKind.invoice);
    final documentLabels = {
      for (final doc in [...orders, ...invoices]) doc.id: doc.invoiceNumber ?? 'Entwurf',
    };

    final projects = await projectRepo.listForCompany(companyId);
    final projectNames = {for (final project in projects) project.id: project.name};

    return _ListData(
      entries: entries,
      roleNames: roleNames,
      documentLabels: documentLabels,
      projectNames: projectNames,
    );
  }

  void _reload() => setState(() {
        _future = _load();
      });

  Future<void> _create() async {
    final companyId = context.read<ActiveCompanyService>().active!.id;
    final invoiceRepo = context.read<InvoiceRepository>();
    final projectRepo = context.read<ProjectRepository>();
    final staffRoleRepo = context.read<StaffRoleRepository>();
    final timeEntryRepo = context.read<TimeEntryRepository>();

    final orders = await invoiceRepo.listAllForCompany(companyId, kind: DocumentKind.order);
    final invoices = await invoiceRepo.listAllForCompany(companyId, kind: DocumentKind.invoice);
    final projects = await projectRepo.listForCompany(companyId);
    final roles = await staffRoleRepo.listForCompany(companyId);
    if (!mounted) return;

    final result = await showDialog<_TimeEntryFormResult>(
      context: context,
      builder: (context) => _TimeEntryFormDialog(
        documents: [...orders, ...invoices],
        projects: projects,
        roles: roles,
      ),
    );
    if (result == null || !mounted) return;
    await timeEntryRepo.create(
          companyId: companyId,
          date: result.date,
          hours: result.hours,
          staffRoleId: result.staffRoleId,
          invoiceId: result.invoiceId,
          projectId: result.projectId,
          note: result.note,
        );
    _reload();
  }

  Future<void> _delete(TimeEntry entry) async {
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
    final companyId = context.read<ActiveCompanyService>().active!.id;
    await context.read<TimeEntryRepository>().delete(companyId: companyId, id: entry.id);
    _reload();
  }

  String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';

  String _formatHours(double hours) =>
      hours == hours.roundToDouble() ? hours.toStringAsFixed(0) : hours.toString();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<_ListData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data!;
          if (data.entries.isEmpty) {
            return const Center(child: Text('Noch keine Zeiten gebucht.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
            itemCount: data.entries.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final entry = data.entries[index];
              final reference = entry.invoiceId != null
                  ? data.documentLabels[entry.invoiceId] ?? '(unbekanntes Dokument)'
                  : entry.projectId != null
                      ? data.projectNames[entry.projectId] ?? '(unbekanntes Projekt)'
                      : '–';
              final roleLabel = entry.staffRoleId == null ? null : data.roleNames[entry.staffRoleId];
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.schedule_outlined),
                  title: Text('${_formatHours(entry.hours)} Std. · $reference'),
                  subtitle: Text(
                    [
                      _formatDate(entry.date),
                      ?roleLabel,
                      ?entry.note,
                    ].join(' · '),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _delete(entry),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'time-entries-fab',
        onPressed: _create,
        icon: const Icon(Icons.add),
        label: const Text('Zeit buchen'),
      ),
    );
  }
}

class _ListData {
  const _ListData({
    required this.entries,
    required this.roleNames,
    required this.documentLabels,
    required this.projectNames,
  });
  final List<TimeEntry> entries;
  final Map<String, String> roleNames;
  final Map<String, String> documentLabels;
  final Map<String, String> projectNames;
}

enum _ReferenceKind { document, project }

class _TimeEntryFormResult {
  const _TimeEntryFormResult({
    required this.date,
    required this.hours,
    this.staffRoleId,
    this.invoiceId,
    this.projectId,
    this.note,
  });
  final DateTime date;
  final double hours;
  final String? staffRoleId;
  final String? invoiceId;
  final String? projectId;
  final String? note;
}

/// Zeitbuchungs-Dialog — Bezug ist entweder ein Auftrag/eine Rechnung
/// ODER ein Projekt (Segmented-Auswahl), mindestens einer der beiden
/// ist Pflicht (siehe `TimeEntryRepository.create()`).
class _TimeEntryFormDialog extends StatefulWidget {
  const _TimeEntryFormDialog({required this.documents, required this.projects, required this.roles});
  final List<Invoice> documents;
  final List<Project> projects;
  final List<StaffRole> roles;

  @override
  State<_TimeEntryFormDialog> createState() => _TimeEntryFormDialogState();
}

class _TimeEntryFormDialogState extends State<_TimeEntryFormDialog> {
  _ReferenceKind _referenceKind = _ReferenceKind.document;
  String? _invoiceId;
  String? _projectId;
  String? _staffRoleId;
  DateTime _date = DateTime.now();
  final _hoursCtrl = TextEditingController(text: '1');
  final _noteCtrl = TextEditingController();

  @override
  void dispose() {
    _hoursCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Zeit buchen'),
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
              TextField(
                controller: _hoursCtrl,
                decoration: const InputDecoration(labelText: 'Stunden *'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 8),
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
              if (widget.roles.isNotEmpty)
                DropdownButtonFormField<String?>(
                  isExpanded: true,
                  initialValue: _staffRoleId,
                  decoration: const InputDecoration(labelText: 'Rolle (optional)'),
                  items: [
                    const DropdownMenuItem<String?>(value: null, child: Text('— ohne Rolle —')),
                    for (final role in widget.roles)
                      DropdownMenuItem(value: role.id, child: Text(role.name)),
                  ],
                  onChanged: (value) => setState(() => _staffRoleId = value),
                ),
              TextField(
                controller: _noteCtrl,
                decoration: const InputDecoration(labelText: 'Notiz (optional)'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
        FilledButton(
          onPressed: () {
            final hours = double.tryParse(_hoursCtrl.text.trim().replaceAll(',', '.'));
            if (hours == null || hours <= 0) return;
            final referenceId =
                _referenceKind == _ReferenceKind.document ? _invoiceId : _projectId;
            if (referenceId == null) return;
            Navigator.pop(
              context,
              _TimeEntryFormResult(
                date: _date,
                hours: hours,
                staffRoleId: _staffRoleId,
                invoiceId: _referenceKind == _ReferenceKind.document ? _invoiceId : null,
                projectId: _referenceKind == _ReferenceKind.project ? _projectId : null,
                note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
              ),
            );
          },
          child: const Text('Buchen'),
        ),
      ],
    );
  }
}
