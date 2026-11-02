/// B4 — Umzug Einzelplatz → Online-Firma. Liest das Umzugspaket der
/// Offline-App (`migrationPackageFormat`) in Server-Modelle ein: IDs
/// werden neu vergeben (ein Probe-/Fehlimport in eine andere Firma kann
/// so nie kollidieren), alle Verweise umgeschrieben und geprüft.
/// Finalisierte Dokumente kommen **unverändert** an (Nummer, Datum,
/// Schnappschüsse, Zahlstatus) — der Server vergibt nichts neu (GoBD).
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:decimal/decimal.dart';
import 'package:werkkern_core/werkkern_core.dart';

import 'accounting.dart';
import 'fleet.dart';
import 'models.dart';
import 'purchasing.dart';
import 'recurring.dart';
import 'staff_roles.dart';
import 'stock.dart';
import 'suppliers.dart';
import 'timesheets.dart';

/// Fertig umgeschriebene Fachdaten einer Firma — wird in **einer**
/// Transaktion geschrieben ([CompanyImportStore.importCompanyData]).
class CompanyImportData {
  final customers = <Customer>[];
  final suppliers = <Supplier>[];
  final articleGroups = <ArticleGroup>[];
  final articles = <Article>[];
  final articlePrices = <ArticleSupplierPrice>[];
  final projects = <Project>[];
  final documents = <Document>[];
  final documentItems = <DocumentItem>[];
  final vehicles = <Vehicle>[];
  final vehicleCosts = <VehicleCostEntry>[];
  final recurringTemplates = <RecurringTemplate>[];
  final recurringItems = <DocumentItem>[];
  final expenseCategories = <ExpenseCategory>[];
  final expenses = <Expense>[];
  final bankTransactions = <BankTransaction>[];
  final purchaseOrders = <PurchaseOrder>[];
  final purchaseOrderItems = <PurchaseOrderItem>[];
  final stockMovements = <StockMovement>[];
  final inventoryCounts = <InventoryCount>[];
  final inventoryItems = <InventoryCountItem>[];
  final staffRoles = <StaffRole>[];
  final timeEntries = <TimeEntry>[];
  final timeSheets = <TimeSheet>[];

  /// Stundenzettel-ID → zugeordnete Zeitbuchungen.
  final timeSheetEntries = <String, List<String>>{};

  /// Nummernkreise wie offline (`documentType` = Dokumentart, `project`,
  /// `purchaseOrder`) — der Server zählt danach nahtlos weiter.
  final numberSequences = <({String documentType, int year, int lastNumber})>[];

  /// Einstellungsabschnitte (`dunning`, `bankCsv`, `datev`) und das
  /// Umzugs-Kennzeichen `import`.
  final settings = <String, Map<String, Object?>>{};

  Map<String, int> get counts => {
    'customers': customers.length,
    'suppliers': suppliers.length,
    'articleGroups': articleGroups.length,
    'articles': articles.length,
    'articlePrices': articlePrices.length,
    'projects': projects.length,
    'documents': documents.length,
    'vehicles': vehicles.length,
    'vehicleCosts': vehicleCosts.length,
    'recurringTemplates': recurringTemplates.length,
    'expenseCategories': expenseCategories.length,
    'expenses': expenses.length,
    'bankTransactions': bankTransactions.length,
    'purchaseOrders': purchaseOrders.length,
    'stockMovements': stockMovements.length,
    'inventoryCounts': inventoryCounts.length,
    'staffRoles': staffRoles.length,
    'timeEntries': timeEntries.length,
    'timeSheets': timeSheets.length,
  };
}

abstract interface class CompanyImportStore {
  /// `true`, sobald die Firma Fachdaten hat. Rollen und Belegkategorien
  /// zählen nicht (Vorschläge, die der Import ersetzt).
  Future<bool> companyHasBusinessData(String companyId);

  /// Schreibt [data] alles-oder-nichts; ersetzt vorhandene Rollen und
  /// Belegkategorien.
  Future<void> importCompanyData(String companyId, CompanyImportData data);
}

/// Firmenprofil und Module aus dem Paket — liegen im Plattform-Repository
/// und werden nach den Fachdaten gesetzt.
class CompanyImportProfile {
  const CompanyImportProfile({
    this.address,
    this.taxNumber,
    this.vatId,
    this.iban,
    this.email,
    this.phone,
    this.footerText,
    this.documentTexts = const {},
    this.smallBusinessExempt = false,
    this.modules = const {},
  });
  final String? address;
  final String? taxNumber;
  final String? vatId;
  final String? iban;
  final String? email;
  final String? phone;
  final String? footerText;
  final Map<String, ({String? intro, String? closing})> documentTexts;
  final bool smallBusinessExempt;
  final Set<String> modules;
}

/// Eine Rolle aus dem Paket mit Zahl der Zeitbuchungen — für die
/// Zuordnung im Umzugsassistenten. [id] ist die Offline-ID bzw.
/// [migrationNoRoleKey] für Buchungen ohne Rolle.
typedef ImportRoleUsage = ({String id, String name, int timeEntries});

/// Ergebnis des Einlesens. [errors] nicht leer → Paket wird abgewiesen.
class ParsedCompanyImport {
  ParsedCompanyImport(this.data, this.profile);
  final CompanyImportData data;
  final CompanyImportProfile profile;
  final errors = <String>[];
  final warnings = <String>[];

  /// Rollen (inkl. „ohne Rolle“), auf die Zeiten oder Stundenzettel
  /// gebucht sind — jede braucht ein Mitglied.
  final roles = <ImportRoleUsage>[];
  final missingAssignments = <String>[];
}

const _settingsSections = {
  'dunning': {
    'reminder2AfterDays',
    'reminder3AfterDays',
    'feeLevel1Cents',
    'feeLevel2Cents',
    'feeLevel3Cents',
    'interestRatePercent',
    'introText',
    'closingText',
  },
  'bankCsv': {
    'delimiter',
    'hasHeaderRow',
    'dateColumn',
    'amountColumn',
    'purposeColumn',
    'counterpartyColumn',
    'dateFormat',
    'decimalSeparator',
  },
  'datev': {'beraterNummer', 'mandantNummer', 'bankGegenkonto', 'sachkontenlaenge'},
};

/// Module, die ein Umzug setzen darf (`smtp` nicht: das Passwort liegt
/// nur im Gerät, der Versand muss online neu eingerichtet werden).
const _importableModules = {
  'quotes',
  'orders',
  'deliveryNotes',
  'proforma',
  'creditNotes',
  'advancePaymentInvoices',
  'projects',
  'fleet',
  'recurringInvoices',
  'dunning',
  'buchhaltung',
  'lagerbestand',
  'bestellwesen',
  'timeTracking',
};

/// Liest [package] für [companyId] ein. [roleAssignments]: Offline-Rollen-ID
/// (bzw. [migrationNoRoleKey]) → Nutzer-ID eines aktiven Mitglieds aus
/// [memberUserIds]. Fehlende Zuordnungen landen in
/// [ParsedCompanyImport.missingAssignments] (der Probelauf zeigt sie, der
/// echte Import lehnt ab). [userId] ist der importierende Admin.
ParsedCompanyImport parseCompanyImport(
  Map<String, Object?> package, {
  required String companyId,
  required String userId,
  required Map<String, String> roleAssignments,
  required Set<String> memberUserIds,
  required String Function() newId,
  required DateTime now,
}) {
  final parser = _Parser(companyId, userId, newId, now);
  try {
    parser.parse(package, roleAssignments, memberUserIds);
  } on _Invalid catch (e) {
    parser.result.errors.add(e.message);
  }
  return parser.result;
}

class _Invalid implements Exception {
  const _Invalid(this.message);
  final String message;
}

class _Parser {
  _Parser(this.companyId, this.userId, this.newId, this.now)
    : result = ParsedCompanyImport(CompanyImportData(), const CompanyImportProfile());

  final String companyId;
  final String userId;
  final String Function() newId;
  final DateTime now;
  ParsedCompanyImport result;
  CompanyImportData get data => result.data;

  /// Offline-ID → neue ID, je Entitätsart.
  final _ids = <String, Map<String, String>>{};

  String _assign(String type, String oldId, String path) {
    final byType = _ids.putIfAbsent(type, () => {});
    if (byType.containsKey(oldId)) throw _Invalid('$path: doppelte ID $oldId.');
    return byType[oldId] = newId();
  }

  /// Neue ID zum Verweis [oldId]; unbekannt → Fehler (null bleibt null).
  String? _ref(String type, String? oldId, String path) {
    if (oldId == null) return null;
    final id = _ids[type]?[oldId];
    if (id == null) result.errors.add('$path: Verweis auf unbekannte(n) $type $oldId.');
    return id;
  }

  void parse(Map<String, Object?> p, Map<String, String> roleAssignments, Set<String> memberUserIds) {
    if (p['format'] != migrationPackageFormat) throw const _Invalid('Keine WerkkernERP-Umzugsdatei.');
    final version = p['formatVersion'];
    if (version != migrationPackageVersion) {
      throw _Invalid(
        'Umzugsformat $version wird nicht unterstützt (erwartet $migrationPackageVersion) — '
        'bitte App und Server auf denselben Stand bringen.',
      );
    }
    _company(_map(p['company'], 'company'));
    _settings(p['settings'] == null ? const {} : _map(p['settings'], 'settings'));

    for (final (i, s) in _list(p, 'numberSequences')) {
      final r = _R(s, 'numberSequences[$i]');
      data.numberSequences.add((
        documentType: r.str('documentType'),
        year: r.integer('year'),
        lastNumber: r.integer('lastNumber'),
      ));
    }
    for (final (i, c) in _list(p, 'customers')) {
      final r = _R(c, 'customers[$i]');
      data.customers.add(
        Customer(
          id: _assign('customer', r.str('id'), r.path),
          companyId: companyId,
          name: r.str('name'),
          address: r.optStr('address'),
          email: r.optStr('email'),
          phone: r.optStr('phone'),
          vatId: r.optStr('vatId'),
          contactPerson: r.optStr('contactPerson'),
          notes: r.optStr('notes'),
          createdAt: r.time('createdAt'),
        ),
      );
    }
    for (final (i, s) in _list(p, 'suppliers')) {
      final r = _R(s, 'suppliers[$i]');
      data.suppliers.add(
        Supplier(
          id: _assign('supplier', r.str('id'), r.path),
          companyId: companyId,
          name: r.str('name'),
          address: r.optStr('address'),
          email: r.optStr('email'),
          phone: r.optStr('phone'),
          vatId: r.optStr('vatId'),
          contactPerson: r.optStr('contactPerson'),
          notes: r.optStr('notes'),
          minimumOrderQuantity: r.optDecimal('minimumOrderQuantity'),
          deliveryTerms: r.optStr('deliveryTerms'),
          createdAt: r.time('createdAt'),
        ),
      );
    }
    for (final (i, g) in _list(p, 'articleGroups')) {
      final r = _R(g, 'articleGroups[$i]');
      data.articleGroups.add(
        ArticleGroup(
          id: _assign('articleGroup', r.str('id'), r.path),
          companyId: companyId,
          name: r.str('name'),
          markupPercent: r.number('markupPercent'),
          createdAt: r.time('createdAt'),
        ),
      );
    }
    for (final (i, a) in _list(p, 'articles')) {
      final r = _R(a, 'articles[$i]');
      data.articles.add(
        Article(
          id: _assign('article', r.str('id'), r.path),
          companyId: companyId,
          name: r.str('name'),
          unit: r.optStr('unit'),
          salePriceCents: r.optInt('salePriceCents'),
          active: r.boolean('active', fallback: true),
          createdAt: r.time('createdAt'),
          articleGroupId: _ref('articleGroup', r.optStr('articleGroupId'), r.path),
          defaultSupplierId: _ref('supplier', r.optStr('defaultSupplierId'), r.path),
          stockQuantity: r.optDecimal('stockQuantity') ?? '0',
          minimumStock: r.optDecimal('minimumStock'),
        ),
      );
    }
    for (final (i, a) in _list(p, 'articlePrices')) {
      final r = _R(a, 'articlePrices[$i]');
      final articleId = _ref('article', r.str('articleId'), r.path);
      final supplierId = _ref('supplier', r.str('supplierId'), r.path);
      if (articleId == null || supplierId == null) continue;
      data.articlePrices.add(
        ArticleSupplierPrice(
          articleId: articleId,
          supplierId: supplierId,
          purchasePriceCents: r.integer('purchasePriceCents'),
        ),
      );
    }
    _projects(_list(p, 'projects'));
    _documents(_list(p, 'documents'));
    _fleet(_list(p, 'vehicles'), _list(p, 'vehicleCosts'));
    _recurring(_list(p, 'recurringTemplates'));
    _accounting(_list(p, 'expenseCategories'), _list(p, 'expenses'), _list(p, 'bankTransactions'));
    _purchasing(_list(p, 'purchaseOrders'));
    _stock(_list(p, 'stockMovements'), _list(p, 'inventoryCounts'));
    _time(_list(p, 'staffRoles'), _list(p, 'timeEntries'), _list(p, 'timeSheets'), roleAssignments, memberUserIds);
    _checkNumbers();

    data.settings['import'] = {
      'importedAt': now.toIso8601String(),
      'importedByUserId': userId,
      'formatVersion': migrationPackageVersion,
      'sourceCreatedAt': p['createdAt'],
    };
  }

  void _company(Map<String, Object?> c) {
    final r = _R(c, 'company');
    final texts = <String, ({String? intro, String? closing})>{};
    final rawTexts = c['documentTexts'];
    if (rawTexts is Map<String, Object?>) {
      for (final e in rawTexts.entries) {
        if (!documentKindModules.containsKey(e.key)) continue;
        final t = _R(_map(e.value, 'company.documentTexts.${e.key}'), 'company.documentTexts.${e.key}');
        texts[e.key] = (intro: t.optStr('intro'), closing: t.optStr('closing'));
      }
    }
    final modules = <String>{};
    for (final m in (c['modules'] as List<Object?>? ?? const [])) {
      if (m is String && _importableModules.contains(m)) modules.add(m);
    }
    if ((c['modules'] as List<Object?>? ?? const []).contains('smtp')) {
      result.warnings.add(
        'E-Mail-Versand (SMTP) wird nicht übernommen — online unter Einstellungen → Versand neu einrichten.',
      );
    }
    result = ParsedCompanyImport(
      data,
      CompanyImportProfile(
        address: r.optStr('address'),
        taxNumber: r.optStr('taxNumber'),
        vatId: r.optStr('vatId'),
        iban: r.optStr('iban'),
        email: r.optStr('email'),
        phone: r.optStr('phone'),
        footerText: r.optStr('footerText'),
        documentTexts: texts,
        smallBusinessExempt: r.boolean('smallBusinessExempt', fallback: false),
        modules: modules,
      ),
    )..warnings.addAll(result.warnings);
  }

  void _settings(Map<String, Object?> s) {
    for (final e in _settingsSections.entries) {
      final raw = s[e.key];
      if (raw == null) continue;
      final section = _map(raw, 'settings.${e.key}');
      data.settings[e.key] = {
        for (final key in e.value)
          if (section[key] != null) key: section[key],
      };
    }
  }

  void _projects(List<(int, Map<String, Object?>)> projects) {
    for (final (i, pr) in projects) {
      final r = _R(pr, 'projects[$i]');
      final created = r.time('createdAt');
      final status = r.str('status');
      if (!{'active', 'archived'}.contains(status)) throw _Invalid('${r.path}: unbekannter Status $status.');
      data.projects.add(
        Project(
          id: _assign('project', r.str('id'), r.path),
          companyId: companyId,
          name: r.str('name'),
          customerId: _ref('customer', r.optStr('customerId'), r.path),
          notes: r.optStr('notes'),
          status: status,
          // Ältere Offline-Projekte ohne Nummer bekommen das Anlagejahr
          // und eine Nummer hinter dem höchsten Stand (siehe _checkNumbers).
          foundingYear: r.optInt('foundingYear') ?? created.year,
          projectNumber: r.optInt('projectNumber') ?? 0,
          createdAt: created,
        ),
      );
    }
  }

  void _documents(List<(int, Map<String, Object?>)> documents) {
    // Erst alle IDs vergeben — Umwandlungsquellen dürfen in beliebiger
    // Reihenfolge stehen.
    for (final (i, d) in documents) {
      _assign('document', _R(d, 'documents[$i]').str('id'), 'documents[$i]');
    }
    for (final (i, d) in documents) {
      final r = _R(d, 'documents[$i]');
      final id = _ids['document']![r.str('id')]!;
      final kind = r.str('kind');
      final status = r.str('status');
      if (!documentKindModules.containsKey(kind)) throw _Invalid('${r.path}: unbekannte Dokumentart $kind.');
      if (!documentStatuses.contains(status)) throw _Invalid('${r.path}: unbekannter Status $status.');
      final finalized = status == 'finalized';
      if (finalized && (r.optStr('number') == null || r.optInt('numberYear') == null)) {
        result.errors.add('${r.path}: finalisiertes Dokument ohne Nummer.');
      }
      final paymentStatus = r.optStr('paymentStatus') ?? 'open';
      if (!{'open', 'paid'}.contains(paymentStatus)) throw _Invalid('${r.path}: unbekannter Zahlstatus.');
      final customerId = _ref('customer', r.str('customerId'), r.path);
      data.documents.add(
        Document(
          id: id,
          companyId: companyId,
          customerId: customerId ?? '',
          kind: kind,
          status: status,
          number: finalized ? r.optStr('number') : null,
          numberYear: finalized ? r.optInt('numberYear') : null,
          issueDate: r.date('issueDate'),
          serviceDate: r.date('serviceDate'),
          paymentTerms: r.optStr('paymentTerms'),
          notes: r.optStr('notes'),
          customerSnapshotName: r.optStr('customerSnapshotName'),
          customerSnapshotAddress: r.optStr('customerSnapshotAddress'),
          customerSnapshotVatId: r.optStr('customerSnapshotVatId'),
          companySnapshotName: r.optStr('companySnapshotName'),
          companySnapshotAddress: r.optStr('companySnapshotAddress'),
          companySnapshotTaxNumber: r.optStr('companySnapshotTaxNumber'),
          companySnapshotVatId: r.optStr('companySnapshotVatId'),
          companySnapshotIban: r.optStr('companySnapshotIban'),
          createdByUserId: userId,
          createdAt: r.time('createdAt'),
          updatedAt: r.time('updatedAt'),
          finalizedAt: r.optTime('finalizedAt'),
          version: 1,
          convertedFromId: _ref('document', r.optStr('convertedFromId'), r.path),
          paymentStatus: paymentStatus,
          paidAt: r.optTime('paidAt'),
          dueDate: r.optDate('dueDate'),
          projectId: _ref('project', r.optStr('projectId'), r.path),
          isAdvancePayment: r.boolean('isAdvancePayment', fallback: false),
          isFixedPrice: r.boolean('isFixedPrice', fallback: false),
          introTextSnapshot: r.optStr('introTextSnapshot'),
          closingTextSnapshot: r.optStr('closingTextSnapshot'),
          footerTextSnapshot: r.optStr('footerTextSnapshot'),
          smallBusinessExemptSnapshot: r.boolean('smallBusinessExemptSnapshot', fallback: false),
          stockBooked: r.boolean('stockBooked', fallback: false),
        ),
      );
      data.documentItems.addAll(_items(d['items'], '${r.path}.items', id));
    }
  }

  List<DocumentItem> _items(Object? raw, String path, String ownerId) => [
    for (final (i, item) in _listOf(raw, path))
      () {
        final r = _R(item, '$path[$i]');
        final kind = r.str('kind');
        if (!itemKinds.contains(kind)) throw _Invalid('${r.path}: unbekannte Positionsart $kind.');
        return DocumentItem(
          id: newId(),
          documentId: ownerId,
          kind: kind,
          articleId: _ref('article', r.optStr('articleId'), r.path),
          description: r.str('description', allowEmpty: true),
          quantity: r.decimal('quantity'),
          unitPriceCents: r.integer('unitPriceCents'),
          vatRatePercent: r.number('vatRatePercent'),
          unit: r.optStr('unit'),
          discountPercent: r.optNumber('discountPercent') ?? 0,
          groupLabel: r.optStr('groupLabel'),
          sortOrder: r.optInt('sortOrder') ?? i,
        );
      }(),
  ];

  void _fleet(List<(int, Map<String, Object?>)> vehicles, List<(int, Map<String, Object?>)> costs) {
    for (final (i, v) in vehicles) {
      final r = _R(v, 'vehicles[$i]');
      data.vehicles.add(
        Vehicle(
          id: _assign('vehicle', r.str('id'), r.path),
          companyId: companyId,
          name: r.str('name'),
          licensePlate: r.optStr('licensePlate'),
          notes: r.optStr('notes'),
          nextInspectionDate: r.optDate('nextInspectionDate'),
          active: r.boolean('active', fallback: true),
          createdAt: r.time('createdAt'),
        ),
      );
    }
    for (final (i, c) in costs) {
      final r = _R(c, 'vehicleCosts[$i]');
      final category = r.str('category');
      if (!vehicleCostCategories.contains(category)) throw _Invalid('${r.path}: unbekannte Kostenart $category.');
      data.vehicleCosts.add(
        VehicleCostEntry(
          id: newId(),
          companyId: companyId,
          vehicleId: _ref('vehicle', r.str('vehicleId'), r.path) ?? '',
          date: r.date('date'),
          amountCents: r.integer('amountCents'),
          category: category,
          description: r.optStr('description'),
          principalAmountCents: r.optInt('principalAmountCents'),
          interestAmountCents: r.optInt('interestAmountCents'),
          projectId: _ref('project', r.optStr('projectId'), r.path),
          createdByUserId: userId,
          createdAt: r.time('createdAt'),
        ),
      );
    }
  }

  void _recurring(List<(int, Map<String, Object?>)> templates) {
    for (final (i, t) in templates) {
      final r = _R(t, 'recurringTemplates[$i]');
      final interval = r.str('interval');
      if (!recurrenceIntervals.contains(interval)) throw _Invalid('${r.path}: unbekannter Rhythmus $interval.');
      final id = _assign('recurringTemplate', r.str('id'), r.path);
      data.recurringTemplates.add(
        RecurringTemplate(
          id: id,
          companyId: companyId,
          customerId: _ref('customer', r.str('customerId'), r.path) ?? '',
          label: r.str('label'),
          interval: interval,
          nextDueDate: r.date('nextDueDate'),
          paymentTerms: r.optStr('paymentTerms'),
          notes: r.optStr('notes'),
          active: r.boolean('active', fallback: true),
          createdByUserId: userId,
          createdAt: r.time('createdAt'),
        ),
      );
      data.recurringItems.addAll(_items(t['items'], '${r.path}.items', id));
    }
  }

  void _accounting(
    List<(int, Map<String, Object?>)> categories,
    List<(int, Map<String, Object?>)> expenses,
    List<(int, Map<String, Object?>)> bank,
  ) {
    for (final (i, c) in categories) {
      final r = _R(c, 'expenseCategories[$i]');
      data.expenseCategories.add(
        ExpenseCategory(
          id: _assign('expenseCategory', r.str('id'), r.path),
          companyId: companyId,
          label: r.str('label'),
          skr03Account: r.optStr('skr03Account'),
          createdAt: r.time('createdAt'),
        ),
      );
    }
    for (final (i, e) in expenses) {
      final r = _R(e, 'expenses[$i]');
      data.expenses.add(
        Expense(
          id: newId(),
          companyId: companyId,
          date: r.date('date'),
          description: r.str('description'),
          amountGrossCents: r.integer('amountGrossCents'),
          vatRatePercent: r.number('vatRatePercent'),
          categoryId: _ref('expenseCategory', r.optStr('categoryId'), r.path),
          supplierReference: r.optStr('supplierReference'),
          projectId: _ref('project', r.optStr('projectId'), r.path),
          createdByUserId: userId,
          createdAt: r.time('createdAt'),
          updatedAt: r.time('updatedAt'),
        ),
      );
    }
    final hashes = <String>{};
    for (final (i, b) in bank) {
      final r = _R(b, 'bankTransactions[$i]');
      final hash = r.str('importHash');
      // Offline ist der Hash je Firma eindeutig — doppelte überspringen.
      if (!hashes.add(hash)) continue;
      data.bankTransactions.add(
        BankTransaction(
          id: newId(),
          companyId: companyId,
          date: r.date('date'),
          amountCents: r.integer('amountCents'),
          purpose: r.optStr('purpose'),
          counterparty: r.optStr('counterparty'),
          matchedDocumentId: _ref('document', r.optStr('matchedDocumentId'), r.path),
          importHash: hash,
          importedAt: r.time('importedAt'),
        ),
      );
    }
  }

  void _purchasing(List<(int, Map<String, Object?>)> orders) {
    const statuses = {'draft', 'finalized', 'partiallyReceived', 'fullyReceived'};
    for (final (i, o) in orders) {
      final r = _R(o, 'purchaseOrders[$i]');
      final status = r.str('status');
      if (!statuses.contains(status)) throw _Invalid('${r.path}: unbekannter Status $status.');
      final id = _assign('purchaseOrder', r.str('id'), r.path);
      final draft = status == 'draft';
      if (!draft && r.optStr('number') == null) result.errors.add('${r.path}: finalisierte Bestellung ohne Nummer.');
      data.purchaseOrders.add(
        PurchaseOrder(
          id: id,
          companyId: companyId,
          supplierId: _ref('supplier', r.str('supplierId'), r.path) ?? '',
          status: status,
          number: draft ? null : r.optStr('number'),
          numberYear: draft ? null : r.optInt('numberYear'),
          issueDate: r.date('issueDate'),
          notes: r.optStr('notes'),
          supplierSnapshotName: r.optStr('supplierSnapshotName'),
          supplierSnapshotAddress: r.optStr('supplierSnapshotAddress'),
          finalizedAt: r.optTime('finalizedAt'),
          sourceOrderId: _ref('document', r.optStr('sourceOrderId'), r.path),
          projectId: _ref('project', r.optStr('projectId'), r.path),
          expenseCategoryId: _ref('expenseCategory', r.optStr('expenseCategoryId'), r.path),
          createdByUserId: userId,
          createdAt: r.time('createdAt'),
          updatedAt: r.time('updatedAt'),
          version: 1,
        ),
      );
      for (final (j, item) in _listOf(o['items'], '${r.path}.items')) {
        final ir = _R(item, '${r.path}.items[$j]');
        data.purchaseOrderItems.add(
          PurchaseOrderItem(
            id: newId(),
            purchaseOrderId: id,
            articleId: _ref('article', ir.optStr('articleId'), ir.path),
            description: ir.str('description', allowEmpty: true),
            quantity: ir.decimal('quantity'),
            purchasePriceCents: ir.optInt('purchasePriceCents'),
            receivedQuantity: ir.optDecimal('receivedQuantity') ?? '0',
            sortOrder: ir.optInt('sortOrder') ?? j,
          ),
        );
      }
    }
  }

  void _stock(List<(int, Map<String, Object?>)> movements, List<(int, Map<String, Object?>)> counts) {
    final sums = <String, Decimal>{};
    for (final (i, m) in movements) {
      final r = _R(m, 'stockMovements[$i]');
      final type = r.str('type');
      if (!stockMovementTypes.contains(type)) throw _Invalid('${r.path}: unbekannte Bewegungsart $type.');
      final articleId = _ref('article', r.str('articleId'), r.path) ?? '';
      final delta = r.decimal('quantityDelta');
      sums[articleId] = (sums[articleId] ?? Decimal.zero) + Decimal.parse(delta);
      data.stockMovements.add(
        StockMovement(
          id: newId(),
          companyId: companyId,
          articleId: articleId,
          type: type,
          quantityDelta: delta,
          resultingQuantity: r.decimal('resultingQuantity'),
          referenceLabel: r.optStr('referenceLabel'),
          note: r.optStr('note'),
          createdByUserId: userId,
          createdAt: r.time('createdAt'),
        ),
      );
    }
    // Der Bestand kommt wie offline mit; weicht er von der Summe der
    // Bewegungen ab (z. B. Bestand vor Einführung des Lagermoduls), nur
    // melden — nichts nachbuchen.
    final differing = [
      for (final a in data.articles)
        if (Decimal.parse(a.stockQuantity) != (sums[a.id] ?? Decimal.zero)) a.name,
    ];
    if (differing.isNotEmpty && data.stockMovements.isNotEmpty) {
      result.warnings.add(
        'Bestand ohne vollständige Bewegungshistorie (übernommen wie offline): '
        '${differing.take(5).join(', ')}${differing.length > 5 ? ' …' : ''}.',
      );
    }
    for (final (i, c) in counts) {
      final r = _R(c, 'inventoryCounts[$i]');
      final status = r.str('status');
      if (!{'draft', 'completed'}.contains(status)) throw _Invalid('${r.path}: unbekannter Status $status.');
      final id = _assign('inventoryCount', r.str('id'), r.path);
      data.inventoryCounts.add(
        InventoryCount(
          id: id,
          companyId: companyId,
          label: r.str('label'),
          date: r.date('date'),
          status: status,
          completedAt: r.optTime('completedAt'),
          createdAt: r.time('createdAt'),
        ),
      );
      final seen = <String>{};
      for (final (j, item) in _listOf(c['items'], '${r.path}.items')) {
        final ir = _R(item, '${r.path}.items[$j]');
        final articleId = _ref('article', ir.str('articleId'), ir.path);
        if (articleId == null || !seen.add(articleId)) continue;
        data.inventoryItems.add(
          InventoryCountItem(
            id: newId(),
            inventoryCountId: id,
            articleId: articleId,
            expectedQuantity: ir.decimal('expectedQuantity'),
            countedQuantity: ir.optDecimal('countedQuantity'),
            countedAt: ir.optTime('countedAt'),
          ),
        );
      }
    }
  }

  void _time(
    List<(int, Map<String, Object?>)> roles,
    List<(int, Map<String, Object?>)> entries,
    List<(int, Map<String, Object?>)> sheets,
    Map<String, String> assignments,
    Set<String> members,
  ) {
    final roleRates = <String, int>{};
    final roleNames = <String, String>{};
    for (final (i, ro) in roles) {
      final r = _R(ro, 'staffRoles[$i]');
      final oldId = r.str('id');
      final role = StaffRole(
        id: _assign('staffRole', oldId, r.path),
        companyId: companyId,
        name: r.str('name'),
        hourlyCostCents: r.optInt('hourlyCostCents') ?? 0,
        createdAt: r.time('createdAt'),
      );
      data.staffRoles.add(role);
      roleRates[oldId] = role.hourlyCostCents;
      roleNames[oldId] = role.name;
    }

    // Stundenzettel zuerst (Zeiten verweisen offline auf ihren Zettel);
    // der Zettel gehört dem Mitglied seiner ersten Buchung, sonst dem
    // importierenden Admin.
    final sheetOld = <String, Map<String, Object?>>{};
    for (final (i, s) in sheets) {
      final r = _R(s, 'timeSheets[$i]');
      final oldId = r.str('id');
      _assign('timeSheet', oldId, r.path);
      sheetOld[oldId] = s;
    }

    final usage = <String, int>{};
    final sheetOwner = <String, String>{};
    for (final (i, e) in entries) {
      final r = _R(e, 'timeEntries[$i]');
      final oldRole = r.optStr('staffRoleId');
      if (oldRole != null && !roleRates.containsKey(oldRole)) {
        result.errors.add('${r.path}: Verweis auf unbekannte Rolle $oldRole.');
        continue;
      }
      final key = oldRole ?? migrationNoRoleKey;
      usage[key] = (usage[key] ?? 0) + 1;
      final member = assignments[key];
      if (member != null && !members.contains(member)) {
        result.errors.add('Zuordnung ${roleNames[key] ?? 'ohne Rolle'}: kein aktives Mitglied dieser Firma.');
      }
      final created = r.time('createdAt');
      final entry = TimeEntry(
        id: newId(),
        companyId: companyId,
        userId: member ?? userId,
        documentId: _ref('document', r.optStr('documentId'), r.path),
        projectId: _ref('project', r.optStr('projectId'), r.path),
        workDate: r.date('date'),
        hours: r.decimal('hours'),
        note: r.optStr('note'),
        // Offline gilt der Satz der Rolle; ohne Rolle kostet die Buchung
        // nichts — so bleibt das Projektergebnis gleich.
        hourlyCostCents: oldRole == null ? null : roleRates[oldRole],
        staffRoleId: oldRole == null ? null : _ids['staffRole']![oldRole],
        createdAt: created,
        updatedAt: created,
      );
      data.timeEntries.add(entry);
      final sheetOldId = r.optStr('timeSheetId');
      if (sheetOldId != null) {
        final sheetId = _ref('timeSheet', sheetOldId, r.path);
        if (sheetId != null) {
          data.timeSheetEntries.putIfAbsent(sheetId, () => []).add(entry.id);
          sheetOwner.putIfAbsent(sheetId, () => entry.userId);
        }
      }
    }
    for (final e in usage.entries) {
      result.roles.add((id: e.key, name: roleNames[e.key] ?? 'Ohne Rolle', timeEntries: e.value));
      if (!assignments.containsKey(e.key)) result.missingAssignments.add(e.key);
    }

    for (final (i, s) in sheets) {
      final r = _R(s, 'timeSheets[$i]');
      final id = _ids['timeSheet']![r.str('id')]!;
      final status = r.str('status');
      if (!{'draft', 'signed'}.contains(status)) throw _Invalid('${r.path}: unbekannter Status $status.');
      final png = r.optStr('signaturePng');
      Uint8List? signature;
      if (png != null) {
        try {
          signature = base64Decode(png);
        } on FormatException {
          throw _Invalid('${r.path}: Unterschrift ist kein gültiges Base64.');
        }
      }
      if (status == 'signed' && signature == null) {
        result.errors.add('${r.path}: unterschriebener Zettel ohne Unterschrift.');
      }
      final supersedes = r.optStr('supersedesId');
      data.timeSheets.add(
        TimeSheet(
          id: id,
          companyId: companyId,
          date: r.date('date'),
          documentId: _ref('document', r.optStr('documentId'), r.path),
          projectId: _ref('project', r.optStr('projectId'), r.path),
          status: status,
          signaturePng: signature,
          signerName: r.optStr('signerName'),
          signedAt: r.optTime('signedAt'),
          supersedesId: supersedes == null ? null : _ref('timeSheet', supersedes, r.path),
          createdByUserId: sheetOwner[id] ?? userId,
          createdAt: r.time('createdAt'),
        ),
      );
    }
    sheetOld.clear();
  }

  /// Nummern eindeutig; Nummernkreise mindestens auf dem höchsten
  /// übernommenen Stand; Projekte ohne Nummer hinten anhängen.
  void _checkNumbers() {
    final seen = <String>{};
    for (final d in data.documents) {
      final n = d.number;
      if (n != null && !seen.add(n)) result.errors.add('Dokumentnummer $n kommt mehrfach vor.');
    }
    final poSeen = <String>{};
    for (final o in data.purchaseOrders) {
      final n = o.number;
      if (n != null && !poSeen.add(n)) result.errors.add('Bestellnummer $n kommt mehrfach vor.');
    }

    final seq = <String, int>{for (final s in data.numberSequences) '${s.documentType}|${s.year}': s.lastNumber};
    final projectNumbers = <int, int>{};
    for (final p in data.projects) {
      if (p.projectNumber > 0) {
        projectNumbers[p.foundingYear] = [
          projectNumbers[p.foundingYear] ?? 0,
          p.projectNumber,
        ].reduce((a, b) => a > b ? a : b);
      }
    }
    for (final e in projectNumbers.entries) {
      final key = 'project|${e.key}';
      if ((seq[key] ?? 0) < e.value) seq[key] = e.value;
    }
    for (final (index, p) in data.projects.indexed) {
      if (p.projectNumber > 0) continue;
      final key = 'project|${p.foundingYear}';
      final number = (seq[key] ?? 0) + 1;
      seq[key] = number;
      data.projects[index] = Project(
        id: p.id,
        companyId: p.companyId,
        name: p.name,
        customerId: p.customerId,
        notes: p.notes,
        status: p.status,
        foundingYear: p.foundingYear,
        projectNumber: number,
        createdAt: p.createdAt,
      );
    }
    final projectKeys = <String>{};
    for (final p in data.projects) {
      if (!projectKeys.add('${p.foundingYear}|${p.projectNumber}')) {
        result.errors.add('Projektnummer ${p.displayNumber} kommt mehrfach vor.');
      }
    }
    data.numberSequences
      ..clear()
      ..addAll([
        for (final e in seq.entries)
          (documentType: e.key.split('|').first, year: int.parse(e.key.split('|').last), lastNumber: e.value),
      ]);
  }

  Map<String, Object?> _map(Object? value, String path) {
    if (value is Map<String, Object?>) return value;
    throw _Invalid('$path: Objekt erwartet.');
  }

  List<(int, Map<String, Object?>)> _list(Map<String, Object?> p, String key) => _listOf(p[key], key);

  List<(int, Map<String, Object?>)> _listOf(Object? raw, String path) {
    if (raw == null) return const [];
    if (raw is! List<Object?>) throw _Invalid('$path: Liste erwartet.');
    return [for (final (i, v) in raw.indexed) (i, _map(v, '$path[$i]'))];
  }
}

/// Typisierter Lesezugriff mit Pfad in der Fehlermeldung.
class _R {
  _R(this.m, this.path);
  final Map<String, Object?> m;
  final String path;

  Never _bad(String key, String expected) => throw _Invalid('$path.$key: $expected erwartet.');

  String str(String key, {bool allowEmpty = false}) {
    final v = m[key];
    if (v is! String || (!allowEmpty && v.trim().isEmpty)) _bad(key, 'Text');
    return v;
  }

  String? optStr(String key) {
    final v = m[key];
    if (v == null) return null;
    if (v is! String) _bad(key, 'Text');
    return v.trim().isEmpty ? null : v;
  }

  int integer(String key) => optInt(key) ?? _bad(key, 'Ganzzahl');

  int? optInt(String key) {
    final v = m[key];
    if (v == null) return null;
    if (v is int) return v;
    if (v is double && v == v.roundToDouble()) return v.toInt();
    _bad(key, 'Ganzzahl');
  }

  double number(String key) => optNumber(key) ?? _bad(key, 'Zahl');

  double? optNumber(String key) {
    final v = m[key];
    if (v == null) return null;
    if (v is num) return v.toDouble();
    _bad(key, 'Zahl');
  }

  String decimal(String key) => optDecimal(key) ?? _bad(key, 'Dezimalzahl');

  String? optDecimal(String key) {
    final v = m[key];
    if (v == null) return null;
    final text = v is num ? v.toString() : (v is String ? v.trim().replaceAll(',', '.') : null);
    final parsed = text == null ? null : Decimal.tryParse(text);
    if (parsed == null) _bad(key, 'Dezimalzahl');
    return parsed.toString();
  }

  bool boolean(String key, {required bool fallback}) {
    final v = m[key];
    if (v == null) return fallback;
    if (v is! bool) _bad(key, 'true/false');
    return v;
  }

  DateTime time(String key) => optTime(key) ?? _bad(key, 'Zeitpunkt (ISO 8601)');

  DateTime? optTime(String key) {
    final v = m[key];
    if (v == null) return null;
    final parsed = v is String ? DateTime.tryParse(v) : null;
    if (parsed == null) _bad(key, 'Zeitpunkt (ISO 8601)');
    return parsed.toUtc();
  }

  DateTime date(String key) => optDate(key) ?? _bad(key, 'Datum JJJJ-MM-TT');

  DateTime? optDate(String key) {
    final v = m[key];
    if (v == null) return null;
    if (v is! String || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(v)) _bad(key, 'Datum JJJJ-MM-TT');
    return DateTime.parse('${v}T00:00:00Z');
  }
}
