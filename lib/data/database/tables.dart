import 'package:drift/drift.dart';

/// Eine lokal geführte Firma. Jede Firma ist vollständig datenseitig
/// isoliert — alle anderen Tabellen tragen eine companyId und werden
/// ausschließlich im Kontext der gerade gewählten Firma gelesen/
/// geschrieben (Roadmap A0: "unqualifizierte globale Listen/Suchen
/// vermeiden").
class Companies extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get address => text().nullable()();
  TextColumn get taxNumber => text().nullable()();
  TextColumn get vatId => text().nullable()();
  TextColumn get iban => text().nullable()();
  TextColumn get email => text().nullable()();
  TextColumn get phone => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  /// A5: Angebot/Auftrag sind pro Firma ein-/ausblendbare Module (nicht
  /// pro Nutzer — WerkkernERP hat bewusst kein Nutzerkonto/Login, Firma
  /// ist die einzige vorhandene Mandantengrenze). Default aus: Rechnung
  /// bleibt ohne Zusatzschritt direkt nutzbar (A0-Prinzip).
  BoolColumn get quotesEnabled => boolean().withDefault(const Constant(false))();
  BoolColumn get ordersEnabled => boolean().withDefault(const Constant(false))();
  BoolColumn get deliveryNotesEnabled => boolean().withDefault(const Constant(false))();

  /// Anpassbare PDF-Texte (Kay-Nachtrag 2026-10-16: "Rechtstexte,
  /// Fußzeile und Kopfzeile in Dokumenten anpassbar machen"). Gelten
  /// für alle drei Dokumentarten (Rechnung/Angebot/Auftrag) — anders
  /// als RechnungsFee (nur als fachliche Anregung angeschaut) bewusst
  /// EIN gemeinsamer Satz statt separater Texte je Dokumentart, um die
  /// Einstellungen nicht unnötig aufzublähen; bei Bedarf später pro
  /// Dokumentart aufteilbar, ohne Bestandsdaten zu verlieren.
  TextColumn get pdfIntroText => text().nullable()();
  TextColumn get pdfClosingText => text().nullable()();
  TextColumn get pdfFooterText => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class Customers extends Table {
  TextColumn get id => text()();
  TextColumn get companyId =>
      text().references(Companies, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text()();
  TextColumn get address => text().nullable()();
  TextColumn get email => text().nullable()();
  TextColumn get phone => text().nullable()();

  /// USt-IdNr. des Kunden (B2B/Reverse-Charge-Fälle) — eigenständig als
  /// Feld ergänzt (Kay-Nachtrag 2026-10-16: "es fehlen viele Datenfelder",
  /// RechnungsFee nur als fachliche Anregung angeschaut, keine Übernahme
  /// von Code/Feldnamen/Texten).
  TextColumn get vatId => text().nullable()();
  TextColumn get contactPerson => text().nullable()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class Suppliers extends Table {
  TextColumn get id => text()();
  TextColumn get companyId =>
      text().references(Companies, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text()();
  TextColumn get address => text().nullable()();
  TextColumn get email => text().nullable()();
  TextColumn get phone => text().nullable()();
  TextColumn get vatId => text().nullable()();
  TextColumn get contactPerson => text().nullable()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Artikelgruppe mit prozentualem Aufschlag (Kays Entscheidung, siehe
/// Brainstorming). Ungleich den Positionsgruppen einer Rechnung.
class ArticleGroups extends Table {
  TextColumn get id => text()();
  TextColumn get companyId =>
      text().references(Companies, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text()();

  /// Aufschlag in Prozent, z. B. 30.0 für 30 %.
  RealColumn get markupPercent => real()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class Articles extends Table {
  TextColumn get id => text()();
  TextColumn get companyId =>
      text().references(Companies, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text()();
  TextColumn get unit => text().nullable()();
  TextColumn get articleGroupId =>
      text().nullable().references(ArticleGroups, #id, onDelete: KeyAction.setNull)();

  /// Bevorzugter Kalkulations-Preisgeber (Brainstorming: "Standardlieferant
  /// gibt den bevorzugten Einkaufspreis für die Kalkulation vor"). `null`,
  /// solange kein Lieferant gesetzt ist — dann ist nur ein manueller
  /// Verkaufspreis möglich (siehe [manualSalePriceCents]).
  TextColumn get defaultSupplierId =>
      text().nullable().references(Suppliers, #id, onDelete: KeyAction.setNull)();

  /// Manuell abweichender Verkaufspreis (Minor Units/Cent). Überschreibt
  /// die Kalkulation aus Standardlieferant + Artikelgruppen-Aufschlag,
  /// falls gesetzt.
  IntColumn get manualSalePriceCents => integer().nullable()();

  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Einkaufspreis eines Artikels bei einem bestimmten Lieferanten — ein
/// Artikel kann mehrere Lieferanten mit je eigenem Preis haben
/// (Brainstorming: Mehrlieferanten-Preise).
class ArticleSupplierPrices extends Table {
  TextColumn get id => text()();
  TextColumn get articleId =>
      text().references(Articles, #id, onDelete: KeyAction.cascade)();
  TextColumn get supplierId =>
      text().references(Suppliers, #id, onDelete: KeyAction.cascade)();
  IntColumn get purchasePriceCents => integer()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
        {articleId, supplierId},
      ];
}

/// Art einer Rechnungsposition.
enum InvoiceItemKind { article, hours, text }

/// Status einer Rechnung. `draft` ist nummernlos und frei bearbeitbar,
/// `finalized` ist unveränderlich und trägt die vergebene Nummer
/// (Roadmap F3).
enum InvoiceStatus { draft, finalized }

/// Dokumentart. Rechnung ("R") existiert seit A2/A3; Angebot ("An")
/// und Auftrag ("A") kamen mit A5 dazu; Lieferschein ("LS") mit dem
/// Kay-Nachtrag 2026-10-16 — gleiche Tabelle/Positionslogik/
/// Finalisierung wie die Rechnung, aber eigene Nummernkreise (nie
/// vermischt) und ein eigenes PDF-Layout je Dokumentart. Ein
/// Lieferschein darf **keine** Stunden-Positionen enthalten (Kay:
/// "Lieferscheine sollen KEINE Stunden enthalten!!!") — durchgesetzt
/// in `InvoiceRepository.createDraft()`/`update()`, nicht nur in der
/// UI. Konvertierung Angebot→Auftrag/Lieferschein/Rechnung und
/// Auftrag→Lieferschein/Rechnung über `InvoiceRepository.convertTo()`.
enum DocumentKind { invoice, quote, order, deliveryNote }

class Invoices extends Table {
  TextColumn get id => text()();
  TextColumn get companyId =>
      text().references(Companies, #id, onDelete: KeyAction.cascade)();
  TextColumn get customerId =>
      text().references(Customers, #id, onDelete: KeyAction.restrict)();

  /// Default `invoice` für Bestandsdaten vor A5 (Migration, siehe
  /// `database.dart`).
  TextColumn get kind =>
      textEnum<DocumentKind>().withDefault(Constant(DocumentKind.invoice.name))();

  TextColumn get status => textEnum<InvoiceStatus>()();

  /// Vollständige Dokumentnummer, z. B. "R-26054". `null`, solange die
  /// Rechnung ein Entwurf ist.
  TextColumn get invoiceNumber => text().nullable()();

  /// Jahr des Nummernkreises (Finalisierungszeitpunkt, siehe F3). `null`
  /// im Entwurf.
  IntColumn get numberYear => integer().nullable()();

  DateTimeColumn get issueDate => dateTime()();

  /// Leistungsdatum/-zeitraum-Beginn (F1-Pflichtangabe).
  DateTimeColumn get serviceDate => dateTime()();

  TextColumn get paymentTerms => text().nullable()();
  TextColumn get notes => text().nullable()();

  /// Kundendaten-Schnappschuss zum Finalisierungszeitpunkt (Roadmap A1:
  /// spätere Stammdatenänderungen dürfen finalisierte PDFs nicht
  /// verändern). `null` im Entwurf — dort wird live aus [Customers]
  /// gelesen.
  TextColumn get customerSnapshotName => text().nullable()();
  TextColumn get customerSnapshotAddress => text().nullable()();
  TextColumn get customerSnapshotVatId => text().nullable()();

  /// Firmendaten-Schnappschuss zum Finalisierungszeitpunkt, aus demselben
  /// Grund wie der Kunden-Schnappschuss.
  TextColumn get companySnapshotName => text().nullable()();
  TextColumn get companySnapshotAddress => text().nullable()();
  TextColumn get companySnapshotTaxNumber => text().nullable()();
  TextColumn get companySnapshotVatId => text().nullable()();
  TextColumn get companySnapshotIban => text().nullable()();

  DateTimeColumn get finalizedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  /// Zeigt auf das **Quelldokument**, aus dem diese Zeile per
  /// `InvoiceRepository.convertTo()` erzeugt wurde (Kay-Nachtrag
  /// 2026-10-16: "Finalisierte Dokumente muss man wandeln können —
  /// Angebot in Auftrag, Lieferschein oder Rechnung"). `null` für
  /// eigenständig angelegte Dokumente. Bewusst ein einziges rückwärts
  /// zeigendes Feld statt eines eigenen Fremdschlüssels je möglicher
  /// Zielart (wie bei RechnungsFee) — ein Angebot kann so sowohl in
  /// einen Auftrag **als auch** separat in einen Lieferschein
  /// umgewandelt werden, beide neuen Zeilen zeigen einfach auf
  /// dasselbe Quelldokument zurück; `onDelete: setNull` ist nur
  /// defensiv, finalisierte Dokumente werden in der UI nie gelöscht.
  TextColumn get convertedFromId =>
      text().nullable().references(Invoices, #id, onDelete: KeyAction.setNull)();

  @override
  Set<Column> get primaryKey => {id};
}

class InvoiceItems extends Table {
  TextColumn get id => text()();
  TextColumn get invoiceId =>
      text().references(Invoices, #id, onDelete: KeyAction.cascade)();
  TextColumn get kind => textEnum<InvoiceItemKind>()();
  TextColumn get articleId =>
      text().nullable().references(Articles, #id, onDelete: KeyAction.setNull)();
  TextColumn get description => text()();

  /// Menge — Dezimalwert als Text gespeichert (siehe [Money]/Decimal-
  /// Nutzung, F2: keine Binär-Floats für Geld-/Mengenwerte).
  TextColumn get quantity => text()();
  IntColumn get unitPriceCents => integer()();
  RealColumn get vatRatePercent => real()();

  /// Einheit (z. B. "Stk", "h", "m", "pauschal") — Kay-Nachtrag
  /// 2026-10-16: "Es fehlen Details" beim Vergleich mit RechnungsFee.
  /// `null` = keine Einheit angegeben (z. B. Freitext-Pauschalposten).
  TextColumn get unit => text().nullable()();

  /// Rabatt in Prozent auf diese Position (Kay-Nachtrag 2026-10-16,
  /// analog zu RechnungsFees `rabatt_prozent` — nur als fachliche
  /// Anregung angeschaut, keine Code-/Text-Übernahme). Wird auf den
  /// Netto-Betrag **vor** Steuerberechnung angewendet, siehe
  /// `InvoiceLineInput.lineNet`.
  RealColumn get discountPercent => real().withDefault(const Constant(0))();

  /// Positionsgruppe (z. B. "Elektroinstallation EG") — ungleich der
  /// Artikelgruppe im Stamm. `null` = ungruppierte Position.
  TextColumn get groupLabel => text().nullable()();
  IntColumn get sortOrder => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Nummernkreis je Firma, Dokumenttyp und Jahr (Roadmap: "eigene
/// Dokument-Nummernkreise; keine Vermischung zwischen Firmen", "eigene
/// Folgen je Firma, Dokumenttyp und Jahr"). `lastNumber` ist ein
/// unbegrenzter Integer (F5: nie wiederverwendete Nummern, kein
/// Stellen-Cap — das Anzeigeformat wächst über `xxx` hinaus natürlich).
class NumberSequences extends Table {
  TextColumn get companyId =>
      text().references(Companies, #id, onDelete: KeyAction.cascade)();

  /// `DocumentKind.name`, also "invoice"/"quote"/"order"/"deliveryNote"
  /// (Präfixe "R"/"An"/"A"/"LS"). Gutschrift ("G") kommt erst mit Phase C.
  TextColumn get documentType => text()();
  IntColumn get year => integer()();
  IntColumn get lastNumber => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {companyId, documentType, year};
}
