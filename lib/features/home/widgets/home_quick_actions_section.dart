import 'package:flutter/material.dart';

import '../../../config/theme/app_colors.dart';
import '../../../l10n/ar.dart';

class HomeQuickActionsSection extends StatelessWidget {
  final VoidCallback onAddExpense;
  final VoidCallback onCreatePoll;
  final VoidCallback onAddMaqadi;
  final VoidCallback onCapturePhoto;

  const HomeQuickActionsSection({
    super.key,
    required this.onAddExpense,
    required this.onCreatePoll,
    required this.onAddMaqadi,
    required this.onCapturePhoto,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.cl;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          Ar.quickActions,
          style: TextStyle(
            fontSize: 15.2,
            fontWeight: FontWeight.w900,
            color: c.t1,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _QuickTile(
                icon: Icons.add_shopping_cart_rounded,
                label: 'مقاضي',
                color: c.warning,
                onTap: onAddMaqadi,
              ),
            ),
            const SizedBox(width: 7),
            Expanded(
              child: _QuickTile(
                icon: Icons.add_card_rounded,
                label: 'مصروف',
                color: c.success,
                onTap: onAddExpense,
              ),
            ),
            const SizedBox(width: 7),
            Expanded(
              child: _QuickTile(
                icon: Icons.how_to_vote_rounded,
                label: 'تصويت',
                color: const Color(0xFF60A5FA),
                onTap: onCreatePoll,
              ),
            ),
            const SizedBox(width: 7),
            Expanded(
              child: _QuickTile(
                icon: Icons.camera_alt_rounded,
                label: 'صورة',
                color: c.error,
                onTap: onCapturePhoto,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _QuickTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const _QuickTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.cl;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(17),
      child: Container(
        height: 66,
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.060),
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: color.withValues(alpha: 0.09)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.9,
                color: c.t2,
                fontWeight: FontWeight.w800,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
