import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:mailer/mailer.dart' as mailer;
import 'package:mailer/smtp_server.dart';

/// Mailversand über den Server (Kay-Entscheidung 2026-10-25): SMTP-Zugang
/// je Firma, Passwort AES-GCM-verschlüsselt mit einem Betreiber-Schlüssel
/// (`WERKKERN_SECRET_KEY`, 32 Byte Base64). Ohne Schlüssel ist der
/// Mailversand abgeschaltet — Passwörter werden nie im Klartext gespeichert.
class SmtpSettings {
  const SmtpSettings({
    required this.host,
    required this.port,
    this.username,
    required this.fromAddress,
    this.fromName,
    required this.useTls,
  });
  final String host;
  final int port;
  final String? username;
  final String fromAddress;
  final String? fromName;
  final bool useTls;
}

class MailAttachment {
  const MailAttachment({required this.fileName, required this.contentType, required this.bytes});
  final String fileName;
  final String contentType;
  final Uint8List bytes;
}

class OutgoingMail {
  const OutgoingMail({required this.to, required this.subject, required this.body, this.attachments = const []});
  final String to;
  final String subject;
  final String body;
  final List<MailAttachment> attachments;
}

/// Austauschbarer Versandweg — im Betrieb SMTP, in Tests ein Recorder.
abstract interface class MailTransport {
  /// Wirft [MailDeliveryException] mit verständlicher Meldung.
  Future<void> send(SmtpSettings settings, String? password, OutgoingMail mail);
}

class MailDeliveryException implements Exception {
  const MailDeliveryException(this.message);
  final String message;
  @override
  String toString() => message;
}

class SmtpMailTransport implements MailTransport {
  const SmtpMailTransport();

  @override
  Future<void> send(SmtpSettings settings, String? password, OutgoingMail mail) async {
    final server = SmtpServer(
      settings.host,
      port: settings.port,
      username: settings.username,
      password: password,
      ssl: settings.port == 465,
      allowInsecure: !settings.useTls && settings.port != 465,
    );
    final message = mailer.Message()
      ..from = mailer.Address(settings.fromAddress, settings.fromName)
      ..recipients.add(mail.to)
      ..subject = mail.subject
      ..text = mail.body
      ..attachments = [
        for (final a in mail.attachments)
          mailer.StreamAttachment(Stream.fromIterable([a.bytes]), a.contentType, fileName: a.fileName),
      ];
    try {
      await mailer.send(message, server);
    } on mailer.MailerException catch (e) {
      throw MailDeliveryException('Versand fehlgeschlagen: ${e.message}');
    } on Object catch (e) {
      throw MailDeliveryException('Versand fehlgeschlagen: $e');
    }
  }
}

/// Merkt sich versendete Mails statt sie zu verschicken (Tests, lokale
/// Vorschau ohne SMTP).
class RecordingMailTransport implements MailTransport {
  final sent = <({SmtpSettings settings, String? password, OutgoingMail mail})>[];
  String? failWith;

  @override
  Future<void> send(SmtpSettings settings, String? password, OutgoingMail mail) async {
    if (failWith != null) throw MailDeliveryException(failWith!);
    sent.add((settings: settings, password: password, mail: mail));
  }
}

/// Ver-/Entschlüsselung gespeicherter Geheimnisse (AES-256-GCM, zufällige
/// Nonce je Wert; Format Base64 von nonce|ciphertext|mac).
class SecretSealer {
  SecretSealer(List<int> key) : _key = SecretKey(key) {
    if (key.length != 32) throw ArgumentError('WERKKERN_SECRET_KEY muss 32 Byte (Base64) lang sein.');
  }

  /// `null` ohne/mit leerem Schlüssel; [ArgumentError] bei falscher Länge.
  static SecretSealer? fromBase64(String? value) =>
      value == null || value.trim().isEmpty ? null : SecretSealer(base64Decode(value.trim()));

  final SecretKey _key;
  static final _algorithm = AesGcm.with256bits();

  Future<String> encrypt(String plain) async {
    final box = await _algorithm.encrypt(utf8.encode(plain), secretKey: _key);
    return base64Encode(box.concatenation());
  }

  Future<String> decrypt(String encoded) async {
    final box = SecretBox.fromConcatenation(
      base64Decode(encoded),
      nonceLength: _algorithm.nonceLength,
      macLength: _algorithm.macAlgorithm.macLength,
    );
    return utf8.decode(await _algorithm.decrypt(box, secretKey: _key));
  }
}

/// Dienst, den die Router nutzen. [secrets] fehlt, wenn der Betreiber
/// keinen Schlüssel gesetzt hat.
class MailService {
  MailService({required this.transport, this.secrets});
  final MailTransport transport;
  final SecretSealer? secrets;

  bool get available => secrets != null;
}

/// Standardtexte je Anlass (wie offline), Platzhalter {{kunde}},
/// {{nummer}}, {{firma}}.
const defaultMailTemplates = <String, String>{
  'documentSubject': '{{firma}}: {{nummer}}',
  'documentBody': 'Guten Tag {{kunde}},\n\nanbei erhalten Sie das Dokument {{nummer}}.\n\nMit freundlichen Grüßen\n{{firma}}',
  'dunningSubject': 'Mahnung: {{nummer}}',
  'dunningBody': 'Guten Tag {{kunde}},\n\nanbei erhalten Sie unser Mahnschreiben zur Rechnung {{nummer}}.\n\n'
      'Mit freundlichen Grüßen\n{{firma}}',
  'purchaseOrderSubject': 'Bestellung {{nummer}} — {{firma}}',
  'purchaseOrderBody': 'Guten Tag,\n\nanbei erhalten Sie unsere Bestellung {{nummer}}.\n\nMit freundlichen Grüßen\n{{firma}}',
  'invitationSubject': 'Einladung zu {{firma}} in WerkkernERP',
  'invitationBody': 'Guten Tag,\n\nSie wurden zu {{firma}} eingeladen. Ihr Einladungscode:\n\n{{code}}\n\n'
      'Lösen Sie ihn in der App unter „Einladung einlösen“ ein. Der Code gilt nur einmal.',
};

/// Wie offline `applyEmailTemplatePlaceholders`, plus {{code}}.
String applyMailPlaceholders(String template, {String kunde = '', String nummer = '', required String firma, String code = ''}) =>
    template.replaceAll('{{kunde}}', kunde).replaceAll('{{nummer}}', nummer).replaceAll('{{firma}}', firma).replaceAll('{{code}}', code);

/// PDF-Anhang aus Base64 prüfen (Dateisignatur, Größe).
Uint8List? decodePdfAttachment(Object? base64Value, {int maxBytes = 10 * 1024 * 1024}) {
  if (base64Value is! String) return null;
  final bytes = base64Decode(base64Value);
  if (bytes.length < 5 || bytes.length > maxBytes) return null;
  if (String.fromCharCodes(bytes.sublist(0, 5)) != '%PDF-') return null;
  return bytes;
}
