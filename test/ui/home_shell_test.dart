import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:werkkernerp/data/database/database.dart';
import 'package:werkkernerp/main.dart';
import 'package:werkkernerp/ui/widgets/sidebar_nav_item.dart';

/// Deckt die mit dem RechnungsFee-Layout-Update eingeführte Adaptivität
/// von `HomeShell` ab: schmal (Android-Smartphone) → Bottom-Navigation
/// wie bisher; breit (Kays Web-/LAN-Vorschau, Desktop-Browser) → neue
/// gruppierte Sidebar statt Bottom-Navigation.
AppDatabase _inMemoryDb() =>
    AppDatabase.forTesting(NativeDatabase.memory(setup: (db) => db.execute('PRAGMA foreign_keys = ON;')));

Future<void> _createCompanyAndEnter(WidgetTester tester) async {
  await tester.pumpWidget(WerkkernErpApp(database: _inMemoryDb()));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Firma anlegen'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField), 'Elektro Beckmann');
  await tester.tap(find.text('Anlegen'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Schmales Fenster (Android-Smartphone) zeigt Bottom-Navigation, keine Sidebar', (
    tester,
  ) async {
    // tester.view statt des veralteten binding.setSurfaceSize — setzt
    // zusätzlich devicePixelRatio=1, sonst entspricht die physische
    // Pixelgröße nicht der von MediaQuery gelesenen logischen Breite
    // (Default-devicePixelRatio der Testumgebung ist nicht 1).
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _createCompanyAndEnter(tester);

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(SidebarNavItem), findsNothing);
  });

  testWidgets('Breites Fenster (Web/Desktop) zeigt gruppierte Sidebar statt Bottom-Navigation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _createCompanyAndEnter(tester);

    expect(find.byType(SidebarNavItem), findsWidgets);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('Sidebar-Navigation wechselt den angezeigten Bereich', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await _createCompanyAndEnter(tester);

    // Sanity-Check: Sidebar ist wirklich aktiv (sonst würde ein Tap auf
    // "Kunden" fälschlich über die Bottom-Navigation treffen und die
    // eigentliche Sidebar-Navigation wäre nicht getestet).
    expect(find.byType(SidebarNavItem), findsWidgets);
    expect(find.text('Noch keine Rechnungsentwürfe.'), findsOneWidget);

    await tester.tap(find.text('Kunden'));
    await tester.pumpAndSettle();

    expect(find.text('Noch keine Kunden angelegt.'), findsOneWidget);
  });
}
