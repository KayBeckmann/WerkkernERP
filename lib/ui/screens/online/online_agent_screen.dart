import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../../domain/services/online_session.dart';
import 'online_text_prompt.dart';

/// C8 "KI-Zugang": eigene Agent-Token für LLM-Werkzeuge (MCP/API) und
/// die Freigabe irreversibler Agent-Aktionen. Der Agent hat genau die
/// Rechte des angemeldeten Nutzers, aber nie Admin-Funktionen;
/// Finalisieren/Löschen wartet hier auf ausdrückliche Bestätigung.
class OnlineAgentScreen extends StatefulWidget {
  const OnlineAgentScreen({super.key, required this.session});
  final OnlineSession session;

  @override
  State<OnlineAgentScreen> createState() => _OnlineAgentScreenState();
}

class _OnlineAgentScreenState extends State<OnlineAgentScreen> {
  late Future<_AgentData> _future = _load();

  Future<_AgentData> _load() async => _AgentData(
        tokens: await widget.session.client.agentTokens(),
        approvals: await widget.session.client.approvals(),
      );

  void _reload() => setState(() {
        _future = _load();
      });

  void _snack(String message) => ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(SnackBar(content: Text(message)));

  Future<void> _createToken() async {
    final label = await showOnlineTextPrompt(
      context,
      title: 'Neuer KI-Zugang',
      label: 'Bezeichnung (z. B. "Claude Desktop")',
      confirm: 'Erzeugen',
      fieldKey: const Key('online-agent-label'),
      intro: 'Der Agent arbeitet mit genau deinen Rechten in dieser Firma — ohne Verwaltungsfunktionen. '
          'Finalisieren und Löschen musst du hier jeweils bestätigen.',
    );
    if (label == null || label.isEmpty) return;
    try {
      final created = await widget.session.client.createAgentToken(label);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('KI-Zugang erzeugt'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Dieses Token wird nur jetzt angezeigt. Trage es im MCP-Client als WERKKERN_AGENT_TOKEN ein '
                '(zusammen mit WERKKERN_URL = Server-Adresse).',
              ),
              const SizedBox(height: 12),
              SelectableText(created.token, key: const Key('online-agent-token')),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Clipboard.setData(ClipboardData(text: created.token)), child: const Text('Kopieren')),
            FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Fertig')),
          ],
        ),
      );
      _reload();
    } on Exception catch (e) {
      if (mounted) _snack(describeOnlineError(e));
    }
  }

  Future<void> _decide(String id, {required bool confirm}) async {
    try {
      if (confirm) {
        await widget.session.client.confirmApproval(id);
        _snack('Bestätigt und ausgeführt.');
      } else {
        await widget.session.client.rejectApproval(id);
        _snack('Abgelehnt — nichts geändert.');
      }
    } on Exception catch (e) {
      // Bei der Ausführung prüft der Server alles neu (z. B. Recht
      // inzwischen entzogen) — dann ist die Freigabe trotzdem erledigt.
      _snack(describeOnlineError(e));
    }
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd.MM.yyyy HH:mm');
    return Scaffold(
      appBar: AppBar(
        title: const Text('KI-Zugang'),
        actions: [IconButton(tooltip: 'Aktualisieren', icon: const Icon(Icons.refresh), onPressed: _reload)],
      ),
      body: FutureBuilder<_AgentData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text(describeOnlineError(snapshot.error!)));
          if (snapshot.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator());
          final data = snapshot.data!;
          final pending = data.approvals.where((a) => a.status == 'pending').toList();
          final decided = data.approvals.where((a) => a.status != 'pending').take(20).toList();
          return ListView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
            children: [
              Text('Freigaben', style: Theme.of(context).textTheme.titleMedium),
              if (pending.isEmpty) const Padding(padding: EdgeInsets.all(8), child: Text('Keine offenen Freigaben.')),
              for (final a in pending)
                Card(
                  color: Theme.of(context).colorScheme.tertiaryContainer,
                  child: ListTile(
                    leading: const Icon(Icons.smart_toy_outlined),
                    title: Text(a.summary),
                    subtitle: Text('Angefragt ${dateFormat.format(a.createdAt.toLocal())}'),
                    trailing: Wrap(
                      children: [
                        TextButton(onPressed: () => _decide(a.id, confirm: false), child: const Text('Ablehnen')),
                        FilledButton(onPressed: () => _decide(a.id, confirm: true), child: const Text('Bestätigen')),
                      ],
                    ),
                  ),
                ),
              for (final a in decided)
                ListTile(
                  dense: true,
                  leading: Icon(a.status == 'confirmed' ? Icons.check : Icons.block),
                  title: Text(a.summary),
                  subtitle: Text(switch (a.status) {
                    'confirmed' => a.resultStatus != null && a.resultStatus! >= 400
                        ? 'Bestätigt, aber vom Server abgelehnt (${a.resultStatus})'
                        : 'Bestätigt',
                    'rejected' => 'Abgelehnt',
                    _ => a.status,
                  }),
                ),
              const Divider(height: 32),
              Text('Zugänge', style: Theme.of(context).textTheme.titleMedium),
              if (data.tokens.isEmpty) const Padding(padding: EdgeInsets.all(8), child: Text('Noch kein KI-Zugang.')),
              for (final t in data.tokens)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.key_outlined),
                    title: Text(t.label),
                    subtitle: Text(
                      'Erstellt ${dateFormat.format(t.createdAt.toLocal())}'
                      '${t.lastUsedAt == null ? ' · nie benutzt' : ' · zuletzt ${dateFormat.format(t.lastUsedAt!.toLocal())}'}',
                    ),
                    trailing: IconButton(
                      tooltip: 'Widerrufen',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () async {
                        try {
                          await widget.session.client.revokeAgentToken(t.id);
                          _reload();
                        } on Exception catch (e) {
                          _snack(describeOnlineError(e));
                        }
                      },
                    ),
                  ),
                ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'online-agent-fab',
        onPressed: _createToken,
        icon: const Icon(Icons.add),
        label: const Text('KI-Zugang erzeugen'),
      ),
    );
  }
}

class _AgentData {
  const _AgentData({required this.tokens, required this.approvals});
  final List<({String id, String label, DateTime createdAt, DateTime? lastUsedAt})> tokens;
  final List<({String id, String summary, String status, DateTime createdAt, int? resultStatus})> approvals;
}
