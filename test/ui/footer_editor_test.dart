import 'package:flutter_test/flutter_test.dart';
import 'package:werkkernerp/ui/screens/online/online_admin_screen.dart';

void main() {
  test('saved empty footer column remains empty in settings editor', () {
    expect(footerEditorInitialText({'left': null}, 'left', '{{companyName}}'), '');
    expect(footerEditorInitialText(null, 'left', '{{companyName}}'), '{{companyName}}');
  });
}
