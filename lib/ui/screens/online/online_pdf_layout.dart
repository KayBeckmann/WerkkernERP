import 'package:werkkern_client/werkkern_client.dart';

import '../../../pdf/invoice_pdf_builder.dart' show PdfLayout;

/// Drafts use the current profile; issued documents use their stored layout.
PdfLayout documentPdfLayout(OnlineDocument document, {OnlineCompanyProfile? liveCompany}) {
  final name = document.isDraft ? liveCompany?.pdfLayout : document.pdfLayoutSnapshot;
  return name == 'nordLetterhead' ? PdfLayout.nordLetterhead : PdfLayout.classic;
}
