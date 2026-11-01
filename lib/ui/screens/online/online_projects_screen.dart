import 'package:flutter/material.dart';
import 'package:werkkern_client/werkkern_client.dart';
import 'package:werkkern_core/werkkern_core.dart' show Money;

import '../../../domain/services/online_session.dart';
import 'online_document_screen.dart';

/// Projekte online (C1): Liste "JJ/PP · Name", anlegen, Detail mit
/// Dokumenten und einfacher Ergebnisrechnung wie offline.
class OnlineProjectsScreen extends StatefulWidget {
  const OnlineProjectsScreen({super.key, required this.session});
  final OnlineSession session;

  @override
  State<OnlineProjectsScreen> createState() => _OnlineProjectsScreenState();
}

class _OnlineProjectsScreenState extends State<OnlineProjectsScreen> {
  bool _showArchived = false;
  late Future<List<OnlineProject>> _future = _load();

  Future<List<OnlineProject>> _load() async {
    final projects = await widget.session.client.projects(includeArchived: _showArchived);
    if (widget.session.can('customers.read')) {
      try {
        _customerNames = {for (final c in await widget.session.client.customers()) c.id: c.name};
      } on Exception {
        // Ohne Kundenliste bleibt der Untertitel leer.
      }
    }
    return projects;
  }

  void _reload() => setState(() {
        _future = _load();
      });

  Map<String, String> _customerNames = const {};

  Future<void> _create() async {
    final customers = widget.session.can('customers.read') ? await widget.session.client.customers() : const <OnlineCustomer>[];
    if (!mounted) return;
    final result = await showDialog<({String name, String? customerId, String? notes})>(
      context: context,
      builder: (_) => OnlineProjectFormDialog(customers: customers),
    );
    if (result == null || !mounted) return;
    try {
      await widget.session.client.createProject(result.name, customerId: result.customerId, notes: result.notes);
      _reload();
    } on Exception catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(describeOnlineError(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<List<OnlineProject>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text(describeOnlineError(snapshot.error!)));
          if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          final projects = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
            children: [
              SwitchListTile(
                title: const Text('Archivierte anzeigen'),
                value: _showArchived,
                onChanged: (v) {
                  _showArchived = v;
                  _reload();
                },
              ),
              if (projects.isEmpty) const Padding(padding: EdgeInsets.all(16), child: Text('Noch keine Projekte angelegt.')),
              for (final p in projects)
                Card(
                  child: ListTile(
                    leading: Icon(p.isArchived ? Icons.inventory_outlined : Icons.folder_outlined),
                    title: Text('${p.displayNumber} · ${p.name}'),
                    // Wie offline: Kunde bzw. „Ohne Kundenbezug“.
                    subtitle: Text([
                      p.customerId == null ? 'Ohne Kundenbezug' : _customerNames[p.customerId] ?? '–',
                      if (p.isArchived) 'archiviert',
                    ].join(' · ')),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => OnlineProjectScreen(session: widget.session, projectId: p.id),
                        ),
                      );
                      _reload();
                    },
                  ),
                ),
            ],
          );
        },
      ),
      floatingActionButton: widget.session.can('projects.write')
          ? FloatingActionButton.extended(
              heroTag: 'online-projects-fab',
              onPressed: _create,
              icon: const Icon(Icons.add),
              label: const Text('Projekt anlegen'),
            )
          : null,
    );
  }
}

class OnlineProjectScreen extends StatefulWidget {
  const OnlineProjectScreen({super.key, required this.session, required this.projectId});
  final OnlineSession session;
  final String projectId;

  @override
  State<OnlineProjectScreen> createState() => _OnlineProjectScreenState();
}

class _OnlineProjectScreenState extends State<OnlineProjectScreen> {
  late Future<OnlineProjectDetail> _future = widget.session.client.projectDetail(widget.projectId);

  void _reload() => setState(() {
        _future = widget.session.client.projectDetail(widget.projectId);
      });

  Future<void> _toggleArchived(OnlineProject project) async {
    try {
      await widget.session.client.updateProject(project.id, status: project.isArchived ? 'active' : 'archived');
      // Wie offline: nach dem (Ent-)Archivieren zurück zur Liste.
      if (mounted) Navigator.of(context).pop();
    } on Exception catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(describeOnlineError(e))));
    }
  }

  /// Nur online: Name, Kunde und Notizen nachträglich ändern.
  Future<void> _edit(OnlineProject project) async {
    final customers = widget.session.can('customers.read') ? await widget.session.client.customers() : const <OnlineCustomer>[];
    if (!mounted) return;
    final result = await showDialog<({String name, String? customerId, String? notes})>(
      context: context,
      builder: (_) => OnlineProjectFormDialog(customers: customers, existing: project),
    );
    if (result == null || !mounted) return;
    try {
      await widget.session.client.updateProject(
        project.id,
        name: result.name,
        customerId: () => result.customerId,
        notes: () => result.notes,
      );
      _reload();
    } on Exception catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(describeOnlineError(e))));
    }
  }

  static String _money(int? cents) => cents == null ? '–' : Money.fromCents(cents).toString();

  @override
  Widget build(BuildContext context) {
    final modules = widget.session.modules;
    final showHours = modules.contains('timeTracking');
    final showExpenses = modules.contains('buchhaltung');
    final theme = Theme.of(context);
    return FutureBuilder<OnlineProjectDetail>(
      future: _future,
      builder: (context, snapshot) {
        final detail = snapshot.data;
        final project = detail?.project;
        return Scaffold(
          appBar: AppBar(
            title: Text(project == null ? 'Projekt' : '${project.displayNumber} · ${project.name}'),
            actions: [
              if (project != null && widget.session.can('projects.write')) ...[
                IconButton(tooltip: 'Bearbeiten', icon: const Icon(Icons.edit_outlined), onPressed: () => _edit(project)),
                IconButton(
                  tooltip: project.isArchived ? 'Reaktivieren' : 'Archivieren',
                  icon: Icon(project.isArchived ? Icons.unarchive_outlined : Icons.archive_outlined),
                  onPressed: () => _toggleArchived(project),
                ),
              ],
            ],
          ),
          body: snapshot.hasError
              ? Center(child: Text(describeOnlineError(snapshot.error!)))
              : detail == null
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        if (project!.notes != null) ...[
                          Text(project.notes!, style: theme.textTheme.bodyMedium),
                          const SizedBox(height: 16),
                        ],
                        Card(
                          color: theme.colorScheme.surfaceContainerHighest,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Summe finalisierter Rechnungen: ${_money(detail.invoiceGrossCents)}',
                                  style: theme.textTheme.titleMedium,
                                ),
                                if (showHours) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'Geplante Stunden (laut Angebot/Auftrag): ${detail.plannedHours?.replaceAll('.', ',') ?? '–'} · '
                                    'Gebucht: ${detail.bookedHours?.replaceAll('.', ',') ?? '–'}',
                                  ),
                                  Text('Stundenkosten: ${_money(detail.hoursCostCents)}'),
                                ],
                                if (showHours || showExpenses) ...[
                                  const SizedBox(height: 4),
                                  if (showExpenses) Text('Zugeordnete Belege: ${_money(detail.expenseCostCents)}'),
                                  const Divider(),
                                  Text(
                                    'Ergebnis: ${_money(detail.resultCents)}',
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: (detail.resultCents ?? 0) < 0 ? theme.colorScheme.error : null,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Einfache Ergebnisrechnung (Erlöse aus zugeordneten Rechnungen minus '
                                    'direkte Kosten aus zugeordneten Belegen und Stundenkosten) — ohne '
                                    'Fuhrpark-Umlage (Fuhrpark läuft als Gemeinkosten, siehe '
                                    'EÜR-Übersicht). Keine Rechtsprüfung.'
                                    '${detail.resultCents == null ? ' „–“: dafür fehlt dir ein Leserecht.' : ''}',
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ] else ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'Keine Projekt-Ergebnisrechnung — reine Rechnungssumme ohne Kosten, '
                                    'Stundensätze oder Umlagen (weder Buchhaltung- noch '
                                    'Zeiterfassungs-Modul aktiviert).',
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text('Zugeordnete Dokumente', style: theme.textTheme.titleSmall),
                        const SizedBox(height: 8),
                        if (detail.documents.isEmpty) const Text('Noch keine Dokumente zugeordnet.'),
                        for (final d in detail.documents)
                          Card(
                            child: ListTile(
                              leading: Icon(d.isDraft ? Icons.receipt_long_outlined : Icons.receipt_long),
                              title: Text(onlineDocumentKindLabels[d.kind] ?? d.kind),
                              subtitle: Text(d.number ?? 'Entwurf'),
                              trailing: Text(d.grossCents == null ? '' : Money.fromCents(d.grossCents!).toString()),
                              onTap: () async {
                                await Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => OnlineDocumentScreen(session: widget.session, documentId: d.id),
                                  ),
                                );
                                _reload();
                              },
                            ),
                          ),
                      ],
                    ),
        );
      },
    );
  }
}

/// Projekt anlegen/bearbeiten wie offline: Name, Kunde (optional),
/// Notizen.
class OnlineProjectFormDialog extends StatefulWidget {
  const OnlineProjectFormDialog({super.key, required this.customers, this.existing});
  final List<OnlineCustomer> customers;
  final OnlineProject? existing;

  @override
  State<OnlineProjectFormDialog> createState() => _OnlineProjectFormDialogState();
}

class _OnlineProjectFormDialogState extends State<OnlineProjectFormDialog> {
  late final _name = TextEditingController(text: widget.existing?.name);
  late final _notes = TextEditingController(text: widget.existing?.notes);
  late String? _customerId = widget.customers.any((c) => c.id == widget.existing?.customerId) ? widget.existing?.customerId : null;

  @override
  void dispose() {
    _name.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'Neues Projekt' : 'Projekt bearbeiten'),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                key: const Key('online-project-name'),
                controller: _name,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Name *'),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String?>(
                key: const Key('online-project-customer'),
                isExpanded: true,
                initialValue: _customerId,
                decoration: const InputDecoration(labelText: 'Kunde (optional)'),
                items: [
                  const DropdownMenuItem<String?>(value: null, child: Text('Ohne Kundenbezug')),
                  for (final c in widget.customers) DropdownMenuItem<String?>(value: c.id, child: Text(c.name)),
                ],
                onChanged: (value) => setState(() => _customerId = value),
              ),
              const SizedBox(height: 8),
              TextField(
                key: const Key('online-project-notes'),
                controller: _notes,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Notizen'),
              ),
              if (widget.existing == null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Die Projektnummer (JJ/PP) wird beim Anlegen fest vergeben.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
        FilledButton(
          onPressed: () {
            if (_name.text.trim().isEmpty) return;
            Navigator.pop(context, (
              name: _name.text.trim(),
              customerId: _customerId,
              notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
            ));
          },
          child: Text(widget.existing == null ? 'Anlegen' : 'Speichern'),
        ),
      ],
    );
  }
}
