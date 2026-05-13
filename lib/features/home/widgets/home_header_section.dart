import 'package:flutter/material.dart';

import '../../../config/theme/app_colors.dart';

class HomeHeaderSection extends StatelessWidget {
  final String diwaniyaName;
  final String district;
  final int unreadNotifs;
  final int myJoinRequestCount;
  final VoidCallback onSwitchDiwaniya;
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenNotifications;
  final VoidCallback onOpenMyRequests;

  const HomeHeaderSection({
    super.key,
    required this.diwaniyaName,
    required this.district,
    required this.unreadNotifs,
    required this.myJoinRequestCount,
    required this.onSwitchDiwaniya,
    required this.onOpenSettings,
    required this.onOpenNotifications,
    required this.onOpenMyRequests,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.cl;
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: onSwitchDiwaniya,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Flexible(
                    child: Text(
                      diwaniyaName,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: c.t1,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.keyboard_arrow_down_rounded,
                      size: 20, color: c.t2),
                ]),
                const SizedBox(height: 2),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(
                    Icons.location_on_outlined,
                    size: 12,
                    color: c.accent.withValues(alpha: 0.7),
                  ),
                  const SizedBox(width: 3),
                  Text(
                    district,
                    style: TextStyle(
                      fontSize: 12,
                      color: c.accent.withValues(alpha: 0.7),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ),
        // RTL order note: children render from right to left. This keeps the
        // visual left edge as Settings, then Notifications, then My Requests.
        _HeaderActionButton(
          icon: Icons.assignment_turned_in_outlined,
          tooltip: 'طلباتي',
          badgeCount: myJoinRequestCount,
          onTap: onOpenMyRequests,
        ),
        const SizedBox(width: 8),
        _HeaderActionButton(
          icon: Icons.notifications_outlined,
          tooltip: 'الإشعارات',
          badgeCount: unreadNotifs,
          onTap: onOpenNotifications,
        ),
        const SizedBox(width: 8),
        _HeaderActionButton(
          icon: Icons.settings_outlined,
          tooltip: 'الإعدادات',
          onTap: onOpenSettings,
        ),
      ],
    );
  }
}

class _HeaderActionButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final int badgeCount;
  final VoidCallback onTap;

  const _HeaderActionButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.cl;
    final visibleBadge = badgeCount > 0;
    return Semantics(
      button: true,
      label: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: c.card,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 22, color: c.t2),
            ),
            if (visibleBadge)
              PositionedDirectional(
                top: -6,
                end: -6,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 18),
                  height: 18,
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  decoration: BoxDecoration(
                    color: c.error,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: c.bg, width: 1.5),
                  ),
                  child: Center(
                    child: Text(
                      badgeCount > 99 ? '99+' : '$badgeCount',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
