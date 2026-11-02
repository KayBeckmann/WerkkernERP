import 'dart:convert';

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' show BooleanExpressionOperators, Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:werkkern_client/werkkern_client.dart';
import 'package:werkkern_core/werkkern_core.dart' show migrationNoRoleKey;
import 'package:werkkernerp/data/database/database.dart';
import 'package:werkkernerp/data/database/tables.dart';
import 'package:werkkernerp/data/migration/migration_package_builder.dart';
import 'package:werkkernerp/data/repositories/article_repository.dart';
import 'package:werkkernerp/data/repositories/company_repository.dart';
import 'package:werkkernerp/data/repositories/customer_repository.dart';
import 'package:werkkernerp/data/repositories/expense_repository.dart';
import 'package:werkkernerp/data/repositories/invoice_repository.dart';
import 'package:werkkernerp/data/repositories/number_sequence_repository.dart';
import 'package:werkkernerp/data/repositories/project_repository.dart';
import 'package:werkkernerp/data/repositories/purchase_order_repository.dart';
import 'package:werkkernerp/data/repositories/staff_role_repository.dart';
import 'package:werkkernerp/data/repositories/supplier_repository.dart';
import 'package:werkkernerp/data/repositories/time_entry_repository.dart';
import 'package:werkkernerp/domain/services/dashboard_service.dart';
import 'package:werkkernerp/domain/services/euer_service.dart';
import 'package:werkkernerp/domain/services/open_items_service.dart';
import 'package:werkkernerp/pdf/invoice_pdf_builder.dart';
import 'package:werkkernerp/pdf/online_document_pdf.dart';

import '../ui/online/online_test_server.dart';

/// B4.4 Abnahme: eine mit den echten Offline-Abläufen gefüllte Firma
/// (Auftrag mit Lagerbuchung → Rechnung, Abschlag, offene Rechnung mit
/// Fälligkeit, Zeiten mit/ohne Rolle, Beleg, Bestellung mit
/// Wareneingang) zieht um — online stimmen Summen, offene Posten, EÜR,
/// Bestand, Projektzahlen und PDFs (bis auf die zufällige Dokument-ID byte-gleich) mit offline überein,
/// und die nächste Nummer ist die Folgenummer.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Umzug einer gefüllten Offline-Firma: online identisch, Nummern laufen weiter', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory(setup: (d) => d.execute('PRAGMA foreign_keys = ON;')));
    addTearDown(db.close);
    final numbers = NumberSequenceRepository(db);
    final invoices = InvoiceRepository(db, numbers);
    final times = TimeEntryRepository(db);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // ---- Offline-Firma aufbauen ------------------------------------------
    var company = await CompanyRepository(db).create(name: 'Elektro Kay');
    company = company.copyWith(
      address: const Value('Hauptstr. 1\n12345 Musterstadt'),
      taxNumber: const Value('12/345/67890'),
      iban: const Value('DE02120300000000202051'),
      pdfIntroText: const Value('Wir berechnen Ihnen:'),
      pdfFooterText: const Value('Danke für Ihren Auftrag.'),
      ordersEnabled: true,
      projectsEnabled: true,
      timeTrackingEnabled: true,
      lagerbestandEnabled: true,
      bestellwesenEnabled: true,
      buchhaltungEnabled: true,
      dunningEnabled: true,
      advancePaymentInvoicesEnabled: true,
      dunningFeeLevel1Cents: 500,
    );
    await CompanyRepository(db).update(company);
    final companyId = company.id;
    final customer = await CustomerRepository(db).create(companyId: companyId, name: 'Meyer', address: 'Weg 2');
    final supplier = await SupplierRepository(db).create(companyId: companyId, name: 'Großhandel Nord');
    final articles = ArticleRepository(db);
    final cable = await articles.create(companyId: companyId, name: 'NYM 3x1,5', unit: 'm', manualSalePriceCents: 150);
    await articles.setSupplierPrice(
      companyId: companyId,
      articleId: cable.id,
      supplierId: supplier.id,
      purchasePriceCents: 90,
    );
    final project = await ProjectRepository(
      db,
      numbers,
    ).create(companyId: companyId, name: 'Neubau', customerId: customer.id);
    final monteur = await StaffRoleRepository(
      db,
    ).create(companyId: companyId, name: 'Monteur', hourlyCostRateCents: 4500);

    // Bestellung mit Wareneingang → Bestand 50 m.
    final orders = PurchaseOrderRepository(db, numbers);
    final po = await orders.createDraft(
      companyId: companyId,
      supplierId: supplier.id,
      issueDate: today,
      projectId: project.id,
      items: [
        PurchaseOrderItemInput(articleId: cable.id, description: 'NYM 3x1,5', quantity: 50, purchasePriceCents: 90),
      ],
    );
    await orders.finalize(companyId: companyId, id: po.id);
    final poItem = (await orders.itemsFor(po.id)).single;
    await orders.receiveGoods(companyId: companyId, id: po.id, receipts: {poItem.id: 50});

    // Auftrag (bucht Bestand), Zeiten, Abschlag, Schlussrechnung bezahlt.
    final order = await invoices.createDraft(
      companyId: companyId,
      customerId: customer.id,
      issueDate: today,
      serviceDate: today,
      kind: DocumentKind.order,
      projectId: project.id,
      items: [
        InvoiceItemInput(
          kind: InvoiceItemKind.article,
          articleId: cable.id,
          description: 'NYM 3x1,5',
          quantity: Decimal.parse('12.5'),
          unitPriceCents: 150,
          vatRatePercent: 19,
          unit: 'm',
          groupLabel: 'Material',
        ),
        InvoiceItemInput(
          kind: InvoiceItemKind.hours,
          description: 'Montage',
          quantity: Decimal.parse('3'),
          unitPriceCents: 6500,
          vatRatePercent: 19,
          discountPercent: 10,
          groupLabel: 'Arbeit',
        ),
      ],
    );
    await invoices.finalize(companyId: companyId, id: order.id);
    await times.create(companyId: companyId, date: today, hours: 2.5, staffRoleId: monteur.id, invoiceId: order.id);
    await times.create(companyId: companyId, date: today, hours: 1, projectId: project.id, note: 'Aufmaß');
    final advance = await invoices.createMaterialAdvanceDraft(
      companyId: companyId,
      sourceOrderId: order.id,
      includeAllArticles: true,
    );
    await invoices.finalize(companyId: companyId, id: advance.id);
    final finalInvoice = await invoices.convertTo(
      companyId: companyId,
      sourceId: order.id,
      targetKind: DocumentKind.invoice,
      timeEntryRepository: times,
    );
    await invoices.finalize(companyId: companyId, id: finalInvoice.id);
    await invoices.markPaid(companyId: companyId, id: finalInvoice.id);

    // Offene, überfällige Rechnung + Entwurf.
    final open = await invoices.createDraft(
      companyId: companyId,
      customerId: customer.id,
      issueDate: today,
      serviceDate: today,
      dueDate: today.subtract(const Duration(days: 20)),
      items: [
        InvoiceItemInput(
          kind: InvoiceItemKind.text,
          description: 'Prüfung E-Check',
          quantity: Decimal.one,
          unitPriceCents: 8900,
          vatRatePercent: 19,
        ),
      ],
    );
    await invoices.finalize(companyId: companyId, id: open.id);
    await invoices.createDraft(companyId: companyId, customerId: customer.id, issueDate: today, serviceDate: today);
    await ExpenseRepository(db).create(
      companyId: companyId,
      date: today,
      description: 'Kabeltrommel',
      amountGrossCents: 11900,
      vatRatePercent: 19,
      projectId: project.id,
    );

    // ---- Umziehen ----------------------------------------------------------
    final package = await MigrationPackageBuilder(db).build(companyId);
    final server = OnlineTestServer();
    final client = server.client()
      ..token = await server.seedCompany(
        email: 'kay@example.com',
        companyName: 'Elektro Kay GmbH',
        permissions: [
          'customers.read',
          'customers.write',
          'articles.read',
          'invoices.read',
          'invoices.write',
          'invoices.finalize',
          'invoices.payment',
          'projects.read',
          'timeTracking.read',
          'accounting.read',
          'stock.read',
          'purchaseOrders.read',
        ],
      );
    final me = (await client.members()).single.id;
    final dry = await client.importCompany(package, dryRun: true);
    expect(dry.errors, isEmpty);
    expect(dry.missingAssignments, unorderedEquals([monteur.id, migrationNoRoleKey]));
    await client.importCompany(package, roleAssignments: {monteur.id: me, migrationNoRoleKey: me});

    // ---- Vergleich -----------------------------------------------------------
    company = (await CompanyRepository(db).findById(companyId))!;
    final offlineDocs = await (db.select(db.invoices)..where((i) => i.companyId.equals(companyId))).get();
    final onlineDocs = await client.documents();
    expect(onlineDocs, hasLength(offlineDocs.length));

    for (final offline in offlineDocs.where((d) => d.status == InvoiceStatus.finalized)) {
      final online = await client.document(onlineDocs.firstWhere((d) => d.number == offline.invoiceNumber).id);
      final totals = await invoices.totalsFor(offline.id);
      expect(online.grossCents, totals.totalGross.cents, reason: '${offline.invoiceNumber}: Bruttosumme');
      expect(online.paymentStatus, offline.paymentStatus.name);
      expect(online.dueDate == null, offline.dueDate == null);

      final advances =
          offline.kind == DocumentKind.invoice && !offline.isAdvancePayment && offline.convertedFromId != null
          ? await invoices.listAdvancePaymentsForOrder(offline.convertedFromId!)
          : const <AdvancePaymentEntry>[];
      final offlinePdf = await buildInvoicePdf(
        invoice: offline,
        items: await invoices.itemsFor(offline.id),
        company: company,
        priorAdvancePayments: advances,
      );
      final onlinePdf = await buildOnlineDocumentPdf(online);
      expect(
        _withoutDocumentId(onlinePdf),
        _withoutDocumentId(offlinePdf),
        reason: '${offline.invoiceNumber}: PDF gleich',
      );
    }

    // Offene Posten nach derselben Regel wie der Offline-Bildschirm
    // (überfällige Rechnung + noch offene Abschlagsrechnung).
    var offlineOpenCents = 0;
    for (final d in offlineDocs.where(isOpenItem)) {
      offlineOpenCents += (await invoices.totalsFor(d.id)).totalGross.cents;
    }
    expect(offlineOpenCents, greaterThan((await invoices.totalsFor(open.id)).totalGross.cents));
    expect((await client.openItems()).totalCents, offlineOpenCents);

    // EÜR im laufenden Jahr.
    final finalizedWithGross = [
      for (final d in offlineDocs.where((d) => d.status == InvoiceStatus.finalized))
        InvoiceWithGross(invoice: d, gross: (await invoices.totalsFor(d.id)).totalGross),
    ];
    final yearStart = DateTime(now.year);
    final yearEnd = DateTime(now.year, 12, 31);
    final offlineEuer = computeEuerSummary(
      allFinalizedInvoices: finalizedWithGross,
      allExpenses: await (db.select(db.expenses)..where((e) => e.companyId.equals(companyId))).get(),
      categoryById: const {},
      periodStart: yearStart,
      periodEnd: yearEnd,
    );
    final onlineEuer = await client.euer(from: yearStart, to: yearEnd);
    expect(onlineEuer.incomeCents, offlineEuer.totalIncome.cents);
    expect(onlineEuer.expensesCents, offlineEuer.totalExpenses.cents);

    // Bestand: 50 eingegangen − 12,5 gebucht.
    final offlineCable = (await articles.findById(companyId: companyId, id: cable.id))!;
    expect(offlineCable.stockQuantity, 37.5);
    final onlineCable = (await client.articles()).single;
    expect(onlineCable.stockQuantity, '37.5');

    // Projekt: gebuchte Stunden + Stundenkosten wie offline.
    final onlineProject = (await client.projects()).single;
    expect(onlineProject.displayNumber, project.foundingYear == null ? isNotNull : endsWith('/01'));
    final detail = await client.projectDetail(onlineProject.id);
    expect(
      Decimal.parse(detail.bookedHours!),
      Decimal.parse((await times.totalHoursForProject(companyId: companyId, projectId: project.id)).toString()),
    );
    expect(detail.hoursCostCents, (await times.totalCostForProject(companyId: companyId, projectId: project.id)).cents);

    // Nächste Rechnung online = Offline-Folgenummer.
    final lastInvoice = (await (db.select(
      db.numberSequences,
    )..where((s) => s.companyId.equals(companyId) & s.documentType.equals('invoice'))).getSingle()).lastNumber;
    final onlineCustomer = (await client.customers()).single;
    final next = await client.createDocument(
      customerId: onlineCustomer.id,
      items: const [
        OnlineDocumentItem(
          kind: OnlineItemKind.text,
          description: 'Nach dem Umzug',
          quantity: '1',
          unitPriceCents: 100,
          vatRatePercent: 19,
        ),
      ],
    );
    final finalized = await client.finalizeDocument(next.id, version: next.version);
    final yy = (now.year % 100).toString().padLeft(2, '0');
    expect(finalized.number, 'R-$yy${(lastInvoice + 1).toString().padLeft(3, '0')}');
  });
}

/// Das pdf-Paket vergibt je Rendern eine zufällige Dokument-ID im
/// Trailer — alles andere muss byte-gleich sein.
String _withoutDocumentId(List<int> pdf) =>
    latin1.decode(pdf).replaceAll(RegExp(r'/ID\[<[0-9a-f]+><[0-9a-f]+>\]'), '/ID[]');
