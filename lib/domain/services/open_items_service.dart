import 'package:werkkern_core/werkkern_core.dart' show hasPaymentStatusKind;

import '../../data/database/database.dart';
import '../../data/database/tables.dart';
import '../models/money.dart';

/// C14.1 Offene-Posten-Übersicht (Kay-Priorisierungsentscheidung
/// 2026-10-18 — erster Baustein der vollen Buchhaltung). Reine
/// Aggregationslogik ohne Datenbankzugriff, testbar ohne DB — gleiches
/// Trennungsprinzip wie `dashboard_service.dart`/
/// `invoice_totals_service.dart`.
/// Ob ein Dokument ein offener Posten ist: finalisierte, unbezahlte
/// **Rechnung** — Angebote/Aufträge/Lieferscheine/Proforma/Gutschriften
/// haben keinen Zahlungsstatus (`hasPaymentStatusKind`).
bool isOpenItem(Invoice invoice) =>
    invoice.status == InvoiceStatus.finalized &&
    invoice.paymentStatus == PaymentStatus.open &&
    hasPaymentStatusKind(invoice.kind.name);

class OpenItem {
  const OpenItem({required this.invoice, required this.gross, required this.customerName});
  final Invoice invoice;
  final Money gross;
  final String customerName;
}

/// Alle offenen Rechnungen EINES Kunden samt Summe — die eigentliche
/// "Debitorenübersicht".
class CustomerOpenItems {
  const CustomerOpenItems({
    required this.customerId,
    required this.customerName,
    required this.items,
    required this.total,
  });
  final String customerId;
  final String customerName;
  final List<OpenItem> items;
  final Money total;
}

/// Gruppiert bereits geladene offene Posten nach Kunde, größte offene
/// Summe zuerst (das ist fachlich am relevantesten für eine Offene-
/// Posten-Liste — wer am meisten schuldet, steht oben).
List<CustomerOpenItems> groupOpenItemsByCustomer(List<OpenItem> items) {
  final byCustomer = <String, List<OpenItem>>{};
  for (final item in items) {
    byCustomer.putIfAbsent(item.invoice.customerId, () => []).add(item);
  }
  final result = [
    for (final entry in byCustomer.entries)
      CustomerOpenItems(
        customerId: entry.key,
        customerName: entry.value.first.customerName,
        items: entry.value,
        total: totalOpenAmount(entry.value),
      ),
  ];
  result.sort((a, b) => b.total.cents.compareTo(a.total.cents));
  return result;
}

Money totalOpenAmount(List<OpenItem> items) =>
    items.fold(Money.zero(), (sum, item) => sum + item.gross);
