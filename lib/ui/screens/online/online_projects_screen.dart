import 'package:flutter/material.dart';
import 'package:werkkern_client/werkkern_client.dart';
import 'package:werkkern_core/werkkern_core.dart' show Money;

import '../../../domain/services/online_session.dart';
import 'online_document_screen.dart';
import 'online_text_prompt.dart';

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

  Future<List<OnlineProject>> _load() => widget.session.client.projects(includeArchived: _showArchived);

  void _reload() => setState(() {
        _future = _load();
      });

  Future<void> _create() async {
    final name = await showOnlineTextPrompt(
      context,
      title: 'Neues Projekt',
      label: 'Projektname',
      confirm: 'Anlegen',
      fieldKey: const Key('online-project-name'),
      intro: 'Die Projektnummer (JJ/PP) wird beim Anlegen fest vergeben.',
    );
    if (name == null || name.isEmpty) return;
    try {
      await widget.session.client.createProject(name);
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
              if (projects.isEmpty) const Padding(padding: EdgeInsets.all(16), child: Text('Keine Projekte.')),
              for (final p in projects)
                Card(
                  child: ListTile(
                    leading: Icon(p.isArchived ? Icons.inventory_outlined : Icons.folder_outlined),
                    title: Text('${p.displayNumber} · ${p.name}'),
                    subtitle: p.isArchived ? const Text('archiviert') : null,
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
              icon: const Icon(Icons.create_new_folder_outlined),
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
      _reload();
    } on Exception catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(describeOnlineError(e))));
    }
  }

  Widget _row(String label, String value, {bool bold = false}) {
    final style = bold ? const TextStyle(fontWeight: FontWeight.bold) : null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(children: [Expanded(child: Text(label, style: style)), Text(value, style: style)]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<OnlineProjectDetail>(
      future: _future,
      builder: (context, snapshot) {
        final detail = snapshot.data;
        return Scaffold(
          appBar: AppBar(
            title: Text(detail == null ? 'Projekt' : '${detail.project.displayNumber} · ${detail.project.name}'),
            actions: [
              if (detail != null && widget.session.can('projects.write'))
                IconButton(
                  tooltip: detail.project.isArchived ? 'Wieder aktivieren' : 'Archivieren',
                  icon: Icon(detail.project.isArchived ? Icons.unarchive_outlined : Icons.archive_outlined),
                  onPressed: () => _toggleArchived(detail.project),
                ),
            ],
          ),
          body: snapshot.hasError
              ? Center(child: Text(describeOnlineError(snapshot.error!)))
              : detail == null
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      padding: const EdgeInsets.all(12),
                      children: [
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Ergebnis', style: Theme.of(context).textTheme.titleMedium),
                                if (detail.invoiceGrossCents != null)
                                  _row('Erlöse (finalisierte Rechnungen, brutto)', '${Money.fromCents(detail.invoiceGrossCents!)}'),
                                if (detail.hoursCostCents != null)
                                  _row('Stundenkosten (gebuchte Zeiten)', '− ${Money.fromCents(detail.hoursCostCents!)}'),
                                if (detail.resultCents != null) ...[
                                  const Divider(),
                                  _row('Ergebnis', '${Money.fromCents(detail.resultCents!)}', bold: true),
                                ],
                                if (detail.plannedHours != null || detail.bookedHours != null) ...[
                                  const SizedBox(height: 8),
                                  _row(
                                    'Stunden geplant / gebucht',
                                    '${detail.plannedHours?.replaceAll('.', ',') ?? '–'} / '
                                        '${detail.bookedHours?.replaceAll('.', ',') ?? '–'}',
                                  ),
                                ],
                                const SizedBox(height: 8),
                                const Text(
                                  'Einfache interne Ergebnisrechnung, keine GuV. Belege/Fuhrpark laufen online noch nicht ein.',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text('Dokumente', style: Theme.of(context).textTheme.titleMedium),
                        if (detail.documents.isEmpty) const Padding(padding: EdgeInsets.all(8), child: Text('Keine (sichtbaren) Dokumente.')),
                        for (final d in detail.documents)
                          Card(
                            child: ListTile(
                              title: Text(d.number ?? '${onlineDocumentKindLabels[d.kind] ?? d.kind} (Entwurf)'),
                              subtitle: Text(onlineDocumentKindLabels[d.kind] ?? d.kind),
                              trailing: Text(d.grossCents == null ? '' : '${Money.fromCents(d.grossCents!)}'),
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
