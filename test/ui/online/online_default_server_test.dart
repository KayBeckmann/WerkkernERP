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

  test('Fest eingebaute Adresse hat Vorrang; native Apps ohne Vorgabe nehmen das Produktiv-Backend', () {
    expect(defaultOnlineServerUrl(web: true, configured: 'https://erp.example.org/api'), 'https://erp.example.org/api');
    expect(
      defaultOnlineServerUrl(web: false, configured: 'https://erp.example.org/api'),
      'https://erp.example.org/api',
    );
    expect(defaultOnlineServerUrl(web: false, configured: ''), werkkernProductionServerUrl);
  });

  test('Gespeichertes lokales Test-Backend überdeckt die öffentliche Vorgabe nicht', () {
    const prod = 'https://erp.kay-beckmann.de/api';
    expect(restoredOnlineServerUrl(null, fallback: prod), prod);
    expect(restoredOnlineServerUrl('http://10.10.2.123:8085/api', fallback: prod), prod);
    expect(restoredOnlineServerUrl('http://192.168.1.20:8080', fallback: prod), prod);
    expect(restoredOnlineServerUrl('localhost:8080', fallback: prod), prod);
    expect(restoredOnlineServerUrl('https://erp.example.org/api', fallback: prod), 'https://erp.example.org/api');
    // Lokale Web-App (Vorgabe selbst lokal): gespeicherte Adresse bleibt.
    expect(
      restoredOnlineServerUrl('http://10.10.2.123:8085/api', fallback: 'http://localhost:8080/api'),
      'http://10.10.2.123:8085/api',
    );
  });
}
