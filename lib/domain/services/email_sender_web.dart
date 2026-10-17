import 'dart:typed_data';

import 'smtp_config.dart';

bool get emailSendingSupported => false;

/// Ergebnis eines Versandversuchs — siehe `email_sender_native.dart` für
/// den ausführlichen Doc-Kommentar (identische API, nur die
/// Web-Implementierung liefert hier immer einen Fehlschlag, siehe
/// `sendEmail` unten).
class EmailSendResult {
  const EmailSendResult.success() : errorMessage = null;
  const EmailSendResult.failure(this.errorMessage);

  final String? errorMessage;
  bool get isSuccess => errorMessage == null;
}

/// Im Browser ist ein roher SMTP-Socket aus Sicherheitsgründen nicht
/// möglich (siehe Doc-Kommentar in `email_sender.dart`) — liefert daher
/// immer einen sprechenden Fehlschlag statt einen stillen/falschen
/// Erfolg. Die UI prüft vorher ohnehin `emailSendingSupported` und
/// bietet auf Web stattdessen den PDF-Download/Teilen-Weg an.
Future<EmailSendResult> sendEmail({
  required SmtpConfig config,
  required String password,
  required String toAddress,
  required String subject,
  required String body,
  required String attachmentFilename,
  required Uint8List attachmentBytes,
}) async => const EmailSendResult.failure(
      'E-Mail-Versand per SMTP ist im Web-Build aus technischen Gründen '
      '(kein Rohsocket-Zugriff im Browser) nicht möglich. Bitte das PDF '
      'herunterladen/teilen und über das eigene Mailprogramm versenden.',
    );
