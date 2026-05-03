import 'package:flutter/material.dart';

import '../../../config/theme/app_colors.dart';
import '../../../l10n/ar.dart';

class OpenClosedBadge extends StatelessWidget {
  final bool isOpen;
  final double fontSize;
  const OpenClosedBadge({super.key, required this.isOpen, this.fontSize = 10});

  @override
  Widget build(BuildContext context) {
    final c = context.cl;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isOpen ? c.successM : c.errorM,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        isOpen ? Ar.openNow : Ar.closed,
        style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w600,
            color: isOpen ? c.success : c.error),
      ),
    );
  }
}

class StoreBadge extends StatelessWidget {
  final String label;
  final Color color;
  final double fontSize;
  const StoreBadge({super.key, required this.label, required this.color, this.fontSize = 11});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(label,
        style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w600, color: color)),
  );
}

class SmallBadge extends StatelessWidget {
  final String label;
  final Color color;
  const SmallBadge({super.key, required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(5),
    ),
    child: Text(label,
        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: color)),
  );
}
