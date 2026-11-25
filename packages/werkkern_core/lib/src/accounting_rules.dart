/// Buchhaltungsregeln je Dokumentart (Schlüssel = `DocumentKind`-Name),
/// gemeinsam für Offline-App und Server.
///
/// Umsatz/Einnahme sind nur Rechnungen (inkl. Abschlagsrechnungen);
/// eine Gutschrift mindert sie. Angebot, Auftrag, Lieferschein und
/// Proforma sind keine Einnahmen — sonst zählten z. B. ein finalisierter
/// Auftrag und die Rechnung daraus doppelt.
int revenueSignForKind(String kind) => switch (kind) {
      'invoice' => 1,
      'creditNote' => -1,
      _ => 0,
    };

/// Nur Rechnungen haben einen Zahlungsstatus und sind damit offene
/// Posten, mahnbar und im Bankabgleich zuordenbar.
bool hasPaymentStatusKind(String kind) => kind == 'invoice';

/// Eine Rechnung ist durch Gutschriften geschlossen, wenn sie storniert ist
/// oder finalisierte Gutschriften ihren Bruttobetrag voll abdecken (Kay
/// 2026-11-25: „Wenn die Rechnung storniert wurde, muss sie im System als
/// geschlossen gekennzeichnet werden“). Dann ist sie keine offene Forderung
/// mehr — weder in offenen Posten noch im Dashboard, Mahnwesen oder
/// Bankabgleich. Teilgutschriften lassen die Rechnung offen.
bool isInvoiceClosedByCredit({
  required bool cancelled,
  required int invoiceGrossCents,
  required int creditedGrossCents,
}) =>
    cancelled || (invoiceGrossCents > 0 && creditedGrossCents >= invoiceGrossCents);
