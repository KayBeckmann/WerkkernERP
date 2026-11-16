import 'package:test/test.dart';
import 'package:werkkern_client/werkkern_client.dart';

void main() {
  test('profile layout round-trips and defaults to classic for older responses', () {
    expect(OnlineCompanyProfile.fromJson(const {}).pdfLayout, 'classic');
    final profile = OnlineCompanyProfile.fromJson(const {'pdfLayout': 'nordLetterhead'});
    expect(profile.pdfLayout, 'nordLetterhead');
    expect(profile.toJson()['pdfLayout'], 'nordLetterhead');
  });

  test('finalized document uses immutable snapshot and legacy classic', () {
    Map<String, Object?> json([String? layout]) => {
      'id': 'doc', 'customerId': 'customer', 'kind': 'invoice',
      'status': 'finalized', 'number': 'R-001', 'version': 2,
      'issueDate': '2026-01-01', 'serviceDate': '2026-01-01',
      'pdfLayoutSnapshot': ?layout,
    };
    expect(OnlineDocument.fromJson(json()).pdfLayoutSnapshot, 'classic');
    expect(OnlineDocument.fromJson(json('nordLetterhead')).pdfLayoutSnapshot, 'nordLetterhead');
    expect(OnlineDocument.fromJson({...json(), 'status': 'draft'}).pdfLayoutSnapshot, isNull);
  });
}
