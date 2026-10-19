import 'package:flutter/foundation.dart';

/// Bugfix 2026-10-19 (Kay: "Wenn ich den Bestand aus einer Bestellung
/// buche, wird dieser nicht angezeigt") — ein gewöhnlicher
/// `ChangeNotifier` (gleiches Muster wie `ActiveCompanyService`), den
/// JEDE Stelle anpingt, die den Lagerbestand tatsächlich verändert hat
/// (`ArticleDetailScreen._correctStock()`, `PurchaseOrderDetailScreen.
/// _receiveGoods()`, `InvoiceEditorScreen._finalize()` sofern das
/// Lagerbestand-Modul aktiv ist). `ArticlesScreen`/`ArticleDetailScreen`
/// hören darauf und laden ihre Bestandsanzeige neu — unabhängig davon,
/// ob sie gerade sichtbar sind oder im Hintergrund eines anderen Tabs
/// gemountet bleiben (IndexedStack, siehe `home_shell.dart`).
///
/// Bewusst **kein** Drift-`.watch()`-Stream: ein erster Versuch damit
/// hat 38 bestehende Widget-Tests mit "A Timer is still pending even
/// after the widget tree was disposed" zum Scheitern gebracht. Der
/// ChangeNotifier-Weg ist in dieser Codebase bereits vielfach erprobt
/// (siehe `ActiveCompanyService`) und birgt dieses Risiko nicht.
class StockChangeNotifier extends ChangeNotifier {
  void notifyStockChanged() => notifyListeners();
}
