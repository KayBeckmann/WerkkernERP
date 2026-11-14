import 'package:shared_preferences/shared_preferences.dart';

/// Ablage der festen Einträge in der schmalen Bottom-Bar („Schnellzugriff“,
/// Kay-Feedback 2026-11-14: „Nicht jeder User braucht die gleichen Module
/// im Schnellzugriff“).
///
/// Bewusst eine **Geräte-/Nutzer-Einstellung** je Firma (gleiches Prinzip
/// wie [ThemePreferenceService]): per `shared_preferences` lokal auf dem
/// Gerät, getrennt nach [scope] (lokale Firma bzw. Server + Konto +
/// Online-Firma). Keine Firmen-/Geschäftsdatenspalte — sonst würde ein
/// Kollege in derselben Online-Firma die Leiste eines anderen verstellen
/// und ein Backup/Restore die Wahl eines fremden Geräts übernehmen.
abstract class QuickAccessStore {
  /// Gespeicherte Tab-Schlüssel in Reihenfolge; `null` = noch nie
  /// angepasst (dann gilt die Vorgabe der Shell).
  Future<List<String>?> load(String scope);

  Future<void> save(String scope, List<String> keys);
}

class PrefsQuickAccessStore implements QuickAccessStore {
  const PrefsQuickAccessStore();

  static String _key(String scope) => 'quick_access.$scope';

  /// Fängt `shared_preferences` bewusst ab (Widget-Tests ohne gemockten
  /// Plugin-Kanal): ein fehlender Zugriff bedeutet „Vorgabe“, kein Absturz.
  @override
  Future<List<String>?> load(String scope) async {
    try {
      return (await SharedPreferences.getInstance()).getStringList(_key(scope));
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> save(String scope, List<String> keys) async {
    try {
      await (await SharedPreferences.getInstance()).setStringList(_key(scope), keys);
    } catch (_) {
      // Die Wahl gilt zumindest für die laufende Sitzung weiter.
    }
  }
}

/// Für Widget-Tests — und um einen „Geräteneustart“ (neue Shell, gleicher
/// Store) nachzustellen.
class MemoryQuickAccessStore implements QuickAccessStore {
  final Map<String, List<String>> _values = {};

  @override
  Future<List<String>?> load(String scope) async => _values[scope];

  @override
  Future<void> save(String scope, List<String> keys) async => _values[scope] = List.of(keys);
}
