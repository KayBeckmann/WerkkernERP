import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:werkkernerp/data/database/database.dart';
import 'package:werkkernerp/data/repositories/company_repository.dart';
import 'package:werkkernerp/data/repositories/pdf_archive_repository.dart';
import 'package:werkkernerp/main.dart';
import 'package:werkkernerp/ui/screens/document_archive_screen.dart';
import 'package:werkkernerp/ui/widgets/sidebar_nav_item.dart';
import 'package:werkkern_client/werkkern_client.dart';
import 'package:werkkernerp/domain/services/online_session.dart';
import 'package:werkkernerp/ui/screens/online/online_home_screen.dart';
import 'package:werkkernerp/ui/screens/online/online_document_archive_screen.dart';

class _ArchiveClient extends WerkkernApiClient {
  _ArchiveClient() : super(baseUrl: Uri.parse('https://example.invalid'));
  final paths = <String>[];
  @override
  Future<Object?> request(
    String method,
    String path, {
    Object? body,
    Map<String, String>? query,
  }) async {
    paths.add('$method $path');
    if (path == '/pdf-archive/versions') {
      return {
        'versions': [
          {
            'sourceType': 'document',
            'sourceId': 'invoice-1',
            'version': 2,
            'createdAt': '2026-11-18T12:00:00Z',
          },
          {
            'sourceType': 'purchase-order',
            'sourceId': 'po-1',
            'version': 1,
            'createdAt': '2026-11-17T12:00:00Z',
          },
        ],
      };
    }
    return {'versions': []};
  }
}

class _PagedArchiveClient extends _ArchiveClient {
  final offsets = <int>[];
  @override
  Future<Object?> request(
    String method,
    String path, {
    Object? body,
    Map<String, String>? query,
  }) async {
    offsets.add(int.parse(query!['offset']!));
    final first = offsets.length == 1;
    return {
      'versions': [
        {
          'sourceType': 'purchase-order',
          'sourceId': first ? 'po-first' : 'po-second',
          'version': 1,
          'createdAt': '2026-11-18T12:00:00Z',
        },
      ],
      'hasMore': first,
    };
  }
}

void main() {
  testWidgets(
    'offline menu always shows the global archive and browses saved sources',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final companies = CompanyRepository(db);
      final company = await companies.create(name: 'Archivfirma');
      final archive = PdfArchiveRepository(db);
      await archive.storeGenerated(
        companyId: company.id,
        sourceType: PdfArchiveSource.customerDocument,
        sourceId: 'invoice-1',
        bytes: Uint8List.fromList([37, 80, 68, 70]),
      );
      await archive.storeGenerated(
        companyId: company.id,
        sourceType: PdfArchiveSource.purchaseOrder,
        sourceId: 'po-1',
        bytes: Uint8List.fromList([37, 80, 68, 70]),
      );
      await tester.pumpWidget(WerkkernErpApp(database: db));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Archivfirma'));
      await tester.pumpAndSettle();
      expect(
        find.widgetWithText(SidebarNavItem, 'Dokumentenablage'),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(SidebarNavItem, 'Dokumentenablage'));
      await tester.pumpAndSettle();
      expect(find.byType(DocumentArchiveScreen), findsOneWidget);
      expect(find.textContaining('invoice-1'), findsOneWidget);
      expect(find.textContaining('po-1'), findsOneWidget);
    },
  );

  testWidgets(
    'online archive tab is independent of modules and hides inaccessible source rows',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final client = _ArchiveClient();
      final session = OnlineSession(
        client: client,
        serverUrl: Uri.parse('https://example.invalid'),
        email: 'test@example.invalid',
        companyId: 'tenant',
        companyName: 'Tenant',
        isAdmin: false,
        permissions: {'invoices.read'},
        modules: {},
      );
      await tester.pumpWidget(
        MaterialApp(home: OnlineHomeScreen(session: session)),
      );
      await tester.pumpAndSettle();
      expect(
        find.widgetWithText(SidebarNavItem, 'Dokumentenablage'),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(SidebarNavItem, 'Dokumentenablage'));
      await tester.pumpAndSettle();
      expect(client.paths, contains('GET /pdf-archive/versions'));
      expect(find.textContaining('invoice-1'), findsOneWidget);
      expect(find.textContaining('po-1'), findsNothing);
    },
  );

  testWidgets('online archive paginates across the tenant index', (
    tester,
  ) async {
    final client = _PagedArchiveClient();
    final session = OnlineSession(
      client: client,
      serverUrl: Uri.parse('https://example.invalid'),
      email: 'test@example.invalid',
      companyId: 'tenant',
      companyName: 'Tenant',
      isAdmin: false,
      permissions: {'purchaseOrders.read'},
      modules: {},
    );
    await tester.pumpWidget(
      MaterialApp(home: OnlineDocumentArchiveScreen(session: session)),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('po-first'), findsOneWidget);
    expect(find.textContaining('po-second'), findsOneWidget);
    expect(client.offsets, [0, 1]);
  });

  testWidgets(
    'archive needs a document read right, independent of module switches',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final session = OnlineSession(
        client: _ArchiveClient(),
        serverUrl: Uri.parse('https://example.invalid'),
        email: 'test@example.invalid',
        companyId: 'tenant',
        companyName: 'Tenant',
        isAdmin: false,
        permissions: {},
        modules: {},
      );
      await tester.pumpWidget(
        MaterialApp(home: OnlineHomeScreen(session: session)),
      );
      await tester.pumpAndSettle();
      expect(
        find.widgetWithText(SidebarNavItem, 'Dokumentenablage'),
        findsNothing,
      );
    },
  );
}
