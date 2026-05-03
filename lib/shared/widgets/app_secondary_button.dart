import 'package:flutter/material.dart';

import '../../config/theme/app_colors.dart';

class AppSecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color? color;
  final double height;
  const AppSecondaryButton({super.key, required this.label, this.onPressed, this.icon, this.color, this.height = 48});

  @override
  Widget build(BuildContext context) {
    final c = context.cl;
    final clr = color ?? c.accent;
    return SizedBox(
      width: double.infinity,
      height: height,
      child: icon != null
          ? OutlinedButton.icon(
              onPressed: onPressed,
              icon: Icon(icon, color: clr, size: 18),
              label: Text(label, style: TextStyle(color: clr)),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: clr.withValues(alpha: 0.3)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            )
          : OutlinedButton(
              onPressed: onPressed,
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: clr.withValues(alpha: 0.3)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: Text(label, style: TextStyle(color: clr)),
            ),
    );
  }
}
