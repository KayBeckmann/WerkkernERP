import 'package:test/test.dart';
import 'package:werkkern_core/werkkern_core.dart';

void main() {
  group('documentRecipient', () {
    test('Rechnung: Rechnungs-E-Mail vor Kontakt vor Kunde', () {
      expect(
        documentRecipient(billing: true, invoiceEmail: 'rechnung@k.de', contactEmail: 'a@k.de', customerEmail: 'info@k.de'),
        'rechnung@k.de',
      );
      expect(documentRecipient(billing: true, contactEmail: 'a@k.de', customerEmail: 'info@k.de'), 'a@k.de');
      expect(documentRecipient(billing: true, customerEmail: 'info@k.de'), 'info@k.de');
    });

    test('Angebot/Auftrag ignoriert die Rechnungs-E-Mail', () {
      expect(
        documentRecipient(billing: false, invoiceEmail: 'rechnung@k.de', contactEmail: 'a@k.de', customerEmail: 'info@k.de'),
        'a@k.de',
      );
      expect(documentRecipient(billing: false, invoiceEmail: 'rechnung@k.de', customerEmail: 'info@k.de'), 'info@k.de');
    });

    test('leere/ungültige Einträge werden übersprungen', () {
      expect(documentRecipient(billing: true, invoiceEmail: '  ', contactEmail: 'kein-at', customerEmail: ' info@k.de '), 'info@k.de');
      expect(documentRecipient(billing: true), isNull);
    });

    test('Mahnwesen-relevante Arten', () {
      expect(billingDocumentKinds, containsAll(['invoice', 'proforma', 'creditNote']));
      expect(billingDocumentKinds, isNot(contains('quote')));
      expect(billingDocumentKinds, isNot(contains('order')));
    });
  });
}
