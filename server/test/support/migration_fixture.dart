import 'dart:convert';

import 'package:werkkern_core/werkkern_core.dart';

/// 1×1-PNG als Unterschrift.
final migrationSignaturePng = base64Encode([
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, //
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89,
]);

/// Umzugspaket einer gefüllten Offline-Firma (alle Module) im laufenden
/// Jahr — so prüfen die Tests, dass die Nummernkreise nahtlos weiterlaufen.
Map<String, Object?> sampleMigrationPackage() {
  final year = DateTime.now().toUtc().year;
  final yy = (year % 100).toString().padLeft(2, '0');
  final at = '$year-01-05T08:00:00.000Z';
  return {
    'format': migrationPackageFormat,
    'formatVersion': migrationPackageVersion,
    'createdAt': '$year-02-01T10:00:00.000Z',
    'company': {
      'name': 'Elektro Kay (offline)',
      'address': 'Hauptstr. 1\n12345 Musterstadt',
      'taxNumber': '12/345/67890',
      'iban': 'DE02120300000000202051',
      'footerText': 'Danke für Ihren Auftrag.',
      'smallBusinessExempt': false,
      'documentTexts': {
        'invoice': {'intro': 'Wir berechnen:', 'closing': 'Zahlbar sofort.'},
      },
      'modules': [
        'quotes',
        'orders',
        'projects',
        'timeTracking',
        'lagerbestand',
        'bestellwesen',
        'buchhaltung',
        'dunning',
        'fleet',
        'recurringInvoices',
        'smtp',
      ],
    },
    'settings': {
      'dunning': {
        'reminder2AfterDays': 10,
        'reminder3AfterDays': 20,
        'feeLevel1Cents': 500,
        'feeLevel2Cents': 0,
        'feeLevel3Cents': 0,
        'interestRatePercent': 5.0,
      },
      'bankCsv': {'delimiter': ';', 'hasHeaderRow': true, 'dateFormat': 'dd.MM.yyyy', 'decimalSeparator': ','},
      'datev': {'beraterNummer': '1234', 'mandantNummer': '56', 'sachkontenlaenge': 4},
    },
    'numberSequences': [
      {'documentType': 'invoice', 'year': year, 'lastNumber': 3},
      {'documentType': 'order', 'year': year, 'lastNumber': 1},
      {'documentType': 'project', 'year': year, 'lastNumber': 1},
      {'documentType': 'purchaseOrder', 'year': year, 'lastNumber': 1},
    ],
    'customers': [
      {'id': 'c1', 'name': 'Meyer', 'address': 'Weg 2', 'email': 'meyer@example.com', 'createdAt': at},
    ],
    'suppliers': [
      {'id': 's1', 'name': 'Großhandel Nord', 'minimumOrderQuantity': '10', 'createdAt': at},
    ],
    'articleGroups': [
      {'id': 'g1', 'name': 'Kabel', 'markupPercent': 25.0, 'createdAt': at},
    ],
    'articles': [
      {
        'id': 'a1',
        'name': 'NYM 3x1,5',
        'unit': 'm',
        'articleGroupId': 'g1',
        'defaultSupplierId': 's1',
        'active': true,
        'stockQuantity': '7.5',
        'minimumStock': '5',
        'createdAt': at,
      },
      {'id': 'a2', 'name': 'Alte Dose', 'active': false, 'createdAt': at},
    ],
    'articlePrices': [
      {'articleId': 'a1', 'supplierId': 's1', 'purchasePriceCents': 120},
    ],
    'projects': [
      {
        'id': 'p1',
        'name': 'Neubau',
        'customerId': 'c1',
        'notes': 'Schlüssel beim Nachbarn',
        'status': 'active',
        'foundingYear': year,
        'projectNumber': 1,
        'createdAt': at,
      },
      {'id': 'p2', 'name': 'Altprojekt ohne Nummer', 'status': 'archived', 'createdAt': at},
    ],
    'documents': [
      // Die Rechnung steht bewusst vor ihrem Auftrag (Reihenfolge egal).
      {
        'id': 'd1',
        'customerId': 'c1',
        'kind': 'invoice',
        'status': 'finalized',
        'number': 'R-${yy}003',
        'numberYear': year,
        'issueDate': '$year-01-20',
        'serviceDate': '$year-01-18',
        'dueDate': '$year-02-03',
        'paymentTerms': '14 Tage',
        'customerSnapshotName': 'Meyer',
        'customerSnapshotAddress': 'Weg 2',
        'companySnapshotName': 'Elektro Kay',
        'companySnapshotAddress': 'Hauptstr. 1',
        'companySnapshotTaxNumber': '12/345/67890',
        'companySnapshotIban': 'DE02120300000000202051',
        'introTextSnapshot': 'Wir berechnen:',
        'closingTextSnapshot': 'Zahlbar sofort.',
        'footerTextSnapshot': 'Danke für Ihren Auftrag.',
        'smallBusinessExemptSnapshot': false,
        'finalizedAt': '$year-01-20T09:00:00.000Z',
        'createdAt': at,
        'updatedAt': '$year-01-20T09:00:00.000Z',
        'convertedFromId': 'o1',
        'projectId': 'p1',
        'stockBooked': true,
        'paymentStatus': 'paid',
        'paidAt': '$year-01-25T12:00:00.000Z',
        'items': [
          {
            'kind': 'article',
            'articleId': 'a1',
            'description': 'NYM 3x1,5',
            'quantity': '2.5',
            'unitPriceCents': 150,
            'vatRatePercent': 19.0,
            'unit': 'm',
            'sortOrder': 0,
          },
          {
            'kind': 'hours',
            'description': 'Montage',
            'quantity': '2',
            'unitPriceCents': 6500,
            'vatRatePercent': 19.0,
            'groupLabel': 'Arbeit',
            'sortOrder': 1,
          },
        ],
      },
      {
        'id': 'o1',
        'customerId': 'c1',
        'kind': 'order',
        'status': 'finalized',
        'number': 'A-${yy}001',
        'numberYear': year,
        'issueDate': '$year-01-10',
        'serviceDate': '$year-01-10',
        'customerSnapshotName': 'Meyer',
        'companySnapshotName': 'Elektro Kay',
        'finalizedAt': at,
        'createdAt': at,
        'updatedAt': at,
        'projectId': 'p1',
        'isFixedPrice': false,
        'items': [
          {
            'kind': 'hours',
            'description': 'Montage',
            'quantity': '2',
            'unitPriceCents': 6500,
            'vatRatePercent': 19.0,
            'sortOrder': 0,
          },
        ],
      },
      {
        'id': 'd2',
        'customerId': 'c1',
        'kind': 'invoice',
        'status': 'draft',
        'issueDate': '$year-02-01',
        'serviceDate': '$year-02-01',
        'createdAt': at,
        'updatedAt': at,
        'items': [
          {
            'kind': 'text',
            'description': 'Kleinmaterial',
            'quantity': '1',
            'unitPriceCents': 2000,
            'vatRatePercent': 19.0,
            'sortOrder': 0,
          },
        ],
      },
    ],
    'vehicles': [
      {
        'id': 'v1',
        'name': 'Caddy',
        'licensePlate': 'MD-K 1',
        'nextInspectionDate': '${year + 1}-03-01',
        'active': true,
        'createdAt': at,
      },
    ],
    'vehicleCosts': [
      {
        'vehicleId': 'v1',
        'date': '$year-01-15',
        'amountCents': 8000,
        'category': 'fuel',
        'projectId': 'p1',
        'createdAt': at,
      },
    ],
    'recurringTemplates': [
      {
        'id': 't1',
        'customerId': 'c1',
        'label': 'Wartung',
        'interval': 'monthly',
        'nextDueDate': '${year + 1}-01-01',
        'active': true,
        'createdAt': at,
        'items': [
          {
            'kind': 'text',
            'description': 'Wartungspauschale',
            'quantity': '1',
            'unitPriceCents': 5000,
            'vatRatePercent': 19.0,
            'sortOrder': 0,
          },
        ],
      },
    ],
    'expenseCategories': [
      {'id': 'e1', 'label': 'Material', 'skr03Account': '3400', 'createdAt': at},
    ],
    'expenses': [
      {
        'date': '$year-01-12',
        'description': 'Kabeltrommel',
        'amountGrossCents': 11900,
        'vatRatePercent': 19.0,
        'categoryId': 'e1',
        'projectId': 'p1',
        'createdAt': at,
        'updatedAt': at,
      },
    ],
    'bankTransactions': [
      {
        'date': '$year-01-25',
        'amountCents': 11053,
        'purpose': 'R-${yy}003',
        'counterparty': 'Meyer',
        'matchedDocumentId': 'd1',
        'importHash': 'h1',
        'importedAt': at,
      },
    ],
    'purchaseOrders': [
      {
        'id': 'po1',
        'supplierId': 's1',
        'status': 'fullyReceived',
        'number': 'B-${yy}001',
        'numberYear': year,
        'issueDate': '$year-01-08',
        'supplierSnapshotName': 'Großhandel Nord',
        'finalizedAt': at,
        'sourceOrderId': 'o1',
        'projectId': 'p1',
        'expenseCategoryId': 'e1',
        'createdAt': at,
        'updatedAt': at,
        'items': [
          {
            'articleId': 'a1',
            'description': 'NYM 3x1,5',
            'quantity': '10',
            'purchasePriceCents': 120,
            'receivedQuantity': '10',
          },
        ],
      },
    ],
    'stockMovements': [
      {
        'articleId': 'a1',
        'type': 'purchaseOrderReceipt',
        'quantityDelta': '10',
        'resultingQuantity': '10',
        'referenceLabel': 'B-${yy}001',
        'createdAt': at,
      },
      {
        'articleId': 'a1',
        'type': 'documentBooking',
        'quantityDelta': '-2.5',
        'resultingQuantity': '7.5',
        'referenceLabel': 'R-${yy}003',
        'createdAt': '$year-01-20T09:00:00.000Z',
      },
    ],
    'inventoryCounts': [
      {
        'id': 'i1',
        'label': 'Inventur Januar',
        'date': '$year-01-31',
        'status': 'completed',
        'completedAt': '$year-01-31T17:00:00.000Z',
        'createdAt': at,
        'items': [
          {
            'articleId': 'a1',
            'expectedQuantity': '7.5',
            'countedQuantity': '7.5',
            'countedAt': '$year-01-31T16:00:00.000Z',
          },
        ],
      },
    ],
    'staffRoles': [
      {'id': 'r1', 'name': 'Monteur', 'hourlyCostCents': 4500, 'createdAt': at},
      {'id': 'r2', 'name': 'Meister', 'hourlyCostCents': 6500, 'createdAt': at},
    ],
    'timeEntries': [
      {
        'date': '$year-01-18',
        'hours': '2',
        'staffRoleId': 'r1',
        'documentId': 'o1',
        'timeSheetId': 'ts1',
        'note': 'Montage',
        'createdAt': at,
      },
      {'date': '$year-01-19', 'hours': '1.5', 'projectId': 'p1', 'createdAt': at},
    ],
    'timeSheets': [
      {
        'id': 'ts1',
        'date': '$year-01-18',
        'documentId': 'o1',
        'status': 'signed',
        'signaturePng': migrationSignaturePng,
        'signedAt': '$year-01-18T17:00:00.000Z',
        'createdAt': at,
      },
    ],
  };
}
