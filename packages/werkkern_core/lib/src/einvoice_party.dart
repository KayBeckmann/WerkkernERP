/// C15 E-Rechnung — strukturierte Parteien (Verkäufer/Käufer) nach
/// EN 16931. Reines Dart: die Offline-App friert diese Daten beim
/// Finalisieren als JSON am Dokument ein (`Invoices.eInvoiceSnapshot`),
/// der Server genauso (`documents.e_invoice_snapshot`); die XML-Erzeugung
/// (C15.2) liest ausschließlich daraus.
library;

/// Strukturierte Anschrift (BG-5/BG-8): Straße mit Hausnummer, PLZ, Ort,
/// Ländercode ISO 3166-1 alpha-2.
class PostalAddress {
  const PostalAddress({this.street, this.postalCode, this.city, this.countryCode = 'DE'});

  final String? street;
  final String? postalCode;
  final String? city;
  final String countryCode;

  bool get isComplete => _has(street) && _has(postalCode) && _has(city) && countryCode.length == 2;

  /// Mehrzeilige Darstellung, z. B. fürs PDF — ohne Land, wenn `DE`.
  String? get display {
    final lines = [
      if (_has(street)) street!.trim(),
      if (_has(postalCode) || _has(city)) [postalCode, city].where(_has).map((s) => s!.trim()).join(' '),
      if (countryCode != 'DE') countryNames[countryCode] ?? countryCode,
    ];
    return lines.isEmpty ? null : lines.join('\n');
  }

  Map<String, Object?> toJson() =>
      {'street': street, 'postalCode': postalCode, 'city': city, 'countryCode': countryCode};

  factory PostalAddress.fromJson(Map<String, Object?> j) => PostalAddress(
        street: j['street'] as String?,
        postalCode: j['postalCode'] as String?,
        city: j['city'] as String?,
        countryCode: (j['countryCode'] as String?)?.toUpperCase() ?? 'DE',
      );
}

bool _has(String? s) => s != null && s.trim().isNotEmpty;

/// Ländernamen (deutsch), die der Freitext-Parser erkennt, und die
/// Anzeige für Nicht-DE-Adressen. Bewusst kurz — Nachbarländer und die
/// häufigsten Handelspartner eines Elektrobetriebs.
const countryNames = <String, String>{
  'DE': 'Deutschland',
  'AT': 'Österreich',
  'CH': 'Schweiz',
  'NL': 'Niederlande',
  'BE': 'Belgien',
  'LU': 'Luxemburg',
  'FR': 'Frankreich',
  'PL': 'Polen',
  'CZ': 'Tschechien',
  'DK': 'Dänemark',
  'IT': 'Italien',
  'ES': 'Spanien',
  'GB': 'Vereinigtes Königreich',
};

const _countryByName = <String, String>{
  'deutschland': 'DE',
  'germany': 'DE',
  'österreich': 'AT',
  'oesterreich': 'AT',
  'austria': 'AT',
  'schweiz': 'CH',
  'switzerland': 'CH',
  'niederlande': 'NL',
  'netherlands': 'NL',
  'belgien': 'BE',
  'belgium': 'BE',
  'luxemburg': 'LU',
  'luxembourg': 'LU',
  'frankreich': 'FR',
  'france': 'FR',
  'polen': 'PL',
  'poland': 'PL',
  'tschechien': 'CZ',
  'dänemark': 'DK',
  'denmark': 'DK',
  'italien': 'IT',
  'italy': 'IT',
  'spanien': 'ES',
  'spain': 'ES',
};

final _postalLine = RegExp(r'^(?:([A-Z]{1,2})[- ])?(\d{4,5})\s+(.+)$');

/// Zerlegt eine Freitext-Anschrift („Musterstraße 1, 23966 Wismar“,
/// auch mehrzeilig oder mit Land am Ende) in Felder — Fallback für
/// Bestandsdaten, bei denen die strukturierten Felder noch leer sind.
/// Findet sich keine PLZ-Zeile, landet der ganze Text in [PostalAddress.street].
PostalAddress parsePostalAddress(String? text, {String defaultCountryCode = 'DE'}) {
  if (!_has(text)) return PostalAddress(countryCode: defaultCountryCode);
  final parts = text!
      .split(RegExp(r'[\n,;]'))
      .map((p) => p.trim())
      .where((p) => p.isNotEmpty)
      .toList();
  var country = defaultCountryCode;
  // Landesangabe am Ende („Deutschland“, „Österreich“, „A-“-Präfix vor der PLZ).
  if (parts.length > 1) {
    final last = parts.last.toLowerCase();
    if (_countryByName.containsKey(last)) {
      country = _countryByName[last]!;
      parts.removeLast();
    }
  }
  final index = parts.indexWhere(_postalLine.hasMatch);
  if (index == -1) return PostalAddress(street: parts.join(', '), countryCode: country);
  final match = _postalLine.firstMatch(parts[index])!;
  if (match.group(1) != null) {
    country = switch (match.group(1)) {
      'A' => 'AT',
      'D' => 'DE',
      'CH' => 'CH',
      final other => other!,
    };
  }
  return PostalAddress(
    street: index == 0 ? null : parts.sublist(0, index).join(', '),
    postalCode: match.group(2),
    city: match.group(3)!.trim(),
    countryCode: country,
  );
}

/// Verkäufer oder Käufer einer E-Rechnung (BG-4/BG-7 mit Kontakt,
/// Steuerangaben und Zahlungsdaten). Alle Felder optional — die
/// Pflichtfeldprüfung erfolgt in C15.2 je Profil.
class EInvoiceParty {
  const EInvoiceParty({
    required this.name,
    this.address = const PostalAddress(),
    this.vatId,
    this.taxNumber,
    this.email,
    this.phone,
    this.contactName,
    this.iban,
    this.bic,
    this.leitwegId,
  });

  final String name;
  final PostalAddress address;

  /// USt-IdNr. (BT-31/BT-48), Steuernummer (BT-32, nur Verkäufer).
  final String? vatId;
  final String? taxNumber;
  final String? email;
  final String? phone;

  /// Ansprechpartner (BT-41 Verkäufer, BT-56 Käufer) — leer = Firmenname.
  final String? contactName;

  /// Nur Verkäufer: Zahlungskonto (BT-84/BT-86).
  final String? iban;
  final String? bic;

  /// Nur Käufer: Leitweg-ID als Käuferreferenz (BT-10, Pflicht XRechnung).
  final String? leitwegId;

  Map<String, Object?> toJson() => {
        'name': name,
        'address': address.toJson(),
        'vatId': vatId,
        'taxNumber': taxNumber,
        'email': email,
        'phone': phone,
        'contactName': contactName,
        'iban': iban,
        'bic': bic,
        'leitwegId': leitwegId,
      };

  factory EInvoiceParty.fromJson(Map<String, Object?> j) => EInvoiceParty(
        name: j['name'] as String? ?? '',
        address: j['address'] is Map ? PostalAddress.fromJson((j['address'] as Map).cast()) : const PostalAddress(),
        vatId: j['vatId'] as String?,
        taxNumber: j['taxNumber'] as String?,
        email: j['email'] as String?,
        phone: j['phone'] as String?,
        contactName: j['contactName'] as String?,
        iban: j['iban'] as String?,
        bic: j['bic'] as String?,
        leitwegId: j['leitwegId'] as String?,
      );
}

/// Nur Rechnung und Gutschrift (inkl. Abschlags-/Schlussrechnung) sind
/// E-Rechnungen; Angebot, Auftrag, Lieferschein, Proforma bleiben PDFs.
bool isEInvoiceDocumentKind(String kind) => kind == 'invoice' || kind == 'creditNote';

/// E-Rechnungsformat je Kunde: ZUGFeRD (Hybrid-PDF, Vorgabe) oder
/// XRechnung (reines XML, öffentliche Auftraggeber mit Leitweg-ID).
enum EInvoiceFormat {
  zugferd,
  xrechnung;

  static EInvoiceFormat parse(String? value) =>
      value == 'xrechnung' ? EInvoiceFormat.xrechnung : EInvoiceFormat.zugferd;

  String get label => switch (this) {
        EInvoiceFormat.zugferd => 'ZUGFeRD (PDF mit XML)',
        EInvoiceFormat.xrechnung => 'XRechnung (XML, Behörden)',
      };
}

/// Beim Finalisieren eingefrorene Parteien — unabhängig von späteren
/// Stammdatenänderungen (wie die übrigen Schnappschüsse).
class EInvoiceSnapshot {
  const EInvoiceSnapshot({required this.seller, required this.buyer, this.format = EInvoiceFormat.zugferd});

  final EInvoiceParty seller;
  final EInvoiceParty buyer;
  final EInvoiceFormat format;

  Map<String, Object?> toJson() => {'seller': seller.toJson(), 'buyer': buyer.toJson(), 'format': format.name};

  factory EInvoiceSnapshot.fromJson(Map<String, Object?> j) => EInvoiceSnapshot(
        seller: EInvoiceParty.fromJson((j['seller'] as Map).cast()),
        buyer: EInvoiceParty.fromJson((j['buyer'] as Map).cast()),
        format: EInvoiceFormat.parse(j['format'] as String?),
      );
}

/// Strukturierte Felder bevorzugen, sonst den Freitext zerlegen — für
/// Stammdaten, die noch nicht nachgepflegt sind.
PostalAddress addressFromFields({
  String? street,
  String? postalCode,
  String? city,
  String? countryCode,
  String? freeText,
}) {
  if (_has(street) || _has(postalCode) || _has(city)) {
    return PostalAddress(
      street: _has(street) ? street!.trim() : null,
      postalCode: _has(postalCode) ? postalCode!.trim() : null,
      city: _has(city) ? city!.trim() : null,
      countryCode: _has(countryCode) ? countryCode!.trim().toUpperCase() : 'DE',
    );
  }
  return parsePostalAddress(freeText, defaultCountryCode: _has(countryCode) ? countryCode!.trim().toUpperCase() : 'DE');
}
