import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:werkkernerp/domain/services/email_sender.dart' as platform;
import 'package:werkkernerp/domain/services/email_sender_native.dart' as native;
import 'package:werkkernerp/domain/services/email_sender_web.dart' as web;
import 'package:werkkernerp/domain/services/smtp_config.dart';

/// C7a SMTP-Versand (Kay-Nachfrage 2026-10-17). `flutter test` läuft auf
/// der Dart-VM (`dart.library.io` ist wahr) — die bedingte Export-Datei
/// `email_sender.dart` liefert hier also IMMER die native Variante.
/// Beide konkreten Implementierungen (native/web) werden deshalb hier
/// zusätzlich direkt importiert, um auch den Web-Zweig (der im
/// gebauten Web-Build gewählt würde) isoliert zu prüfen — ohne einen
/// echten SMTP-Server zu brauchen.
void main() {
  const incompleteConfig = SmtpConfig(
    host: null,
    port: 587,
    username: null,
    fromAddress: null,
    fromName: null,
    useTls: true,
  );

  test('Die bedingte Export-Datei wählt unter flutter test die native Variante', () {
    expect(platform.emailSendingSupported, isTrue);
  });

  test('Native: unvollständige Konfiguration schlägt ohne Netzwerkversuch fehl', () async {
    final result = await native.sendEmail(
      config: incompleteConfig,
      password: 'irrelevant',
      toAddress: 'kunde@example.test',
      subject: 'Betreff',
      body: 'Text',
      attachmentFilename: 'test.pdf',
      attachmentBytes: Uint8List(0),
    );
    expect(result.isSuccess, isFalse);
    expect(result.errorMessage, isNotNull);
  });

  test('Web: emailSendingSupported ist immer false', () {
    expect(web.emailSendingSupported, isFalse);
  });

  test('Web: sendEmail liefert immer einen sprechenden Fehlschlag, nie einen Erfolg', () async {
    const completeConfig = SmtpConfig(
      host: 'smtp.example.test',
      port: 587,
      username: 'user',
      fromAddress: 'rechnung@example.test',
      fromName: 'Elektro Beckmann',
      useTls: true,
    );
    final result = await web.sendEmail(
      config: completeConfig,
      password: 'irrelevant',
      toAddress: 'kunde@example.test',
      subject: 'Betreff',
      body: 'Text',
      attachmentFilename: 'test.pdf',
      attachmentBytes: Uint8List(0),
    );
    expect(result.isSuccess, isFalse);
    expect(result.errorMessage, contains('Browser'));
  });
}
