import 'package:test/test.dart';
import 'package:werkkern_core/werkkern_core.dart';

/// C15.1: Freitext-Anschriften aus dem Bestand müssen ohne Nachpflege in
/// die strukturierten E-Rechnungs-Felder (BG-5/BG-8) zerlegbar sein.
void main() {
  group('parsePostalAddress', () {
    test('einzeilig mit Komma', () {
      final a = parsePostalAddress('Musterstraße 1, 23966 Wismar');
      expect(a.street, 'Musterstraße 1');
      expect(a.postalCode, '23966');
      expect(a.city, 'Wismar');
      expect(a.countryCode, 'DE');
      expect(a.isComplete, isTrue);
    });

    test('mehrzeilig mit Land', () {
      final a = parsePostalAddress('Hauptplatz 3\n8010 Graz\nÖsterreich');
      expect(a.street, 'Hauptplatz 3');
      expect(a.postalCode, '8010');
      expect(a.city, 'Graz');
      expect(a.countryCode, 'AT');
    });

    test('Länderpräfix vor der PLZ', () {
      final a = parsePostalAddress('Bahnhofstr. 2, CH-8001 Zürich');
      expect(a.countryCode, 'CH');
      expect(a.postalCode, '8001');
      expect(a.city, 'Zürich');
    });

    test('Zusatzzeile vor der Straße bleibt Teil der Straße', () {
      final a = parsePostalAddress('Gebäude B, Musterstraße 1, 23966 Wismar');
      expect(a.street, 'Gebäude B, Musterstraße 1');
      expect(a.city, 'Wismar');
    });

    test('ohne PLZ-Zeile: alles Straße, nicht vollständig', () {
      final a = parsePostalAddress('Irgendwo');
      expect(a.street, 'Irgendwo');
      expect(a.postalCode, isNull);
      expect(a.isComplete, isFalse);
    });

    test('leer', () {
      expect(parsePostalAddress(null).isComplete, isFalse);
      expect(parsePostalAddress('  ').display, isNull);
    });
  });

  test('addressFromFields bevorzugt strukturierte Felder', () {
    final a = addressFromFields(street: 'Weg 9', postalCode: '10115', city: 'Berlin', freeText: 'Alt 1, 99999 Falsch');
    expect(a.city, 'Berlin');
    final b = addressFromFields(freeText: 'Alt 1, 99999 Richtig', countryCode: 'at');
    expect(b.city, 'Richtig');
    expect(b.countryCode, 'AT');
  });

  test('display: Land nur außerhalb DE', () {
    expect(const PostalAddress(street: 'Weg 9', postalCode: '10115', city: 'Berlin').display, 'Weg 9\n10115 Berlin');
    expect(
      const PostalAddress(street: 'Weg 9', postalCode: '1010', city: 'Wien', countryCode: 'AT').display,
      'Weg 9\n1010 Wien\nÖsterreich',
    );
  });

  test('Schnappschuss JSON-Rundreise', () {
    final snapshot = EInvoiceSnapshot(
      seller: const EInvoiceParty(
        name: 'Elektro Beckmann',
        address: PostalAddress(street: 'Musterstraße 1', postalCode: '23966', city: 'Wismar'),
        vatId: 'DE123456789',
        taxNumber: '123/456/78901',
        email: 'info@example.org',
        phone: '03841 1',
        iban: 'DE02120300000000202051',
        bic: 'BYLADEM1001',
      ),
      buyer: const EInvoiceParty(
        name: 'Stadt Wismar',
        address: PostalAddress(street: 'Am Markt 1', postalCode: '23966', city: 'Wismar'),
        leitwegId: '04011000-1234512345-06',
        email: 'rechnung@example.org',
      ),
      format: EInvoiceFormat.xrechnung,
    );
    final back = EInvoiceSnapshot.fromJson(snapshot.toJson());
    expect(back.seller.bic, 'BYLADEM1001');
    expect(back.buyer.leitwegId, '04011000-1234512345-06');
    expect(back.buyer.address.city, 'Wismar');
    expect(back.format, EInvoiceFormat.xrechnung);
    expect(EInvoiceFormat.parse('unbekannt'), EInvoiceFormat.zugferd);
  });
}
