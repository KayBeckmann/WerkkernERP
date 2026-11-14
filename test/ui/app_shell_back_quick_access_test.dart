import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:werkkernerp/domain/services/quick_access_store.dart';
import 'package:werkkernerp/ui/widgets/app_shell.dart';
import 'package:werkkernerp/ui/widgets/sidebar_nav_item.dart';

/// Kay-Feedback 2026-11-14 (Android): „Wenn ich in einem Screen bin und
/// ‚zurück‘ drücke, möchte ich nicht auf der Auswahl der Firma landen oder
/// die App beenden, sondern nur einen Screen zurück.“ und „Die
/// Navigationsleiste am unteren Rand bei kleinen Bildschirmen sollte auch
/// modular sein.“
///
/// Die Shell wird hier ohne Datenbank direkt mit synthetischen Bereichen
/// getestet; die Android-Zurück-Taste ist `handlePopRoute()` (derselbe
/// Weg, den die Plattform über den `navigation`-Kanal auslöst).
enum _Tab { dashboard, invoices, customers, articles, settings }

/// Bereich mit einem Knopf, der eine Detailseite öffnet — über
/// `Navigator.of(context)`, also schmal auf der App-Wurzel, breit im
/// Inhalts-Navigator neben der Sidebar.
class _Area extends StatelessWidget {
  const _Area(this.name);
  final String name;

  @override
  Widget build(BuildContext context) => Center(
        child: FilledButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => Scaffold(appBar: AppBar(title: Text('Detail $name')), body: Text('Detailinhalt $name')),
            ),
          ),
          child: Text('Inhalt $name'),
        ),
      );
}

const _tabs = [
  ShellTab(id: _Tab.dashboard, icon: Icons.dashboard, title: 'Dashboard', screen: _Area('Dashboard'), section: ShellSection.dashboard),
  ShellTab(id: _Tab.invoices, icon: Icons.receipt, title: 'Rechnungen', screen: _Area('Rechnungen'), section: ShellSection.fakturierung),
  ShellTab(id: _Tab.customers, icon: Icons.group, title: 'Kunden', screen: _Area('Kunden'), section: ShellSection.stammdaten),
  ShellTab(id: _Tab.articles, icon: Icons.inventory, title: 'Artikel', screen: _Area('Artikel'), section: ShellSection.stammdaten),
  ShellTab(id: _Tab.settings, icon: Icons.settings, title: 'Einstellungen', screen: _Area('Einstellungen'), section: ShellSection.einstellungen),
];

Widget _shell({QuickAccessStore? store}) => AppShell(
      companyName: 'Elektro Test',
      tabs: _tabs,
      pinnedNarrowIds: const [_Tab.dashboard, _Tab.invoices, _Tab.customers],
      onSwitchCompany: () {},
      quickAccessScope: 'test:firma-1',
      quickAccessStore: store ?? MemoryQuickAccessStore(),
    );

/// Startet wie die echte App mit einer Vorseite (Firmenauswahl) und der
/// Shell darüber — so zeigt sich, wann „Zurück“ die Firma wirklich verlässt.
Future<void> _open(WidgetTester tester, Size size, {QuickAccessStore? store}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final navigator = GlobalKey<NavigatorState>();
  await tester.pumpWidget(MaterialApp(navigatorKey: navigator, home: const Scaffold(body: Text('Firmenauswahl'))));
  navigator.currentState!.push(MaterialPageRoute<void>(builder: (_) => _shell(store: store)));
  await tester.pumpAndSettle();
  expect(find.text('Firmenauswahl'), findsNothing);
}

Future<void> _back(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
  await tester.pumpAndSettle();
}

void main() {
  group('Zurück (Android) schmal', () {
    testWidgets('schließt erst die Detailseite, dann die zuvor besuchten Bereiche, zuletzt die Firma', (tester) async {
      await _open(tester, const Size(400, 800));
      expect(find.text('Inhalt Dashboard'), findsOneWidget);

      await tester.tap(find.text('Rechnungen'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kunden'));
      await tester.pumpAndSettle();
      expect(find.text('Elektro Test — Kunden'), findsOneWidget);

      // Detailseite aus dem Bereich heraus öffnen …
      await tester.tap(find.text('Inhalt Kunden'));
      await tester.pumpAndSettle();
      expect(find.text('Detailinhalt Kunden'), findsOneWidget);

      // … Zurück schließt nur sie — der Bereich bleibt „Kunden“.
      await _back(tester);
      expect(find.text('Detailinhalt Kunden'), findsNothing);
      expect(find.text('Elektro Test — Kunden'), findsOneWidget);
      expect(find.text('Firmenauswahl'), findsNothing);

      // Zurück durch den Bereichsverlauf, nicht sofort raus.
      await _back(tester);
      expect(find.text('Elektro Test — Rechnungen'), findsOneWidget);
      await _back(tester);
      expect(find.text('Elektro Test — Dashboard'), findsOneWidget);
      expect(find.text('Firmenauswahl'), findsNothing);

      // Erst auf dem Ausgangsbereich verlässt Zurück die Firma.
      await _back(tester);
      expect(find.text('Firmenauswahl'), findsOneWidget);
    });

    testWidgets('Verlauf hält jeden Bereich nur einmal (keine Schleife)', (tester) async {
      await _open(tester, const Size(400, 800));
      for (final title in ['Rechnungen', 'Kunden', 'Dashboard', 'Kunden']) {
        await tester.tap(find.text(title));
        await tester.pumpAndSettle();
      }
      // Verlauf: Rechnungen → Dashboard (Kunden steckt nur einmal darin).
      await _back(tester);
      expect(find.text('Elektro Test — Dashboard'), findsOneWidget);
      await _back(tester);
      expect(find.text('Elektro Test — Rechnungen'), findsOneWidget);
      await _back(tester);
      expect(find.text('Firmenauswahl'), findsOneWidget);
    });

    testWidgets('über „Mehr“ gewählter Bereich steht ebenfalls im Verlauf', (tester) async {
      await _open(tester, const Size(400, 800));
      await tester.tap(find.text('Mehr'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Artikel'));
      await tester.pumpAndSettle();
      expect(find.text('Elektro Test — Artikel'), findsOneWidget);
      await _back(tester);
      expect(find.text('Elektro Test — Dashboard'), findsOneWidget);
      expect(find.text('Firmenauswahl'), findsNothing);
    });
  });

  group('Zurück (Android) breit', () {
    testWidgets('schließt die Detailseite im Inhaltsbereich statt der ganzen Shell', (tester) async {
      await _open(tester, const Size(1200, 800));
      expect(find.byType(SidebarNavItem), findsWidgets);

      await tester.tap(find.widgetWithText(SidebarNavItem, 'Kunden'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Inhalt Kunden'));
      await tester.pumpAndSettle();
      expect(find.text('Detailinhalt Kunden'), findsOneWidget);
      expect(find.byType(SidebarNavItem), findsWidgets);

      await _back(tester);
      expect(find.text('Detailinhalt Kunden'), findsNothing);
      expect(find.text('Inhalt Kunden'), findsOneWidget);
      expect(find.text('Firmenauswahl'), findsNothing);

      await _back(tester);
      expect(find.text('Inhalt Dashboard'), findsOneWidget);
      await _back(tester);
      expect(find.text('Firmenauswahl'), findsOneWidget);
    });
  });

  group('Schnellzugriff (schmale Bottom-Bar)', () {
    testWidgets('Vorgabe Dashboard/Rechnungen/Kunden + Mehr; Stecknadel in „Mehr“ ändert die Leiste', (tester) async {
      final store = MemoryQuickAccessStore();
      await _open(tester, const Size(400, 1200), store: store);
      Iterable<String> bar() =>
          tester.widgetList<NavigationDestination>(find.byType(NavigationDestination)).map((d) => d.label);
      expect(bar(), ['Dashboard', 'Rechnungen', 'Kunden', 'Mehr']);

      await tester.tap(find.text('Mehr'));
      await tester.pumpAndSettle();
      // Kunden raus, Artikel rein — die Übersicht bleibt dabei offen.
      final pinArtikel = find.descendant(
        of: find.widgetWithText(ListTile, 'Artikel'),
        matching: find.byTooltip('In den Schnellzugriff aufnehmen'),
      );
      await tester.tap(pinArtikel);
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(
        of: find.widgetWithText(ListTile, 'Kunden'),
        matching: find.byTooltip('Aus dem Schnellzugriff entfernen'),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Mehr'), findsOneWidget, reason: 'Übersicht weiterhin offen');

      await _back(tester);
      expect(bar(), ['Dashboard', 'Rechnungen', 'Artikel', 'Mehr']);
      expect(await store.load('test:firma-1'), ['dashboard', 'invoices', 'articles']);
    });

    testWidgets('höchstens vier Einträge, mindestens einer — mit Hinweis', (tester) async {
      await _open(tester, const Size(400, 1200));
      await tester.tap(find.text('Mehr'));
      await tester.pumpAndSettle();
      Finder pin(String title, String tooltip) =>
          find.descendant(of: find.widgetWithText(ListTile, title), matching: find.byTooltip(tooltip));

      await tester.tap(pin('Artikel', 'In den Schnellzugriff aufnehmen'));
      await tester.pumpAndSettle();
      await tester.tap(pin('Einstellungen', 'In den Schnellzugriff aufnehmen'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Höchstens 4 Bereiche'), findsOneWidget);
      expect(pin('Einstellungen', 'In den Schnellzugriff aufnehmen'), findsOneWidget, reason: 'nicht aufgenommen');

      for (final title in ['Dashboard', 'Rechnungen', 'Kunden']) {
        await tester.tap(pin(title, 'Aus dem Schnellzugriff entfernen'));
        await tester.pumpAndSettle();
      }
      await tester.tap(pin('Artikel', 'Aus dem Schnellzugriff entfernen'));
      await tester.pumpAndSettle();
      expect(find.text('Mindestens ein Bereich bleibt im Schnellzugriff.'), findsOneWidget);

      await _back(tester);
      final labels =
          tester.widgetList<NavigationDestination>(find.byType(NavigationDestination)).map((d) => d.label).toList();
      expect(labels, ['Artikel', 'Mehr']);
    });

    testWidgets('gespeicherte Auswahl überlebt einen Neustart der Shell; fehlende Bereiche werden übersprungen',
        (tester) async {
      final store = MemoryQuickAccessStore();
      await store.save('test:firma-1', ['articles', 'nicht-mehr-da', 'dashboard']);
      await _open(tester, const Size(400, 800), store: store);
      final labels =
          tester.widgetList<NavigationDestination>(find.byType(NavigationDestination)).map((d) => d.label).toList();
      // Reihenfolge wie in der Navigation, nicht wie gespeichert.
      expect(labels, ['Dashboard', 'Artikel', 'Mehr']);
    });
  });
}
