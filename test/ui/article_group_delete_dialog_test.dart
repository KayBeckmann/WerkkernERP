import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:werkkernerp/ui/widgets/article_group_delete_dialog.dart';

void main() {
  testWidgets('confirmation shows current count and cancellation never chooses deletion', (tester) async {
    DeleteGroupChoice? result;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) => Scaffold(body: TextButton(
      onPressed: () async => result = await showArticleGroupDeleteDialog(context, 'Material', 3),
      child: const Text('Open'),
    )))));
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.textContaining('3 Artikel'), findsOneWidget);
    expect(find.text('Artikel löschen'), findsOneWidget);
    expect(find.text('Artikel ohne Gruppe behalten'), findsOneWidget);
    await tester.tap(find.text('Abbrechen'));
    await tester.pumpAndSettle();
    expect(result, isNull);
  });

  for (final choice in DeleteGroupChoice.values) {
    testWidgets('explicit ${choice.name} button returns only its choice', (tester) async {
      DeleteGroupChoice? result;
      await tester.pumpWidget(MaterialApp(home: Builder(builder: (context) => Scaffold(body: TextButton(
        onPressed: () async => result = await showArticleGroupDeleteDialog(context, 'Leer', 0),
        child: const Text('Open'),
      )))));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.textContaining('0 Artikel'), findsOneWidget);
      await tester.tap(find.text(choice == DeleteGroupChoice.ungroup
          ? 'Artikel ohne Gruppe behalten' : 'Artikel löschen'));
      await tester.pumpAndSettle();
      expect(result, choice);
    });
  }
}
