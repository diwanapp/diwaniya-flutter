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
        HomeChatOverviewCard(
          preview: chatPreview,
          sender: chatSender,
          unreadCount: chatUnread,
          onTap: onOpenChat,
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          decoration: BoxDecoration(
            color: c.card.withValues(alpha: 0.40),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: c.border.withValues(alpha: 0.07)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: HomeSumCard(
                      label: 'المقاضي الناقصة',
                      value: '$maqadiNeeded ناقص',
                      icon: Icons.shopping_cart_rounded,
                      iconColor: c.warning,
                      iconBg: c.warning.withValues(alpha: 0.12),
                      onTap: onOpenMaqadi,
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: HomeSumCard(
                      label: Ar.currentBalance,
                      value: '$balanceStr ر.س',
                      icon: Icons.account_balance_wallet_rounded,
                      iconColor: c.success,
                      iconBg: c.success.withValues(alpha: 0.12),
                      valueColor: balanceColor,
                      onTap: onOpenBalances,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 11),
              Row(
                children: [
                  Expanded(
                    child: HomeSumCard(
                      label: 'التصويتات القائمة',
                      value: '$activePolls',
                      icon: Icons.how_to_vote_rounded,
                      iconColor: c.pollAccent,
                      iconBg: c.pollAccent.withValues(alpha: 0.14),
                      onTap: onOpenPolls,
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: HomeSumCard(
                      label: Ar.albumTitle,
                      value: albumCount > 0 ? '$albumCount صور' : 'لا توجد صور',
                      icon: Icons.photo_library_rounded,
                      iconColor: c.error,
                      iconBg: c.error.withValues(alpha: 0.12),
                      onTap: onOpenAlbum,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 11),
              _MembersMiniTile(
                memberCount: memberCount,
                onTap: onOpenMembers,
              ),
            ],
          ),
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

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        constraints: const BoxConstraints(minHeight: 104),
        padding: const EdgeInsets.fromLTRB(13, 13, 13, 12),
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: c.border.withValues(alpha: 0.10)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, size: 17, color: iconColor),
            ),
            const SizedBox(height: 14),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: valueColor ?? c.t1,
                height: 1.1,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.6,
                color: c.t2,
                fontWeight: FontWeight.w600,
                height: 1.2,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
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
    final chatAccent = c.chatAccent;
    final chatSurface = c.chatSurface;
    final hasPreview = preview != null && preview!.trim().isNotEmpty;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        constraints: const BoxConstraints(minHeight: 104),
        padding: const EdgeInsets.fromLTRB(16, 15, 16, 15),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [
              c.card,
              chatSurface.withValues(alpha: 0.60),
            ],
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: chatAccent.withValues(alpha: 0.18)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.022),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: chatAccent.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(17),
              ),
              child: Icon(
                Icons.chat_rounded,
                size: 25,
                color: chatAccent,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    Ar.chat,
                    style: TextStyle(
                      fontSize: 15.4,
                      color: c.t1,
                      fontWeight: FontWeight.w900,
                      height: 1.20,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    hasPreview
                        ? '${(sender ?? '').trim().isEmpty ? '' : '${sender!}: '}${preview!}'
                        : 'لا توجد رسائل جديدة',
                    style: TextStyle(
                      fontSize: 12.4,
                      color: hasPreview ? c.t2 : c.t3,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            if (unreadCount > 0)
              Container(
                constraints: const BoxConstraints(minWidth: 28),
                height: 28,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: chatAccent,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: [
                    BoxShadow(
                      color: chatAccent.withValues(alpha: 0.20),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    unreadCount > 99 ? '99+' : '$unreadCount',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w900,
                      color: c.tInverse,
                      height: 1,
                    ),
                  ),
                ),
              )
          ],
        ),
      ),
    );
  }
}

class _MembersMiniTile extends StatelessWidget {
  final int memberCount;
  final VoidCallback onTap;

  const _MembersMiniTile({
    required this.memberCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.cl;
    const blue = Color(0xFF60A5FA);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.border.withValues(alpha: 0.08)),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: blue.withValues(alpha: 0.11),
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Icon(Icons.people_rounded, size: 17, color: blue),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '$memberCount أعضاء',
                style: TextStyle(
                  color: c.t1,
                  fontSize: 12.8,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Icon(Icons.chevron_left_rounded, color: c.t3, size: 20),
          ],
        ),
      ),
    );
  }
}
