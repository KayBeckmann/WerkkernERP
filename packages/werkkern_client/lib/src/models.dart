/// Datentransferobjekte des Online-Servers. Bewusst unabhängig von den
/// Drift-Zeilen der Offline-App — Online- und Offline-Daten werden nie
/// vermischt (ADR-0001 B0.1: kein automatischer Übergang).
library;

class OnlineMembership {
  const OnlineMembership({
    required this.companyId,
    required this.companyName,
    required this.groupName,
    required this.isAdmin,
    this.suspended = false,
  });
  factory OnlineMembership.fromJson(Map<String, Object?> j) => OnlineMembership(
        companyId: j['companyId'] as String,
        companyName: j['companyName'] as String,
        groupName: j['groupName'] as String,
        isAdmin: j['isAdmin'] as bool,
        suspended: j['suspended'] as bool? ?? false,
      );
  final String companyId;
  final String companyName;
  final String groupName;
  final bool isAdmin;

  /// Firma vom Anbieter gesperrt (SaaS-Abo) — Anmeldung nicht möglich.
  final bool suspended;
}

class OnlineLogin {
  const OnlineLogin({required this.identityToken, required this.memberships});
  final String identityToken;
  final List<OnlineMembership> memberships;
}

class OnlineCustomer {
  const OnlineCustomer({
    required this.id,
    required this.name,
    this.address,
    this.email,
    this.phone,
    this.vatId,
    this.contactPerson,
    this.notes,
    this.invoiceEmail,
    this.contacts = const [],
  });
  factory OnlineCustomer.fromJson(Map<String, Object?> j) => OnlineCustomer(
        id: j['id'] as String,
        name: j['name'] as String,
        address: j['address'] as String?,
        email: j['email'] as String?,
        phone: j['phone'] as String?,
        vatId: j['vatId'] as String?,
        contactPerson: j['contactPerson'] as String?,
        notes: j['notes'] as String?,
        invoiceEmail: j['invoiceEmail'] as String?,
        contacts: [
          for (final c in (j['contacts'] as List? ?? const [])) OnlineContact.fromJson(c as Map<String, Object?>),
        ],
      );
  final String id;
  final String name;
  final String? address;
  final String? email;
  final String? phone;
  final String? vatId;

  /// Altes Einzelfeld — seit den Kontaktpersonen leer, nur noch gelesen.
  final String? contactPerson;
  final String? notes;

  /// Vorrangige Adresse für Rechnungsdokumente und Mahnungen.
  final String? invoiceEmail;
  final List<OnlineContact> contacts;

  OnlineContact? contact(String? id) => id == null ? null : contacts.where((c) => c.id == id).firstOrNull;

  Map<String, Object?> toWriteJson() => {
        'name': name,
        'address': address,
        'email': email,
        'phone': phone,
        'vatId': vatId,
        'notes': notes,
        'invoiceEmail': invoiceEmail,
        'contacts': [for (final c in contacts) c.toWriteJson()],
      };
}

/// Kontaktperson eines Kunden (z. B. Erika, Buchhaltung).
class OnlineContact {
  const OnlineContact({this.id, required this.name, this.role, this.email, this.phone});
  factory OnlineContact.fromJson(Map<String, Object?> j) => OnlineContact(
        id: j['id'] as String?,
        name: j['name'] as String,
        role: j['role'] as String?,
        email: j['email'] as String?,
        phone: j['phone'] as String?,
      );

  /// `null` bei einer neuen, noch nicht gespeicherten Kontaktperson.
  final String? id;
  final String name;
  final String? role;
  final String? email;
  final String? phone;

  /// „Max (Betriebstechniker)“
  String get label => role == null ? name : '$name ($role)';

  Map<String, Object?> toWriteJson() => {'id': ?id, 'name': name, 'role': role, 'email': email, 'phone': phone};
}

class OnlineArticle {
  const OnlineArticle({
    required this.id,
    required this.name,
    this.unit,
    this.salePriceCents,
    required this.active,
    this.articleGroupId,
    this.articleGroupName,
    this.defaultSupplierId,
    this.calculatedSalePriceCents,
    int? effectiveSalePriceCents,
    this.stockQuantity = '0',
    this.minimumStock,
  }) : effectiveSalePriceCents = effectiveSalePriceCents ?? salePriceCents;
  factory OnlineArticle.fromJson(Map<String, Object?> j) => OnlineArticle(
        id: j['id'] as String,
        name: j['name'] as String,
        unit: j['unit'] as String?,
        salePriceCents: j['salePriceCents'] as int?,
        active: j['active'] as bool,
        articleGroupId: j['articleGroupId'] as String?,
        articleGroupName: j['articleGroupName'] as String?,
        defaultSupplierId: j['defaultSupplierId'] as String?,
        calculatedSalePriceCents: j['calculatedSalePriceCents'] as int?,
        effectiveSalePriceCents: j['effectiveSalePriceCents'] as int?,
        stockQuantity: j['stockQuantity'] as String? ?? '0',
        minimumStock: j['minimumStock'] as String?,
      );
  final String id;
  final String name;
  final String? unit;

  /// Manueller Netto-Verkaufspreis (überschreibt die Kalkulation).
  final int? salePriceCents;
  final bool active;
  final String? articleGroupId;
  final String? articleGroupName;
  final String? defaultSupplierId;

  /// EK des Standardlieferanten × Gruppenaufschlag (`null` ohne EK).
  final int? calculatedSalePriceCents;

  /// Was in eine Position übernommen wird: manuell, sonst kalkuliert.
  final int? effectiveSalePriceCents;

  /// Lagerbestand (Dezimaltext, ändert sich nur über Bewegungen).
  final String stockQuantity;
  final String? minimumStock;

  Map<String, Object?> toWriteJson() => {
        'name': name,
        'unit': unit,
        'salePriceCents': salePriceCents,
        'active': active,
        'articleGroupId': articleGroupId,
        'defaultSupplierId': defaultSupplierId,
        'minimumStock': minimumStock,
      };
}

/// Positionsart wie offline (`InvoiceItemKind`).
enum OnlineItemKind { article, hours, text }

class OnlineDocumentItem {
  const OnlineDocumentItem({
    required this.kind,
    this.articleId,
    required this.description,
    required this.quantity,
    required this.unitPriceCents,
    required this.vatRatePercent,
    this.unit,
    this.discountPercent = 0,
    this.groupLabel,
    this.staffRoleId,
  });
  factory OnlineDocumentItem.fromJson(Map<String, Object?> j) => OnlineDocumentItem(
        kind: OnlineItemKind.values.byName(j['kind'] as String),
        articleId: j['articleId'] as String?,
        description: j['description'] as String,
        quantity: j['quantity'] as String,
        unitPriceCents: j['unitPriceCents'] as int,
        vatRatePercent: (j['vatRatePercent'] as num).toDouble(),
        unit: j['unit'] as String?,
        discountPercent: (j['discountPercent'] as num? ?? 0).toDouble(),
        groupLabel: j['groupLabel'] as String?,
        staffRoleId: j['staffRoleId'] as String?,
      );
  final OnlineItemKind kind;
  final String? articleId;
  final String description;

  /// Dezimalzahl als String ("1.5") — nie double (F2).
  final String quantity;
  final int unitPriceCents;
  final double vatRatePercent;
  final String? unit;
  final double discountPercent;
  final String? groupLabel;

  /// Rolle einer Stunden-Position (C3.4) — `null` = ohne Rolle.
  final String? staffRoleId;

  Map<String, Object?> toJson() => {
        'kind': kind.name,
        'articleId': articleId,
        'description': description,
        'quantity': quantity,
        'unitPriceCents': unitPriceCents,
        'vatRatePercent': vatRatePercent,
        'unit': unit,
        'discountPercent': discountPercent,
        'groupLabel': groupLabel,
        'staffRoleId': staffRoleId,
      };
}

class OnlineTaxLine {
  const OnlineTaxLine({required this.vatRatePercent, required this.netCents, required this.taxCents});
  final double vatRatePercent;
  final int netCents;
  final int taxCents;
}

class OnlineDocument {
  const OnlineDocument({
    required this.id,
    required this.customerId,
    required this.kind,
    required this.status,
    this.number,
    required this.issueDate,
    required this.serviceDate,
    this.paymentTerms,
    this.notes,
    this.customerSnapshotName,
    this.customerSnapshotAddress,
    this.customerSnapshotVatId,
    this.companySnapshot,
    this.customerName,
    this.convertedFromId,
    this.convertedTo = const [],
    this.paymentStatus = 'open',
    this.paidAt,
    this.dueDate,
    this.finalizedAt,
    this.projectId,
    this.contactId,
    this.isAdvancePayment = false,
    this.isFixedPrice = false,
    this.convertedFromNumber,
    this.advancePayments = const [],
    this.remainingCents,
    this.creditNotes = const [],
    this.introTextSnapshot,
    this.closingTextSnapshot,
    this.footerTextSnapshot,
    this.smallBusinessExemptSnapshot = false,
    required this.version,
    this.items = const [],
    this.netCents,
    this.taxCents,
    this.grossCents,
    this.taxLines = const [],
    this.rawJson = const {},
    bool? editable,
  }) : editable = editable ?? status == 'draft';

  factory OnlineDocument.fromJson(Map<String, Object?> j) {
    final totals = j['totals'] as Map<String, Object?>?;
    final customerSnapshot = j['customerSnapshot'] as Map<String, Object?>?;
    final companySnapshot = j['companySnapshot'] as Map<String, Object?>?;
    return OnlineDocument(
      id: j['id'] as String,
      customerId: j['customerId'] as String,
      kind: j['kind'] as String,
      status: j['status'] as String,
      number: j['number'] as String?,
      issueDate: DateTime.parse(j['issueDate'] as String),
      serviceDate: DateTime.parse(j['serviceDate'] as String),
      paymentTerms: j['paymentTerms'] as String?,
      notes: j['notes'] as String?,
      customerSnapshotName: customerSnapshot?['name'] as String?,
      customerSnapshotAddress: customerSnapshot?['address'] as String?,
      customerSnapshotVatId: customerSnapshot?['vatId'] as String?,
      companySnapshot: companySnapshot == null ? null : OnlineCompanyProfile.fromJson(companySnapshot),
      customerName: j['customerName'] as String?,
      convertedFromId: j['convertedFromId'] as String?,
      isAdvancePayment: j['isAdvancePayment'] as bool? ?? false,
      isFixedPrice: j['isFixedPrice'] as bool? ?? false,
      editable: j['editable'] as bool?,
      convertedFromNumber: j['convertedFromNumber'] as String?,
      advancePayments: _summaries(j['advancePayments']),
      remainingCents: j['remainingCents'] as int?,
      creditNotes: _summaries(j['creditNotes']),
      introTextSnapshot: (j['textSnapshot'] as Map<String, Object?>?)?['intro'] as String?,
      closingTextSnapshot: (j['textSnapshot'] as Map<String, Object?>?)?['closing'] as String?,
      footerTextSnapshot: (j['textSnapshot'] as Map<String, Object?>?)?['footer'] as String?,
      smallBusinessExemptSnapshot: (j['textSnapshot'] as Map<String, Object?>?)?['smallBusinessExempt'] as bool? ?? false,
      convertedTo: [
        for (final c in (j['convertedTo'] as List? ?? const []))
          (
            id: (c as Map<String, Object?>)['id'] as String,
            kind: c['kind'] as String,
            number: c['number'] as String?,
          ),
      ],
      paymentStatus: j['paymentStatus'] as String? ?? 'open',
      paidAt: j['paidAt'] == null ? null : DateTime.parse(j['paidAt'] as String),
      dueDate: j['dueDate'] == null ? null : DateTime.parse(j['dueDate'] as String),
      finalizedAt: j['finalizedAt'] == null ? null : DateTime.parse(j['finalizedAt'] as String),
      projectId: j['projectId'] as String?,
      contactId: j['contactId'] as String?,
      version: j['version'] as int,
      items: [
        for (final i in (j['items'] as List? ?? const [])) OnlineDocumentItem.fromJson(i as Map<String, Object?>),
      ],
      netCents: totals?['netCents'] as int?,
      taxCents: totals?['taxCents'] as int?,
      grossCents: (totals?['grossCents'] ?? j['totalGrossCents']) as int?,
      taxLines: [
        for (final r in (totals?['byRate'] as List? ?? const []))
          OnlineTaxLine(
            vatRatePercent: ((r as Map<String, Object?>)['vatRatePercent'] as num).toDouble(),
            netCents: r['netCents'] as int,
            taxCents: r['taxCents'] as int,
          ),
      ],
      rawJson: j,
    );
  }

  /// Unveränderte Serverantwort — wird so in den Offline-Bestand gelegt.
  final Map<String, Object?> rawJson;

  final String id;
  final String customerId;
  final String kind;
  final String status;
  final String? number;
  final DateTime issueDate;
  final DateTime serviceDate;
  final String? paymentTerms;
  final String? notes;
  final String? customerSnapshotName;
  final String? customerSnapshotAddress;
  final String? customerSnapshotVatId;

  /// Beim Finalisieren eingefrorene Firmendaten (`null` im Entwurf).
  final OnlineCompanyProfile? companySnapshot;

  /// Aktueller Name aus den Stammdaten (nur Anzeige).
  final String? customerName;

  final String? convertedFromId;

  /// Folgedokumente, die per Umwandlung aus diesem entstanden sind.
  final List<({String id, String kind, String? number})> convertedTo;

  /// `open`/`paid` (nur finalisierte Rechnungen).
  final String paymentStatus;
  final DateTime? paidAt;
  final DateTime? dueDate;
  final DateTime? finalizedAt;

  bool get isPaid => paymentStatus == 'paid';

  /// Projektzuordnung (C1 online).
  final String? projectId;

  /// Kontaktperson des Kunden (optional), Vorgabe-Empfänger beim Versand.
  final String? contactId;

  /// C13: diese Rechnung ist eine Abschlagsrechnung.
  final bool isAdvancePayment;

  /// C3.2: Festpreis vereinbart (Angebot/Auftrag).
  final bool isFixedPrice;

  /// Nummer des Quelldokuments (z. B. Rechnung einer Gutschrift).
  final String? convertedFromNumber;

  /// Schlussrechnung: bereits finalisierte Abschläge desselben Auftrags.
  final List<({String id, String? number, int grossCents})> advancePayments;

  /// Brutto abzüglich [advancePayments] (nur wenn es Abschläge gibt).
  final int? remainingCents;

  /// Beim Finalisieren eingefrorene Texte und § 19-Status (nur finalisiert).
  final String? introTextSnapshot;
  final String? closingTextSnapshot;
  final String? footerTextSnapshot;
  final bool smallBusinessExemptSnapshot;

  /// Rechnung: finalisierte Gutschriften dazu.
  final List<({String id, String? number, int grossCents})> creditNotes;

  static List<({String id, String? number, int grossCents})> _summaries(Object? raw) => [
        for (final s in (raw as List? ?? const []))
          (
            id: (s as Map<String, Object?>)['id'] as String,
            number: s['number'] as String?,
            grossCents: s['grossCents'] as int,
          ),
      ];

  /// Was angezeigt wird: bei finalisierten Dokumenten der eingefrorene
  /// Schnappschuss, bei Entwürfen der aktuelle Stammdatenname.
  String? get displayCustomerName => customerSnapshotName ?? customerName;

  /// Für optimistische Sperre — bei jedem Update/Finalisieren mitsenden.
  final int version;
  final List<OnlineDocumentItem> items;
  final int? netCents;
  final int? taxCents;
  final int? grossCents;
  final List<OnlineTaxLine> taxLines;

  bool get isDraft => status == 'draft';

  /// Darf noch bearbeitet werden (Server-Regel `isDocumentEditable`):
  /// Entwurf, oder finalisiertes Angebot/Auftrag/Proforma ohne
  /// Umwandlung. Fehlt das Feld (ältere Antwort), gilt nur der Entwurf.
  final bool editable;
}

// ---- Verwaltung (nur Firmen-Admin) -------------------------------------------

class OnlineGroup {
  const OnlineGroup({required this.id, required this.name});
  final String id;
  final String name;
}

class OnlineMember {
  const OnlineMember({
    required this.id,
    required this.email,
    required this.groupId,
    required this.groupName,
    required this.isAdmin,
    required this.active,
    this.hourlyCostCents,
  });
  factory OnlineMember.fromJson(Map<String, Object?> j) => OnlineMember(
        id: j['id'] as String,
        email: j['email'] as String? ?? '?',
        groupId: j['groupId'] as String,
        groupName: j['groupName'] as String? ?? '?',
        isAdmin: j['isAdmin'] as bool,
        active: j['active'] as bool,
        hourlyCostCents: j['hourlyCostCents'] as int?,
      );

  /// Stundenkostensatz dieses Mitglieds (Zeiterfassung), `null` = nicht gepflegt.
  final int? hourlyCostCents;
  final String id;
  final String email;
  final String groupId;
  final String groupName;
  final bool isAdmin;
  final bool active;
}

class OnlinePermissionInfo {
  const OnlinePermissionInfo({required this.key, this.module});
  final String key;

  /// Erforderliches Firmenmodul, `null` = Kernfunktion.
  final String? module;
}

class OnlineInvitation {
  const OnlineInvitation({required this.id, required this.email, required this.groupId, required this.expiresAt, required this.expired});
  final String id;
  final String email;
  final String groupId;
  final DateTime expiresAt;
  final bool expired;
}

class OnlineCompanyProfile {
  const OnlineCompanyProfile({
    this.name,
    this.address,
    this.taxNumber,
    this.vatId,
    this.iban,
    this.email,
    this.phone,
    this.footerText,
    this.documentTexts = const {},
    this.smallBusinessExempt = false,
  });
  factory OnlineCompanyProfile.fromJson(Map<String, Object?> j) => OnlineCompanyProfile(
        name: j['name'] as String?,
        address: j['address'] as String?,
        taxNumber: j['taxNumber'] as String?,
        vatId: j['vatId'] as String?,
        iban: j['iban'] as String?,
        email: j['email'] as String?,
        phone: j['phone'] as String?,
        footerText: j['footerText'] as String?,
        documentTexts: {
          for (final e in ((j['documentTexts'] as Map<String, Object?>?) ?? const {}).entries)
            e.key: (
              intro: (e.value as Map<String, Object?>)['intro'] as String?,
              closing: (e.value as Map<String, Object?>)['closing'] as String?,
            ),
        },
        smallBusinessExempt: j['smallBusinessExempt'] as bool? ?? false,
      );
  final String? name;
  final String? address;
  final String? taxNumber;
  final String? vatId;
  final String? iban;
  final String? email;
  final String? phone;
  final String? footerText;

  /// Einleitungs-/Schlusstext je Dokumentart (`invoice`, `quote`, ...).
  final Map<String, ({String? intro, String? closing})> documentTexts;

  /// Kleinunternehmerregelung § 19 UStG (Server erzwingt 0 % USt).
  final bool smallBusinessExempt;

  Map<String, Object?> toJson() => {
        'address': address,
        'taxNumber': taxNumber,
        'vatId': vatId,
        'iban': iban,
        'email': email,
        'phone': phone,
        'footerText': footerText,
        'documentTexts': {
          for (final e in documentTexts.entries) e.key: {'intro': e.value.intro, 'closing': e.value.closing},
        },
        'smallBusinessExempt': smallBusinessExempt,
      };
}

class OnlineAuditEntry {
  const OnlineAuditEntry({required this.at, this.userEmail, required this.action, required this.entityType});
  final DateTime at;
  final String? userEmail;
  final String action;
  final String entityType;
}

/// Zeitbuchung (C3 online) eines Nutzers auf einen Auftrag/eine Rechnung.
class OnlineTimeEntry {
  const OnlineTimeEntry({
    required this.id,
    required this.userId,
    this.userEmail,
    this.documentId,
    this.projectId,
    required this.date,
    required this.hours,
    this.note,
    this.hourlyCostCents,
    this.staffRoleId,
  });
  factory OnlineTimeEntry.fromJson(Map<String, Object?> j) => OnlineTimeEntry(
        id: j['id'] as String,
        userId: j['userId'] as String,
        userEmail: j['userEmail'] as String?,
        documentId: j['documentId'] as String?,
        projectId: j['projectId'] as String?,
        date: DateTime.parse(j['date'] as String),
        hours: j['hours'] as String,
        note: j['note'] as String?,
        hourlyCostCents: j['hourlyCostCents'] as int?,
        staffRoleId: j['staffRoleId'] as String?,
      );
  final String id;
  final String userId;
  final String? userEmail;
  final String? documentId;
  final String? projectId;
  final DateTime date;

  /// Dezimal als Text ("1.5").
  final String hours;
  final String? note;

  /// Beim Buchen eingefrorener Stundensatz — der Rolle oder des
  /// Mitglieds (`null` = nicht gepflegt).
  final int? hourlyCostCents;
  final String? staffRoleId;
}

/// Projekt (C1 online). [displayNumber] = "JJ/PP".
class OnlineProject {
  const OnlineProject({
    required this.id,
    required this.name,
    this.customerId,
    this.notes,
    required this.status,
    required this.displayNumber,
  });
  factory OnlineProject.fromJson(Map<String, Object?> j) => OnlineProject(
        id: j['id'] as String,
        name: j['name'] as String,
        customerId: j['customerId'] as String?,
        notes: j['notes'] as String?,
        status: j['status'] as String,
        displayNumber: j['displayNumber'] as String,
      );
  final String id;
  final String name;
  final String? customerId;
  final String? notes;
  final String status;
  final String displayNumber;

  bool get isArchived => status == 'archived';
}

/// Projektdetail mit Ergebnisrechnung; Teilsummen `null`, wenn dem
/// Nutzer das jeweilige Leserecht fehlt.
class OnlineProjectDetail {
  const OnlineProjectDetail({
    required this.project,
    required this.documents,
    this.invoiceGrossCents,
    this.plannedHours,
    this.bookedHours,
    this.hoursCostCents,
    this.expenseCostCents,
    this.resultCents,
  });
  factory OnlineProjectDetail.fromJson(Map<String, Object?> j) {
    final r = j['result'] as Map<String, Object?>;
    return OnlineProjectDetail(
      project: OnlineProject.fromJson(j),
      documents: [for (final d in j['documents'] as List) OnlineDocument.fromJson(d as Map<String, Object?>)],
      invoiceGrossCents: r['invoiceGrossCents'] as int?,
      plannedHours: r['plannedHours'] as String?,
      bookedHours: r['bookedHours'] as String?,
      hoursCostCents: r['hoursCostCents'] as int?,
      expenseCostCents: r['expenseCostCents'] as int?,
      resultCents: r['resultCents'] as int?,
    );
  }
  final OnlineProject project;
  final List<OnlineDocument> documents;
  final int? invoiceGrossCents;
  final String? plannedHours;
  final String? bookedHours;
  final int? hoursCostCents;

  /// Zugeordnete Belege (Buchhaltung); `null` ohne Leserecht.
  final int? expenseCostCents;
  final int? resultCents;
}
