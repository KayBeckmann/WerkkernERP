import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../domain/services/ecad_material_preview.dart';

class EcadMaterialScreen extends StatefulWidget {
  const EcadMaterialScreen({
    super.key,
    required this.companyId,
    required this.companyName,
    required this.loadArticles,
    this.readFile,
  });
  final String companyId, companyName;
  final Future<List<EcadJson>> Function() loadArticles;
  final Future<String?> Function()? readFile;
  @override
  State<EcadMaterialScreen> createState() => _EcadMaterialScreenState();
}

class _EcadMaterialScreenState extends State<EcadMaterialScreen> {
  EcadMaterialPreview? preview;
  List<EcadJson> articles = [];
  final matches = <String, String>{};
  String? error;
  bool busy = false;
  int loadGeneration = 0;
  Future<String?> readLocalFile() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    return file == null ? null : utf8.decode(await file.readAsBytes());
  }

  Future<void> load() async {
    setState(() => busy = true);
    try {
      final input = await (widget.readFile ?? readLocalFile)();
      if (input == null) return;
      final next = await EcadMaterialPreview.parse(input);
      final existing = await widget.loadArticles();
      if (mounted) {
        setState(() {
          preview = next;
          articles = existing;
          matches.clear();
          loadGeneration++;
          error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> saveDraft() async {
    final current = preview;
    if (current == null) return;
    final yes = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Zuordnung als Entwurf exportieren?'),
        content: Text(
          'Zielfirma: ${widget.companyName}. ${matches.length} von ${current.rows.length} Artikelpositionen zugeordnet. Nicht zugeordnete Zeilen bleiben offen. Es entstehen keine ERP-Artikel, Angebote, Aufträge oder Lagerbuchungen.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Entwurf exportieren'),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    try {
      final data = {
        'schema': 'werkkernerp.ecad-preview.v1',
        'companyId': widget.companyId,
        'packetId': current.packetId,
        'source': current.packet,
        'mappings': matches,
        'status': 'preview',
      };
      await FilePicker.saveFile(
        fileName: 'ecad-importvorschau.json',
        type: FileType.custom,
        allowedExtensions: ['json'],
        bytes: Uint8List.fromList(
          utf8.encode(const JsonEncoder.withIndent('  ').convert(data)),
        ),
      );
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('LibreECAD · Materialvorschau')),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          'Zielfirma: ${widget.companyName}',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const Text(
          'Eine Materialdatei ersetzt die bisherige Vorschau vollständig. Gleiche Paket-IDs erzeugen keine zusätzlichen Positionen. Namensübereinstimmungen sind Vorschläge; die ERP-Artikelzuordnung erfolgt ausdrücklich.',
        ),
        if (error != null)
          Text(
            error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        FilledButton.icon(
          onPressed: busy ? null : load,
          icon: const Icon(Icons.file_open_outlined),
          label: Text(busy ? 'Lädt …' : 'LibreECAD-Datei öffnen'),
        ),
        if (preview != null) ...[
          const SizedBox(height: 20),
          Text(
            '${preview!.packet['projectName']} · Version ${preview!.packet['projectVersion']}',
          ),
          SelectableText(
            'Quelle: ${preview!.packet['source']}\nPaket-ID: ${preview!.packetId}',
          ),
          for (final r in preview!.rows)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${r['articleNumber']} · ${r['name']} · ${r['quantity']} Stück',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      'Artikelversion ${r['articleVersion']} · Variante ${r['variant']} · ${(r['bmks'] as List).join(', ')}',
                    ),
                    Text(
                      '${preview!.candidates(r, articles).length} Namens-/Einheitenvorschläge',
                    ),
                    DropdownButtonFormField<String>(
                      key: ValueKey(
                        '$loadGeneration/${preview!.packetId}/${r['id']}',
                      ),
                      initialValue: matches[r['id']] ?? '',
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText:
                            'Bestehenden ERP-Artikel ausdrücklich zuordnen',
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: '',
                          child: Text('Offen lassen'),
                        ),
                        for (final a in articles.where(
                          (a) => EcadMaterialPreview.pieceUnit(a['unit']),
                        ))
                          DropdownMenuItem(
                            value: a['id'],
                            child: Text(
                              '${a['name']} · ${a['id']}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (v) => setState(() {
                        if (v == null || v.isEmpty) {
                          matches.remove(r['id']);
                        } else {
                          matches[r['id']] = v;
                        }
                      }),
                    ),
                  ],
                ),
              ),
            ),
          Text(
            'Ohne Artikelzuordnung in LibreECAD: ${(preview!.packet['unassigned'] as List).length}',
          ),
          for (final r in preview!.packet['unassigned'])
            ListTile(
              title: Text('${r['bmk']} · ${r['label']}'),
              subtitle: Text(r['reason']),
            ),
          OutlinedButton(
            onPressed: saveDraft,
            child: const Text('Zuordnungsentwurf exportieren'),
          ),
        ],
      ],
    ),
  );
}
