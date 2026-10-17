import 'package:flutter_test/flutter_test.dart';
import 'package:werkkernerp/domain/services/smtp_config.dart';

/// C7a SMTP-Versand (Kay-Nachfrage 2026-10-17: "Gibt es schon den SMTP
/// Versand?").
void main() {
  test('isComplete ist erst wahr, wenn Server UND Absenderadresse gesetzt sind', () {
    const empty = SmtpConfig(
      host: null,
      port: 587,
      username: null,
      fromAddress: null,
      fromName: null,
      useTls: true,
    );
    expect(empty.isComplete, isFalse);

    const onlyHost = SmtpConfig(
      host: 'smtp.example.test',
      port: 587,
      username: null,
      fromAddress: null,
      fromName: null,
      useTls: true,
    );
    expect(onlyHost.isComplete, isFalse);

    const complete = SmtpConfig(
      host: 'smtp.example.test',
      port: 587,
      username: 'user',
      fromAddress: 'rechnung@example.test',
      fromName: 'Elektro Beckmann',
      useTls: true,
    );
    expect(complete.isComplete, isTrue);
  });

  test('applyEmailTemplatePlaceholders ersetzt alle drei Platzhalter', () {
    final result = applyEmailTemplatePlaceholders(
      template: 'Hallo {{kunde}}, anbei {{nummer}} von {{firma}}.',
      customerName: 'Max Mustermann',
      documentNumber: 'R-26001',
      companyName: 'Elektro Beckmann',
    );
    expect(result, 'Hallo Max Mustermann, anbei R-26001 von Elektro Beckmann.');
  });

  test('applyEmailTemplatePlaceholders lässt Text ohne Platzhalter unverändert', () {
    final result = applyEmailTemplatePlaceholders(
      template: 'Fester Text ohne Platzhalter.',
      customerName: 'Max Mustermann',
      documentNumber: 'R-26001',
      companyName: 'Elektro Beckmann',
    );
    expect(result, 'Fester Text ohne Platzhalter.');
  });
}
