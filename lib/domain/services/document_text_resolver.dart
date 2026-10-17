import '../../data/database/database.dart';
import '../../data/database/tables.dart';

/// Einleitungs-/Schlusstext je Dokumentart (Kay-Nachtrag 2026-10-16,
/// zweiter Nachtrag: "müssen pro Dokument abweichend sein" — Angebot
/// braucht z. B. eine Bindefrist, Rechnung ein Zahlungsziel). Rechnung
/// nutzt weiterhin die unpräfigierten Firmenfelder (siehe Doc-Kommentar
/// bei `Companies.pdfIntroText` in tables.dart).
///
/// Eigenständige Datei statt privater Funktionen im PDF-Builder: wird
/// seit dem Audit-Befund 2026-10-17 (`Abweichungen.md` Abschnitt 2.1)
/// auch von `InvoiceRepository.finalize()` gebraucht, um die zum
/// Finalisierungszeitpunkt gültigen Texte als Schnappschuss
/// einzufrieren — Daten- und PDF-Schicht sollen dafür nicht
/// gegenseitig voneinander importieren müssen.
String? introTextFor(Company company, DocumentKind kind) => switch (kind) {
      DocumentKind.invoice => company.pdfIntroText,
      DocumentKind.quote => company.pdfIntroTextQuote,
      DocumentKind.order => company.pdfIntroTextOrder,
      DocumentKind.deliveryNote => company.pdfIntroTextDeliveryNote,
      DocumentKind.proforma => company.pdfIntroTextProforma,
    };

String? closingTextFor(Company company, DocumentKind kind) => switch (kind) {
      DocumentKind.invoice => company.pdfClosingText,
      DocumentKind.quote => company.pdfClosingTextQuote,
      DocumentKind.order => company.pdfClosingTextOrder,
      DocumentKind.deliveryNote => company.pdfClosingTextDeliveryNote,
      DocumentKind.proforma => company.pdfClosingTextProforma,
    };
