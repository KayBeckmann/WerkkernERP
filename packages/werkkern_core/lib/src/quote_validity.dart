/// A5-Nachtrag (Kay, 16.11.2026): Angebotsbindefrist.
///
/// Die Firma hat eine Standard-Dauer in Tagen (Vorbelegung für neue
/// Angebote), der Entwurf seine eigene Dauer. Erst beim Finalisieren
/// entstehen Fristbeginn (Finalisierungsdatum) und „bindend bis“ — eine
/// spätere Änderung des Firmenstandards ändert finalisierte Angebote nie.
library;

/// Nur der Kalendertag zählt (keine Uhrzeit).
DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

/// „Bindend bis“ = Fristbeginn + [days] Kalendertage.
DateTime quoteValidUntil(DateTime validFrom, int days) {
  final from = _day(validFrom);
  return DateTime(from.year, from.month, from.day + days);
}

/// Dauer in Tagen zwischen Fristbeginn und „bindend bis“ (nach einer
/// bestätigten Anpassung des Enddatums).
int quoteValidityDaysBetween(DateTime validFrom, DateTime validUntil) =>
    _day(validUntil).difference(_day(validFrom)).inDays;

/// Zulässige Dauer: 0 bis 3650 Tage (`null` = keine Bindefrist).
bool isValidQuoteValidityDays(int? days) => days == null || (days >= 0 && days <= 3650);

String _date(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';

/// Text für Angebot/PDF. Finalisiert mit festem Datum, im Entwurf nur die
/// Dauer (das Enddatum steht erst beim Finalisieren fest). `null` = keine
/// Bindefrist, keine Zeile.
String? quoteValidityText({int? days, DateTime? validUntil}) {
  if (validUntil != null) return 'Dieses Angebot ist gültig bis ${_date(validUntil)}.';
  if (days == null) return null;
  return days == 1
      ? 'Dieses Angebot ist 1 Tag ab Ausstellung gültig.'
      : 'Dieses Angebot ist $days Tage ab Ausstellung gültig.';
}
