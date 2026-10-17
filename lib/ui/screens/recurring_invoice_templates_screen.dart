import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/database/database.dart';
import '../../data/database/tables.dart';
import '../../data/repositories/customer_repository.dart';
import '../../data/repositories/recurring_invoice_template_repository.dart';
import '../../domain/services/active_company_service.dart';
import 'recurring_invoice_template_editor_screen.dart';

/// Liste der wiederkehrenden Rechnungsvorlagen (C11-Kern, Kay-
/// Priorisierungsentscheidung 2026-10-17). Zeigt nur aktive Vorlagen —
/// pausierte bleiben erhalten, tauchen hier aber nicht mehr auf (gleiches
/// Prinzip wie Projekte/Fahrzeuge/Modul-Schalter).
class RecurringInvoiceTemplatesScreen extends StatefulWidget {
  const RecurringInvoiceTemplatesScreen({super.key});

  @override
  State<RecurringInvoiceTemplatesScreen> createState() => _RecurringInvoiceTemplatesScreenState();
}

class _RecurringInvoiceTemplatesScreenState extends State<RecurringInvoiceTemplatesScreen> {
  late Future<_TemplatesData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_TemplatesData> _load() async {
    final companyId = context.read<ActiveCompanyService>().active!.id;
    final templateRepo = context.read<RecurringInvoiceTemplateRepository>();
    final customerRepo = context.read<CustomerRepository>();
    final templates = await templateRepo.listForCompany(companyId);
    final customers = await customerRepo.listForCompany(companyId);
    return _TemplatesData(templates: templates, customerById: {for (final c in customers) c.id: c});
  }

  // Bewusst ein Block-Body statt `setState(() => _future = _load())` —
  // eine Zuweisung als Ausdruck liefert ihren Wert (hier ein `Future`)
  // zurück, und Flutter wirft im Debug-Modus bei jedem `setState()`,
  // dessen Callback ein `Future` zurückgibt (bereits einmal in A5 so
  // gefunden, siehe Roadmap-Notiz zu `_ArticlesScreen`/`_InvoicesScreen`).
  void _reload() => setState(() {
        _future = _load();
      });

  static String _intervalLabel(RecurrenceInterval interval) => switch (interval) {
        RecurrenceInterval.monthly => 'monatlich',
        RecurrenceInterval.quarterly => 'vierteljährlich',
        RecurrenceInterval.yearly => 'jährlich',
      };

  String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<_TemplatesData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data!;
          if (data.templates.isEmpty) {
            return const Center(child: Text('Noch keine wiederkehrenden Vorlagen angelegt.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
            itemCount: data.templates.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final template = data.templates[index];
              final customer = data.customerById[template.customerId];
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.repeat_outlined),
                  title: Text(template.label),
                  subtitle: Text(
                    '${customer?.name ?? '(unbekannter Kunde)'} — ${_intervalLabel(template.interval)} '
                    '— nächste Rechnung: ${_formatDate(template.nextDueDate)}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => RecurringInvoiceTemplateEditorScreen(template: template),
                      ),
                    );
                    if (mounted) _reload();
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'recurring-templates-fab',
        onPressed: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const RecurringInvoiceTemplateEditorScreen()),
          );
          if (mounted) _reload();
        },
        icon: const Icon(Icons.add),
        label: const Text('Neue Vorlage'),
      ),
    );
  }
}

class _TemplatesData {
  const _TemplatesData({required this.templates, required this.customerById});
  final List<RecurringInvoiceTemplate> templates;
  final Map<String, Customer> customerById;
}
