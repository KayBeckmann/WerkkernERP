import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';

import '../../domain/services/email_sender.dart';
import '../../domain/services/smtp_config.dart';
import '../../domain/services/smtp_credential_store.dart';

/// Versanddialog (C7a, Kay-Nachfrage 2026-10-17): zeigt Empfänger/
/// Betreff/Text **vor** dem tatsächlichen Versand an, alle drei bleiben
/// frei editierbar — kein stiller Versand mit vorausgefüllten Werten
/// (Roadmap Zielbild/Freigabetor-Vorgabe: "erst Vorschau, Empfänger/
/// Anhänge prüfen und bewusst bestätigen").
///
/// Auf Web (kein SMTP-Rohsocket möglich, siehe `email_sender_web.dart`)
/// zeigt der Dialog nur den Hinweis + einen "PDF herunterladen"-Button
/// als Alternative an, statt einen Senden-Button zu zeigen, der ohnehin
/// scheitern würde.
Future<void> showEmailSendDialog({
  required BuildContext context,
  required SmtpConfig config,
  required SmtpCredentialStore credentialStore,
  required String companyId,
  required String initialTo,
  required String initialSubject,
  required String initialBody,
  required String attachmentFilename,
  required Future<Uint8List> Function() buildAttachment,
}) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => _EmailSendDialog(
      config: config,
      credentialStore: credentialStore,
      companyId: companyId,
      initialTo: initialTo,
      initialSubject: initialSubject,
      initialBody: initialBody,
      attachmentFilename: attachmentFilename,
      buildAttachment: buildAttachment,
    ),
  );
}

class _EmailSendDialog extends StatefulWidget {
  const _EmailSendDialog({
    required this.config,
    required this.credentialStore,
    required this.companyId,
    required this.initialTo,
    required this.initialSubject,
    required this.initialBody,
    required this.attachmentFilename,
    required this.buildAttachment,
  });

  final SmtpConfig config;
  final SmtpCredentialStore credentialStore;
  final String companyId;
  final String initialTo;
  final String initialSubject;
  final String initialBody;
  final String attachmentFilename;
  final Future<Uint8List> Function() buildAttachment;

  @override
  State<_EmailSendDialog> createState() => _EmailSendDialogState();
}

class _EmailSendDialogState extends State<_EmailSendDialog> {
  late final TextEditingController _toCtrl = TextEditingController(text: widget.initialTo);
  late final TextEditingController _subjectCtrl = TextEditingController(text: widget.initialSubject);
  late final TextEditingController _bodyCtrl = TextEditingController(text: widget.initialBody);
  bool _sending = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _toCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _toCtrl.dispose();
    _subjectCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _downloadInstead() async {
    try {
      final bytes = await widget.buildAttachment();
      await Printing.sharePdf(bytes: bytes, filename: widget.attachmentFilename);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) setState(() => _errorMessage = 'PDF konnte nicht erstellt/geteilt werden.');
    }
  }

  Future<void> _send() async {
    setState(() {
      _sending = true;
      _errorMessage = null;
    });
    try {
      final password = await widget.credentialStore.readPassword(widget.companyId);
      if (password == null) {
        setState(() {
          _errorMessage =
              'Kein SMTP-Passwort gespeichert. Bitte in den Einstellungen unter "Versand (SMTP)" '
              'hinterlegen.';
          _sending = false;
        });
        return;
      }
      final bytes = await widget.buildAttachment();
      if (!mounted) return;
      final result = await sendEmail(
        config: widget.config,
        password: password,
        toAddress: _toCtrl.text.trim(),
        subject: _subjectCtrl.text.trim(),
        body: _bodyCtrl.text,
        attachmentFilename: widget.attachmentFilename,
        attachmentBytes: bytes,
      );
      if (!mounted) return;
      if (result.isSuccess) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('E-Mail an ${_toCtrl.text.trim()} gesendet.')),
        );
      } else {
        setState(() => _errorMessage = result.errorMessage);
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Per E-Mail senden'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!emailSendingSupported) ...[
                const Text(
                  'E-Mail-Versand per SMTP ist im Web-Build aus technischen Gründen (kein '
                  'Rohsocket-Zugriff im Browser) nicht möglich. Bitte das PDF herunterladen '
                  'und über das eigene Mailprogramm versenden.',
                ),
                const SizedBox(height: 12),
              ] else if (!widget.config.isComplete) ...[
                const Text(
                  'SMTP ist noch nicht vollständig eingerichtet (Server/Absenderadresse fehlt '
                  'in den Einstellungen unter "Versand (SMTP)").',
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: _toCtrl,
                enabled: emailSendingSupported,
                decoration: const InputDecoration(labelText: 'An'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _subjectCtrl,
                enabled: emailSendingSupported,
                decoration: const InputDecoration(labelText: 'Betreff'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _bodyCtrl,
                enabled: emailSendingSupported,
                decoration: const InputDecoration(labelText: 'Text'),
                maxLines: 6,
              ),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Anhang: ${widget.attachmentFilename}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _sending ? null : () => Navigator.of(context).pop(),
          child: const Text('Abbrechen'),
        ),
        if (!emailSendingSupported)
          FilledButton(
            onPressed: _sending ? null : _downloadInstead,
            child: const Text('PDF herunterladen'),
          )
        else
          FilledButton(
            onPressed: _sending || _toCtrl.text.trim().isEmpty ? null : _send,
            child: _sending
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Senden'),
          ),
      ],
    );
  }
}
