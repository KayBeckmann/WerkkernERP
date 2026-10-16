import 'package:flutter/material.dart';

/// Design-Tokens, visuell an RechnungsFee angelehnt (Farbpalette/Layout-
/// Muster, siehe `~/git/RechnungsFee-reference`, AGPL-3.0) — **kein**
/// Code, keine Vorlagen, Texte, Icons oder Assets von dort übernommen,
/// nur eigenständig in Flutter/Material 3 nachgebaute Werte:
/// Indigo-Akzent, Slate-Neutraltöne, kompakte abgerundete Listenzeilen,
/// gruppierte Navigation mit dezenten Sektionsbeschriftungen.
class AppColors {
  AppColors._();

  static const indigo = Color(0xFF4F46E5);
  static const indigoLight = Color(0xFF6366F1);

  // Slate-Neutraltöne (Tailwind-Skala) für Hintergründe/Text/Ränder.
  static const slate50 = Color(0xFFF8FAFC);
  static const slate100 = Color(0xFFF1F5F9);
  static const slate200 = Color(0xFFE2E8F0);
  static const slate300 = Color(0xFFCBD5E1);
  static const slate400 = Color(0xFF94A3B8);
  static const slate500 = Color(0xFF64748B);
  static const slate600 = Color(0xFF475569);
  static const slate700 = Color(0xFF334155);
  static const slate800 = Color(0xFF1E293B);
  static const slate900 = Color(0xFF0F172A);

  static const indigoActiveBgLight = Color(0xFFEEF2FF); // indigo-50
  static const indigoActiveBgDark = Color(0xFF1E1B4B); // indigo-950
}

/// Gemeinsame Abstands-/Formwerte, damit Sidebar, Bottom-Nav und
/// Listenkarten konsistent wirken statt Material-3-Default-Rundungen.
class AppMetrics {
  AppMetrics._();

  static const sidebarWidth = 240.0;
  static const wideLayoutBreakpoint = 840.0;
  static const rowRadius = 8.0;
  static const cardRadius = 10.0;
}

ThemeData buildAppTheme({required Brightness brightness}) {
  final isDark = brightness == Brightness.dark;

  final colorScheme = ColorScheme.fromSeed(
    seedColor: AppColors.indigo,
    brightness: brightness,
    primary: AppColors.indigo,
    surface: isDark ? AppColors.slate900 : AppColors.slate50,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: isDark ? AppColors.slate900 : AppColors.slate50,
    canvasColor: isDark ? AppColors.slate900 : AppColors.slate50,
    dividerColor: isDark ? AppColors.slate700 : AppColors.slate200,
    appBarTheme: AppBarTheme(
      backgroundColor: isDark ? AppColors.slate900 : Colors.white,
      foregroundColor: isDark ? AppColors.slate100 : AppColors.slate800,
      elevation: 0,
      scrolledUnderElevation: 1,
      surfaceTintColor: Colors.transparent,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: isDark ? AppColors.slate900 : Colors.white,
      indicatorColor: isDark ? AppColors.indigoActiveBgDark : AppColors.indigoActiveBgLight,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final active = states.contains(WidgetState.selected);
        return TextStyle(
          fontSize: 11,
          fontWeight: active ? FontWeight.w600 : FontWeight.w500,
          color: active
              ? (isDark ? AppColors.indigoLight : AppColors.indigo)
              : (isDark ? AppColors.slate400 : AppColors.slate500),
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        final active = states.contains(WidgetState.selected);
        return IconThemeData(
          color: active
              ? (isDark ? AppColors.indigoLight : AppColors.indigo)
              : (isDark ? AppColors.slate400 : AppColors.slate500),
        );
      }),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: isDark ? AppColors.slate800.withValues(alpha: 0.5) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppMetrics.cardRadius),
        side: BorderSide(color: isDark ? AppColors.slate700 : AppColors.slate200),
      ),
      margin: EdgeInsets.zero,
    ),
    listTileTheme: ListTileThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppMetrics.rowRadius)),
      iconColor: isDark ? AppColors.slate400 : AppColors.slate500,
    ),
    dividerTheme: DividerThemeData(color: isDark ? AppColors.slate700 : AppColors.slate200),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: isDark ? AppColors.slate800 : AppColors.slate100,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppMetrics.rowRadius),
        borderSide: BorderSide.none,
      ),
    ),
    fontFamily: 'Roboto',
  );
}
