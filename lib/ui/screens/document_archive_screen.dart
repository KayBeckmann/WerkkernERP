import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../data/repositories/pdf_archive_repository.dart';

/// Firm-wide read-only archive. Saved bytes are never regenerated on open.
class DocumentArchiveScreen extends StatefulWidget {
  const DocumentArchiveScreen({
    super.key,
    required this.archive,
    required this.companyId,
  });
  final PdfArchiveRepository archive;
  final String companyId;

  @override
  State<DocumentArchiveScreen> createState() => _DocumentArchiveScreenState();
}

class _DocumentArchiveScreenState extends State<DocumentArchiveScreen> {
  late Future<List<ArchivedPdf>> _versions = widget.archive.listAll(
    companyId: widget.companyId,
  );

  void _reload() => setState(
    () => _versions = widget.archive.listAll(companyId: widget.companyId),
  );

  String _source(PdfArchiveSource type) => switch (type) {
    PdfArchiveSource.customerDocument => 'Dokument',
    PdfArchiveSource.purchaseOrder => 'Bestellung',
    PdfArchiveSource.signedTimeSheet => 'Stundenzettel',
  };

  Future<void> _open(ArchivedPdf pdf) async {
    try {
      final bytes = await widget.archive.readBytes(
        companyId: widget.companyId,
        artifactId: pdf.id,
      );
      if (bytes == null) throw StateError('PDF not found');
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => Scaffold(
            appBar: AppBar(
              title: Text(
                '${_source(pdf.sourceType)} ${pdf.sourceId} · Version ${pdf.version}',
              ),
            ),
            body: PdfPreview(
              build: (_) async => bytes,
              pdfFileName:
                  '${pdf.sourceType.name}_${pdf.sourceId}_v${pdf.version}.pdf',
            ),
          ),
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Gespeicherte PDF-Version konnte nicht geöffnet werden.',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      automaticallyImplyLeading: false,
      title: const Text('Dokumentenablage'),
    ),
    body: FutureBuilder<List<ArchivedPdf>>(
      future: _versions,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(
            child: Text('Dokumentenablage konnte nicht geladen werden.'),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        return RefreshIndicator(
          onRefresh: () async => _reload(),
          child: ListView(
            children: [
              if (snapshot.data!.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: Text('Noch keine PDF-Version gespeichert.'),
                  ),
                ),
              for (final pdf in snapshot.data!)
                ListTile(
                  title: Text(
                    '${_source(pdf.sourceType)} ${pdf.sourceId} · Version ${pdf.version}',
                  ),
                  subtitle: Text(pdf.createdAt.toLocal().toString()),
                  trailing: const Icon(Icons.picture_as_pdf_outlined),
                  onTap: () => _open(pdf),
                ),
            ],
          ),
        );
      },
    ),
  );
}
