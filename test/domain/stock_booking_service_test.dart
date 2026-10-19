import 'package:flutter_test/flutter_test.dart';
import 'package:werkkernerp/data/database/tables.dart';
import 'package:werkkernerp/domain/services/stock_booking_service.dart';

/// C5.1 Lagerbestand (Nachtrag 2026-10-19) — reine Entscheidungslogik,
/// wann eine Dokumentenkette ihre Bestandsbuchung bekommt.
void main() {
  test('Angebot, Proforma und Gutschrift sind nie bestandsrelevant', () {
    expect(shouldBookStockOnFinalize(kind: DocumentKind.quote, predecessorKind: null), isFalse);
    expect(shouldBookStockOnFinalize(kind: DocumentKind.proforma, predecessorKind: null), isFalse);
    expect(shouldBookStockOnFinalize(kind: DocumentKind.creditNote, predecessorKind: null), isFalse);
  });

  test(
    'Auftrag/Rechnung/Lieferschein ohne Vorgänger (direkt erstellt oder aus Angebot/Proforma '
    'umgewandelt) buchen — sie sind das erste bestandsrelevante Dokument ihrer Kette',
    () {
      for (final kind in [DocumentKind.order, DocumentKind.invoice, DocumentKind.deliveryNote]) {
        expect(shouldBookStockOnFinalize(kind: kind, predecessorKind: null), isTrue);
        expect(shouldBookStockOnFinalize(kind: kind, predecessorKind: DocumentKind.quote), isTrue);
        expect(shouldBookStockOnFinalize(kind: kind, predecessorKind: DocumentKind.proforma), isTrue);
      }
    },
  );

  test(
    'Kay-Vorgabe ("Artikel in einem Auftrag dürfen NICHT doppelt gebucht werden, wenn eine '
    'Rechnung erstellt wird"): eine aus einem bereits bestandsrelevanten Dokument erzeugte '
    'Rechnung/Lieferschein bucht NICHT erneut',
    () {
      expect(
        shouldBookStockOnFinalize(kind: DocumentKind.invoice, predecessorKind: DocumentKind.order),
        isFalse,
      );
      expect(
        shouldBookStockOnFinalize(kind: DocumentKind.deliveryNote, predecessorKind: DocumentKind.order),
        isFalse,
      );
      // Auch die umgekehrte, laut `allowedConversionTargets` nie
      // vorkommende Richtung bleibt konsistent falsch, nicht nur
      // zufällig durch die konkreten Testfälle oben.
      expect(
        shouldBookStockOnFinalize(kind: DocumentKind.invoice, predecessorKind: DocumentKind.deliveryNote),
        isFalse,
      );
    },
  );
}
