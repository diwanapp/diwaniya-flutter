import 'package:flutter/material.dart';

import '../../../config/theme/app_colors.dart';
import '../../../core/models/mock_data.dart';
import '../../../l10n/ar.dart';

String homeTimeAgo(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1) return 'الآن';
  if (diff.inMinutes < 60) return 'قبل ${diff.inMinutes} د';
  if (diff.inHours < 24) return 'قبل ${diff.inHours} س';
  if (diff.inDays < 7) return 'قبل ${diff.inDays} يوم';
  return 'قبل ${diff.inDays ~/ 7} أسبوع';
}

class HomeActivitySection extends StatelessWidget {
  final List<DiwaniyaActivity> activities;

  const HomeActivitySection({
    super.key,
    required this.activities,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.cl;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          Ar.recentActivity,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: c.t1,
          ),
        ),
        const SizedBox(height: 12),
        if (activities.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 32),
            decoration: BoxDecoration(
              color: c.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: c.border),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.history_rounded, size: 36, color: c.t3),
                  const SizedBox(height: 8),
                  Text(
                    Ar.noActivity,
                    style: TextStyle(fontSize: 13, color: c.t3),
                  ),
                ],
              ),
            ),
          )
        else
          ...activities.take(8).map((a) => HomeActivityRow(activity: a)),
      ],
    );
  }
}

class HomeActivityRow extends StatelessWidget {
  final DiwaniyaActivity activity;

  const HomeActivityRow({
    super.key,
    required this.activity,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.cl;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.border),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: activity.iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                activity.icon,
                size: 18,
                color: activity.iconColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                activity.message,
                style: TextStyle(
                  fontSize: 13,
                  color: c.t1,
                  height: 1.45,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              homeTimeAgo(activity.createdAt),
              style: TextStyle(fontSize: 11, color: c.t3),
            ),
          ],
        ),
      ),
    );
  }
}