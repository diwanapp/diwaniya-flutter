import 'package:flutter/material.dart';

import '../../../config/theme/app_colors.dart';
import '../../../core/models/mock_data.dart';
import '../../../l10n/ar.dart';
import 'home_activity_section.dart';
import 'home_handle.dart';

class HomeNotificationsSheet extends StatelessWidget {
  final List<DiwaniyaNotification> notifs;
  final void Function(DiwaniyaNotification)? onTap;

  const HomeNotificationsSheet({super.key, required this.notifs, this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.cl;
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: c.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        HomeHandle(c),
        const SizedBox(height: 16),
        Text(Ar.notificationsTitle, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: c.t1)),
        const SizedBox(height: 16),
        if (notifs.isEmpty)
          Padding(padding: const EdgeInsets.symmetric(vertical: 32),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.notifications_off_rounded, size: 36, color: c.t3),
              const SizedBox(height: 8),
              Text(Ar.noNotifications, style: TextStyle(fontSize: 13, color: c.t3)),
            ]))
        else
          Flexible(child: ListView.separated(
            shrinkWrap: true, itemCount: notifs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 4),
            itemBuilder: (_, i) {
              final n = notifs[i];
              return GestureDetector(
                onTap: onTap != null ? () => onTap!(n) : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(12)),
                  child: Row(children: [
                    Container(width: 36, height: 36,
                      decoration: BoxDecoration(color: n.iconColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10)),
                      child: Icon(n.icon, size: 18, color: n.iconColor)),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(n.message, style: TextStyle(fontSize: 13, color: c.t1, fontWeight: FontWeight.w500),
                          maxLines: 2, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 3),
                      Text(homeTimeAgo(n.createdAt), style: TextStyle(fontSize: 11, color: c.t3)),
                    ])),
                    Icon(Icons.chevron_left_rounded, size: 16, color: c.t3),
                  ]),
                ),
              );
            },
          )),
      ]),
    );
  }
}
