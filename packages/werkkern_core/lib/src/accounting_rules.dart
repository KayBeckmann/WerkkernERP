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
