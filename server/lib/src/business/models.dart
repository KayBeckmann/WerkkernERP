/// B1 Punkt 3 — Fachdaten im Online-Server (Kunden, Artikel, Dokumente).
/// Felder bewusst nah an der Offline-App (`lib/data/database/tables.dart`),
/// damit ein späterer Import (ADR-0001 B0.1) 1:1 abbildbar bleibt.
/// Jede Entität führt `companyId` direkt (ADR-0001 B0.5).
library;

class Customer {
  const Customer({
    required this.id,
    required this.companyId,
    required this.name,
    this.address,
    this.email,
    this.phone,
    this.vatId,
    this.contactPerson,
    this.notes,
    required this.createdAt,
  });
  final String id;
  final String companyId;
  final String name;
  final String? address;
  final String? email;
  final String? phone;
  final String? vatId;
  final String? contactPerson;
  final String? notes;
  final DateTime createdAt;

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'address': address,
        'email': email,
        'phone': phone,
        'vatId': vatId,
        'contactPerson': contactPerson,
        'notes': notes,
        'createdAt': createdAt.toIso8601String(),
      };
}

/// Artikel wie offline: [salePriceCents] ist der **manuelle** Netto-
/// Verkaufspreis; ohne ihn kalkuliert der Server aus Standardlieferant +
/// Artikelgruppen-Aufschlag (siehe `suppliers.dart`). Artikel werden wie
/// offline deaktiviert, nie gelöscht.
class Article {
  const Article({
    required this.id,
    required this.companyId,
    required this.name,
    this.unit,
    this.salePriceCents,
    required this.active,
    required this.createdAt,
    this.articleGroupId,
    this.defaultSupplierId,
    this.stockQuantity = '0',
    this.minimumStock,
  });
  final String id;
  final String companyId;
  final String name;
  final String? unit;
  final int? salePriceCents;
  final bool active;
  final DateTime createdAt;
  final String? articleGroupId;
  final String? defaultSupplierId;

  /// C5.1 Lagerbestand als Dezimaltext — ändert sich ausschließlich über
  /// Bestandsbewegungen (nie über die Artikelpflege).
  final String stockQuantity;
  final String? minimumStock;

  Article withReferences({required String? articleGroupId, required String? defaultSupplierId}) => Article(
        id: id,
        companyId: companyId,
        name: name,
        unit: unit,
        salePriceCents: salePriceCents,
        active: active,
        createdAt: createdAt,
        articleGroupId: articleGroupId,
        defaultSupplierId: defaultSupplierId,
        stockQuantity: stockQuantity,
        minimumStock: minimumStock,
      );

  Article withStock(String quantity) => Article(
        id: id,
        companyId: companyId,
        name: name,
        unit: unit,
        salePriceCents: salePriceCents,
        active: active,
        createdAt: createdAt,
        articleGroupId: articleGroupId,
        defaultSupplierId: defaultSupplierId,
        stockQuantity: quantity,
        minimumStock: minimumStock,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'unit': unit,
        'salePriceCents': salePriceCents,
        'active': active,
        'createdAt': createdAt.toIso8601String(),
        'articleGroupId': articleGroupId,
        'defaultSupplierId': defaultSupplierId,
        'stockQuantity': stockQuantity,
        'minimumStock': minimumStock,
      };
}

/// Dokumentarten wie `DocumentKind` der Offline-App. Rechnung ist
/// Kernfunktion; alle anderen setzen ihr Firmenmodul voraus.
const documentKindModules = <String, String?>{
  'invoice': null,
  'quote': 'quotes',
  'order': 'orders',
  'deliveryNote': 'deliveryNotes',
  'proforma': 'proforma',
  'creditNote': 'creditNotes',
};

const documentStatuses = {'draft', 'finalized'};
const itemKinds = {'article', 'hours', 'text'};

/// Ein Dokument (Rechnung/Angebot/...). [version] steigt bei jeder
/// Änderung — Grundlage für die Konflikterkennung in B2 ("Kein last
/// write wins"): ein Update mit veralteter Version wird mit 409
/// abgewiesen statt still zu überschreiben.
class Document {
  const Document({
    required this.id,
    required this.companyId,
    required this.customerId,
    required this.kind,
    required this.status,
    this.number,
    this.numberYear,
    required this.issueDate,
    required this.serviceDate,
    this.paymentTerms,
    this.notes,
    this.customerSnapshotName,
    this.customerSnapshotAddress,
    this.customerSnapshotVatId,
    this.companySnapshotName,
    this.companySnapshotAddress,
    this.companySnapshotTaxNumber,
    this.companySnapshotVatId,
    this.companySnapshotIban,
    required this.createdByUserId,
    required this.createdAt,
    required this.updatedAt,
    this.finalizedAt,
    required this.version,
    this.convertedFromId,
    this.paymentStatus = 'open',
    this.paidAt,
    this.dueDate,
    this.projectId,
    this.isAdvancePayment = false,
    this.isFixedPrice = false,
    this.introTextSnapshot,
    this.closingTextSnapshot,
    this.footerTextSnapshot,
    this.smallBusinessExemptSnapshot = false,
    this.stockBooked = false,
  });
  final String id;
  final String companyId;
  final String customerId;
  final String kind;
  final String status;
  final String? number;
  final int? numberYear;
  final DateTime issueDate;
  final DateTime serviceDate;
  final String? paymentTerms;
  final String? notes;
  final String? customerSnapshotName;
  final String? customerSnapshotAddress;
  final String? customerSnapshotVatId;
  final String? companySnapshotName;
  final String? companySnapshotAddress;
  final String? companySnapshotTaxNumber;
  final String? companySnapshotVatId;
  final String? companySnapshotIban;
  final String createdByUserId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? finalizedAt;
  final int version;

  /// Quelldokument einer Umwandlung (Angebot -> Auftrag -> Rechnung).
  final String? convertedFromId;

  /// `open`/`paid` — Folge-Metadatum wie offline (C12), ändert nie den
  /// Dokumentinhalt und ist daher auch nach Finalisierung setzbar.
  final String paymentStatus;
  final DateTime? paidAt;
  final DateTime? dueDate;

  /// C1 online: optionale Projektzuordnung (jede Dokumentart).
  final String? projectId;

  /// C13: Abschlagsrechnung (nur Rechnung) — eine spätere Schlussrechnung
  /// aus demselben Auftrag zieht sie einzeln ab.
  final bool isAdvancePayment;

  /// C3.2: Festpreis vereinbart (Angebot/Auftrag). Ohne Festpreis ersetzt
  /// die Umwandlung Auftrag -> Rechnung die geplanten Stunden durch die
  /// gebuchten Ist-Stunden (Zeit und Material).
  final bool isFixedPrice;

  final String? introTextSnapshot;
  final String? closingTextSnapshot;
  final String? footerTextSnapshot;
  final bool smallBusinessExemptSnapshot;

  /// C5.1: dieses Dokument hat beim Finalisieren Bestand gebucht —
  /// spätere Bearbeitungen (Auftrag bis zur Umwandlung) buchen die
  /// Mengendifferenz nach.
  final bool stockBooked;

  bool get isDraft => status == 'draft';

  /// Kopie mit geänderten Feldern — verhindert, dass beim Aktualisieren
  /// einzelner Felder andere stillschweigend verloren gehen.
  Document copyWith({
    String? customerId,
    String? status,
    String? number,
    int? numberYear,
    DateTime? issueDate,
    DateTime? serviceDate,
    String? Function()? paymentTerms,
    String? Function()? notes,
    String? customerSnapshotName,
    String? customerSnapshotAddress,
    String? customerSnapshotVatId,
    CompanySnapshot? company,
    DateTime? updatedAt,
    DateTime? finalizedAt,
    int? version,
    String? paymentStatus,
    DateTime? Function()? paidAt,
    DateTime? Function()? dueDate,
    String? Function()? projectId,
    bool? isAdvancePayment,
    bool? isFixedPrice,
    bool? stockBooked,
  }) =>
      Document(
        id: id,
        companyId: companyId,
        customerId: customerId ?? this.customerId,
        kind: kind,
        status: status ?? this.status,
        number: number ?? this.number,
        numberYear: numberYear ?? this.numberYear,
        issueDate: issueDate ?? this.issueDate,
        serviceDate: serviceDate ?? this.serviceDate,
        paymentTerms: paymentTerms != null ? paymentTerms() : this.paymentTerms,
        notes: notes != null ? notes() : this.notes,
        customerSnapshotName: customerSnapshotName ?? this.customerSnapshotName,
        customerSnapshotAddress: customerSnapshotAddress ?? this.customerSnapshotAddress,
        customerSnapshotVatId: customerSnapshotVatId ?? this.customerSnapshotVatId,
        companySnapshotName: company?.name ?? companySnapshotName,
        companySnapshotAddress: company != null ? company.address : companySnapshotAddress,
        companySnapshotTaxNumber: company != null ? company.taxNumber : companySnapshotTaxNumber,
        companySnapshotVatId: company != null ? company.vatId : companySnapshotVatId,
        companySnapshotIban: company != null ? company.iban : companySnapshotIban,
        createdByUserId: createdByUserId,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        finalizedAt: finalizedAt ?? this.finalizedAt,
        version: version ?? this.version,
        convertedFromId: convertedFromId,
        paymentStatus: paymentStatus ?? this.paymentStatus,
        paidAt: paidAt != null ? paidAt() : this.paidAt,
        dueDate: dueDate != null ? dueDate() : this.dueDate,
        projectId: projectId != null ? projectId() : this.projectId,
        isAdvancePayment: isAdvancePayment ?? this.isAdvancePayment,
        isFixedPrice: isFixedPrice ?? this.isFixedPrice,
        introTextSnapshot: company != null ? company.introText : introTextSnapshot,
        closingTextSnapshot: company != null ? company.closingText : closingTextSnapshot,
        footerTextSnapshot: company != null ? company.footerText : footerTextSnapshot,
        smallBusinessExemptSnapshot: company != null ? company.smallBusinessExempt : smallBusinessExemptSnapshot,
        stockBooked: stockBooked ?? this.stockBooked,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'customerId': customerId,
        'kind': kind,
        'status': status,
        'number': number,
        'numberYear': numberYear,
        'issueDate': _date(issueDate),
        'serviceDate': _date(serviceDate),
        'paymentTerms': paymentTerms,
        'notes': notes,
        'customerSnapshot': customerSnapshotName == null
            ? null
            : {'name': customerSnapshotName, 'address': customerSnapshotAddress, 'vatId': customerSnapshotVatId},
        'companySnapshot': companySnapshotName == null
            ? null
            : {
                'name': companySnapshotName,
                'address': companySnapshotAddress,
                'taxNumber': companySnapshotTaxNumber,
                'vatId': companySnapshotVatId,
                'iban': companySnapshotIban,
              },
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'finalizedAt': finalizedAt?.toIso8601String(),
        'version': version,
        'convertedFromId': convertedFromId,
        'paymentStatus': paymentStatus,
        'paidAt': paidAt?.toIso8601String(),
        'dueDate': dueDate == null ? null : _date(dueDate!),
        'projectId': projectId,
        'isAdvancePayment': isAdvancePayment,
        'isFixedPrice': isFixedPrice,
        'stockBooked': stockBooked,
        'textSnapshot': isDraft
            ? null
            : {
                'intro': introTextSnapshot,
                'closing': closingTextSnapshot,
                'footer': footerTextSnapshot,
                'smallBusinessExempt': smallBusinessExemptSnapshot,
              },
      };
}

class DocumentItem {
  const DocumentItem({
    required this.id,
    required this.documentId,
    required this.kind,
    this.articleId,
    required this.description,
    required this.quantity,
    required this.unitPriceCents,
    required this.vatRatePercent,
    this.unit,
    this.discountPercent = 0,
    this.groupLabel,
    required this.sortOrder,
  });
  final String id;
  final String documentId;
  final String kind;
  final String? articleId;
  final String description;

  /// Dezimal als String (z. B. "2.5") — wie offline, nie `double` (F2).
  final String quantity;
  final int unitPriceCents;
  final double vatRatePercent;
  final String? unit;
  final double discountPercent;
  final String? groupLabel;
  final int sortOrder;

  Map<String, Object?> toJson() => {
        'id': id,
        'kind': kind,
        'articleId': articleId,
        'description': description,
        'quantity': quantity,
        'unitPriceCents': unitPriceCents,
        'vatRatePercent': vatRatePercent,
        'unit': unit,
        'discountPercent': discountPercent,
        'groupLabel': groupLabel,
        'sortOrder': sortOrder,
      };
}

/// Firmendaten, die beim Finalisieren eingefroren werden — eine
/// spätere Änderung der Stammdaten verändert ein finalisiertes Dokument
/// nicht mehr (gleicher Audit-Befund wie offline, Abweichungen.md 2.1).
class CompanySnapshot {
  const CompanySnapshot({
    required this.name,
    this.address,
    this.taxNumber,
    this.vatId,
    this.iban,
    this.introText,
    this.closingText,
    this.footerText,
    this.smallBusinessExempt = false,
  });
  final String name;
  final String? address;
  final String? taxNumber;
  final String? vatId;
  final String? iban;

  /// Texte der Dokumentart + Fußzeile + § 19 zum Finalisierungszeitpunkt
  /// (spätere Änderungen verändern das PDF nicht — Audit-Befund 2.1).
  final String? introText;
  final String? closingText;
  final String? footerText;
  final bool smallBusinessExempt;
}

String _date(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// C1 online: Projekt. [foundingYear] + [projectNumber] (PP) werden bei
/// Anlage eingefroren und nie neu vergeben (C2-Entscheidung).
class Project {
  const Project({
    required this.id,
    required this.companyId,
    required this.name,
    this.customerId,
    required this.status,
    required this.foundingYear,
    required this.projectNumber,
    required this.createdAt,
  });
  final String id;
  final String companyId;
  final String name;
  final String? customerId;

  /// `active` | `archived`
  final String status;
  final int foundingYear;
  final int projectNumber;
  final DateTime createdAt;

  /// Anzeige "JJ/PP", z. B. "26/03".
  String get displayNumber =>
      '${(foundingYear % 100).toString().padLeft(2, '0')}/${projectNumber.toString().padLeft(2, '0')}';

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'customerId': customerId,
        'status': status,
        'foundingYear': foundingYear,
        'projectNumber': projectNumber,
        'displayNumber': displayNumber,
        'createdAt': createdAt.toIso8601String(),
      };
}

/// C3 online: Zeitbuchung eines echten Nutzers auf einen Auftrag bzw.
/// eine Rechnung. [hourlyCostCents] ist der beim Buchen eingefrorene
/// Stundensatz des Mitglieds (spätere Satzänderungen ändern keine
/// gebuchten Kosten).
class TimeEntry {
  const TimeEntry({
    required this.id,
    required this.companyId,
    required this.userId,
    required this.documentId,
    this.projectId,
    required this.workDate,
    required this.hours,
    this.note,
    this.hourlyCostCents,
    required this.createdAt,
    required this.updatedAt,
  });
  final String id;
  final String companyId;
  final String userId;
  final String? documentId;
  final String? projectId;
  final DateTime workDate;

  /// Dezimal als Text (z. B. "1.5") — nie double.
  final String hours;
  final String? note;
  final int? hourlyCostCents;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, Object?> toJson() => {
        'id': id,
        'userId': userId,
        'documentId': documentId,
        'projectId': projectId,
        'date': _date(workDate),
        'hours': hours,
        'note': note,
        'hourlyCostCents': hourlyCostCents,
      };
}

/// Fachlicher Konflikt (409) — z. B. Bearbeiten eines finalisierten
/// Dokuments, veraltete Version, Löschen eines referenzierten Kunden.
class BusinessConflict implements Exception {
  const BusinessConflict(this.message);
  final String message;
  @override
  String toString() => message;
}
