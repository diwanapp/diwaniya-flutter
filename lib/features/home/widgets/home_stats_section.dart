import 'package:flutter/material.dart';

class HomeChatOverviewCard extends StatelessWidget {
  const HomeChatOverviewCard({
    super.key,
    required this.preview,
    required this.sender,
    required this.unreadCount,
    this.onTap,
  });

  final String? preview;
  final String? sender;
  final int unreadCount;
  final VoidCallback? onTap;

  static const _navy = Color(0xFF101923);
  static const _green = Color(0xFF8DD6A5);
  static const _textSoft = Color(0xFFC9D0D4);

  @override
  Widget build(BuildContext context) {
    final effectivePreview = (preview == null || preview!.trim().isEmpty)
        ? 'افتحوا دردشتكم وتابعوا آخر السوالف'
        : preview!.trim();

    final effectiveSender = (sender == null || sender!.trim().isEmpty)
        ? 'الدردشة'
        : sender!.trim();

    return Container(
      margin: const EdgeInsets.only(top: 14),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(26),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(26),
          child: Ink(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.centerRight,
                end: Alignment.centerLeft,
                colors: [
                  Color(0xFF1B332D),
                  Color(0xFF101923),
                ],
              ),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: Color(0x2278D6A2)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x26000000),
                  blurRadius: 22,
                  offset: Offset(0, 12),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: const Color(0x2278D6A2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      const Icon(Icons.chat_bubble_rounded, color: _green, size: 26),
                      if (unreadCount > 0)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(
                              color: Color(0xFFD66B75),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        'الدردشة',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '$effectiveSender: $effectivePreview',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          color: _textSoft,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class HomeStatsSection extends StatelessWidget {
  const HomeStatsSection({
    super.key,
    this.showChatOverview = false,
    this.memberCount = 0,
    this.balanceStr,
    this.balanceColor,
    this.activePolls = 0,
    this.maqadiNeeded = 0,
    this.chatPreview,
    this.chatSender,
    this.chatUnread = 0,
    this.albumCount = 0,
    this.onOpenMembers,
    this.onOpenBalances,
    this.onOpenPolls,
    this.onOpenMaqadi,
    this.onOpenChat,
    this.onOpenAlbum,
    this.balanceLabel,
    this.groceryLabel,
    this.pollsLabel,
    this.photosLabel,
    this.membersLabel,
    this.onExpensesTap,
    this.onGroceryTap,
    this.onPollsTap,
    this.onPhotosTap,
    this.onMembersTap,
  });

  final bool showChatOverview;
  final int memberCount;
  final String? balanceStr;
  final Color? balanceColor;
  final int activePolls;
  final int maqadiNeeded;
  final String? chatPreview;
  final String? chatSender;
  final int chatUnread;
  final int albumCount;

  final VoidCallback? onOpenMembers;
  final VoidCallback? onOpenBalances;
  final VoidCallback? onOpenPolls;
  final VoidCallback? onOpenMaqadi;
  final VoidCallback? onOpenChat;
  final VoidCallback? onOpenAlbum;

  // Backward-compatible aliases.
  final String? balanceLabel;
  final String? groceryLabel;
  final String? pollsLabel;
  final String? photosLabel;
  final String? membersLabel;
  final VoidCallback? onExpensesTap;
  final VoidCallback? onGroceryTap;
  final VoidCallback? onPollsTap;
  final VoidCallback? onPhotosTap;
  final VoidCallback? onMembersTap;

  static const _border = Color(0x1FFFFFFF);

  @override
  Widget build(BuildContext context) {
    final resolvedBalance = balanceLabel ?? balanceStr ?? '0+ رس';
    final resolvedBalanceColor = balanceColor ?? const Color(0xFF70C89B);
    final resolvedGrocery = groceryLabel ?? '$maqadiNeeded ناقص';
    final resolvedPolls = pollsLabel ?? '$activePolls';
    final resolvedPhotos = photosLabel ?? '$albumCount صور';
    final resolvedMembers = membersLabel ?? '$memberCount أعضاء';

    return Column(
      children: [
        if (showChatOverview)
          HomeChatOverviewCard(
            preview: chatPreview,
            sender: chatSender,
            unreadCount: chatUnread,
            onTap: onOpenChat,
          ),
        Container(
          margin: const EdgeInsets.only(top: 14),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF0F1722),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: _border),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 24,
                offset: Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _MetricCard(
                      label: 'الرصيد',
                      value: resolvedBalance,
                      icon: Icons.account_balance_wallet_rounded,
                      accent: resolvedBalanceColor,
                      onTap: onOpenBalances ?? onExpensesTap,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _MetricCard(
                      label: 'المقاضي الناقصة',
                      value: resolvedGrocery,
                      icon: Icons.shopping_cart_rounded,
                      accent: const Color(0xFFD6B56D),
                      onTap: onOpenMaqadi ?? onGroceryTap,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _MetricCard(
                      label: 'التصويتات القائمة',
                      value: resolvedPolls,
                      icon: Icons.how_to_vote_rounded,
                      accent: const Color(0xFFCB8A48),
                      onTap: onOpenPolls ?? onPollsTap,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _MetricCard(
                      label: 'الألبوم',
                      value: resolvedPhotos,
                      icon: Icons.photo_rounded,
                      accent: const Color(0xFFD66B75),
                      onTap: onOpenAlbum ?? onPhotosTap,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _MembersBar(
                label: resolvedMembers,
                onTap: onOpenMembers ?? onMembersTap,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color accent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          height: 166,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [
                Color.lerp(const Color(0xFF151F2A), accent, .08)!,
                const Color(0xFF111A24),
              ],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: accent.withValues(alpha: .12)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x22000000),
                blurRadius: 18,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Align(
                alignment: Alignment.topRight,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: .14),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon, color: accent, size: 22),
                ),
              ),
              const Spacer(),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: TextStyle(
                  color: accent,
                  fontSize: 25,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: const TextStyle(
                  color: Color(0xFF9EA8AE),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MembersBar extends StatelessWidget {
  const _MembersBar({
    required this.label,
    this.onTap,
  });

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF7BA7D9);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.centerRight,
              end: Alignment.centerLeft,
              colors: [
                Color(0xFF152637),
                Color(0xFF101923),
              ],
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Color(0x1FFFFFFF)),
          ),
          child: Row(
            children: [
              const Icon(Icons.chevron_left_rounded, color: Color(0xFF9EA8AE)),
              const Spacer(),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: .16),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(Icons.groups_rounded, color: accent),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
