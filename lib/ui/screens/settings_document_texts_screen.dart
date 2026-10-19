import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/database/tables.dart';
import '../../data/repositories/company_repository.dart';
import '../../domain/services/active_company_service.dart';
import 'invoices_screen.dart' show DocumentLabels;

/// "Dokumenttexte" als eigene Unterseite (Nachtrag 2026-10-18: "Die
/// Einstellungen müssen aufgeräumt werden" — in Unterseiten
/// aufgeteilt). Einleitung/Schluss je Dokumentart (Kay-Nachtrag
/// 2026-10-16, zweiter Nachtrag: "müssen pro Dokument abweichend
/// sein").
class SettingsDocumentTextsScreen extends StatefulWidget {
  const SettingsDocumentTextsScreen({super.key});

  @override
  State<SettingsDocumentTextsScreen> createState() => _SettingsDocumentTextsScreenState();
}

class _SettingsDocumentTextsScreenState extends State<SettingsDocumentTextsScreen> {
  bool _textsSaving = false;

  // Ein Controller-Paar je Dokumentart, unabhängig davon, ob das Modul
  // aktuell aktiv ist — alle existieren immer, nur die TextFields
  // werden je nach aktivem Modul ein-/ausgeblendet. So bleibt der
  // Zustand erhalten, wenn ein Modul während der Bearbeitung ein- oder
  // ausgeschaltet wird, ohne Controller dynamisch anlegen/verwerfen zu
  // müssen.
  late final Map<DocumentKind, TextEditingController> _introCtrls;
  late final Map<DocumentKind, TextEditingController> _closingCtrls;
  late final TextEditingController _footerCtrl;

  @override
  void initState() {
    super.initState();
    final company = context.read<ActiveCompanyService>().active;
    _introCtrls = {
      DocumentKind.invoice: TextEditingController(text: company?.pdfIntroText),
      DocumentKind.quote: TextEditingController(text: company?.pdfIntroTextQuote),
      DocumentKind.order: TextEditingController(text: company?.pdfIntroTextOrder),
      DocumentKind.deliveryNote: TextEditingController(text: company?.pdfIntroTextDeliveryNote),
      DocumentKind.proforma: TextEditingController(text: company?.pdfIntroTextProforma),
      DocumentKind.creditNote: TextEditingController(text: company?.pdfIntroTextCreditNote),
    };
    _closingCtrls = {
      DocumentKind.invoice: TextEditingController(text: company?.pdfClosingText),
      DocumentKind.quote: TextEditingController(text: company?.pdfClosingTextQuote),
      DocumentKind.order: TextEditingController(text: company?.pdfClosingTextOrder),
      DocumentKind.deliveryNote: TextEditingController(text: company?.pdfClosingTextDeliveryNote),
      DocumentKind.proforma: TextEditingController(text: company?.pdfClosingTextProforma),
      DocumentKind.creditNote: TextEditingController(text: company?.pdfClosingTextCreditNote),
    };
    _footerCtrl = TextEditingController(text: company?.pdfFooterText);
  }

  @override
  void dispose() {
    for (final c in _introCtrls.values) {
      c.dispose();
    }
    for (final c in _closingCtrls.values) {
      c.dispose();
    }
    _footerCtrl.dispose();
    super.dispose();
  }

  String? _textOrNull(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();

  Future<void> _saveTexts() async {
    final service = context.read<ActiveCompanyService>();
    final company = service.active;
    if (company == null) return;
    setState(() => _textsSaving = true);
    try {
      await context.read<CompanyRepository>().update(
            company.copyWith(
              pdfIntroText: Value(_textOrNull(_introCtrls[DocumentKind.invoice]!)),
              pdfClosingText: Value(_textOrNull(_closingCtrls[DocumentKind.invoice]!)),
              pdfIntroTextQuote: Value(_textOrNull(_introCtrls[DocumentKind.quote]!)),
              pdfClosingTextQuote: Value(_textOrNull(_closingCtrls[DocumentKind.quote]!)),
              pdfIntroTextOrder: Value(_textOrNull(_introCtrls[DocumentKind.order]!)),
              pdfClosingTextOrder: Value(_textOrNull(_closingCtrls[DocumentKind.order]!)),
              pdfIntroTextDeliveryNote: Value(_textOrNull(_introCtrls[DocumentKind.deliveryNote]!)),
              pdfClosingTextDeliveryNote: Value(_textOrNull(_closingCtrls[DocumentKind.deliveryNote]!)),
              pdfIntroTextProforma: Value(_textOrNull(_introCtrls[DocumentKind.proforma]!)),
              pdfClosingTextProforma: Value(_textOrNull(_closingCtrls[DocumentKind.proforma]!)),
              pdfIntroTextCreditNote: Value(_textOrNull(_introCtrls[DocumentKind.creditNote]!)),
              pdfClosingTextCreditNote: Value(_textOrNull(_closingCtrls[DocumentKind.creditNote]!)),
              pdfFooterText: Value(_textOrNull(_footerCtrl)),
            ),
          );
      await service.refreshActive();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dokumenttexte gespeichert.')),
        );
      }
    } finally {
      if (mounted) setState(() => _textsSaving = false);
    }
  }

  Widget _textPair(DocumentKind kind) {
    final label = DocumentLabels.title(kind);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 6),
          TextField(
            controller: _introCtrls[kind],
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'Einleitungstext ($label)',
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _closingCtrls[kind],
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'Schlusstext ($label)',
              border: const OutlineInputBorder(),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final company = context.watch<ActiveCompanyService>().active;
    if (company == null) return const Scaffold(body: SizedBox.shrink());

    final activeKinds = [
      DocumentKind.invoice,
      if (company.quotesEnabled) DocumentKind.quote,
      if (company.ordersEnabled) DocumentKind.order,
      if (company.deliveryNotesEnabled) DocumentKind.deliveryNote,
      if (company.proformaEnabled) DocumentKind.proforma,
      if (company.creditNotesEnabled) DocumentKind.creditNote,
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Dokumenttexte')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Einleitung/Schluss je Dokumentart (z. B. Bindefrist im Angebot, '
                    'Zahlungsziel in der Rechnung). Nur aktive Module werden angezeigt.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  for (final kind in activeKinds) _textPair(kind),
                  TextField(
                    controller: _footerCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Fußzeile (gemeinsam für alle Dokumentarten)',
                      hintText: 'z. B. Firmenname — Anschrift',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton(
                      onPressed: _textsSaving ? null : _saveTexts,
                      child: _textsSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Speichern'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
