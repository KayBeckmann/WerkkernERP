import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:werkkernerp/ui/screens/ecad_material_screen.dart';

void main() {
  testWidgets('reopening same packet visibly resets explicit article mapping', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final input = File(
      'test/fixtures/libre_ecad_material.json',
    ).readAsStringSync();
    var reads = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: EcadMaterialScreen(
          companyId: 'test',
          companyName: 'TEST Firma',
          readFile: () async => input,
          loadArticles: () async {
            reads++;
            return [
              {'id': 'erp-id', 'name': 'TEST ERP Ziel', 'unit': 'Stk'},
            ];
          },
        ),
      ),
    );
    await tester.tap(find.text('LibreECAD-Datei öffnen'));
    await tester.pumpAndSettle();
    expect(find.text('Offen lassen'), findsNWidgets(3));
    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('TEST ERP Ziel · erp-id').last);
    await tester.pumpAndSettle();
    expect(find.text('TEST ERP Ziel · erp-id').hitTestable(), findsOneWidget);
    await tester.tap(find.text('LibreECAD-Datei öffnen'));
    await tester.pumpAndSettle();
    expect(reads, 2);
    expect(find.text('Offen lassen').hitTestable(), findsNWidgets(3));
    expect(find.text('TEST ERP Ziel · erp-id').hitTestable(), findsNothing);
    expect(find.byType(DropdownButtonFormField<String>), findsNWidgets(3));
  });
}
