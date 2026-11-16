import 'package:flutter_test/flutter_test.dart';
import 'package:werkkern_client/werkkern_client.dart';
import 'package:werkkernerp/pdf/invoice_pdf_builder.dart';
import 'package:werkkernerp/ui/screens/online/online_pdf_layout.dart';

void main() {
  OnlineDocument doc({String status = 'finalized', String? snapshot}) => OnlineDocument(
    id: 'doc', customerId: 'customer', kind: 'invoice', status: status,
    issueDate: DateTime.utc(2026), serviceDate: DateTime.utc(2026), version: 1,
    pdfLayoutSnapshot: snapshot,
  );

  test('draft preview selects live preference', () {
    expect(documentPdfLayout(doc(status: 'draft'), liveCompany: const OnlineCompanyProfile(pdfLayout: 'nordLetterhead')),
        PdfLayout.nordLetterhead);
  });
  test('issued document selects snapshot even after company changes', () {
    expect(documentPdfLayout(doc(snapshot: 'nordLetterhead'), liveCompany: const OnlineCompanyProfile()),
        PdfLayout.nordLetterhead);
  });
  test('legacy issued documents remain classic', () {
    expect(documentPdfLayout(doc(), liveCompany: const OnlineCompanyProfile(pdfLayout: 'nordLetterhead')),
        PdfLayout.classic);
  });
}
