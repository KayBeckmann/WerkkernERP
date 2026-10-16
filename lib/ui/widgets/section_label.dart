import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Dezente, großgeschriebene Gruppenüberschrift in der Sidebar-
/// Navigation (z.B. "Fakturierung", "Stammdaten") — Layout-Muster
/// von RechnungsFee übernommen, eigenständig in Flutter nachgebaut.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.label, {super.key});
  final String label;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.1,
          color: isDark ? AppColors.slate500 : AppColors.slate400,
        ),
      ),
    );
  }
}
