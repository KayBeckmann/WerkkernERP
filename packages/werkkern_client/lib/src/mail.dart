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
        'templates': ?templates,
      })));

  Future<void> sendTestMail(String to) => request('POST', '/mail/test', body: {'to': to});

  /// Liefert den tatsächlichen Empfänger.
  Future<String> sendDocumentMail(String documentId, Uint8List pdf, {String? to, String? subject, String? body}) async =>
      _map(await request('POST', '/documents/$documentId/send', body: {
        'pdfBase64': base64Encode(pdf),
        'to': ?to,
        'subject': ?subject,
        'body': ?body,
      }))['to'] as String;

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
