part of '../repository_postgres.dart';

/// B4 Umzug: alle Fachdaten in **einer** Transaktion — scheitert eine
/// Zeile, bleibt die Firma leer (kein halber Umzug).
mixin _PostgresCompanyImport implements CompanyImportStore {
  SessionExecutor get _db;

  static const _dataTables = [
    'customers',
    'articles',
    'documents',
    'projects',
    'time_entries',
    'suppliers',
    'article_groups',
    'vehicles',
    'expenses',
    'bank_transactions',
    'purchase_orders',
    'stock_movements',
    'inventory_counts',
    'recurring_templates',
    'time_sheets',
  ];

  @override
  Future<bool> companyHasBusinessData(String companyId) => _db.run((s) => _hasBusinessData(s, companyId));

  @override
  Future<void> importCompanyData(String companyId, CompanyImportData data) => _db.runTx((s) async {
    Future<void> insert(String table, Map<String, Object?> row) => s.execute(
      Sql.named('INSERT INTO $table (${row.keys.join(', ')}) VALUES (${row.keys.map((k) => '@$k').join(', ')})'),
      parameters: row,
    );
    TypedValue date(DateTime? d) => TypedValue(Type.date, d);

    // Gleichzeitige Umzüge derselben Firma serialisieren.
    await s.execute(Sql.named('SELECT 1 FROM companies WHERE id = @id FOR UPDATE'), parameters: {'id': companyId});
    if (await _hasBusinessData(s, companyId)) {
      throw const BusinessConflict('Die Firma enthält bereits Daten — ein Umzug ist nur in eine leere Firma möglich.');
    }
    await s.execute(Sql.named('DELETE FROM staff_roles WHERE company_id = @c'), parameters: {'c': companyId});
    await s.execute(Sql.named('DELETE FROM expense_categories WHERE company_id = @c'), parameters: {'c': companyId});

    for (final c in data.customers) {
      await insert('customers', {
        'id': c.id,
        'company_id': companyId,
        'name': c.name,
        'address': c.address,
        'email': c.email,
        'phone': c.phone,
        'vat_id': c.vatId,
        'contact_person': c.contactPerson,
        'notes': c.notes,
        'created_at': c.createdAt,
        'invoice_email': c.invoiceEmail,
      });
      for (final x in c.contacts) {
        await insert('customer_contacts', {
          'id': x.id,
          'company_id': companyId,
          'customer_id': c.id,
          'name': x.name,
          'role': x.role,
          'email': x.email,
          'phone': x.phone,
          'sort_order': x.sortOrder,
        });
      }
    }
    for (final x in data.suppliers) {
      await insert('suppliers', {
        'id': x.id,
        'company_id': companyId,
        'name': x.name,
        'address': x.address,
        'email': x.email,
        'phone': x.phone,
        'vat_id': x.vatId,
        'contact_person': x.contactPerson,
        'notes': x.notes,
        'minimum_order_quantity': x.minimumOrderQuantity,
        'delivery_terms': x.deliveryTerms,
        'created_at': x.createdAt,
      });
    }
    for (final g in data.articleGroups) {
      await insert('article_groups', {
        'id': g.id,
        'company_id': companyId,
        'name': g.name,
        'markup_percent': g.markupPercent,
        'created_at': g.createdAt,
      });
    }
    for (final a in data.articles) {
      await insert('articles', {
        'id': a.id,
        'company_id': companyId,
        'name': a.name,
        'unit': a.unit,
        'sale_price_cents': a.salePriceCents,
        'active': a.active,
        'created_at': a.createdAt,
        'article_group_id': a.articleGroupId,
        'default_supplier_id': a.defaultSupplierId,
        'stock_quantity': a.stockQuantity,
        'minimum_stock': a.minimumStock,
      });
    }
    for (final p in data.articlePrices) {
      await insert('article_supplier_prices', {
        'company_id': companyId,
        'article_id': p.articleId,
        'supplier_id': p.supplierId,
        'purchase_price_cents': p.purchasePriceCents,
      });
    }
    for (final p in data.projects) {
      await insert('projects', {
        'id': p.id,
        'company_id': companyId,
        'name': p.name,
        'customer_id': p.customerId,
        'status': p.status,
        'founding_year': p.foundingYear,
        'project_number': p.projectNumber,
        'created_at': p.createdAt,
        'notes': p.notes,
      });
    }
    // Umwandlungsquellen zuerst (Fremdschlüssel converted_from_id).
    final inserted = <String>{};
    // Vor den Positionen: Stunden-Positionen verweisen auf Rollen (C3.4).
    for (final r in data.staffRoles) {
      await insert('staff_roles', {
        'id': r.id,
        'company_id': companyId,
        'name': r.name,
        'hourly_cost_cents': r.hourlyCostCents,
        'hourly_billing_cents': r.hourlyBillingCents,
        'created_at': r.createdAt,
      });
    }
    final byId = {for (final d in data.documents) d.id: d};
    Future<void> insertDocument(Document d) async {
      if (!inserted.add(d.id)) return;
      final source = byId[d.convertedFromId];
      if (source != null) await insertDocument(source);
      await insert('documents', {
        'id': d.id,
        'company_id': companyId,
        'customer_id': d.customerId,
        'kind': d.kind,
        'status': d.status,
        'number': d.number,
        'number_year': d.numberYear,
        'issue_date': date(d.issueDate),
        'service_date': date(d.serviceDate),
        'payment_terms': d.paymentTerms,
        'notes': d.notes,
        'customer_snapshot_name': d.customerSnapshotName,
        'customer_snapshot_address': d.customerSnapshotAddress,
        'customer_snapshot_vat_id': d.customerSnapshotVatId,
        'company_snapshot_name': d.companySnapshotName,
        'company_snapshot_address': d.companySnapshotAddress,
        'company_snapshot_tax_number': d.companySnapshotTaxNumber,
        'company_snapshot_vat_id': d.companySnapshotVatId,
        'company_snapshot_iban': d.companySnapshotIban,
        'created_by_user_id': d.createdByUserId,
        'created_at': d.createdAt,
        'updated_at': d.updatedAt,
        'finalized_at': d.finalizedAt,
        'version': d.version,
        'converted_from_id': d.convertedFromId,
        'payment_status': d.paymentStatus,
        'paid_at': d.paidAt,
        'due_date': date(d.dueDate),
        'project_id': d.projectId,
        'is_advance_payment': d.isAdvancePayment,
        'is_fixed_price': d.isFixedPrice,
        'contact_id': d.contactId,
        'intro_text_snapshot': d.introTextSnapshot,
        'closing_text_snapshot': d.closingTextSnapshot,
        'footer_text_snapshot': d.footerTextSnapshot,
        'small_business_exempt_snapshot': d.smallBusinessExemptSnapshot,
        'stock_booked': d.stockBooked,
      });
    }

    for (final d in data.documents) {
      await insertDocument(d);
    }
    Map<String, Object?> itemRow(DocumentItem i, String owner) => {
      'id': i.id,
      owner: i.documentId,
      'kind': i.kind,
      'article_id': i.articleId,
      'description': i.description,
      'quantity': i.quantity,
      'unit_price_cents': i.unitPriceCents,
      'vat_rate_percent': i.vatRatePercent,
      'unit': i.unit,
      'discount_percent': i.discountPercent,
      'group_label': i.groupLabel,
      'sort_order': i.sortOrder,
    };
    for (final i in data.documentItems) {
      await insert('document_items', {...itemRow(i, 'document_id'), 'staff_role_id': i.staffRoleId});
    }
    for (final v in data.vehicles) {
      await insert('vehicles', {
        'id': v.id,
        'company_id': companyId,
        'name': v.name,
        'license_plate': v.licensePlate,
        'notes': v.notes,
        'next_inspection_date': date(v.nextInspectionDate),
        'active': v.active,
        'created_at': v.createdAt,
      });
    }
    for (final c in data.vehicleCosts) {
      await insert('vehicle_costs', {
        'id': c.id,
        'company_id': companyId,
        'vehicle_id': c.vehicleId,
        'cost_date': date(c.date),
        'amount_cents': c.amountCents,
        'category': c.category,
        'description': c.description,
        'principal_amount_cents': c.principalAmountCents,
        'interest_amount_cents': c.interestAmountCents,
        'project_id': c.projectId,
        'created_by_user_id': c.createdByUserId,
        'created_at': c.createdAt,
      });
    }
    for (final t in data.recurringTemplates) {
      await insert('recurring_templates', {
        'id': t.id,
        'company_id': companyId,
        'customer_id': t.customerId,
        'label': t.label,
        'recurrence_interval': t.interval,
        'next_due_date': date(t.nextDueDate),
        'payment_terms': t.paymentTerms,
        'notes': t.notes,
        'project_id': t.projectId,
        'active': t.active,
        'created_by_user_id': t.createdByUserId,
        'created_at': t.createdAt,
      });
    }
    for (final i in data.recurringItems) {
      await insert('recurring_template_items', itemRow(i, 'template_id'));
    }
    for (final c in data.expenseCategories) {
      await insert('expense_categories', {
        'id': c.id,
        'company_id': companyId,
        'label': c.label,
        'skr03_account': c.skr03Account,
        'created_at': c.createdAt,
      });
    }
    for (final e in data.expenses) {
      await insert('expenses', {
        'id': e.id,
        'company_id': companyId,
        'expense_date': date(e.date),
        'description': e.description,
        'amount_gross_cents': e.amountGrossCents,
        'vat_rate_percent': e.vatRatePercent,
        'category_id': e.categoryId,
        'supplier_reference': e.supplierReference,
        'project_id': e.projectId,
        'purchase_order_id': e.purchaseOrderId,
        'created_by_user_id': e.createdByUserId,
        'created_at': e.createdAt,
        'updated_at': e.updatedAt,
      });
    }
    for (final b in data.bankTransactions) {
      await insert('bank_transactions', {
        'id': b.id,
        'company_id': companyId,
        'transaction_date': date(b.date),
        'amount_cents': b.amountCents,
        'purpose': b.purpose,
        'counterparty': b.counterparty,
        'matched_document_id': b.matchedDocumentId,
        'import_hash': b.importHash,
        'imported_at': b.importedAt,
      });
    }
    for (final o in data.purchaseOrders) {
      await insert('purchase_orders', {
        'id': o.id,
        'company_id': companyId,
        'supplier_id': o.supplierId,
        'status': o.status,
        'number': o.number,
        'number_year': o.numberYear,
        'issue_date': date(o.issueDate),
        'notes': o.notes,
        'supplier_snapshot_name': o.supplierSnapshotName,
        'supplier_snapshot_address': o.supplierSnapshotAddress,
        'finalized_at': o.finalizedAt,
        'source_order_id': o.sourceOrderId,
        'project_id': o.projectId,
        'expense_category_id': o.expenseCategoryId,
        'created_by_user_id': o.createdByUserId,
        'created_at': o.createdAt,
        'updated_at': o.updatedAt,
        'version': o.version,
      });
    }
    for (final i in data.purchaseOrderItems) {
      await insert('purchase_order_items', {
        'id': i.id,
        'purchase_order_id': i.purchaseOrderId,
        'article_id': i.articleId,
        'description': i.description,
        'quantity': i.quantity,
        'purchase_price_cents': i.purchasePriceCents,
        'received_quantity': i.receivedQuantity,
        'sort_order': i.sortOrder,
      });
    }
    for (final m in data.stockMovements) {
      await insert('stock_movements', {
        'id': m.id,
        'company_id': companyId,
        'article_id': m.articleId,
        'type': m.type,
        'quantity_delta': m.quantityDelta,
        'resulting_quantity': m.resultingQuantity,
        'reference_label': m.referenceLabel,
        'note': m.note,
        'document_id': m.documentId,
        'created_by_user_id': m.createdByUserId,
        'created_at': m.createdAt,
      });
    }
    for (final c in data.inventoryCounts) {
      await insert('inventory_counts', {
        'id': c.id,
        'company_id': companyId,
        'label': c.label,
        'count_date': date(c.date),
        'status': c.status,
        'completed_at': c.completedAt,
        'created_at': c.createdAt,
      });
    }
    for (final i in data.inventoryItems) {
      await insert('inventory_count_items', {
        'id': i.id,
        'inventory_count_id': i.inventoryCountId,
        'article_id': i.articleId,
        'expected_quantity': i.expectedQuantity,
        'counted_quantity': i.countedQuantity,
        'counted_at': i.countedAt,
      });
    }
    for (final t in data.timeEntries) {
      await insert('time_entries', {
        'id': t.id,
        'company_id': companyId,
        'user_id': t.userId,
        'document_id': t.documentId,
        'work_date': date(t.workDate),
        'hours': t.hours,
        'note': t.note,
        'hourly_cost_cents': t.hourlyCostCents,
        'created_at': t.createdAt,
        'updated_at': t.updatedAt,
        'project_id': t.projectId,
        'staff_role_id': t.staffRoleId,
      });
    }
    // Nachfolger-Zettel verweisen auf ihren Vorgänger.
    final sheetsDone = <String>{};
    final sheetById = {for (final t in data.timeSheets) t.id: t};
    Future<void> insertSheet(TimeSheet t) async {
      if (!sheetsDone.add(t.id)) return;
      final previous = sheetById[t.supersedesId];
      if (previous != null) await insertSheet(previous);
      await insert('time_sheets', {
        'id': t.id,
        'company_id': companyId,
        'sheet_date': date(t.date),
        'document_id': t.documentId,
        'project_id': t.projectId,
        'status': t.status,
        'signature_png': t.signaturePng == null ? null : TypedValue(Type.byteArray, t.signaturePng),
        'signer_name': t.signerName,
        'signed_at': t.signedAt,
        'supersedes_id': t.supersedesId,
        'created_by_user_id': t.createdByUserId,
        'created_at': t.createdAt,
      });
    }

    for (final t in data.timeSheets) {
      await insertSheet(t);
    }
    for (final e in data.timeSheetEntries.entries) {
      for (final entryId in e.value) {
        await insert('time_sheet_entries', {'sheet_id': e.key, 'entry_id': entryId});
      }
    }
    for (final n in data.numberSequences) {
      await insert('number_sequences', {
        'company_id': companyId,
        'document_type': n.documentType,
        'year': n.year,
        'last_number': n.lastNumber,
      });
    }
    for (final e in data.settings.entries) {
      await s.execute(
        Sql.named(
          'INSERT INTO company_settings (company_id, section, settings) VALUES (@c, @section, @settings) '
          'ON CONFLICT (company_id, section) DO UPDATE SET settings = EXCLUDED.settings',
        ),
        parameters: {'c': companyId, 'section': e.key, 'settings': jsonEncode(e.value)},
      );
    }
  });

  Future<bool> _hasBusinessData(Session s, String companyId) async {
    final sql = _dataTables.map((t) => 'SELECT 1 FROM $t WHERE company_id = @companyId').join(' UNION ALL ');
    final result = await s.execute(Sql.named('$sql LIMIT 1'), parameters: {'companyId': companyId});
    return result.isNotEmpty;
  }
}
