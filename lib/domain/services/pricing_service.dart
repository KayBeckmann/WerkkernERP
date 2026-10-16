import '../models/money.dart';

/// Kalkulation des Netto-Verkaufspreises eines Artikels (Brainstorming:
/// "Netto-Verkaufspreis aus dem Standardlieferanten-Einkaufspreis: EK ×
/// (1 + Aufschlag_in_Prozent / 100)").
///
/// **Zwei Randfälle, in A1 ausdrücklich als "noch zu entscheiden"
/// markiert — hier mit einer dokumentierten, konservativen Vorgabe
/// beantwortet statt stillschweigend geraten:**
/// - Kein Standardlieferant/kein Einkaufspreis bekannt → `null` statt 0 €.
///   Eine Rechnungsposition mit unbekanntem Preis soll das sichtbar
///   machen, nicht einen falschen 0-€-Preis vorschlagen.
/// - Artikel ohne Artikelgruppe, aber mit Standardlieferant → Aufschlag
///   0 % (reiner Einkaufspreis als Verkaufspreis). Kein erratener
///   Aufschlag ohne hinterlegte Gruppe.
///
/// `manualSalePriceCents` (falls auf dem Artikel gesetzt) überschreibt
/// diese Kalkulation immer — das entscheidet der Aufrufer (siehe
/// [ArticleRepository.effectiveSalePrice]), nicht dieser reine
/// Rechenkern.
Money? calculateSalePrice({
  required int? defaultSupplierPurchasePriceCents,
  required double? articleGroupMarkupPercent,
}) {
  if (defaultSupplierPurchasePriceCents == null) return null;
  final purchasePrice = Money.fromCents(defaultSupplierPurchasePriceCents);
  if (articleGroupMarkupPercent == null) return purchasePrice;
  return purchasePrice + purchasePrice.applyPercent(articleGroupMarkupPercent);
}
