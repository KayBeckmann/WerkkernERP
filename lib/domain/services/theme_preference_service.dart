import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Hell/Dunkel/System-Auswahl in den Einstellungen (Kay-Nachtrag
/// 2026-10-16: "Design in den Einstellungen konfigurieren"). Bewusst
/// eine **Geräte-/Viewer-Einstellung** (per `shared_preferences`
/// lokal auf dem Gerät gespeichert), keine Firmen-/Geschäftsdatenspalte
/// — sonst würde ein Firmenwechsel ungewollt auch das Design wechseln,
/// und ein Backup/Restore würde die Design-Wahl eines fremden Geräts
/// übernehmen.
class ThemePreferenceService extends ChangeNotifier {
  static const _prefsKey = 'theme_mode';

  ThemeMode _mode = ThemeMode.system;
  ThemeMode get mode => _mode;

  /// Lädt die gespeicherte Wahl nach — Default bleibt `system`, bis das
  /// abgeschlossen ist (kein blockierendes Warten beim App-Start). Fängt
  /// `shared_preferences` bewusst ab: in Widget-Tests ohne gemockten
  /// Plugin-Kanal würde das sonst jeden Test treffen, der die App
  /// pumpt — ein fehlender/fehlerhafter Zugriff bedeutet einfach "Default
  /// System", kein Absturz.
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getString(_prefsKey);
      _mode = _fromStored(stored);
      notifyListeners();
    } catch (_) {
      // Default (system) bleibt bestehen.
    }
  }

  Future<void> setMode(ThemeMode mode) async {
    _mode = mode;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, mode.name);
    } catch (_) {
      // Auswahl gilt zumindest für die laufende Session weiter, auch
      // wenn das Speichern fehlschlägt (z. B. kein Speicherzugriff).
    }
  }

  ThemeMode _fromStored(String? value) => switch (value) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
}
