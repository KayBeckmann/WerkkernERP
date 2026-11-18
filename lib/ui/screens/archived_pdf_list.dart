import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../data/repositories/pdf_archive_repository.dart';

/// Read-only archive view. Opening a saved version never invokes a PDF builder.
class ArchivedPdfList extends StatelessWidget {
  const ArchivedPdfList({super.key, required this.archive, required this.companyId,
    required this.sourceType, required this.sourceId, required this.fileName});
  final PdfArchiveRepository archive;
  final String companyId;
  final PdfArchiveSource sourceType;
  final String sourceId;
  final String fileName;

  @override
  Widget build(BuildContext context) => FutureBuilder<List<ArchivedPdf>>(
    future: archive.list(companyId: companyId, sourceType: sourceType, sourceId: sourceId),
    builder: (context, snapshot) {
      if (snapshot.hasError) return const Text('PDF-Archiv konnte nicht geladen werden.');
      if (!snapshot.hasData) return const LinearProgressIndicator();
      if (snapshot.data!.isEmpty) return const Text('Noch keine PDF-Version gespeichert.');
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Gespeicherte PDF-Versionen'),
        for (final artifact in snapshot.data!)
          ListTile(
            title: Text('Version ${artifact.version}'),
            subtitle: Text(artifact.createdAt.toLocal().toString()),
            trailing: const Icon(Icons.picture_as_pdf_outlined),
            onTap: () async {
              try {
                final bytes = await archive.readBytes(companyId: companyId, artifactId: artifact.id);
                if (bytes == null) throw StateError('PDF not found');
                await Printing.sharePdf(bytes: bytes, filename: '${fileName}_v${artifact.version}.pdf');
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Gespeicherte PDF-Version konnte nicht geöffnet werden.')),
                  );
                }
              }
            },
          ),
      ]);
    },
  );
}
