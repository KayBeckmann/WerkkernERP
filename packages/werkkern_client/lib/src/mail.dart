import 'dart:convert';
import 'dart:typed_data';

import 'api_client.dart';

/// Mailversand über den Server.
class OnlineMailSettings {
  const OnlineMailSettings({
    required this.available,
    this.host,
    this.port = 587,
    this.username,
    this.fromAddress,
    this.fromName,
    this.useTls = true,
    this.hasPassword = false,
    this.sentImapEnabled = false,
    this.sentImapHost,
    this.sentImapPort = 993,
    this.sentImapUsername,
    this.sentImapFolder = 'Sent',
    this.hasSentImapPassword = false,
    this.templates = const {},
  });
  factory OnlineMailSettings.fromJson(Map<String, Object?> j) => OnlineMailSettings(
        available: j['available'] as bool,
        host: j['host'] as String?,
        port: j['port'] as int? ?? 587,
        username: j['username'] as String?,
        fromAddress: j['fromAddress'] as String?,
        fromName: j['fromName'] as String?,
        useTls: j['useTls'] as bool? ?? true,
        hasPassword: j['hasPassword'] as bool? ?? false,
        sentImapEnabled: j['sentImapEnabled'] as bool? ?? false,
        sentImapHost: j['sentImapHost'] as String?,
        sentImapPort: j['sentImapPort'] as int? ?? 993,
        sentImapUsername: j['sentImapUsername'] as String?,
        sentImapFolder: j['sentImapFolder'] as String? ?? 'Sent',
        hasSentImapPassword: j['hasSentImapPassword'] as bool? ?? false,
        templates: (j['templates'] as Map? ?? const {}).cast<String, String>(),
      );

  /// Der Betreiber hat einen Schlüssel gesetzt — sonst kein Versand.
  final bool available;
  final String? host;
  final int port;
  final String? username;
  final String? fromAddress;
  final String? fromName;
  final bool useTls;
  final bool hasPassword;
  final bool sentImapEnabled;
  final String? sentImapHost;
  final int sentImapPort;
  final String? sentImapUsername;
  final String sentImapFolder;
  final bool hasSentImapPassword;
  final Map<String, String> templates;
}

Map<String, Object?> _map(Object? value) => value as Map<String, Object?>;

extension MailApi on WerkkernApiClient {
  Future<OnlineMailSettings> mailSettings() async => OnlineMailSettings.fromJson(_map(await request('GET', '/mail/settings')));

  /// [password]: `null` = unverändert, `''` = entfernen.
  Future<OnlineMailSettings> saveMailSettings({
    required String? host,
    required int port,
    required String? username,
    required String? fromAddress,
    required String? fromName,
    required bool useTls,
    String? password,
    bool? sentImapEnabled,
    String? sentImapHost,
    int? sentImapPort,
    String? sentImapUsername,
    String? sentImapFolder,
    String? sentImapPassword,
    Map<String, String>? templates,
  }) async =>
      OnlineMailSettings.fromJson(_map(await request('PUT', '/mail/settings', body: {
        'host': host,
        'port': port,
        'username': username,
        'fromAddress': fromAddress,
        'fromName': fromName,
        'useTls': useTls,
        'password': ?password,
        'sentImapEnabled': ?sentImapEnabled,
        'sentImapHost': ?sentImapHost,
        'sentImapPort': ?sentImapPort,
        'sentImapUsername': ?sentImapUsername,
        'sentImapFolder': ?sentImapFolder,
        'sentImapPassword': ?sentImapPassword,
        'templates': ?templates,
      })));

  Future<void> sendTestMail(String to) => request('POST', '/mail/test', body: {'to': to});

  /// Liefert den tatsächlichen Empfänger; Status bei IMAP-Fehler separat abrufbar.
  Future<String> sendDocumentMail(String documentId, Uint8List pdf, {String? to, String? subject, String? body, Uint8List? xml}) async =>
      (await sendDocumentMailWithStatus(documentId, pdf, to: to, subject: subject, body: body, xml: xml)).to;

  /// SMTP-Erfolg bleibt Erfolg, auch wenn die anschließende IMAP-Kopie scheitert.
  Future<({String to, String? sentCopyWarning})> sendDocumentMailWithStatus(
    String documentId, Uint8List pdf, {String? to, String? subject, String? body, Uint8List? xml}) async {
    final response = _map(await request('POST', '/documents/$documentId/send', body: {
      'pdfBase64': base64Encode(pdf),
      'xmlBase64': ?(xml == null ? null : base64Encode(xml)),
      'to': ?to,
      'subject': ?subject,
      'body': ?body,
    }));
    return (to: response['to'] as String, sentCopyWarning: response['sentCopyWarning'] as String?);
  }

  Future<String> sendDunningMail(String noticeId, Uint8List pdf, {String? to}) async =>
      _map(await request('POST', '/dunning-notices/$noticeId/send', body: {'pdfBase64': base64Encode(pdf), 'to': ?to}))['to'] as String;

  Future<String> sendPurchaseOrderMail(String purchaseOrderId, Uint8List pdf, {String? to}) async =>
      _map(await request('POST', '/purchase-orders/$purchaseOrderId/send', body: {'pdfBase64': base64Encode(pdf), 'to': ?to}))['to'] as String;

  /// Einladung, optional vom Server per Mail verschickt.
  Future<({String token, bool emailSent, String? emailError})> createInvitationWithMail(
    String email,
    String groupId, {
    required bool sendEmail,
  }) async {
    final j = _map(await request('POST', '/invitations', body: {'email': email, 'groupId': groupId, 'sendEmail': sendEmail}));
    return (
      token: j['invitationToken'] as String,
      emailSent: j['emailSent'] as bool? ?? false,
      emailError: j['emailError'] as String?,
    );
  }
}
