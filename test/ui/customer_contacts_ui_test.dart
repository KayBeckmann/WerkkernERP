import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:werkkernerp/data/database/database.dart';
import 'package:werkkernerp/main.dart';
import 'package:werkkernerp/ui/widgets/customer_contacts.dart';
import 'package:werkkernerp/ui/widgets/sidebar_nav_item.dart';

/// Kay 2026-11-09: mehrere Kontaktpersonen je Kunde, Anrufen aus der App,
/// Kontaktperson am Angebot/an der Rechnung, Rechnungs-E-Mail mit Vorrang.
AppDatabase _inMemoryDb() =>
    AppDatabase.forTesting(NativeDatabase.memory(setup: (db) => db.execute('PRAGMA foreign_keys = ON;')));

Future<void> _field(WidgetTester tester, String label, String text) async {
  await tester.enterText(find.widgetWithText(TextField, label).last, text);
}

Future<void> _addContact(WidgetTester tester, String name, String role, {String? email, String? phone}) async {
  await tester.ensureVisible(find.text('Kontaktperson hinzufügen'));
  await tester.tap(find.text('Kontaktperson hinzufügen'));
  await tester.pumpAndSettle();
  await _field(tester, 'Name der Kontaktperson *', name);
  await _field(tester, 'Funktion', role);
  if (email != null) await _field(tester, 'E-Mail der Kontaktperson', email);
  if (phone != null) await _field(tester, 'Telefon der Kontaktperson', phone);
  await tester.tap(find.text('Übernehmen'));
  await tester.pumpAndSettle();
}

/// Dokument mit einer Position anlegen, Kontaktperson wählen, finalisieren
/// und den Versanddialog öffnen; liefert den vorausgefüllten Empfänger.
Future<String> _finalizeAndOpenMail(WidgetTester tester, String nav, String newLabel, String? contact) async {
  await tester.tap(find.widgetWithText(SidebarNavItem, nav));
  await tester.pumpAndSettle();
  await tester.tap(find.text(newLabel));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Remondis'));
  await tester.pumpAndSettle();
  if (contact != null) {
    await tester.ensureVisible(find.byKey(const Key('document-contact')));
    await tester.tap(find.byKey(const Key('document-contact')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(contact).last);
    await tester.pumpAndSettle();
  }
  await tester.tap(find.text('Position hinzufügen'));
  await tester.pumpAndSettle();
  await tester.enterText(find.widgetWithText(TextField, 'Beschreibung *'), 'Wartung');
  await tester.enterText(find.widgetWithText(TextField, 'Einzelpreis (€) *'), '100');
  await tester.tap(find.text('Hinzufügen'));
  await tester.pumpAndSettle();
  await tester.tap(find.byTooltip('Entwurf speichern'));
  await tester.pumpAndSettle();
  await tester.tap(find.byTooltip('Finalisieren'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Finalisieren'));
  await tester.pumpAndSettle();
  // Gespeichert: finalisiertes Angebot zeigt die Auswahl, Rechnung den Text.
  if (contact != null) expect(find.textContaining(contact), findsWidgets);
  await tester.tap(find.byTooltip('Per E-Mail senden'));
  await tester.pumpAndSettle();
  final to = tester
      .widgetList<TextField>(find.byType(TextField))
      .map((f) => f.controller?.text ?? '')
      .firstWhere((t) => t.contains('@'), orElse: () => '');
  await tester.tap(find.text('Abbrechen'));
  await tester.pumpAndSettle();
  return to;
}

void main() {
  testWidgets('Kontaktpersonen anlegen, anrufen, am Dokument zuweisen; Rechnungs-E-Mail hat Vorrang', (tester) async {
    tester.view.physicalSize = const Size(1200, 1100);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final calls = <Uri>[];
    phoneLauncher = (uri) async {
      calls.add(uri);
      return true;
    };
    addTearDown(() => phoneLauncher = (uri) async => false);

    await tester.pumpWidget(WerkkernErpApp(database: _inMemoryDb()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Firma anlegen'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Elektro Beckmann');
    await tester.tap(find.text('Anlegen'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(SidebarNavItem, 'Einstellungen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Module'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(SwitchListTile, 'Angebote'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(SwitchListTile, 'Versand (SMTP)'));
    await tester.pumpAndSettle();

    // Kunde mit zwei Kontaktpersonen und Rechnungs-E-Mail.
    await tester.tap(find.widgetWithText(SidebarNavItem, 'Kunden'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kunde anlegen'));
    await tester.pumpAndSettle();
    await _field(tester, 'Name *', 'Remondis');
    await _field(tester, 'E-Mail', 'info@remondis.example');
    await _field(tester, 'Telefon', '0201 / 123-0');
    await _field(tester, 'Rechnungs-E-Mail', 'rechnung@remondis.example');
    await _addContact(tester, 'Vincent', 'Betriebstechniker', email: 'vincent@remondis.example', phone: '0171 111');
    await _addContact(tester, 'Annika', 'Buchhaltung', email: 'annika@remondis.example');
    expect(find.text('Vincent (Betriebstechniker)'), findsOneWidget);
    await tester.tap(find.text('Anlegen'));
    await tester.pumpAndSettle();

    // Anrufen direkt aus der Liste und aus der Detailansicht.
    await tester.tap(find.byTooltip('Remondis anrufen'));
    await tester.pumpAndSettle();
    expect(calls.last.toString(), 'tel:02011230', reason: 'nur Ziffern und +');
    await tester.tap(find.text('Remondis'));
    await tester.pumpAndSettle();
    expect(find.text('Annika (Buchhaltung)'), findsOneWidget);
    expect(find.text('rechnung@remondis.example'), findsOneWidget);
    await tester.tap(find.byTooltip('Vincent anrufen'));
    await tester.pumpAndSettle();
    expect(calls.last.toString(), 'tel:0171111');
    expect(find.byTooltip('Annika anrufen'), findsNothing, reason: 'ohne Telefonnummer kein Anruf');
    await tester.pageBack();
    await tester.pumpAndSettle();

    // Angebot an Vincent geht an Vincent, Rechnung an die Rechnungs-E-Mail.
    expect(await _finalizeAndOpenMail(tester, 'Angebote', 'Neues Angebot', 'Vincent (Betriebstechniker)'),
        'vincent@remondis.example');
    expect(await _finalizeAndOpenMail(tester, 'Rechnungen', 'Neue Rechnung', 'Vincent (Betriebstechniker)'),
        'rechnung@remondis.example');
  });
}
