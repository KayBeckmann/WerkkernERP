import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:werkkern_client/werkkern_client.dart';
import 'package:werkkern_core/werkkern_core.dart';

import '../../../domain/services/online_session.dart';
import '../../../pdf/dunning_letter_pdf_builder.dart';
import 'online_document_screen.dart';
import 'online_form.dart';
import 'online_mail.dart';
import 'online_settings_screen.dart';

/// Mahnwesen der Online-Firma (C12): überfällige Rechnungen mit Stufe,
/// Gebühr und Zins nach den eigenen Einstellungen, Mahnung erstellen
/// (protokolliert) und als PDF teilen.
class OnlineDunningScreen extends StatelessWidget {
  const OnlineDunningScreen({super.key, required this.session});
  final OnlineSession session;

  /// Mahnung zur heutigen Stufe erstellen und als PDF zeigen.
  Future<void> _createNotice(BuildContext context, OnlineOverdueInvoice item) async {
    OnlineDunningNotice? notice;
    OnlineDocument? document;
    OnlineCompanyProfile? company;
    final ok = await runOnline(context, () async {
      notice = await session.client.createDunningNotice(item.documentId);
      document = await session.client.document(item.documentId);
      company = await session.client.companyProfile();
    });
    if (!ok || !context.mounted) return;
    await showDunningLetter(context, session: session, document: document!, notice: notice!, company: company!);
  }

  @override
  Widget build(BuildContext context) {
    final canWrite = session.can('dunning.write');
    return OnlineListView<OnlineOverdueInvoice>(
      load: (_) => session.client.overdueInvoices(),
      emptyText: 'Keine überfälligen Rechnungen.',
      header: (context, items, reload) => Wrap(
        spacing: 8,
        children: [
          if (canWrite)
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => OnlineDunningSettingsScreen(session: session)),
              ),
              icon: const Icon(Icons.tune),
              label: const Text('Einstellungen'),
            ),
          if (items.isNotEmpty)
            Chip(label: Text('Offen inkl. Gebühren/Zinsen: ${Money.fromCents(items.fold(0, (s, i) => s + i.totalDueCents))}')),
        ],
      ),
      itemBuilder: (context, i, reload) => Card(
        child: ListTile(
          leading: CircleAvatar(child: Text('${i.level}')),
          title: Text('${i.number ?? 'Rechnung'} · ${i.customerName ?? ''}'),
          subtitle: Text([
            '${i.levelLabel} · ${i.overdueDays} Tage',
            'fällig ${formatOnlineDate(i.dueDate)}',
            if (i.feeCents > 0) 'Gebühr ${Money.fromCents(i.feeCents)}',
            if (i.interestCents > 0) 'Zins ${Money.fromCents(i.interestCents)}',
            if (i.lastNoticeLevel != null)
              'zuletzt ${i.lastNoticeLevel}. Mahnung am ${formatOnlineDate(i.lastNoticeAt!.toLocal())}',
          ].join(' · ')),
          trailing: Text(Money.fromCents(i.totalDueCents).toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
          onTap: () async {
            final action = await showModalBottomSheet<String>(
              context: context,
              builder: (context) => SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (canWrite)
                      ListTile(
                        leading: const Icon(Icons.mark_email_unread_outlined),
                        title: Text('${dunningLetterTitle(DunningLevel.values[i.level])} erstellen'),
                        onTap: () => Navigator.pop(context, 'notice'),
                      ),
                    ListTile(
                      leading: const Icon(Icons.receipt_long_outlined),
                      title: const Text('Rechnung öffnen'),
                      onTap: () => Navigator.pop(context, 'open'),
                    ),
                  ],
                ),
              ),
            );
            if (!context.mounted) return;
            if (action == 'notice') await _createNotice(context, i);
            if (action == 'open' && context.mounted) {
              await Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => OnlineDocumentScreen(session: session, documentId: i.documentId)),
              );
            }
            reload();
          },
        ),
      ),
    );
  }
}

/// Mahnschreiben aus Rechnungs-Schnappschuss und protokollierter Mahnung.
Future<void> showDunningLetter(
  BuildContext context, {
  required OnlineSession session,
  required OnlineDocument document,
  required OnlineDunningNotice notice,
  required OnlineCompanyProfile company,
}) {
  final level = DunningLevel.values[notice.level];
  final data = DunningLetterPdfData(
    level: level,
    date: notice.createdAt.toLocal(),
    companyName: document.companySnapshot?.name ?? '',
    companyAddress: document.companySnapshot?.address,
    customerName: document.customerSnapshotName ?? '',
    customerAddress: document.customerSnapshotAddress,
    invoiceNumber: document.number ?? '',
    invoiceDate: document.issueDate,
    dueDate: document.dueDate ?? document.issueDate,
    invoiceGross: Money.fromCents(notice.invoiceGrossCents),
    fee: Money.fromCents(notice.feeCents),
    interest: Money.fromCents(notice.interestCents),
    overdueDays: notice.overdueDays,
    interestRatePercent: notice.interestRatePercent,
    introText: notice.introText,
    closingText: notice.closingText,
    footerText: document.footerTextSnapshot ?? company.footerText,
  );
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => Scaffold(
        appBar: AppBar(
          title: Text('${dunningLetterTitle(level)} ${document.number ?? ''}'),
          actions: [
            if (canSendMail(session) && session.can('dunning.write'))
              Builder(
                builder: (context) => IconButton(
                  tooltip: 'Per E-Mail senden',
                  icon: const Icon(Icons.send_outlined),
                  onPressed: () => sendPdfByMail(
                    context,
                    session: session,
                    title: '${dunningLetterTitle(level)} senden',
                    defaultRecipientHint: 'Leer = E-Mail des Kunden',
                    buildPdf: () => buildDunningLetterPdfFromData(data),
                    send: (pdf, {to, subject, body}) => session.client.sendDunningMail(notice.id, pdf, to: to),
                  ),
                ),
              ),
          ],
        ),
        body: PdfPreview(
          canChangeOrientation: false,
          canChangePageFormat: false,
          pdfFileName: 'Mahnung-${notice.level}-${document.number}.pdf',
          build: (_) => buildDunningLetterPdfFromData(data),
        ),
      ),
    ),
  );
}
