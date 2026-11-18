import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../../domain/services/online_session.dart';

/// All archived renditions in this tenant; the server remains the authority
/// for source-level access and the UI also hides unavailable source kinds.
class OnlineDocumentArchiveScreen extends StatefulWidget {
  const OnlineDocumentArchiveScreen({super.key, required this.session});
  final OnlineSession session;

  @override
  State<OnlineDocumentArchiveScreen> createState() =>
      _OnlineDocumentArchiveScreenState();
}

class _ArchiveVersion {
  const _ArchiveVersion(
    this.sourceType,
    this.sourceId,
    this.version,
    this.createdAt,
  );
  final String sourceType;
  final String sourceId;
  final int version;
  final DateTime createdAt;
}

class _OnlineDocumentArchiveScreenState
    extends State<OnlineDocumentArchiveScreen> {
  late Future<List<_ArchiveVersion>> _versions = _load();

  bool _canRead(String type) => switch (type) {
    'document' => widget.session.can('invoices.read'),
    'purchase-order' => widget.session.can('purchaseOrders.read'),
    'time-sheet' =>
      widget.session.can('timeTracking.read') ||
          widget.session.can('timeTracking.write'),
    _ => false,
  };

  Future<List<_ArchiveVersion>> _load() async {
    if (widget.session.offlineOnly ||
        ![
          'invoices.read',
          'purchaseOrders.read',
          'timeTracking.write',
          'timeTracking.read',
        ].any(widget.session.can)) {
      return [];
    }
    final versions = <_ArchiveVersion>[];
    var offset = 0;
    while (true) {
      final response =
          await widget.session.client.request(
                'GET',
                '/pdf-archive/versions',
                query: {'limit': '100', 'offset': '$offset'},
              )
              as Map;
      final page = response['versions'] as List;
      for (final raw in page) {
        if (raw is Map &&
            raw['sourceType'] is String &&
            _canRead(raw['sourceType'] as String)) {
          versions.add(
            _ArchiveVersion(
              raw['sourceType'] as String,
              raw['sourceId'] as String,
              (raw['version'] as num).toInt(),
              DateTime.parse(raw['createdAt'] as String),
            ),
          );
        }
      }
      if (response['hasMore'] != true) break;
      if (page.isEmpty) {
        throw StateError('Leere Archivseite trotz weiterer Einträge.');
      }
      offset += page.length;
    }
    return versions;
  }

  String _label(String type) => switch (type) {
    'document' => 'Dokument',
    'purchase-order' => 'Bestellung',
    'time-sheet' => 'Stundenzettel',
    _ => 'PDF',
  };

  Future<void> _open(_ArchiveVersion pdf) async {
    try {
      final type = Uri.encodeComponent(pdf.sourceType);
      final id = Uri.encodeComponent(pdf.sourceId);
      final bytes = await widget.session.client.downloadBytes(
        '/pdf-archive/$type/$id/versions/${pdf.version}',
      );
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => Scaffold(
            appBar: AppBar(
              title: Text(
                '${_label(pdf.sourceType)} ${pdf.sourceId} · Version ${pdf.version}',
              ),
            ),
            body: PdfPreview(
              build: (_) async => bytes,
              pdfFileName:
                  '${pdf.sourceType}_${pdf.sourceId}_v${pdf.version}.pdf',
            ),
          ),
        ),
      );
    } on Exception catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(describeOnlineError(error))));
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      automaticallyImplyLeading: false,
      title: const Text('Dokumentenablage'),
    ),
    body: FutureBuilder<List<_ArchiveVersion>>(
      future: _versions,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text(describeOnlineError(snapshot.error!)));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        return RefreshIndicator(
          onRefresh: () async {
            setState(() => _versions = _load());
            await _versions;
          },
          child: ListView(
            children: [
              if (snapshot.data!.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: Text('Noch keine PDF-Version verfügbar.'),
                  ),
                ),
              for (final pdf in snapshot.data!)
                ListTile(
                  title: Text(
                    '${_label(pdf.sourceType)} ${pdf.sourceId} · Version ${pdf.version}',
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
