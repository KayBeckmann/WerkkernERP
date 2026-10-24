import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:werkkernerp/ui/screens/online/online_login_screen.dart';

import 'online_test_server.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('KI-Zugang erzeugen; Agent fragt Finalisierung an; Bestätigung in der App finalisiert', (tester) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final server = OnlineTestServer();
    late String docId;
    await tester.runAsync(() async {
      final token = await server.seedCompany(
        email: 'kay@example.com',
        companyName: 'Elektro Kay',
        permissions: ['customers.read', 'customers.write', 'invoices.read', 'invoices.write', 'invoices.finalize'],
      );
      await server.put('/company/modules', {'modules': ['aiAgents']}, token);
      final customer = await server.post('/customers', {'name': 'Meyer'}, token);
      docId = (await server.post('/documents', {
        'customerId': customer['id'],
        'items': [
          {'kind': 'text', 'description': 'Pauschale', 'quantity': '1', 'unitPriceCents': 10000, 'vatRatePercent': 19},
        ],
      }, token))['id'] as String;
    });

    await tester.pumpWidget(MaterialApp(
      home: OnlineLoginScreen(clientFactory: (_) => server.client(), offlineStoreFactory: () => null),
    ));
    await tester.enterText(find.byKey(const Key('online-server')), 'erp.example.org');
    await tester.enterText(find.byKey(const Key('online-email')), 'kay@example.com');
    await tester.enterText(find.byKey(const Key('online-password')), 'passwort-12345');
    await tester.tap(find.text('Anmelden'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Elektro Kay'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('KI-Zugang und Freigaben'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('KI-Zugang erzeugen'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('online-agent-label')), 'Claude Desktop');
    await tester.tap(find.text('Erzeugen'));
    await tester.pumpAndSettle();
    final agentToken = tester.widget<SelectableText>(find.byKey(const Key('online-agent-token'))).data!;
    expect(agentToken, startsWith('wka_'));
    await tester.tap(find.text('Fertig'));
    await tester.pumpAndSettle();
    expect(find.text('Claude Desktop'), findsOneWidget);

    // Der Agent (z. B. über MCP) fragt die Finalisierung an.
    final requested = await tester.runAsync(() async {
      final agent = server.client()..token = agentToken;
      return agent.request('POST', '/documents/$docId/finalize', body: {'version': 1});
    });
    expect((requested as Map)['status'], 'pending');

    await tester.tap(find.byTooltip('Aktualisieren'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Rechnung für Meyer über 119,00 €'), findsOneWidget);
    await tester.tap(find.text('Bestätigen'));
    await tester.pumpAndSettle();
    expect(find.text('Bestätigt und ausgeführt.'), findsOneWidget);
    expect(find.text('Bestätigt'), findsOneWidget);

    final document = await tester.runAsync(() async {
      final agent = server.client()..token = agentToken;
      return agent.document(docId);
    });
    expect(document!.isDraft, isFalse);
    expect(document.number, isNotNull);
  });
}
