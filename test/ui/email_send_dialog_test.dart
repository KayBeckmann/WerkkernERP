import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:werkkernerp/domain/services/smtp_config.dart';
import 'package:werkkernerp/domain/services/smtp_credential_store.dart';
import 'package:werkkernerp/ui/widgets/email_send_dialog.dart';

/// Reiner In-Memory-Fake, dessen `readPassword()` erst zurückkehrt, wenn
/// der Test es über [passwordCompleter] freigibt — simuliert einen
/// Secure-Storage-Zugriff, der noch läuft, während der Dialog bereits
/// geschlossen wird.
class _SlowCredentialStore extends SmtpCredentialStore {
  final Completer<String?> passwordCompleter = Completer<String?>();

  @override
  Future<String?> readPassword(String companyId) => passwordCompleter.future;

  @override
  Future<void> writePassword(String companyId, String password) async {}

  @override
  Future<void> deletePassword(String companyId) async {}
}

const _config = SmtpConfig(
  host: 'smtp.example.test',
  port: 587,
  username: 'user',
  fromAddress: 'rechnung@example.test',
  fromName: 'Elektro Beckmann',
  useTls: true,
);

void main() {
  testWidgets(
    'Dialog-Schließen waehrend eines noch laufenden Passwort-Lesevorgangs stürzt nicht ab '
    '(Fund: fehlender mounted-Check nach dem await von readPassword())',
    (tester) async {
      final store = _SlowCredentialStore();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showEmailSendDialog(
                  context: context,
                  config: _config,
                  credentialStore: store,
                  companyId: 'company-1',
                  initialTo: 'kunde@example.test',
                  initialSubject: 'Betreff',
                  initialBody: 'Text',
                  attachmentFilename: 'test.pdf',
                  buildAttachment: () async => Uint8List(0),
                ),
                child: const Text('Öffnen'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Öffnen'));
      await tester.pumpAndSettle();
      expect(find.text('Senden'), findsOneWidget);

      await tester.tap(find.text('Senden'));
      // Ein Pump, aber NICHT pumpAndSettle — `readPassword()` hängt
      // bewusst noch im `passwordCompleter`, der Dialog ist also mitten
      // im Warten auf die Zukunft.
      await tester.pump();

      // Dialog jetzt schließen, während der Lesevorgang noch läuft
      // (z. B. weil der Nutzer währenddessen "Abbrechen"/Zurück drückt).
      Navigator.of(tester.element(find.text('Öffnen'))).pop();
      await tester.pumpAndSettle();
      expect(find.text('Senden'), findsNothing, reason: 'Dialog ist geschlossen.');

      // Jetzt den Lesevorgang abschließen — ohne den Fix würde das
      // gleich darauf folgende setState() auf einem bereits verworfenen
      // State einen FlutterError auslösen, den `flutter_test` als
      // Testfehler zählt (kein expect() nötig: ein nicht abgefangener
      // Fehler lässt den Test allein dadurch scheitern).
      store.passwordCompleter.complete(null);
      await tester.pumpAndSettle();
    },
  );
}
