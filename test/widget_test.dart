import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:werkkernerp/data/database/database.dart';
import 'package:werkkernerp/main.dart';

AppDatabase _inMemoryDb() =>
    AppDatabase.forTesting(NativeDatabase.memory(setup: (db) => db.execute('PRAGMA foreign_keys = ON;')));

void main() {
  testWidgets('App startet ohne Server/Login direkt in der Firmenauswahl', (tester) async {
    await tester.pumpWidget(WerkkernErpApp(database: _inMemoryDb()));
    await tester.pumpAndSettle();

    expect(find.text('WerkkernERP — Firmen'), findsOneWidget);
    expect(find.text('Firma anlegen'), findsOneWidget);
  });

  testWidgets('Firma anlegen führt direkt in den Firmenkontext (kein Login/Server)', (
    tester,
  ) async {
    await tester.pumpWidget(WerkkernErpApp(database: _inMemoryDb()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Firma anlegen'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Elektro Beckmann');
    await tester.tap(find.text('Anlegen'));
    await tester.pumpAndSettle();

    expect(
      find.byWidgetPredicate(
        (widget) => widget is Text && (widget.data ?? '').contains('Elektro Beckmann'),
      ),
      findsWidgets,
    );
  });
}
