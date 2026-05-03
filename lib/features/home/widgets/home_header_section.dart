import 'package:flutter/material.dart';

import '../../../config/theme/app_colors.dart';

class HomeHeaderSection extends StatelessWidget {
  final String diwaniyaName;
  final String district;
  final int unreadNotifs;
  final VoidCallback onSwitchDiwaniya;
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenNotifications;

  const HomeHeaderSection({
    super.key,
    required this.diwaniyaName,
    required this.district,
    required this.unreadNotifs,
    required this.onSwitchDiwaniya,
    required this.onOpenSettings,
    required this.onOpenNotifications,
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
                    child: Text(diwaniyaName,
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: c.t1),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: c.t2),
                ]),
                const SizedBox(height: 2),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.location_on_outlined, size: 12, color: c.accent.withValues(alpha: 0.7)),
                  const SizedBox(width: 3),
                  Text(district, style: TextStyle(fontSize: 12,
                      color: c.accent.withValues(alpha: 0.7), fontWeight: FontWeight.w500)),
                ]),
              ],
            ),
          ),
        ),
        GestureDetector(
          onTap: onOpenSettings,
          child: Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(12)),
            child: Icon(Icons.settings_outlined, size: 21, color: c.t2),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: onOpenNotifications,
          child: Stack(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(color: c.card, borderRadius: BorderRadius.circular(12)),
              child: Icon(Icons.notifications_outlined, size: 22, color: c.t2),
            ),
            if (unreadNotifs > 0)
              Positioned(top: 6, left: 6,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 16), height: 16,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(color: c.error, borderRadius: BorderRadius.circular(8)),
                  child: Center(child: Text('$unreadNotifs',
                      style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white))),
                )),
          ]),
        ),
      ],
    );
  }
}
