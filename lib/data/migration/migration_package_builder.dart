import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';
import 'package:werkkern_core/werkkern_core.dart';

import '../database/database.dart';
import '../database/tables.dart';

/// B4 Umzug Einzelplatz → Online-Firma: baut aus der lokalen Datenbank
/// das Umzugspaket einer Firma (`POST /company/import`). Nur lesen — die
/// Offline-Daten bleiben unverändert, bis der Server den Umzug bestätigt.
/// Offline-IDs bleiben im Paket; der Server vergibt neue.
class MigrationPackageBuilder {
  MigrationPackageBuilder(this._db);

  final AppDatabase _db;

  Future<Map<String, Object?>> build(String companyId) async {
    final db = _db;
    final company = await (db.select(db.companies)..where((c) => c.id.equals(companyId))).getSingle();

    final invoices = await (db.select(db.invoices)..where((i) => i.companyId.equals(companyId))).get();
    final invoiceIds = invoices.map((i) => i.id).toList();
    final invoiceItems = invoiceIds.isEmpty
        ? const <InvoiceItem>[]
        : await (db.select(db.invoiceItems)..where((i) => i.invoiceId.isIn(invoiceIds))).get();
    final articles = await (db.select(db.articles)..where((a) => a.companyId.equals(companyId))).get();
    final articleIds = articles.map((a) => a.id).toList();
    final templates =
        await (db.select(db.recurringInvoiceTemplates)..where((t) => t.companyId.equals(companyId))).get();
    final templateIds = templates.map((t) => t.id).toList();
    final templateItems = templateIds.isEmpty
        ? const <RecurringInvoiceTemplateItem>[]
        : await (db.select(db.recurringInvoiceTemplateItems)..where((i) => i.templateId.isIn(templateIds))).get();
    final orders = await (db.select(db.purchaseOrders)..where((o) => o.companyId.equals(companyId))).get();
    final orderIds = orders.map((o) => o.id).toList();
    final orderItems = orderIds.isEmpty
        ? const <PurchaseOrderItem>[]
        : await (db.select(db.purchaseOrderItems)..where((i) => i.purchaseOrderId.isIn(orderIds))).get();
    final counts = await (db.select(db.inventoryCounts)..where((c) => c.companyId.equals(companyId))).get();
    final countIds = counts.map((c) => c.id).toList();
    final countItems = countIds.isEmpty
        ? const <InventoryCountItem>[]
        : await (db.select(db.inventoryCountItems)..where((i) => i.inventoryCountId.isIn(countIds))).get();
    final prices = articleIds.isEmpty
        ? const <ArticleSupplierPrice>[]
        : await (db.select(db.articleSupplierPrices)..where((p) => p.articleId.isIn(articleIds))).get();

    List<Map<String, Object?>> itemsOf<T>(Iterable<T> items, String Function(T) owner, String ownerId,
            Map<String, Object?> Function(T) toJson) =>
        [for (final i in items) if (owner(i) == ownerId) toJson(i)];

    final exempt = company.isSmallBusinessExempt;
    return {
      'format': migrationPackageFormat,
      'formatVersion': migrationPackageVersion,
      'createdAt': _ts(DateTime.now()),
      'company': {
        'name': company.name,
        'address': company.address,
        'taxNumber': company.taxNumber,
        'vatId': company.vatId,
        'iban': company.iban,
        'email': company.email,
        'phone': company.phone,
        'footerText': company.pdfFooterText,
        'smallBusinessExempt': exempt,
        'documentTexts': {
          'invoice': {'intro': company.pdfIntroText, 'closing': company.pdfClosingText},
          'quote': {'intro': company.pdfIntroTextQuote, 'closing': company.pdfClosingTextQuote},
          'order': {'intro': company.pdfIntroTextOrder, 'closing': company.pdfClosingTextOrder},
          'deliveryNote': {'intro': company.pdfIntroTextDeliveryNote, 'closing': company.pdfClosingTextDeliveryNote},
          'proforma': {'intro': company.pdfIntroTextProforma, 'closing': company.pdfClosingTextProforma},
          'creditNote': {'intro': company.pdfIntroTextCreditNote, 'closing': company.pdfClosingTextCreditNote},
        },
        'modules': offlineModulesOf(company),
      },
      'settings': {
        'dunning': {
          'reminder2AfterDays': company.dunningReminder2AfterDays,
          'reminder3AfterDays': company.dunningReminder3AfterDays,
          'feeLevel1Cents': company.dunningFeeLevel1Cents,
          'feeLevel2Cents': company.dunningFeeLevel2Cents,
          'feeLevel3Cents': company.dunningFeeLevel3Cents,
          'interestRatePercent': company.dunningInterestRatePercent,
          'introText': company.pdfIntroTextDunning,
          'closingText': company.pdfClosingTextDunning,
        },
        'bankCsv': {
          'delimiter': company.bankCsvDelimiter,
          'hasHeaderRow': company.bankCsvHasHeaderRow,
          'dateColumn': company.bankCsvDateColumn,
          'amountColumn': company.bankCsvAmountColumn,
          'purposeColumn': company.bankCsvPurposeColumn,
          'counterpartyColumn': company.bankCsvCounterpartyColumn,
          'dateFormat': company.bankCsvDateFormat,
          'decimalSeparator': company.bankCsvDecimalSeparator,
        },
        'datev': {
          'beraterNummer': company.datevBeraterNummer,
          'mandantNummer': company.datevMandantNummer,
          'bankGegenkonto': company.datevBankGegenkonto,
          'sachkontenlaenge': company.datevSachkontenlaenge,
        },
      },
      'numberSequences': [
        for (final s in await (db.select(db.numberSequences)..where((s) => s.companyId.equals(companyId))).get())
          {'documentType': s.documentType, 'year': s.year, 'lastNumber': s.lastNumber},
      ],
      'customers': [
        for (final c in await (db.select(db.customers)..where((c) => c.companyId.equals(companyId))).get())
          {
            'invoiceEmail': c.invoiceEmail,
            'contacts': [
              for (final x in await (db.select(db.customerContacts)
                    ..where((x) => x.customerId.equals(c.id))
                    ..orderBy([(x) => OrderingTerm.asc(x.sortOrder)]))
                  .get())
                {'id': x.id, 'name': x.name, 'role': x.role, 'email': x.email, 'phone': x.phone, 'sortOrder': x.sortOrder},
            ],
            'id': c.id,
            'name': c.name,
            'address': c.address,
            'email': c.email,
            'phone': c.phone,
            'vatId': c.vatId,
            'contactPerson': c.contactPerson,
            'notes': c.notes,
            'createdAt': _ts(c.createdAt),
          },
      ],
      'suppliers': [
        for (final s in await (db.select(db.suppliers)..where((s) => s.companyId.equals(companyId))).get())
          {
            'id': s.id,
            'name': s.name,
            'address': s.address,
            'email': s.email,
            'phone': s.phone,
            'vatId': s.vatId,
            'contactPerson': s.contactPerson,
            'notes': s.notes,
            'minimumOrderQuantity': _dec(s.minimumOrderQuantity),
            'deliveryTerms': s.deliveryTerms,
            'createdAt': _ts(s.createdAt),
          },
      ],
      'articleGroups': [
        for (final g in await (db.select(db.articleGroups)..where((g) => g.companyId.equals(companyId))).get())
          {'id': g.id, 'name': g.name, 'markupPercent': g.markupPercent, 'createdAt': _ts(g.createdAt)},
      ],
      'articles': [
        for (final a in articles)
          {
            'id': a.id,
            'name': a.name,
            'unit': a.unit,
            'articleGroupId': a.articleGroupId,
            'defaultSupplierId': a.defaultSupplierId,
            'salePriceCents': a.manualSalePriceCents,
            'active': a.active,
            'stockQuantity': _dec(a.stockQuantity),
            'minimumStock': _dec(a.minimumStock),
            'createdAt': _ts(a.createdAt),
          },
      ],
      'articlePrices': [
        for (final p in prices) {'articleId': p.articleId, 'supplierId': p.supplierId, 'purchasePriceCents': p.purchasePriceCents},
      ],
      'projects': [
        for (final p in await (db.select(db.projects)..where((p) => p.companyId.equals(companyId))).get())
          {
            'id': p.id,
            'name': p.name,
            'customerId': p.customerId,
            'notes': p.notes,
            'status': p.status.name,
            'foundingYear': p.foundingYear,
            'projectNumber': p.projectNumber,
            'createdAt': _ts(p.createdAt),
          },
      ],
      'documents': [
        for (final d in invoices)
          {
            'id': d.id,
            'customerId': d.customerId,
            'kind': d.kind.name,
            'status': d.status.name,
            'number': d.invoiceNumber,
            'numberYear': d.numberYear,
            'issueDate': _date(d.issueDate),
            'serviceDate': _date(d.serviceDate),
            'dueDate': _date(d.dueDate),
            'paymentTerms': d.paymentTerms,
            'notes': d.notes,
            'customerSnapshotName': d.customerSnapshotName,
            'customerSnapshotAddress': d.customerSnapshotAddress,
            'customerSnapshotVatId': d.customerSnapshotVatId,
            'companySnapshotName': d.companySnapshotName,
            'companySnapshotAddress': d.companySnapshotAddress,
            'companySnapshotTaxNumber': d.companySnapshotTaxNumber,
            'companySnapshotVatId': d.companySnapshotVatId,
            'companySnapshotIban': d.companySnapshotIban,
            'introTextSnapshot': d.pdfIntroTextSnapshot,
            'closingTextSnapshot': d.pdfClosingTextSnapshot,
            'footerTextSnapshot': d.pdfFooterTextSnapshot,
            // Offline gilt § 19 zur Anzeige aus der Firma — online wird
            // er beim Finalisieren eingefroren; hier den heutigen Stand.
            'smallBusinessExemptSnapshot': d.status == InvoiceStatus.finalized && exempt,
            'finalizedAt': _ts(d.finalizedAt),
            'createdAt': _ts(d.createdAt),
            'updatedAt': _ts(d.updatedAt),
            'convertedFromId': d.convertedFromId,
            'projectId': d.projectId,
            'contactId': d.contactId,
            'isAdvancePayment': d.isAdvancePayment,
            'isFixedPrice': d.isFixedPrice,
            'stockBooked': d.stockBooked,
            'paymentStatus': d.paymentStatus.name,
            'paidAt': _ts(d.paidAt),
            'items': itemsOf(invoiceItems, (InvoiceItem i) => i.invoiceId, d.id, _item),
          },
      ],
      'vehicles': [
        for (final v in await (db.select(db.vehicles)..where((v) => v.companyId.equals(companyId))).get())
          {
            'id': v.id,
            'name': v.name,
            'licensePlate': v.licensePlate,
            'notes': v.notes,
            'nextInspectionDate': _date(v.nextInspectionDate),
            'active': v.active,
            'createdAt': _ts(v.createdAt),
          },
      ],
      'vehicleCosts': [
        for (final c in await (db.select(db.vehicleCostEntries)..where((c) => c.companyId.equals(companyId))).get())
          {
            'vehicleId': c.vehicleId,
            'date': _date(c.date),
            'amountCents': c.amountCents,
            'category': c.category.name,
            'description': c.description,
            'principalAmountCents': c.principalAmountCents,
            'interestAmountCents': c.interestAmountCents,
            'projectId': c.projectId,
            'createdAt': _ts(c.createdAt),
          },
      ],
      'recurringTemplates': [
        for (final t in templates)
          {
            'id': t.id,
            'customerId': t.customerId,
            'label': t.label,
            'interval': t.interval.name,
            'nextDueDate': _date(t.nextDueDate),
            'paymentTerms': t.paymentTerms,
            'notes': t.notes,
            'active': t.active,
            'createdAt': _ts(t.createdAt),
            'items': itemsOf(templateItems, (RecurringInvoiceTemplateItem i) => i.templateId, t.id, _templateItem),
          },
      ],
      'expenseCategories': [
        for (final c in await (db.select(db.expenseCategories)..where((c) => c.companyId.equals(companyId))).get())
          {'id': c.id, 'label': c.label, 'skr03Account': c.skr03Account, 'createdAt': _ts(c.createdAt)},
      ],
      'expenses': [
        for (final e in await (db.select(db.expenses)..where((e) => e.companyId.equals(companyId))).get())
          {
            'date': _date(e.date),
            'description': e.description,
            'amountGrossCents': e.amountGrossCents,
            'vatRatePercent': e.vatRatePercent,
            'categoryId': e.categoryId,
            'supplierReference': e.supplierReference,
            'projectId': e.projectId,
            'createdAt': _ts(e.createdAt),
            'updatedAt': _ts(e.updatedAt),
          },
      ],
      'bankTransactions': [
        for (final b in await (db.select(db.bankTransactions)..where((b) => b.companyId.equals(companyId))).get())
          {
            'date': _date(b.date),
            'amountCents': b.amountCents,
            'purpose': b.purpose,
            'counterparty': b.counterparty,
            'matchedDocumentId': b.matchedInvoiceId,
            'importHash': b.importHash,
            'importedAt': _ts(b.importedAt),
          },
      ],
      'purchaseOrders': [
        for (final o in orders)
          {
            'id': o.id,
            'supplierId': o.supplierId,
            'status': o.status.name,
            'number': o.orderNumber,
            'numberYear': o.numberYear,
            'issueDate': _date(o.issueDate),
            'notes': o.notes,
            'supplierSnapshotName': o.supplierSnapshotName,
            'supplierSnapshotAddress': o.supplierSnapshotAddress,
            'finalizedAt': _ts(o.finalizedAt),
            'sourceOrderId': o.sourceOrderId,
            'projectId': o.projectId,
            'expenseCategoryId': o.expenseCategoryId,
            'createdAt': _ts(o.createdAt),
            'updatedAt': _ts(o.updatedAt),
            'items': [
              for (final (index, i) in orderItems.where((i) => i.purchaseOrderId == o.id).indexed)
                {
                  'articleId': i.articleId,
                  'description': i.description,
                  'quantity': _dec(i.quantity),
                  'purchasePriceCents': i.purchasePriceCents,
                  'receivedQuantity': _dec(i.receivedQuantity),
                  'sortOrder': index,
                },
            ],
          },
      ],
      'stockMovements': [
        for (final m in await (db.select(db.stockMovements)
              ..where((m) => m.companyId.equals(companyId))
              ..orderBy([(m) => OrderingTerm.asc(m.createdAt)]))
            .get())
          {
            'articleId': m.articleId,
            'type': m.type.name,
            'quantityDelta': _dec(m.quantityDelta),
            'resultingQuantity': _dec(m.resultingQuantity),
            'referenceLabel': m.referenceLabel,
            'note': m.note,
            'createdAt': _ts(m.createdAt),
          },
      ],
      'inventoryCounts': [
        for (final c in counts)
          {
            'id': c.id,
            'label': c.label,
            'date': _date(c.date),
            'status': c.status.name,
            'completedAt': _ts(c.completedAt),
            'createdAt': _ts(c.createdAt),
            'items': [
              for (final i in countItems.where((i) => i.inventoryCountId == c.id))
                {
                  'articleId': i.articleId,
                  'expectedQuantity': _dec(i.expectedQuantity),
                  'countedQuantity': _dec(i.countedQuantity),
                  'countedAt': _ts(i.countedAt),
                },
            ],
          },
      ],
      'staffRoles': [
        for (final r in await (db.select(db.staffRoles)..where((r) => r.companyId.equals(companyId))).get())
          {
            'id': r.id,
            'name': r.name,
            'hourlyCostCents': r.hourlyCostRateCents,
            'hourlyBillingCents': r.hourlyBillingRateCents,
            'createdAt': _ts(r.createdAt),
          },
      ],
      'timeEntries': [
        for (final t in await (db.select(db.timeEntries)..where((t) => t.companyId.equals(companyId))).get())
          {
            'date': _date(t.date),
            'hours': _dec(t.hours),
            'staffRoleId': t.staffRoleId,
            'documentId': t.invoiceId,
            'projectId': t.projectId,
            'note': t.note,
            'timeSheetId': t.timeSheetId,
            'createdAt': _ts(t.createdAt),
          },
      ],
      'timeSheets': [
        for (final s in await (db.select(db.timeSheets)..where((s) => s.companyId.equals(companyId))).get())
          {
            'id': s.id,
            'date': _date(s.date),
            'documentId': s.invoiceId,
            'projectId': s.projectId,
            'status': s.status.name,
            'signaturePng': s.signatureImage == null ? null : base64Encode(s.signatureImage!),
            'signedAt': _ts(s.signedAt),
            'supersedesId': s.supersedesId,
            'createdAt': _ts(s.createdAt),
          },
      ],
    };
  }

  static Map<String, Object?> _item(InvoiceItem i) => {
        'kind': i.kind.name,
        'articleId': i.articleId,
        'description': i.description,
        'quantity': i.quantity,
        'unitPriceCents': i.unitPriceCents,
        'vatRatePercent': i.vatRatePercent,
        'unit': i.unit,
        'discountPercent': i.discountPercent,
        'groupLabel': i.groupLabel,
        'staffRoleId': i.staffRoleId,
        'sortOrder': i.sortOrder,
      };

  static Map<String, Object?> _templateItem(RecurringInvoiceTemplateItem i) => {
        'kind': i.kind.name,
        'articleId': i.articleId,
        'description': i.description,
        'quantity': i.quantity,
        'unitPriceCents': i.unitPriceCents,
        'vatRatePercent': i.vatRatePercent,
        'unit': i.unit,
        'discountPercent': i.discountPercent,
        'groupLabel': i.groupLabel,
        'sortOrder': i.sortOrder,
      };
}

/// Offline-Modulschalter als Online-Modulschlüssel (`knownModules`).
List<String> offlineModulesOf(Company c) => [
      if (c.quotesEnabled) 'quotes',
      if (c.ordersEnabled) 'orders',
      if (c.deliveryNotesEnabled) 'deliveryNotes',
      if (c.proformaEnabled) 'proforma',
      if (c.creditNotesEnabled) 'creditNotes',
      if (c.advancePaymentInvoicesEnabled) 'advancePaymentInvoices',
      if (c.projectsEnabled) 'projects',
      if (c.fleetEnabled) 'fleet',
      if (c.recurringInvoicesEnabled) 'recurringInvoices',
      if (c.dunningEnabled) 'dunning',
      if (c.smtpEnabled) 'smtp',
      if (c.buchhaltungEnabled) 'buchhaltung',
      if (c.lagerbestandEnabled) 'lagerbestand',
      if (c.bestellwesenEnabled) 'bestellwesen',
      if (c.timeTrackingEnabled) 'timeTracking',
    ];

String? _ts(DateTime? t) => t?.toUtc().toIso8601String();

/// Kalendertag wie offline angezeigt (lokal), ohne Uhrzeit.
String? _date(DateTime? d) {
  if (d == null) return null;
  final l = d.toLocal();
  return '${l.year.toString().padLeft(4, '0')}-${l.month.toString().padLeft(2, '0')}-${l.day.toString().padLeft(2, '0')}';
}

/// Offline-Mengen sind `double` — als exakter Dezimaltext übertragen.
String? _dec(double? v) => v == null ? null : Decimal.parse(v.toString()).toString();
