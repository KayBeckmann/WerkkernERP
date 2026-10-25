import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../domain/services/online_session.dart';
import 'online_form.dart';

/// Versand eines PDFs über den Server: Empfänger (leer = hinterlegte
/// Adresse beim Kunden/Lieferanten), Betreff/Text optional — sonst die
/// Vorlagen der Firma. Nur mit Modul `smtp`.
Future<void> sendPdfByMail(
  BuildContext context, {
  required OnlineSession session,
  required String title,
  String? defaultRecipientHint,
  bool customText = false,
  required Future<Uint8List> Function() buildPdf,
  required Future<String> Function(Uint8List pdf, {String? to, String? subject, String? body}) send,
}) async {
  final values = await showOnlineForm(
    context,
    title: title,
    submitLabel: 'Senden',
    fields: [
      OnlineField('to', 'Empfänger', helper: defaultRecipientHint ?? 'Leer = hinterlegte E-Mail-Adresse'),
      if (customText) ...[
        const OnlineField('subject', 'Betreff', helper: 'Leer = Vorlage der Firma'),
        const OnlineField('body', 'Text', type: OnlineFieldType.multiline, helper: 'Leer = Vorlage der Firma'),
      ],
    ],
  );
  if (values == null || !context.mounted) return;
  String? recipient;
  await runOnline(context, () async {
    final pdf = await buildPdf();
    recipient = await send(
      pdf,
      to: values['to'] as String?,
      subject: values['subject'] as String?,
      body: values['body'] as String?,
    );
  });
  if (recipient != null && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Versendet an $recipient.')));
  }
}

bool canSendMail(OnlineSession session) => session.modules.contains('smtp') && !session.offlineOnly;
