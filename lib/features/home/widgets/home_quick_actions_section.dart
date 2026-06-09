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


  static const _maqadiGold = Color(0xFFD6A13F);
  static const _expenseGreen = Color(0xFF006C35);
  static const _pollFire = Color(0xFFF28C38);
  static const _albumLavender = Color(0xFFA477E8);

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
                accent: _maqadiGold,
                onTap: onAddMaqadi,
              ),
            ),
            const SizedBox(width: 7),
            Expanded(
              child: _QuickTile(
                icon: Icons.add_card_rounded,
                label: 'مصروف',
                accent: _expenseGreen,
                onTap: onAddExpense,
              ),
            ),
            const SizedBox(width: 7),
            Expanded(
              child: _QuickTile(
                icon: Icons.how_to_vote_rounded,
                label: 'تصويت',
                accent: _pollFire,
                onTap: onCreatePoll,
              ),
            ),
            const SizedBox(width: 7),
            Expanded(
              child: _QuickTile(
                icon: Icons.camera_alt_rounded,
                label: 'صورة',
                accent: _albumLavender,
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
  final Color accent;
  final VoidCallback? onTap;

  const _QuickTile({
    required this.icon,
    required this.label,
    required this.accent,
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
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [
              Color.lerp(const Color(0xFF10263A), accent, .22)!,
              Color.lerp(const Color(0xFF071321), accent, .10)!,
            ],
          ),
          borderRadius: BorderRadius.circular(17),
          border: Border.all(
            color: accent.withValues(alpha: .20),
          ),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: .06),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: accent),
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
