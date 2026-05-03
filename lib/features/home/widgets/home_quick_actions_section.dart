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
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: c.t1,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 88,
          child: LayoutBuilder(
            builder: (context, constraints) {
              const gap = 6.0;
              final itemWidth = ((constraints.maxWidth - (gap * 3)) / 4)
                  .clamp(68.0, 78.0)
                  .toDouble();

              return ListView(
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.none,
                physics: const BouncingScrollPhysics(),
                children: [
                  _QA(
                    icon: Icons.add_shopping_cart_rounded,
                    label: 'أضف مقاضي',
                    color: c.warning,
                    onTap: onAddMaqadi,
                    width: itemWidth,
                  ),
                  const SizedBox(width: gap),
                  _QA(
                    icon: Icons.add_card_rounded,
                    label: Ar.addExpense,
                    color: c.accent,
                    onTap: onAddExpense,
                    width: itemWidth,
                  ),
                  const SizedBox(width: gap),
                  _QA(
                    icon: Icons.how_to_vote_rounded,
                    label: Ar.createPoll,
                    color: c.info,
                    onTap: onCreatePoll,
                    width: itemWidth,
                  ),
                  const SizedBox(width: gap),
                  _QA(
                    icon: Icons.camera_alt_rounded,
                    label: 'التقط صورة',
                    color: c.error,
                    onTap: onCapturePhoto,
                    width: itemWidth,
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _QA extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  final double width;

  const _QA({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.cl;

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: width,
        child: Column(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: color.withValues(alpha: 0.12)),
              ),
              child: Icon(icon, size: 24, color: color),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                color: c.t2,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}