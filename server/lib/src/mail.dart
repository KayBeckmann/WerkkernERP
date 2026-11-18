import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:mailer/src/mime/mime.dart' as mime;
import 'package:mailer/src/smtp/capabilities.dart' as smtp_capabilities;

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

/// Explicit IMAP-over-TLS destination; independent of the SMTP credentials.
class SentCopySettings {
  const SentCopySettings({
    required this.host,
    required this.port,
    required this.username,
    required this.folder,
  });
  final String host;
  final int port;
  final String username;
  final String folder;
}

/// A separate operation: call only after SMTP succeeds. A failure here must
/// never trigger another SMTP send; callers should report copy status alone.
abstract interface class SentCopyTransport {
  Future<void> save(
    SentCopySettings settings,
    String password,
    OutgoingMail mail, {
    required String fromAddress,
    String? fromName,
  });
}

class SentCopyException implements Exception {
  const SentCopyException(this.message);
  final String message;
  @override
  String toString() => message;
}

typedef SentCopyConnector =
    Future<Socket> Function(String host, int port, Duration timeout);

/// IMAPS APPEND with a synchronizing literal. The default connector always
/// validates the server TLS certificate; injectable connector is for local tests.
class ImapSentCopyTransport implements SentCopyTransport {
  ImapSentCopyTransport({
    SentCopyConnector? connect,
    this.timeout = const Duration(seconds: 15),
  }) : _connect = connect ?? _tlsConnect;

  final SentCopyConnector _connect;
  final Duration timeout;

  static Future<Socket> _tlsConnect(String host, int port, Duration timeout) =>
      SecureSocket.connect(host, port, timeout: timeout);

  static String _quoted(String value) {
    if (value.contains(RegExp(r'[\x00-\x1f\x7f]')))
      throw const SentCopyException('Ungültige IMAP-Einstellung.');
    final escaped = value.replaceAll(r'\', r'\\').replaceAll('"', r'\"');
    return '"$escaped"';
  }

  @override
  Future<void> save(
    SentCopySettings settings,
    String password,
    OutgoingMail mail, {
    required String fromAddress,
    String? fromName,
  }) async {
    if (settings.host.isEmpty ||
        settings.port < 1 ||
        settings.port > 65535 ||
        settings.username.isEmpty ||
        settings.folder.isEmpty ||
        password.isEmpty) {
      throw const SentCopyException('IMAP-Konfiguration unvollständig.');
    }
    // Validate before opening the socket. Never interpolate server responses,
    // credentials, message content, or socket errors into exceptions.
    final user = _quoted(settings.username);
    final secret = _quoted(password);
    final folder = _quoted(settings.folder);
    Socket? socket;
    try {
      final message = mailer.Message()
        ..from = mailer.Address(fromAddress, fromName)
        ..recipients.add(mail.to)
        ..subject = mail.subject
        ..text = mail.body
        ..attachments = [
          for (final a in mail.attachments)
            mailer.StreamAttachment(
              Stream.value(a.bytes),
              a.contentType,
              fileName: a.fileName,
            ),
        ];
      final data = BytesBuilder(copy: false);
      await for (final chunk in mime.MimeMessage(
        message,
      ).data(const smtp_capabilities.Capabilities()).timeout(timeout)) {
        data.add(chunk);
      }
      final bytes = data.takeBytes();
      socket = await _connect(
        settings.host,
        settings.port,
        timeout,
      ).timeout(timeout);
      final reader = _ImapReplyReader(socket, timeout);
      await reader.greeting();
      socket.write('A1 LOGIN $user $secret\r\n');
      await socket.flush().timeout(timeout);
      await reader.tagged('A1');
      socket.write('A2 APPEND $folder (\\Seen) {${bytes.length}}\r\n');
      await socket.flush().timeout(timeout);
      if (await reader.continuationOrTagged('A2')) {
        socket.add(bytes);
        socket.add([13, 10]);
        await socket.flush().timeout(timeout);
        await reader.tagged('A2');
      }
      socket.write('A3 LOGOUT\r\n');
      await socket.flush().timeout(timeout);
      await reader.tagged('A3');
    } on SentCopyException {
      rethrow;
    } on Object {
      throw const SentCopyException('IMAP-Kopie fehlgeschlagen.');
    } finally {
      socket?.destroy();
    }
  }
}

class _ImapReplyReader {
  _ImapReplyReader(Socket socket, this.timeout)
    : _lines = StreamIterator(
        socket
            .cast<List<int>>()
            .transform(utf8.decoder)
            .transform(const LineSplitter()),
      );
  final StreamIterator<String> _lines;
  final Duration timeout;

  Future<String> _line() async {
    if (!await _lines.moveNext().timeout(timeout))
      throw const SentCopyException('IMAP-Verbindung beendet.');
    return _lines.current;
  }

  Future<void> greeting() async {
    final line = await _line();
    if (!line.startsWith('* OK '))
      throw const SentCopyException('IMAP-Begrüßung abgelehnt.');
  }

  Future<void> tagged(String tag) async {
    while (true) {
      final line = await _line();
      if (line.startsWith('$tag OK')) return;
      if (line.startsWith('$tag ') || line.startsWith('+'))
        throw const SentCopyException('IMAP-Befehl abgelehnt.');
      if (!line.startsWith('* '))
        throw const SentCopyException('Ungültige IMAP-Antwort.');
    }
  }

  Future<bool> continuationOrTagged(String tag) async {
    while (true) {
      final line = await _line();
      if (line.startsWith('+')) return true;
      if (line.startsWith('$tag '))
        throw const SentCopyException('IMAP APPEND abgelehnt.');
      if (!line.startsWith('* '))
        throw const SentCopyException('Ungültige IMAP-Antwort.');
    }
  }
}

class RecordingSentCopyTransport implements SentCopyTransport {
  final saved =
      <
        ({
          SentCopySettings settings,
          String password,
          OutgoingMail mail,
          String fromAddress,
          String? fromName,
        })
      >[];
  String? failWith;

  @override
  Future<void> save(
    SentCopySettings settings,
    String password,
    OutgoingMail mail, {
    required String fromAddress,
    String? fromName,
  }) async {
    if (failWith != null) throw SentCopyException(failWith!);
    saved.add((
      settings: settings,
      password: password,
      mail: mail,
      fromAddress: fromAddress,
      fromName: fromName,
    ));
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
  MailService({required this.transport, this.secrets, SentCopyTransport? sentCopy})
      : sentCopy = sentCopy ?? ImapSentCopyTransport();
  final MailTransport transport;
  final SentCopyTransport sentCopy;
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

/// C15: XML-Anhang (E-Rechnung) aus Base64 prüfen — muss mit `<?xml`
/// oder dem CII-Wurzelelement beginnen, höchstens 2 MB.
Uint8List? decodeXmlAttachment(Object? base64Value, {int maxBytes = 2 * 1024 * 1024}) {
  if (base64Value is! String) return null;
  final Uint8List bytes;
  try {
    bytes = base64Decode(base64Value);
  } on FormatException {
    return null;
  }
  if (bytes.length < 5 || bytes.length > maxBytes) return null;
  final head = utf8.decode(bytes.take(64).toList(), allowMalformed: true).trimLeft();
  if (!head.startsWith('<?xml') && !head.startsWith('<rsm:CrossIndustryInvoice')) return null;
  return bytes;
}

/// PDF-Anhang aus Base64 prüfen (Dateisignatur, Größe).
Uint8List? decodePdfAttachment(Object? base64Value, {int maxBytes = 10 * 1024 * 1024}) {
  if (base64Value is! String) return null;
  final bytes = base64Decode(base64Value);
  if (bytes.length < 5 || bytes.length > maxBytes) return null;
  if (String.fromCharCodes(bytes.sublist(0, 5)) != '%PDF-') return null;
  return bytes;
}
