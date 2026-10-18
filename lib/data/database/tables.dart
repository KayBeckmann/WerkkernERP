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

  /// C10 Proforma-Rechnungen (Kay-Priorisierungsentscheidung 2026-10-17,
  /// Lücke aus dem RechnungsFee-Funktionsabgleich): wie Angebot/Auftrag/
  /// Lieferschein ein pro Firma ein-/ausblendbares Modul, Default aus.
  BoolColumn get proformaEnabled => boolean().withDefault(const Constant(false))();

  /// C1 Projekte (Kay-Priorisierungsentscheidung 2026-10-17): ebenfalls
  /// ein pro Firma ein-/ausblendbares Modul, Default aus — siehe
  /// [Projects].
  BoolColumn get projectsEnabled => boolean().withDefault(const Constant(false))();

  /// C6 Fuhrpark/Auswärtsmontage (Kay-Priorisierungsentscheidung
  /// 2026-10-17): ebenfalls ein pro Firma ein-/ausblendbares Modul,
  /// Default aus — siehe [Vehicles].
  BoolColumn get fleetEnabled => boolean().withDefault(const Constant(false))();

  /// C11 Wiederkehrende Rechnungen (Kay-Priorisierungsentscheidung
  /// 2026-10-17): ebenfalls ein pro Firma ein-/ausblendbares Modul,
  /// Default aus — siehe [RecurringInvoiceTemplates].
  BoolColumn get recurringInvoicesEnabled => boolean().withDefault(const Constant(false))();

  /// C13 Abschlagsrechnungen (Kay-Priorisierungsentscheidung 2026-10-17):
  /// schaltet nur den "Ist eine Abschlagsrechnung"-Schalter im
  /// Rechnungseditor und die Abschlags-Abrechnung in der Schlussrechnung
  /// frei — keine eigene Tabelle/Liste, siehe `Invoices.isAdvancePayment`.
  BoolColumn get advancePaymentInvoicesEnabled => boolean().withDefault(const Constant(false))();

  /// C12 Mahnwesen (Kay-Priorisierungsentscheidung 2026-10-17): schaltet
  /// Fälligkeitsdatum, Zahlungsstatus und die berechnete Mahnstufen-
  /// Anzeige im Rechnungseditor/-liste frei — keine eigene Tabelle.
  BoolColumn get dunningEnabled => boolean().withDefault(const Constant(false))();

  /// C12 Mahnwesen — Nachbesserung (Kay-Feedback 2026-10-17: "Wo stelle
  /// ich die Gebühren und die Fristen ein?"). **Kays eigene Werte**,
  /// keine von dieser App vorgegebenen oder rechtlich geprüften Fristen/
  /// Beträge — siehe ausführlichen Doc-Kommentar bei `DunningConfig` in
  /// `domain/services/dunning_service.dart`. Default-Fristen (14/28
  /// Tage) entsprechen den bisherigen festverdrahteten Werten, Default-
  /// Gebühren/Zins sind 0 (kein Automatismus ohne explizite Eingabe).
  IntColumn get dunningReminder2AfterDays => integer().withDefault(const Constant(14))();
  IntColumn get dunningReminder3AfterDays => integer().withDefault(const Constant(28))();
  IntColumn get dunningFeeLevel1Cents => integer().withDefault(const Constant(0))();
  IntColumn get dunningFeeLevel2Cents => integer().withDefault(const Constant(0))();
  IntColumn get dunningFeeLevel3Cents => integer().withDefault(const Constant(0))();
  RealColumn get dunningInterestRatePercent => real().withDefault(const Constant(0))();

  /// Einleitungs-/Schlusstext für ein erzeugtes Mahnschreiben — gleiches
  /// Muster wie die Dokumentart-Texte oben, aber nicht an einen
  /// [DocumentKind] gebunden (ein Mahnschreiben ist kein eigenständiges
  /// Dokument mit eigenem Nummernkreis, sondern ein Zusatzschreiben zu
  /// einer bereits finalisierten Rechnung).
  TextColumn get pdfIntroTextDunning => text().nullable()();
  TextColumn get pdfClosingTextDunning => text().nullable()();

  /// Anpassbare PDF-Texte (Kay-Nachtrag 2026-10-16: "Rechtstexte,
  /// Fußzeile und Kopfzeile in Dokumenten anpassbar machen"). Ursprünglich
  /// EIN gemeinsamer Satz für alle Dokumentarten — zweiter Nachtrag
  /// (2026-10-16): "Einleitungstext und Schlußtext müssen pro Dokument
  /// abweichend sein!" (Beispiele: Angebot braucht eine Bindefrist,
  /// Rechnung ein Zahlungsziel). `pdfIntroText`/`pdfClosingText` bleiben
  /// als Rechnungs-Text erhalten (keine Datenmigration/-verlust nötig,
  /// analog zu RechnungsFees unpräfigiertem `einleitungstext`/
  /// `schlusstext` für die Rechnung), die drei neuen Paare kommen für
  /// Angebot/Auftrag/Lieferschein dazu — exakt RechnungsFees Muster
  /// (`einleitungstext_angebot` usw., nur fachlich angeschaut, keine
  /// Code-/Text-Übernahme). Fußzeile bleibt bewusst gemeinsam (enthält
  /// typischerweise Firma/Anschrift, nicht dokumentartspezifisch).
  TextColumn get pdfIntroText => text().nullable()();
  TextColumn get pdfClosingText => text().nullable()();
  TextColumn get pdfIntroTextQuote => text().nullable()();
  TextColumn get pdfClosingTextQuote => text().nullable()();
  TextColumn get pdfIntroTextOrder => text().nullable()();
  TextColumn get pdfClosingTextOrder => text().nullable()();
  TextColumn get pdfIntroTextDeliveryNote => text().nullable()();
  TextColumn get pdfClosingTextDeliveryNote => text().nullable()();

  /// C10 Proforma-Rechnungen — eigenes Textpaar wie die übrigen drei
  /// optionalen Dokumentarten (gleiches Muster, siehe oben).
  TextColumn get pdfIntroTextProforma => text().nullable()();
  TextColumn get pdfClosingTextProforma => text().nullable()();
  TextColumn get pdfFooterText => text().nullable()();

  /// C7a SMTP-Versand (Kay-Nachfrage 2026-10-17: "Gibt es schon den SMTP
  /// Versand? Wo konfiguriere ich den Betreff und den Body der Mail?").
  /// Modul-Schalter wie bei den übrigen optionalen Bereichen, Default
  /// aus. Das SMTP-**Passwort** steht bewusst NICHT hier — die lokale
  /// SQLite-Datei ist (noch) unverschlüsselt (siehe F4-Hinweis in
  /// `connection.dart`) und wird 1:1 ins Backup-Zip gepackt; das Passwort
  /// liegt stattdessen in `flutter_secure_storage`
  /// (`domain/services/smtp_credential_store.dart`), referenziert über
  /// die Firmen-ID, nie über eine Spalte in dieser Tabelle.
  BoolColumn get smtpEnabled => boolean().withDefault(const Constant(false))();
  TextColumn get smtpHost => text().nullable()();
  IntColumn get smtpPort => integer().withDefault(const Constant(587))();
  TextColumn get smtpUsername => text().nullable()();
  TextColumn get smtpFromAddress => text().nullable()();
  TextColumn get smtpFromName => text().nullable()();
  BoolColumn get smtpUseTls => boolean().withDefault(const Constant(true))();

  /// Betreff/Text je Versandanlass — Kays ausdrückliche Nachfrage, wo das
  /// konfigurierbar ist. Freitext mit einfachen Platzhaltern
  /// (`{{kunde}}`, `{{nummer}}`, `{{firma}}`), ersetzt beim Öffnen des
  /// Versanddialogs (siehe `EmailSendDialog`) — danach im Dialog noch
  /// frei editierbar, nie stillschweigend unverändert versendet.
  TextColumn get smtpInvoiceSubjectTemplate => text().nullable()();
  TextColumn get smtpInvoiceBodyTemplate => text().nullable()();
  TextColumn get smtpDunningSubjectTemplate => text().nullable()();
  TextColumn get smtpDunningBodyTemplate => text().nullable()();

  /// C14 Buchhaltung (Kay-Priorisierungsentscheidung 2026-10-18, voller
  /// Umfang: Offene Posten + Belege/Ausgaben + Bankabgleich + DATEV-
  /// Export). EIN Modul-Schalter für den gesamten Buchhaltungsbereich
  /// (nicht pro Unterschritt) — die einzelnen Bausteine (C14.1–C14.5)
  /// kommen schrittweise dazu, teilen sich aber dasselbe Flag, weil Kay
  /// sie als ein zusammenhängendes Modul angefragt hat, nicht als
  /// unabhängige Funktionen.
  BoolColumn get buchhaltungEnabled => boolean().withDefault(const Constant(false))();

  /// C14.4 Bankabgleich per CSV (Kay-Priorisierungsentscheidung
  /// 2026-10-18: CSV statt MT940, trotz des höheren Aufwands bewusst so
  /// gewählt — jede Bank hat ein eigenes CSV-Spaltenschema, deshalb
  /// konfigurierbare Spaltenzuordnung statt eines bankspezifischen
  /// Parsers). `bankCsvDateColumn`/`bankCsvAmountColumn`/... sind je
  /// nach `bankCsvHasHeaderRow` entweder Spaltenüberschriften (Text)
  /// oder nullbasierte Spaltenindizes (als Text gespeichert, z. B.
  /// "2") — beides Freitext, damit kein zweites Spaltenpaar für die
  /// beiden Fälle nötig ist.
  TextColumn get bankCsvDelimiter => text().withDefault(const Constant(';'))();
  BoolColumn get bankCsvHasHeaderRow => boolean().withDefault(const Constant(true))();
  TextColumn get bankCsvDateColumn => text().nullable()();
  TextColumn get bankCsvAmountColumn => text().nullable()();
  TextColumn get bankCsvPurposeColumn => text().nullable()();
  TextColumn get bankCsvCounterpartyColumn => text().nullable()();

  /// `intl`-Musterformat, z. B. `dd.MM.yyyy` oder `yyyy-MM-dd`.
  TextColumn get bankCsvDateFormat => text().withDefault(const Constant('dd.MM.yyyy'))();

  /// `,` (deutsch, Standard) oder `.` (englisch/US) als Dezimaltrenner
  /// im Betragsfeld der CSV-Datei.
  TextColumn get bankCsvDecimalSeparator => text().withDefault(const Constant(','))();

  /// C14.5 DATEV-Export (Kay-Priorisierungsentscheidung 2026-10-18,
  /// letzter Baustein der vollen Buchhaltung, Kontenrahmen SKR03).
  /// Berater-/Mandantennummer sind Kays eigene Angaben von seinem
  /// Steuerberater/seiner DATEV-Kanzlei — diese App erfindet oder rät
  /// hier nichts. `datevBankGegenkonto` ist das Konto, gegen das Belege
  /// gebucht werden (typischerweise das Bank-/Kassenkonto, z. B. 1200
  /// in SKR03) — ebenfalls Kays eigene Angabe.
  TextColumn get datevBeraterNummer => text().nullable()();
  TextColumn get datevMandantNummer => text().nullable()();
  TextColumn get datevBankGegenkonto => text().nullable()();
  IntColumn get datevSachkontenlaenge => integer().withDefault(const Constant(4))();

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
///
/// Proforma ("PF") kam mit C10 (Kay-Priorisierungsentscheidung
/// 2026-10-17, Roadmap-Lücke aus dem RechnungsFee-Funktionsabgleich)
/// dazu — anders als der Lieferschein zeigt sie **alle** Positionstypen
/// inkl. Stunden und vollständige Preise/Steuern wie eine Rechnung,
/// ist aber **keine Rechnung im umsatzsteuerrechtlichen Sinne** (eigener
/// Nummernkreis, nicht GoBD-/Umsatz-relevant). Finalisierte Proforma ist
/// per `convertTo()` in eine echte Rechnung umwandelbar.
enum DocumentKind { invoice, quote, order, deliveryNote, proforma }

/// C12 Mahnwesen — bewusst binär (offen/bezahlt), keine Teilzahlungen
/// oder Zahlungseingänge aus einem Bankabgleich (das ist C7).
enum PaymentStatus { open, paid }

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

  /// PDF-Text-Schnappschuss zum Finalisierungszeitpunkt (Audit-Befund
  /// 2026-10-17, `Abweichungen.md` Abschnitt 2.1: "Ein später geänderter
  /// Text kann bei erneutem Teilen eine andere PDF-Fassung derselben
  /// finalisierten Rechnung erzeugen"). `buildInvoicePdf()` liest für
  /// finalisierte Dokumente **ausschließlich** diese drei Felder statt
  /// der aktuellen, möglicherweise seither geänderten Firmeneinstellungen
  /// — das PDF einer finalisierten Rechnung bleibt dadurch über die Zeit
  /// byte-identisch reproduzierbar, ohne die Texte selbst als Datei/BLOB
  /// archivieren zu müssen. `null` im Entwurf — dort gilt weiterhin live
  /// aus [Companies] gelesen (siehe `buildDraftPreviewPdf`).
  TextColumn get pdfIntroTextSnapshot => text().nullable()();
  TextColumn get pdfClosingTextSnapshot => text().nullable()();
  TextColumn get pdfFooterTextSnapshot => text().nullable()();

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

  /// C1 Projekte — optionale Zuordnung zu einem Projekt, über alle
  /// [DocumentKind]s hinweg nutzbar. `onDelete: setNull` statt cascade:
  /// ein gelöschtes Projekt darf keine bereits finalisierten Dokumente
  /// mitlöschen, nur die Zuordnung entfällt.
  TextColumn get projectId =>
      text().nullable().references(Projects, #id, onDelete: KeyAction.setNull)();

  /// C13 Abschlagsrechnungen (Kay-Priorisierungsentscheidung 2026-10-17):
  /// markiert eine Rechnung als Abschlags-/Anzahlungsrechnung statt einer
  /// regulären (Schluss-)Rechnung. **Arbeitsvorgabe, keine Rechtsprüfung**
  /// (analog zu F1/F2 — siehe Roadmap C13): nach gängiger deutscher
  /// Rechnungspraxis weist eine Abschlagsrechnung ihre eigene USt
  /// vollständig aus (keine aufgeschobene Steuer bis zur Schlussrechnung);
  /// die Schlussrechnung rechnet den Gesamtwert ab und zieht bereits
  /// gestellte, finalisierte Abschläge **inklusive** ihrer USt wieder ab
  /// (siehe `InvoiceRepository.sumAdvancePaymentsForOrder()`). Nur bei
  /// `kind == invoice` sinnvoll — Angebot/Auftrag/Lieferschein/Proforma
  /// kennen dieses Feld, setzen es aber nie.
  BoolColumn get isAdvancePayment => boolean().withDefault(const Constant(false))();

  /// C12 Mahnwesen (Kay-Priorisierungsentscheidung 2026-10-17): optionales
  /// Fälligkeitsdatum, vom Nutzer im Entwurf gesetzt. `null` = keine
  /// Fälligkeitsüberwachung für dieses Dokument. Nur bei `kind ==
  /// invoice` sinnvoll — siehe `domain/services/dunning_service.dart`
  /// für die reine Anzeige-Berechnung der Mahnstufe daraus (keine
  /// Mahngebühr/Verzugszins-Berechnung, das braucht eine eigene
  /// rechtliche Prüfung nach §286/288 BGB, siehe Roadmap C12).
  DateTimeColumn get dueDate => dateTime().nullable()();

  /// C12 Mahnwesen: reiner, **manuell** gesetzter Zahlungsstatus — kein
  /// Bankabgleich/automatische Zahlungserfassung (das ist C7, eigenes
  /// Entscheidungstor). Bewusst binär (offen/bezahlt), keine
  /// Teilzahlungen.
  TextColumn get paymentStatus =>
      textEnum<PaymentStatus>().withDefault(Constant(PaymentStatus.open.name))();
  DateTimeColumn get paidAt => dateTime().nullable()();

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

/// Status eines Projekts (C1). `archived` blendet es aus Auswahllisten
/// aus, ohne seine bereits zugeordneten Dokumente zu verändern — gleiches
/// Prinzip wie die Modul-Schalter ("Deaktivieren löscht keine Daten").
enum ProjectStatus { active, archived }

/// C1 Projekte (Kay-Priorisierungsentscheidung 2026-10-17, Brainstorming:
/// "Angebote, Aufträge, Rechnungen und weitere Vorgänge einem Projekt
/// zuordnen"). **Dies ist der C1-Kern**, bewusst ohne die in der Roadmap
/// als offen markierte Projekt-GuV und Stunden-Soll/Ist-Auswertung — die
/// brauchen eigene fachliche Entscheidungen (Erlös-/Kostenzeitpunkt,
/// interne Stundensätze, Gemeinkosten-/Fahrzeugumlage, Finanzrechte), die
/// laut Roadmap ausdrücklich noch mit Kay zu klären sind, nicht hier
/// vorweggenommen. Der Kern deckt die Grundanforderung ab: Dokumente
/// einem Projekt zuordnen und wiederfinden, ohne dass die erste
/// projektfreie Rechnung dadurch Pflicht wird (Brainstorming: "Erste
/// Rechnung bleibt projektfrei möglich").
class Projects extends Table {
  TextColumn get id => text()();
  TextColumn get companyId =>
      text().references(Companies, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text()();

  /// Optionaler Kundenbezug — ein Projekt kann, muss aber nicht genau
  /// einem Kunden zugeordnet sein (Brainstorming lässt das offen).
  TextColumn get customerId =>
      text().nullable().references(Customers, #id, onDelete: KeyAction.setNull)();
  TextColumn get notes => text().nullable()();
  TextColumn get status =>
      textEnum<ProjectStatus>().withDefault(Constant(ProjectStatus.active.name))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Kostenart einer Fahrzeugkosten-Buchung (C6). `other` deckt alles ab,
/// was noch nicht in eine eigene Kategorie gehört (z. B. Maut, Bußgeld).
enum VehicleCostCategory { fuel, maintenance, leasing, insurance, other }

/// C6 Fuhrpark/Auswärtsmontage (Kay-Priorisierungsentscheidung
/// 2026-10-17, Brainstorming: "Fahrzeuge je Firma mit Zuordnung, Kosten
/// und Terminen verwalten"). **Dies ist der C6-Kern**: Fahrzeuge
/// anlegen und Kosten erfassen. Bewusst OHNE die in der Roadmap als
/// offen markierte Umlage in eine Projekt-Ergebnisrechnung (Rate vs.
/// Tilgung, Verteilungsschlüssel) — die braucht erst eine entschiedene
/// Projekt-GuV-Methodik (C1), die es noch nicht gibt. [VehicleCostEntries]
/// trägt deshalb bereits eine optionale Projektzuordnung als reine
/// Markierung/Vormerkung, ohne dass irgendwo automatisch summiert oder
/// einer GuV zugerechnet wird.
class Vehicles extends Table {
  TextColumn get id => text()();
  TextColumn get companyId =>
      text().references(Companies, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text()();
  TextColumn get licensePlate => text().nullable()();
  TextColumn get notes => text().nullable()();

  /// Nächster TÜV-/Hauptuntersuchungstermin (Brainstorming: "TÜV-Termine
  /// ... Fälligkeiten"). `null` = nicht erfasst.
  DateTimeColumn get nextInspectionDate => dateTime().nullable()();
  BoolColumn get active => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class VehicleCostEntries extends Table {
  TextColumn get id => text()();

  /// Direkt auf der Buchung statt nur über [vehicleId] ableitbar — ein
  /// bewusst durchgehaltenes Muster in diesem Schema (siehe z. B.
  /// [Invoices].companyId trotz customerId), hält jede Abfrage
  /// unmittelbar companyId-filterbar statt über einen Join.
  TextColumn get companyId =>
      text().references(Companies, #id, onDelete: KeyAction.cascade)();
  TextColumn get vehicleId =>
      text().references(Vehicles, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get date => dateTime()();
  IntColumn get amountCents => integer()();
  TextColumn get category => textEnum<VehicleCostCategory>()();
  TextColumn get description => text().nullable()();

  /// Reine Markierung für eine spätere, noch zu entscheidende
  /// Projektumlage (siehe Klassendoc) — `onDelete: setNull`, ein
  /// gelöschtes Projekt darf keine Kostenbuchung mitreißen.
  TextColumn get projectId =>
      text().nullable().references(Projects, #id, onDelete: KeyAction.setNull)();
  DateTimeColumn get createdAt => dateTime()();

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

/// Intervall einer wiederkehrenden Rechnungsvorlage (C11).
enum RecurrenceInterval { monthly, quarterly, yearly }

/// C11 Wiederkehrende Rechnungen (Kay-Priorisierungsentscheidung
/// 2026-10-17, Lücke aus dem RechnungsFee-Funktionsabgleich). Eine
/// Vorlage erzeugt bei Fälligkeit einen **neuen Rechnungsentwurf** — nie
/// automatisch finalisiert, der Nutzer prüft/bestätigt wie bei jedem
/// anderen Entwurf (gleiches Prinzip wie `InvoiceRepository.convertTo()`).
///
/// **Ohne Server/Hintergrunddienst** kann die Fälligkeitsprüfung nur
/// beim Öffnen der App laufen, nicht als echter Cronjob (siehe Roadmap-
/// Entscheidung bei C11) — `RecurringInvoiceTemplateRepository.
/// generateDueDrafts()` holt dabei ausdrücklich **alle** fälligen
/// Perioden seit dem letzten Lauf nach (nicht nur die aktuell fällige),
/// damit eine länger nicht geöffnete App keine Rechnung stillschweigend
/// überspringt.
class RecurringInvoiceTemplates extends Table {
  TextColumn get id => text()();
  TextColumn get companyId =>
      text().references(Companies, #id, onDelete: KeyAction.cascade)();
  TextColumn get customerId =>
      text().references(Customers, #id, onDelete: KeyAction.restrict)();

  /// Freitext zur Wiedererkennung der Vorlage (z. B. "Hosting Kunde X
  /// monatlich") — keine der üblichen Rechnungsfelder, nur für die
  /// Vorlagenliste selbst.
  TextColumn get label => text()();
  TextColumn get interval => textEnum<RecurrenceInterval>()();

  /// Nächstes Fälligkeitsdatum — wird nach jeder Generierung um
  /// [interval] weitergeschoben (siehe Klassendoc).
  DateTimeColumn get nextDueDate => dateTime()();
  TextColumn get paymentTerms => text().nullable()();
  TextColumn get notes => text().nullable()();

  /// Pausiert statt gelöscht — gleiches "Deaktivieren löscht keine
  /// Daten"-Prinzip wie die Modul-Schalter und Projekte/Fahrzeuge.
  BoolColumn get active => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Positionen einer wiederkehrenden Vorlage — bewusst dieselben Felder
/// wie [InvoiceItems] (ohne `invoiceId`, dafür mit `templateId`), damit
/// sie 1:1 in `InvoiceItemInput` für `InvoiceRepository.createDraft()`
/// übersetzt werden können, ohne ein zweites Positionsmodell zu
/// erfinden.
class RecurringInvoiceTemplateItems extends Table {
  TextColumn get id => text()();
  TextColumn get templateId =>
      text().references(RecurringInvoiceTemplates, #id, onDelete: KeyAction.cascade)();
  TextColumn get kind => textEnum<InvoiceItemKind>()();
  TextColumn get articleId =>
      text().nullable().references(Articles, #id, onDelete: KeyAction.setNull)();
  TextColumn get description => text()();
  TextColumn get quantity => text()();
  IntColumn get unitPriceCents => integer()();
  RealColumn get vatRatePercent => real()();
  TextColumn get unit => text().nullable()();
  RealColumn get discountPercent => real().withDefault(const Constant(0))();
  TextColumn get groupLabel => text().nullable()();
  IntColumn get sortOrder => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

/// C14.2 Belege/Ausgaben (Kay-Priorisierungsentscheidung 2026-10-18,
/// voller Umfang der Buchhaltung — Kontenrahmen SKR03). Die konkreten
/// SKR03-**Kontonummern** stammen bewusst NICHT aus dieser App — ein
/// falsch erinnertes Kontonummern-Mapping wäre schlimmer als gar keins,
/// sobald es in einen DATEV-Export (C14.5) einfließt. Kay (mit seinem
/// Steuerberater) trägt die tatsächliche Kontonummer je Kategorie
/// selbst ein; diese App liefert nur die Struktur (eine kleine, editier-
/// bare Liste typischer Kategorien für ein Elektro-Kleingewerbe,
/// zunächst ohne Kontonummer).
class ExpenseCategories extends Table {
  TextColumn get id => text()();
  TextColumn get companyId =>
      text().references(Companies, #id, onDelete: KeyAction.cascade)();
  TextColumn get label => text()();

  /// SKR03-Kontonummer als Freitext (nicht als Integer — manche Konten-
  /// bezeichnungen haben führende Nullen oder Unterkonten-Suffixe).
  /// `null`, bis Kay sie selbst einträgt.
  TextColumn get skr03Account => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Eine einzelne Ausgabe/ein Beleg. Bewusst als Bruttobetrag + Steuersatz
/// erfasst (gleiches Muster wie eine Rechnungsposition, siehe F2) statt
/// Netto+Steuer getrennt einzugeben — ein Beleg zeigt in der Praxis den
/// Bruttobetrag, nicht den Vorsteuerbetrag.
class Expenses extends Table {
  TextColumn get id => text()();
  TextColumn get companyId =>
      text().references(Companies, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get date => dateTime()();
  TextColumn get description => text()();
  IntColumn get amountGrossCents => integer()();
  RealColumn get vatRatePercent => real()();

  /// `onDelete: setNull` — eine gelöschte/umbenannte Kategorie darf
  /// keinen bereits erfassten Beleg mitreißen (gleiches Prinzip wie bei
  /// `VehicleCostEntries.projectId`).
  TextColumn get categoryId =>
      text().nullable().references(ExpenseCategories, #id, onDelete: KeyAction.setNull)();

  /// Freitext für Lieferant/Belegnummer — kein eigener Lieferanten-
  /// Stammdatenbezug, das wäre für diesen Zweck Überkonstruktion.
  TextColumn get supplierReference => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

/// C14.4 Bankabgleich (Kay-Priorisierungsentscheidung 2026-10-18,
/// voller Umfang der Buchhaltung, CSV-Import). Eine importierte
/// Bank-Zeile — `amountCents` ist vorzeichenbehaftet (positiv =
/// Eingang, negativ = Ausgang, genau wie im Kontoauszug). **Nie
/// automatisches Buchen**: `matchedInvoiceId` wird ausschließlich durch
/// eine bewusste Nutzerbestätigung im Bankabgleich-Bildschirm gesetzt.
class BankTransactions extends Table {
  TextColumn get id => text()();
  TextColumn get companyId =>
      text().references(Companies, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get date => dateTime()();
  IntColumn get amountCents => integer()();
  TextColumn get purpose => text().nullable()();
  TextColumn get counterparty => text().nullable()();

  /// `onDelete: setNull` — eine gelöschte Rechnung darf keine bereits
  /// importierte Bank-Zeile mitreißen (gleiches Prinzip wie überall in
  /// diesem Schema).
  TextColumn get matchedInvoiceId =>
      text().nullable().references(Invoices, #id, onDelete: KeyAction.setNull)();

  /// Hash aus Datum+Betrag+Verwendungszweck+Auftraggeber — verhindert,
  /// dass ein erneuter Import derselben Export-Datei (z. B. mit
  /// überlappendem Zeitraum) doppelte Zeilen anlegt.
  TextColumn get importHash => text()();
  DateTimeColumn get importedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
