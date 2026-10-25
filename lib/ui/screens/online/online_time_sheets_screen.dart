import 'package:flutter/material.dart';
import 'package:werkkern_client/werkkern_client.dart';

import '../../../domain/services/online_session.dart';
import '../../widgets/signature_pad.dart';
import 'online_form.dart';

/// Kunden-Stundenzettel (C3-Rest): Buchungen eines Tages bündeln, vom
/// Kunden auf dem Gerät unterschreiben lassen; danach unveränderlich,
/// Korrektur nur per Nachtrag.
class OnlineTimeSheetsScreen extends StatelessWidget {
  const OnlineTimeSheetsScreen({super.key, required this.session});
  final OnlineSession session;

  Future<void> _create(BuildContext context, VoidCallback reload) async {
    final documents = [
      for (final d in await session.client.documents())
        if (d.kind == 'order' || d.kind == 'invoice') d,
    ];
    if (!context.mounted) return;
    if (documents.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kein Auftrag/keine Rechnung vorhanden.')));
      return;
    }
    final values = await showOnlineForm(
      context,
      title: 'Neuer Stundenzettel',
      submitLabel: 'Anlegen',
      fields: [
        OnlineField(
          'documentId',
          'Auftrag/Rechnung',
          type: OnlineFieldType.choice,
          required: true,
          options: {for (final d in documents) d.id: '${d.number ?? 'Entwurf'} · ${d.displayCustomerName ?? ''}'},
        ),
        OnlineField('date', 'Tag', type: OnlineFieldType.date, required: true, initial: DateTime.now()),
      ],
    );
    if (values == null || !context.mounted) return;
    final documentId = values['documentId'] as String;
    final date = values['date'] as DateTime;
    OnlineTimeSheet? created;
    await runOnline(context, () async {
      // Eigene Buchungen dieses Auftrags am gewählten Tag gleich übernehmen.
      final entries = (await session.client.timeEntries(mineOnly: true, documentId: documentId)).entries;
      created = await session.client.createTimeSheet(
        documentId: documentId,
        date: date,
        entryIds: [
          for (final e in entries)
            if (e.date.year == date.year && e.date.month == date.month && e.date.day == date.day) e.id,
        ],
      );
    });
    if (created != null && context.mounted) {
      await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => OnlineTimeSheetScreen(session: session, sheetId: created!.id)),
      );
    }
    reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Stundenzettel')),
      body: OnlineListView<OnlineTimeSheet>(
        load: (_) => session.client.timeSheets(),
        emptyText: 'Noch keine Stundenzettel.',
        itemBuilder: (context, s, reload) => Card(
          child: ListTile(
            leading: Icon(s.isSigned ? Icons.verified_outlined : Icons.draw_outlined),
            title: Text('${formatOnlineDate(s.date)}${s.supersedesId == null ? '' : ' · Nachtrag'}'),
            subtitle: Text(s.isSigned ? 'unterschrieben' : 'Entwurf'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              await Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => OnlineTimeSheetScreen(session: session, sheetId: s.id)),
              );
              reload();
            },
          ),
        ),
        floatingActionButton: (reload) => Builder(
          builder: (context) => FloatingActionButton.extended(
            heroTag: 'online-time-sheet-fab',
            onPressed: () => _create(context, reload),
            icon: const Icon(Icons.add),
            label: const Text('Stundenzettel anlegen'),
          ),
        ),
      ),
    );
  }
}

class OnlineTimeSheetScreen extends StatefulWidget {
  const OnlineTimeSheetScreen({super.key, required this.session, required this.sheetId});
  final OnlineSession session;
  final String sheetId;

  @override
  State<OnlineTimeSheetScreen> createState() => _OnlineTimeSheetScreenState();
}

class _OnlineTimeSheetScreenState extends State<OnlineTimeSheetScreen> {
  OnlineTimeSheet? _sheet;
  Object? _error;

  WerkkernApiClient get _client => widget.session.client;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final sheet = await _client.timeSheet(widget.sheetId);
      if (mounted) setState(() => _sheet = sheet);
    } on Exception catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _addEntries() async {
    final sheet = _sheet!;
    final present = {for (final e in sheet.entries) e.id};
    final candidates = [
      for (final e in (await _client.timeEntries(mineOnly: true, documentId: sheet.documentId)).entries)
        if (!present.contains(e.id)) e,
    ];
    if (!mounted) return;
    if (candidates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Keine weiteren eigenen Buchungen zu diesem Auftrag.')));
      return;
    }
    final values = await showOnlineForm(
      context,
      title: 'Buchung hinzufügen',
      submitLabel: 'Hinzufügen',
      fields: [
        OnlineField(
          'entryId',
          'Buchung',
          type: OnlineFieldType.choice,
          required: true,
          options: {
            for (final e in candidates) e.id: '${formatOnlineDate(e.date)} · ${e.hours.replaceAll('.', ',')} Std.${e.note == null ? '' : ' · ${e.note}'}',
          },
        ),
      ],
    );
    if (values == null || !mounted) return;
    await runOnline(context, () async {
      final updated = await _client.addTimeSheetEntries(sheet.id, [values['entryId'] as String]);
      if (mounted) setState(() => _sheet = updated);
    });
  }

  Future<void> _sign() async {
    final values = await showOnlineForm(
      context,
      title: 'Unterschrift',
      submitLabel: 'Weiter zur Unterschrift',
      fields: const [OnlineField('signerName', 'Name des Unterzeichners')],
    );
    if (values == null || !mounted) return;
    final png = await showSignatureDialog(context);
    if (png == null || !mounted) return;
    await runOnline(context, () async {
      final signed = await _client.signTimeSheet(widget.sheetId, png, signerName: values['signerName'] as String?);
      if (mounted) setState(() => _sheet = signed);
    }, success: 'Unterschrieben.');
  }

  Future<void> _correction() async {
    OnlineTimeSheet? created;
    await runOnline(context, () async {
      created = await _client.createTimeSheetCorrection(widget.sheetId);
    });
    if (created != null && mounted) {
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => OnlineTimeSheetScreen(session: widget.session, sheetId: created!.id)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final sheet = _sheet;
    return Scaffold(
      appBar: AppBar(
        title: Text(sheet == null ? 'Stundenzettel' : 'Stundenzettel ${formatOnlineDate(sheet.date)}'),
        actions: [
          if (sheet != null && !sheet.isSigned)
            IconButton(
              tooltip: 'Entwurf löschen',
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                if (!await confirmOnline(context, 'Stundenzettel löschen?', 'Die Buchungen selbst bleiben erhalten.')) return;
                if (!context.mounted) return;
                if (await runOnline(context, () => _client.deleteTimeSheet(sheet.id)) && context.mounted) Navigator.of(context).pop();
              },
            ),
        ],
      ),
      bottomNavigationBar: sheet == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: sheet.isSigned
                    ? OutlinedButton.icon(onPressed: _correction, icon: const Icon(Icons.post_add), label: const Text('Nachtrag anlegen'))
                    : FilledButton.icon(
                        onPressed: sheet.entries.isEmpty ? null : _sign,
                        icon: const Icon(Icons.draw_outlined),
                        label: const Text('Vom Kunden unterschreiben lassen'),
                      ),
              ),
            ),
      body: _error != null
          ? Center(child: Text(describeOnlineError(_error!)))
          : sheet == null
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    Card(
                      child: ListTile(
                        title: Text(sheet.customerName ?? 'Kunde'),
                        subtitle: Text([
                          if (sheet.documentNumber != null) sheet.documentNumber!,
                          if (sheet.projectName != null) sheet.projectName!,
                          if (sheet.supersedesId != null) 'Nachtrag zu einem unterschriebenen Zettel',
                        ].join(' · ')),
                        trailing: Text('${sheet.totalHours.replaceAll('.', ',')} Std.', style: const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                    for (final e in sheet.entries)
                      Card(
                        child: ListTile(
                          title: Text('${e.hours.replaceAll('.', ',')} Std.'),
                          subtitle: Text([formatOnlineDate(e.date), if (e.note != null) e.note!].join(' · ')),
                          trailing: sheet.isSigned
                              ? null
                              : IconButton(
                                  tooltip: 'Vom Zettel lösen',
                                  icon: const Icon(Icons.remove_circle_outline),
                                  onPressed: () async {
                                    await runOnline(context, () => _client.removeTimeSheetEntry(sheet.id, e.id));
                                    await _load();
                                  },
                                ),
                        ),
                      ),
                    if (!sheet.isSigned)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(onPressed: _addEntries, icon: const Icon(Icons.add), label: const Text('Buchung hinzufügen')),
                      ),
                    if (sheet.isSigned) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Unterschrieben${sheet.signerName == null ? '' : ' von ${sheet.signerName}'} am '
                        '${formatOnlineDate(sheet.signedAt!.toLocal())}',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      if (sheet.signaturePng != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Image.memory(sheet.signaturePng!, height: 120),
                        ),
                      const Text(signatureDisclaimer, style: TextStyle(fontSize: 11)),
                    ],
                  ],
                ),
    );
  }
}
