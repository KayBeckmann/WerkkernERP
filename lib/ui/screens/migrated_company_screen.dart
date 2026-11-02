import 'package:drift/drift.dart' show BooleanExpressionOperators, OrderingTerm;
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:werkkern_client/werkkern_client.dart';

import '../../data/database/database.dart';
import '../../data/database/tables.dart';
import '../../data/repositories/invoice_repository.dart';
import '../../domain/services/online_accounts.dart';
import '../../pdf/invoice_pdf_builder.dart';
import 'backup_screen.dart';
import 'invoices_screen.dart' show DocumentLabels;
import 'online/online_login_screen.dart';

/// B4: eine auf den Server umgezogene Firma öffnet die App nur noch als
/// Archiv — finalisierte Dokumente lesen/als PDF teilen und eine
/// Sicherung ziehen. Bearbeiten, Finalisieren und Wiederherstellen gibt
/// es hier bewusst nicht (kein Zurück, Kay 2026-11-02).
class MigratedCompanyScreen extends StatefulWidget {
  const MigratedCompanyScreen({super.key, required this.company, this.accountStore, this.clientFactory});

  final Company company;
  final OnlineAccountStore? accountStore;
  final WerkkernApiClient Function(Uri baseUrl)? clientFactory;

  @override
  State<MigratedCompanyScreen> createState() => _MigratedCompanyScreenState();
}

class _MigratedCompanyScreenState extends State<MigratedCompanyScreen> {
  late final OnlineAccountStore _accounts = widget.accountStore ?? defaultOnlineAccountStore();
  List<Invoice>? _documents;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = context.read<AppDatabase>();
    final docs = await (db.select(db.invoices)
          ..where((i) => i.companyId.equals(widget.company.id) & i.status.equalsValue(InvoiceStatus.finalized))
          ..orderBy([(i) => OrderingTerm.desc(i.issueDate)]))
        .get();
    if (mounted) setState(() => _documents = docs);
  }

  Future<void> _openOnline() async {
    final server = widget.company.migratedToServer;
    final account = (await _accounts.load()).where((a) => a.serverUrl == server).firstOrNull;
    final membership =
        account?.memberships.where((m) => m.companyName == widget.company.migratedToCompanyName).firstOrNull;
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => OnlineLoginScreen(
          clientFactory: widget.clientFactory,
          accountStore: _accounts,
          account: account,
          targetCompanyId: membership?.companyId,
        ),
      ),
    );
  }

  Future<void> _showPdf(Invoice invoice) async {
    final repo = context.read<InvoiceRepository>();
    final items = await repo.itemsFor(invoice.id);
    final advances = invoice.kind == DocumentKind.invoice && !invoice.isAdvancePayment && invoice.convertedFromId != null
        ? await repo.listAdvancePaymentsForOrder(invoice.convertedFromId!)
        : const <AdvancePaymentEntry>[];
    final source = invoice.kind == DocumentKind.creditNote && invoice.convertedFromId != null
        ? await repo.findById(companyId: widget.company.id, id: invoice.convertedFromId!)
        : null;
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(title: Text('${invoice.invoiceNumber} (Archiv)')),
          body: PdfPreview(
            build: (_) => buildInvoicePdf(
              invoice: invoice,
              items: items,
              company: widget.company,
              priorAdvancePayments: advances,
              referencedDocumentNumber: source?.invoiceNumber,
            ),
            canChangeOrientation: false,
            canChangePageFormat: false,
            pdfFileName: '${invoice.invoiceNumber}.pdf',
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final company = widget.company;
    final at = company.migratedAt?.toLocal();
    final host = Uri.tryParse(company.migratedToServer ?? '')?.host ?? company.migratedToServer ?? '';
    final docs = _documents;
    return Scaffold(
      appBar: AppBar(title: Text('${company.name} (Archiv)')),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.cloud_done_outlined),
                      const SizedBox(width: 8),
                      Expanded(child: Text('Auf den Server umgezogen', style: Theme.of(context).textTheme.titleMedium)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${at == null ? '' : 'Am ${_d(at)} '}nach „${company.migratedToCompanyName ?? '?'}“ ($host). '
                    'Hier kann nichts mehr bearbeitet werden — weitergearbeitet wird online.',
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.icon(
                        onPressed: _openOnline,
                        icon: const Icon(Icons.cloud_outlined),
                        label: const Text('Zur Online-Firma'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => Scaffold(
                              appBar: AppBar(title: const Text('Sicherung')),
                              body: const BackupScreen(allowRestore: false),
                            ),
                          ),
                        ),
                        icon: const Icon(Icons.backup_outlined),
                        label: const Text('Sicherung erstellen'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
            child: Text('Finalisierte Dokumente', style: Theme.of(context).textTheme.titleSmall),
          ),
          if (docs == null)
            const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))
          else if (docs.isEmpty)
            const Padding(padding: EdgeInsets.all(16), child: Text('Keine finalisierten Dokumente.'))
          else
            for (final d in docs)
              ListTile(
                leading: const Icon(Icons.picture_as_pdf_outlined),
                title: Text('${d.invoiceNumber} · ${d.customerSnapshotName ?? ''}'),
                subtitle: Text('${DocumentLabels.title(d.kind)} vom ${_d(d.issueDate)}'),
                onTap: () => _showPdf(d),
              ),
        ],
      ),
    );
  }
}

String _d(DateTime d) => '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
