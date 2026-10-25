import 'money.dart';

/// Kalkulation des Netto-Verkaufspreises eines Artikels: EK des
/// Standardlieferanten × (1 + Aufschlag der Artikelgruppe / 100).
/// Gemeinsam für Offline-App und Server.
///
/// Randfälle (A1, dokumentierte Vorgabe):
/// - Kein Standardlieferant/kein Einkaufspreis → `null` statt 0 €.
/// - Artikel ohne Artikelgruppe → Aufschlag 0 %.
///
/// Ein manueller Verkaufspreis auf dem Artikel überschreibt diese
/// Kalkulation immer — das entscheidet der Aufrufer.
Money? calculateSalePrice({
  required int? defaultSupplierPurchasePriceCents,
  required double? articleGroupMarkupPercent,
}) {
  if (defaultSupplierPurchasePriceCents == null) return null;
  final purchasePrice = Money.fromCents(defaultSupplierPurchasePriceCents);
  if (articleGroupMarkupPercent == null) return purchasePrice;
  return purchasePrice + purchasePrice.applyPercent(articleGroupMarkupPercent);
}
