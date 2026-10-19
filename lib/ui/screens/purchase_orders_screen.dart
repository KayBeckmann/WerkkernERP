import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/database/database.dart';
import '../../data/database/tables.dart';
import '../../data/repositories/purchase_order_repository.dart';
import '../../data/repositories/supplier_repository.dart';
import '../../domain/services/active_company_service.dart';
import 'low_stock_suggestions_screen.dart';
import 'purchase_order_detail_screen.dart';

/// Bestellungsliste der aktiven Firma (C5.2 Bestellwesen, Nachtrag
/// 2026-10-19) — gleiches Listen-Muster wie `InvoicesScreen`, aber ohne
/// `DocumentKind`-Filterung (eine Bestellung ist kein [DocumentKind],
/// siehe Doc-Kommentar bei `PurchaseOrders` in tables.dart).
class PurchaseOrdersScreen extends StatefulWidget {
  const PurchaseOrdersScreen({super.key});

  @override
  State<PurchaseOrdersScreen> createState() => _PurchaseOrdersScreenState();
}

class _PurchaseOrdersScreenState extends State<PurchaseOrdersScreen> {
  late Future<List<PurchaseOrder>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<PurchaseOrder>> _load() {
    final companyId = context.read<ActiveCompanyService>().active!.id;
    return context.read<PurchaseOrderRepository>().listForCompany(companyId);
  }

  void _reload() => setState(() => _future = _load());

  Future<void> _createDraft() async {
    final companyId = context.read<ActiveCompanyService>().active!.id;
    final suppliers = await context.read<SupplierRepository>().listForCompany(companyId);
    if (!mounted) return;
    if (suppliers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bitte zuerst einen Lieferanten anlegen.')),
      );
      return;
    }
    final supplier = await showDialog<Supplier>(
      context: context,
      builder: (context) => _SupplierPickerDialog(suppliers: suppliers),
    );
    if (supplier == null || !mounted) return;
    final draft = await context.read<PurchaseOrderRepository>().createDraft(
          companyId: companyId,
          supplierId: supplier.id,
          issueDate: DateTime.now(),
        );
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PurchaseOrderDetailScreen(purchaseOrderId: draft.id)),
    );
    _reload();
  }

  Future<void> _openLowStockSuggestions() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const LowStockSuggestionsScreen()),
    );
    _reload();
  }

  String _statusLabel(PurchaseOrderStatus status) => switch (status) {
        PurchaseOrderStatus.draft => 'Entwurf',
        PurchaseOrderStatus.finalized => 'Finalisiert',
        PurchaseOrderStatus.partiallyReceived => 'Teilweise erhalten',
        PurchaseOrderStatus.fullyReceived => 'Vollständig erhalten',
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<List<PurchaseOrder>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final orders = snapshot.data!;
          if (orders.isEmpty) {
            return const Center(child: Text('Noch keine Bestellungen angelegt.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
            itemCount: orders.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final order = orders[index];
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.shopping_cart_outlined),
                  title: Text(order.orderNumber ?? 'Entwurf'),
                  subtitle: Text(
                    '${order.supplierSnapshotName ?? ''} · ${_statusLabel(order.status)}'.trim(),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => PurchaseOrderDetailScreen(purchaseOrderId: order.id),
                      ),
                    );
                    _reload();
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'purchase-orders-low-stock-fab',
            onPressed: _openLowStockSuggestions,
            icon: const Icon(Icons.warning_amber_outlined),
            label: const Text('Mindestbestand'),
          ),
          const SizedBox(width: 12),
          FloatingActionButton.extended(
            heroTag: 'purchase-orders-fab',
            onPressed: _createDraft,
            icon: const Icon(Icons.add),
            label: const Text('Neue Bestellung'),
          ),
        ],
      ),
    );
  }
}

class _SupplierPickerDialog extends StatelessWidget {
  const _SupplierPickerDialog({required this.suppliers});
  final List<Supplier> suppliers;

  @override
  Widget build(BuildContext context) {
    return SimpleDialog(
      title: const Text('Lieferant wählen'),
      children: [
        for (final supplier in suppliers)
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, supplier),
            child: Text(supplier.name),
          ),
      ],
    );
  }
}
