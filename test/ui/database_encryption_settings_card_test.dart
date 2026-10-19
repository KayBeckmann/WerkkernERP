import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:werkkernerp/data/database/database.dart';
import 'package:werkkernerp/domain/services/database_encryption_service.dart';
import 'package:werkkernerp/main.dart';
import 'package:werkkernerp/ui/widgets/sidebar_nav_item.dart';

/// F4-Verschlüsselung (Kay-Entscheidung 2026-10-19: "Verschlüsselung
/// soll optional sein und der User soll entscheiden ob ein Passwort
/// oder ein Geräteschlüssel verwendet wird") — UI-Flow in den
/// Einstellungen. Nutzt eine In-Memory-Variante des Settings-Stores
/// (siehe `database_encryption_service_test.dart` für die Begründung)
/// und einen Fake-`PathProviderPlatform` (wie `backup_service_test.dart`),
/// damit `applyChange()` gegen eine echte temporäre Datei migrieren kann.
class _FakeDbEncryptionSettingsStore extends DbEncryptionSettingsStore {
  bool enabled = false;
  DbKeyType keyType = DbKeyType.device;
  String? deviceKeyValue;

  @override
  Future<bool> readEnabled() async => enabled;

  @override
  Future<void> writeEnabled(bool value) async => enabled = value;

  @override
  Future<DbKeyType> readKeyType() async => keyType;

  @override
  Future<void> writeKeyType(DbKeyType value) async => keyType = value;

  @override
  Future<String?> readDeviceKey() async => deviceKeyValue;

  @override
  Future<void> writeDeviceKey(String value) async => deviceKeyValue = value;
}

class _FakePathProviderPlatform extends PathProviderPlatform {
  final _tempDir = Directory.systemTemp.createTempSync('werkkernerp_encryption_ui_test_');

  @override
  Future<String?> getTemporaryPath() async => _tempDir.path;

  @override
  Future<String?> getApplicationDocumentsPath() async => _tempDir.path;
}

AppDatabase _inMemoryDb() =>
    AppDatabase.forTesting(NativeDatabase.memory(setup: (db) => db.execute('PRAGMA foreign_keys = ON;')));

void main() {
  // Reihenfolge wichtig: `ensureInitialized()` muss VOR dem Setzen des
  // Fakes laufen, sonst registriert die echte path_provider-Plugin-
  // Registrierung ihre MethodChannel-Implementierung erst später und
  // überschreibt den Fake wieder — die echte Implementierung hängt
  // sich dann ohne Plattform-Kanal auf, statt eine Exception zu
  // werfen (siehe auch `backup_service_test.dart`, gleiche Reihenfolge).
  TestWidgetsFlutterBinding.ensureInitialized();
  PathProviderPlatform.instance = _FakePathProviderPlatform();

  testWidgets(
    'Datenbank verschlüsseln aktivieren (Geräteschlüssel), Übernehmen zeigt einen '
    'Neustart-Hinweis und der Schalter bleibt danach an',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final store = _FakeDbEncryptionSettingsStore();
      final service = DatabaseEncryptionService(store: store);

      await tester.pumpWidget(
        WerkkernErpApp(database: _inMemoryDb(), databaseEncryptionService: service),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Firma anlegen'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Elektro Beckmann');
      await tester.tap(find.text('Anlegen'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(SidebarNavItem, 'Einstellungen'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Datenbank-Verschlüsselung'));
      await tester.pumpAndSettle();

      expect(store.enabled, isFalse, reason: 'F4 ist standardmäßig aus');

      await tester.tap(find.widgetWithText(SwitchListTile, 'Datenbank verschlüsseln'));
      await tester.pumpAndSettle();

      // Default-Auswahl ist "Geräteschlüssel" — kein Passwortfeld nötig.
      expect(find.text('Geräteschlüssel'), findsOneWidget);
      expect(find.text('Passwort bestätigen'), findsNothing);

      // `_apply()` macht echte `dart:io`-Dateizugriffe (PRAGMA rekey auf
      // der echten Temp-Datei) — die laufen in `testWidgets()`s fake-
      // async-Zone sonst nie zu Ende (siehe Flutter-Doku zu
      // `runAsync()`). Tap + das Warten auf die echte Arbeit deshalb
      // zusammen in `runAsync()`, danach ganz normal weiter pumpen.
      await tester.runAsync(() async {
        await tester.tap(find.text('Übernehmen'));
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pumpAndSettle();

      expect(find.text('Neustart erforderlich'), findsOneWidget);
      await tester.tap(find.text('Verstanden'));
      await tester.pumpAndSettle();

      expect(store.enabled, isTrue);
      expect(store.keyType, DbKeyType.device);
      expect(store.deviceKeyValue, isNotNull, reason: 'Geräteschlüssel wurde erzeugt und gespeichert');

      final switchTile = tester.widget<SwitchListTile>(find.widgetWithText(SwitchListTile, 'Datenbank verschlüsseln'));
      expect(switchTile.value, isTrue);
    },
  );

  testWidgets(
    'Verschlüsselung mit Passwort ohne Bestätigung zeigt einen Fehlerhinweis statt zu übernehmen',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 3000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final store = _FakeDbEncryptionSettingsStore();
      final service = DatabaseEncryptionService(store: store);

      await tester.pumpWidget(
        WerkkernErpApp(database: _inMemoryDb(), databaseEncryptionService: service),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Firma anlegen'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Elektro Beckmann');
      await tester.tap(find.text('Anlegen'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(SidebarNavItem, 'Einstellungen'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Datenbank-Verschlüsselung'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(SwitchListTile, 'Datenbank verschlüsseln'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Passwort'));
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextField, 'Neues Passwort'), 'start123');
      await tester.enterText(find.widgetWithText(TextField, 'Passwort bestätigen'), 'anders456');

      await tester.ensureVisible(find.text('Übernehmen'));
      await tester.tap(find.text('Übernehmen'));
      await tester.pumpAndSettle();

      expect(find.text('Die beiden Passwörter stimmen nicht überein.'), findsOneWidget);
      expect(store.enabled, isFalse, reason: 'bei Fehler keine Übernahme');
    },
  );
}
