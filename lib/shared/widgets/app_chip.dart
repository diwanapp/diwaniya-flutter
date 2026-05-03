import 'package:flutter/material.dart';

import '../../config/theme/app_colors.dart';

class AppChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? activeColor;
  final IconData? icon;
  const AppChip({super.key, required this.label, required this.selected, required this.onTap, this.activeColor, this.icon});

  @override
  Widget build(BuildContext context) {
    final c = context.cl;
    final clr = activeColor ?? c.accent;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? clr.withValues(alpha: 0.12) : c.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? clr.withValues(alpha: 0.3) : c.border),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: selected ? clr : c.t3),
            const SizedBox(width: 5),
          ],
          Text(label, style: TextStyle(fontSize: 12,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
              color: selected ? clr : c.t2)),
        ]),
      ),
    );
  }
}
