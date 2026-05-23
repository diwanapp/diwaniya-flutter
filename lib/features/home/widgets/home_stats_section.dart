import 'package:flutter/material.dart';

import '../../../config/theme/app_colors.dart';

class HomeStatsSection extends StatelessWidget {
  final int memberCount;
  final String balanceStr;
  final Color balanceColor;
  final int activePolls;
  final int maqadiNeeded;
  final String chatPreview;
  final String chatSender;
  final int chatUnread;
  final int albumCount;
  final VoidCallback onOpenMembers;
  final VoidCallback onOpenBalances;
  final VoidCallback onOpenPolls;
  final VoidCallback onOpenMaqadi;
  final VoidCallback onOpenChat;
  final VoidCallback onOpenAlbum;
  final bool showChatOverview;

  const HomeStatsSection({
    super.key,
    required this.memberCount,
    required this.balanceStr,
    required this.balanceColor,
    required this.activePolls,
    required this.maqadiNeeded,
    required this.chatPreview,
    required this.chatSender,
    required this.chatUnread,
    required this.onOpenMembers,
    required this.onOpenBalances,
    required this.onOpenPolls,
    required this.onOpenMaqadi,
    required this.onOpenChat,
    required this.onOpenAlbum,
    required this.albumCount,
    this.showChatOverview = true,
  });

  @override
  Widget build(BuildContext context) {
    const maqadiAccent = Color(0xFFD9B56D); // Sand gold
    const balanceAccent = Color(0xFF7FAE8A); // Sage green
    const pollAccent = Color(0xFFC98745); // Desert amber
    const albumAccent = Color(0xFF9F4D4D); // Muted burgundy
    const membersAccent = Color(0xFF6EA6C9); // Calm blue

    return Column(
      children: [
        if (showChatOverview) ...[
          HomeChatOverviewCard(
            preview: chatPreview,
            sender: chatSender,
            unreadCount: chatUnread,
            onTap: onOpenChat,
          ),
          const SizedBox(height: 14),
        ],
        Row(
          children: [
            Expanded(
              child: _SoftMetricTile(
                title: 'الرصيد',
                value: '$balanceStr ر.س',
                icon: Icons.account_balance_wallet_rounded,
                accent: balanceAccent,
                onTap: onOpenBalances,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _SoftMetricTile(
                title: 'المقاضي الناقصة',
                value: '$maqadiNeeded ناقص',
                icon: Icons.shopping_cart_rounded,
                accent: maqadiAccent,
                onTap: onOpenMaqadi,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _SoftMetricTile(
                title: 'الألبوم',
                value: albumCount == 0 ? 'لا توجد صور' : '$albumCount صور',
                icon: Icons.image_rounded,
                accent: albumAccent,
                onTap: onOpenAlbum,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _SoftMetricTile(
                title: 'التصويتات القائمة',
                value: '$activePolls',
                icon: Icons.how_to_vote_rounded,
                accent: pollAccent,
                onTap: onOpenPolls,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _MembersSummaryTile(
          count: memberCount,
          accent: membersAccent,
          onTap: onOpenMembers,
        ),
      ],
    );
  }
}

class HomeChatOverviewCard extends StatelessWidget {
  final String preview;
  final String sender;
  final int unreadCount;
  final VoidCallback onTap;

  const HomeChatOverviewCard({
    super.key,
    required this.preview,
    required this.sender,
    required this.unreadCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.cl;
    const chatAccent = Color(0xFF7FAE8A);

    final subtitle = preview.trim().isEmpty
        ? 'لا توجد رسائل جديدة'
        : (sender.trim().isEmpty ? preview : '$sender: $preview');

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsetsDirectional.fromSTEB(20, 18, 20, 18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [
                chatAccent.withValues(alpha: 0.125),
                c.card.withValues(alpha: 0.42),
                chatAccent.withValues(alpha: 0.045),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: chatAccent.withValues(alpha: 0.18),
            ),
          ),
          child: Row(
            children: [
              _SoftIconBadge(
                icon: Icons.chat_bubble_rounded,
                accent: chatAccent,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (unreadCount > 0) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: chatAccent.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '$unreadCount جديد',
                              style: TextStyle(
                                color: chatAccent,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          'الدردشة',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            color: c.t1,
                            fontSize: 16.5,
                            fontWeight: FontWeight.w900,
                            height: 1.15,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Text(
                      subtitle,
                      textAlign: TextAlign.right,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: c.t2,
                        fontSize: 13.2,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SoftMetricTile extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;

  const _SoftMetricTile({
    required this.title,
    required this.value,
    required this.icon,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.cl;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 128),
          padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 15),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [
                accent.withValues(alpha: 0.115),
                c.card.withValues(alpha: 0.24),
                accent.withValues(alpha: 0.035),
              ],
            ),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: _SoftIconBadge(
                  icon: icon,
                  accent: accent,
                  compact: true,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                value,
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: accent,
                  fontSize: 21.5,
                  fontWeight: FontWeight.w900,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                title,
                textAlign: TextAlign.right,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: c.t2,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MembersSummaryTile extends StatelessWidget {
  final int count;
  final Color accent;
  final VoidCallback onTap;

  const _MembersSummaryTile({
    required this.count,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.cl;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          height: 58,
          padding: const EdgeInsetsDirectional.fromSTEB(14, 10, 14, 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerRight,
              end: Alignment.centerLeft,
              colors: [
                accent.withValues(alpha: 0.105),
                c.card.withValues(alpha: 0.22),
                c.card.withValues(alpha: 0.14),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            textDirection: TextDirection.rtl,
            children: [
              _SoftIconBadge(
                icon: Icons.groups_rounded,
                accent: accent,
                compact: true,
              ),
              const SizedBox(width: 11),
              Text(
                '$count أعضاء',
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: c.t1,
                  fontSize: 15.5,
                  fontWeight: FontWeight.w900,
                  height: 1.1,
                ),
              ),
              const Spacer(),
              Icon(
                Icons.chevron_left_rounded,
                color: c.t3,
                size: 23,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SoftIconBadge extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final bool compact;

  const _SoftIconBadge({
    required this.icon,
    required this.accent,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final size = compact ? 44.0 : 58.0;
    final iconSize = compact ? 21.0 : 27.0;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(compact ? 15 : 19),
      ),
      child: Icon(
        icon,
        color: accent,
        size: iconSize,
      ),
    );
  }
}
