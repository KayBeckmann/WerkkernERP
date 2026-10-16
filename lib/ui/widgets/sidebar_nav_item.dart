import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Eine Navigationszeile in der Desktop/Web-Sidebar — aktiver Zustand
/// als Indigo-Pille (RechnungsFee-Layout-Muster), inaktiv dezent grau
/// mit Hover/Tap-Feedback statt der Material-3-Standard-NavigationRail.
class SidebarNavItem extends StatelessWidget {
  const SidebarNavItem({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeBg = isDark ? AppColors.indigoActiveBgDark : AppColors.indigoActiveBgLight;
    final activeFg = isDark ? AppColors.indigoLight : AppColors.indigo;
    final inactiveFg = isDark ? AppColors.slate400 : AppColors.slate600;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1.5),
      child: Material(
        color: selected ? activeBg : Colors.transparent,
        borderRadius: BorderRadius.circular(AppMetrics.rowRadius),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppMetrics.rowRadius),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(icon, size: 20, color: selected ? activeFg : inactiveFg),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: selected ? activeFg : inactiveFg,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
