/// Empfänger beim Mailversand eines Dokuments (Kay-Anforderung
/// 2026-11-09): Rechnungsdokumente gehen zuerst an die Rechnungs-E-Mail
/// des Kunden, sonst an die Kontaktperson des Dokuments, sonst an die
/// allgemeine E-Mail des Kunden. Angebote/Aufträge/Lieferscheine
/// überspringen die Rechnungs-E-Mail.
library;

/// Dokumentarten, die an die Rechnungs-E-Mail gehen (Mahnungen ebenso,
/// siehe [documentRecipient] mit `billing: true`).
const billingDocumentKinds = {'invoice', 'proforma', 'creditNote'};

/// Erste gültige Adresse in der Reihenfolge Rechnungs-E-Mail (nur bei
/// [billing]) → [contactEmail] → [customerEmail]; `null`, wenn keine
/// hinterlegt ist. Leere oder offensichtlich ungültige Einträge (ohne
/// „@“) werden übersprungen statt den Versand zu blockieren.
String? documentRecipient({
  required bool billing,
  String? invoiceEmail,
  String? contactEmail,
  String? customerEmail,
}) {
  for (final candidate in [if (billing) invoiceEmail, contactEmail, customerEmail]) {
    final trimmed = candidate?.trim();
    if (trimmed != null && trimmed.contains('@')) return trimmed;
  }
  return null;
}
