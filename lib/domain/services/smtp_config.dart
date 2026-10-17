import '../../data/database/database.dart';

/// Firmenbezogene SMTP-Verbindungsdaten ohne das Passwort (das liegt
/// getrennt in [SmtpCredentialStore] — siehe dortigen Doc-Kommentar).
class SmtpConfig {
  const SmtpConfig({
    required this.host,
    required this.port,
    required this.username,
    required this.fromAddress,
    required this.fromName,
    required this.useTls,
  });

  factory SmtpConfig.fromCompany(Company company) => SmtpConfig(
        host: company.smtpHost,
        port: company.smtpPort,
        username: company.smtpUsername,
        fromAddress: company.smtpFromAddress,
        fromName: company.smtpFromName,
        useTls: company.smtpUseTls,
      );

  final String? host;
  final int port;
  final String? username;
  final String? fromAddress;
  final String? fromName;
  final bool useTls;

  /// Host und Absenderadresse sind das fachliche Minimum, ohne das ein
  /// Versand von vornherein keinen Sinn ergibt (Benutzername ist bei
  /// manchen Relays optional/identisch zur Absenderadresse).
  bool get isComplete => host != null && host!.isNotEmpty && fromAddress != null && fromAddress!.isNotEmpty;
}

/// Platzhalter-Ersetzung für Betreff/Text (Kays ausdrückliche Nachfrage,
/// wo Betreff/Body konfigurierbar sind). Bewusst simpel (String-Replace,
/// keine Template-Engine) — die Platzhalter sind in der Settings-UI
/// dokumentiert.
String applyEmailTemplatePlaceholders({
  required String template,
  required String customerName,
  required String documentNumber,
  required String companyName,
}) =>
    template
        .replaceAll('{{kunde}}', customerName)
        .replaceAll('{{nummer}}', documentNumber)
        .replaceAll('{{firma}}', companyName);
