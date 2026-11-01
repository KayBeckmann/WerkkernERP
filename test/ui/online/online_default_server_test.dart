import 'package:flutter_test/flutter_test.dart';
import 'package:werkkernerp/ui/screens/online/online_login_screen.dart';

void main() {
  test('Web: eigener Origin + /api, unabhängig vom Pfad der Seite', () {
    expect(
      defaultOnlineServerUrl(web: true, base: Uri.parse('https://erp.kay-beckmann.de/#/start'), configured: ''),
      'https://erp.kay-beckmann.de/api',
    );
    expect(
      defaultOnlineServerUrl(web: true, base: Uri.parse('http://10.10.2.123:8085/'), configured: ''),
      'http://10.10.2.123:8085/api',
    );
  });

  test('Fest eingebaute Adresse hat Vorrang; native Apps ohne Vorgabe bleiben leer', () {
    expect(defaultOnlineServerUrl(web: true, configured: 'https://erp.example.org/api'), 'https://erp.example.org/api');
    expect(defaultOnlineServerUrl(web: false, configured: 'https://erp.example.org/api'), 'https://erp.example.org/api');
    expect(defaultOnlineServerUrl(web: false, configured: ''), '');
  });
}
