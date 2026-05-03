import 'package:flutter/material.dart';

import '../../../config/theme/app_colors.dart';
import '../../../l10n/ar.dart';

class HomeStatsSection extends StatelessWidget {
  final int memberCount;
  final String balanceStr;
  final Color balanceColor;
  final int activePolls;
  final int maqadiNeeded;
  final String? chatPreview;
  final String? chatSender;
  final int chatUnread;
  final int albumCount;
  final VoidCallback onOpenMembers;
  final VoidCallback onOpenBalances;
  final VoidCallback onOpenPolls;
  final VoidCallback onOpenMaqadi;
  final VoidCallback onOpenChat;
  final VoidCallback onOpenAlbum;

  const HomeStatsSection({
    super.key,
    required this.memberCount,
    required this.balanceStr,
    required this.balanceColor,
    required this.activePolls,
    required this.maqadiNeeded,
    this.chatPreview,
    this.chatSender,
    this.chatUnread = 0,
    this.albumCount = 0,
    required this.onOpenMembers,
    required this.onOpenBalances,
    required this.onOpenPolls,
    required this.onOpenMaqadi,
    required this.onOpenChat,
    required this.onOpenAlbum,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.cl;

    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: HomeChatOverviewCard(
                preview: chatPreview,
                sender: chatSender,
                unreadCount: chatUnread,
                onTap: onOpenChat,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: HomeSumCard(
                label: 'المقاضي الناقصة',
                value: '$maqadiNeeded ${Ar.maqadiNeeded}',
                icon: Icons.shopping_cart_rounded,
                iconColor: c.warning,
                iconBg: c.warningM,
                onTap: onOpenMaqadi,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: HomeSumCard(
                label: Ar.currentBalance,
                value: '$balanceStr ر.س',
                icon: Icons.account_balance_wallet_rounded,
                iconColor: c.success,
                iconBg: c.successM,
                valueColor: balanceColor,
                onTap: onOpenBalances,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: HomeSumCard(
                label: 'التصويتات القائمة',
                value: '$activePolls',
                icon: Icons.how_to_vote_rounded,
                iconColor: c.accent,
                iconBg: c.accentMuted,
                onTap: onOpenPolls,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: HomeSumCard(
                label: Ar.membersCount,
                value: '$memberCount',
                icon: Icons.people_rounded,
                iconColor: c.info,
                iconBg: c.infoM,
                onTap: onOpenMembers,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: HomeSumCard(
                label: Ar.albumTitle,
                value: albumCount > 0
                    ? '$albumCount ${Ar.photoCount}'
                    : 'لا توجد صور بعد',
                icon: Icons.photo_library_rounded,
                iconColor: c.error,
                iconBg: c.errorM,
                onTap: onOpenAlbum,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class HomeSumCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final Color? valueColor;
  final VoidCallback? onTap;

  const HomeSumCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    this.valueColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.cl;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: iconColor),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: valueColor ?? c.t1,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.2,
                color: c.t2,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HomeChatOverviewCard extends StatelessWidget {
  final String? preview;
  final String? sender;
  final int unreadCount;
  final VoidCallback? onTap;

  const HomeChatOverviewCard({
    super.key,
    this.preview,
    this.sender,
    this.unreadCount = 0,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.cl;
    final hasPreview = preview != null && preview!.trim().isNotEmpty;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 126,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFF60A5FA).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.chat_rounded,
                    size: 18,
                    color: Color(0xFF60A5FA),
                  ),
                ),
                const Spacer(),
                if (unreadCount > 0)
                  Container(
                    constraints: const BoxConstraints(minWidth: 22),
                    height: 22,
                    padding: const EdgeInsets.symmetric(horizontal: 7),
                    decoration: BoxDecoration(
                      color: c.accent,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Center(
                      child: Text(
                        unreadCount > 99 ? '99+' : '$unreadCount',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: c.tInverse,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              Ar.chat,
              style: TextStyle(
                fontSize: 12,
                color: c.t2,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 6),
            if (hasPreview) ...[
              Text(
                sender ?? '',
                style: TextStyle(
                  fontSize: 11,
                  color: c.t3,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Expanded(
                child: Text(
                  preview!,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: c.t1,
                    height: 1.45,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ] else
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'لا توجد رسائل حديثة',
                    style: TextStyle(fontSize: 13, color: c.t3),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}