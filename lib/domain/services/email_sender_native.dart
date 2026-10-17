import 'dart:typed_data';

import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

import 'smtp_config.dart';

bool get emailSendingSupported => true;

/// Ergebnis eines Versandversuchs — nie als Exception nach außen
/// geben, sondern explizit prüfbar zurückgeben (A3 Punkt 4: ein
/// Fehlschlag darf nie wie ein Erfolg aussehen, siehe `_sharePdf`/
/// `_generateDunningLetter` für dasselbe Prinzip bei PDFs).
class EmailSendResult {
  const EmailSendResult.success() : errorMessage = null;
  const EmailSendResult.failure(this.errorMessage);

  final String? errorMessage;
  bool get isSuccess => errorMessage == null;
}

Future<EmailSendResult> sendEmail({
  required SmtpConfig config,
  required String password,
  required String toAddress,
  required String subject,
  required String body,
  required String attachmentFilename,
  required Uint8List attachmentBytes,
}) async {
  if (!config.isComplete) {
    return const EmailSendResult.failure(
      'SMTP ist nicht vollständig eingerichtet (Server/Absenderadresse fehlt).',
    );
  }
  final smtpServer = SmtpServer(
    config.host!,
    port: config.port,
    username: config.username,
    password: password,
    ssl: config.port == 465,
    allowInsecure: !config.useTls && config.port != 465,
  );
  final message = Message()
    ..from = Address(config.fromAddress!, config.fromName)
    ..recipients.add(toAddress)
    ..subject = subject
    ..text = body
    ..attachments = [
      StreamAttachment(
        Stream.fromIterable([attachmentBytes]),
        'application/pdf',
        fileName: attachmentFilename,
      ),
    ];
  try {
    await send(message, smtpServer);
    return const EmailSendResult.success();
  } on MailerException catch (e) {
    return EmailSendResult.failure(e.message);
  } catch (e) {
    return EmailSendResult.failure('Versand fehlgeschlagen: $e');
  }
}
