import 'package:flutter/material.dart';

class HomeChatOverviewCard extends StatelessWidget {
  const HomeChatOverviewCard({
    super.key,
    this.preview,
    this.sender,
    this.unreadCount = 0,
    this.onTap,
  });

  final String? preview;
  final String? sender;
  final int unreadCount;
  final VoidCallback? onTap;

  static const _navy = Color(0xFF10263A);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final effectivePreview = (preview == null || preview!.trim().isEmpty)
        ? 'افتحوا الدردشة وتابعوا آخر السوالف'
        : preview!.trim();

    final effectiveSender = (sender == null || sender!.trim().isEmpty)
        ? 'الدردشة'
        : sender!.trim();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 14),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(26),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(26),
            child: Ink(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: isDark
                      ? const [
                          Color(0xFF5B8FCB),
                          Color(0xFF10263A),
                          Color(0xFF0B1624),
                        ]
                      : const [
                          Color(0xFFE8F1FA),
                          Color(0xFFF8EFE2),
                        ],
                ),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(
                  color: isDark ? const Color(0x335B8FCB) : const Color(0x22B79A72),
                ),
                boxShadow: [
                  BoxShadow(
                    color: isDark ? const Color(0x305B8FCB) : const Color(0x18B79A72),
                    blurRadius: 22,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                        colors: isDark
                            ? const [Color(0x335B8FCB), Color(0x1AFFFFFF)]
                            : const [Color(0xFFE1F4E6), Color(0xFFFFFFFF)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(
                      Icons.chat_bubble_rounded,
                      color: isDark ? const Color(0xFF8FC3FF) : const Color(0xFF5B8FCB),
                      size: 27,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'الدردشة',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            color: isDark ? Colors.white : _navy,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '$effectiveSender: $effectivePreview',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            color: isDark ? const Color(0xFFE0E7EA) : const Color(0xFF526168),
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            height: 1.35,
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

  static const _saudiGreen = Color(0xFF006C35);
  static const _oudRed = Color(0xFF8A3A44);
  static const _desertGold = Color(0xFFD6A13F);
  static const _fireOrange = Color(0xFFF28C38);
  static const _lavender = Color(0xFFA477E8);
  static const _royalBlue = Color(0xFF5B8FCB);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final resolvedBalance = balanceLabel ?? balanceStr ?? '0+ رس';
    final isNegativeBalance = resolvedBalance.trim().startsWith('-');
    final resolvedBalanceColor =
        balanceColor ?? (isNegativeBalance ? _oudRed : _saudiGreen);

    final resolvedGrocery = groceryLabel ?? '$maqadiNeeded ناقص';
    final resolvedPolls = pollsLabel ?? '$activePolls';
    final resolvedPhotos = photosLabel ?? '$albumCount صور';
    final resolvedMembers = membersLabel ?? '$memberCount أعضاء';

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Column(
        children: [
          if (showChatOverview)
            HomeChatOverviewCard(
              preview: chatPreview,
              sender: chatSender,
              unreadCount: chatUnread,
              onTap: onOpenChat,
            ),
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(top: 16),
            padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
            color: Colors.transparent,
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _MetricCard(
                        label: 'المقاضي الناقصة',
                        value: resolvedGrocery,
                        icon: Icons.shopping_cart_rounded,
                        accent: _desertGold,
                        isDark: isDark,
                        onTap: onOpenMaqadi ?? onGroceryTap,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _MetricCard(
                        label: 'الرصيد',
                        value: resolvedBalance,
                        icon: Icons.account_balance_wallet_rounded,
                        accent: resolvedBalanceColor,
                        isDark: isDark,
                        onTap: onOpenBalances ?? onExpensesTap,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _MetricCard(
                        label: 'الألبوم',
                        value: resolvedPhotos,
                        icon: Icons.photo_rounded,
                        accent: _lavender,
                        isDark: isDark,
                        onTap: onOpenAlbum ?? onPhotosTap,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _MetricCard(
                        label: 'التصويتات القائمة',
                        value: resolvedPolls,
                        icon: Icons.how_to_vote_rounded,
                        accent: _fireOrange,
                        isDark: isDark,
                        onTap: onOpenPolls ?? onPollsTap,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _MembersBar(
                  label: resolvedMembers,
                  isDark: isDark,
                  accent: _royalBlue,
                  onTap: onOpenMembers ?? onMembersTap,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
    required this.isDark,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color accent;
  final bool isDark;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final baseA = isDark ? const Color(0xFF132B3B) : const Color(0xFFFFF7EA);
    final baseB = isDark ? const Color(0xFF0B1E2C) : const Color(0xFFF2E3CE);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(25),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(25),
        child: Ink(
          height: 156,
          padding: const EdgeInsets.fromLTRB(15, 14, 15, 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: [
                Color.lerp(baseA, accent, isDark ? .50 : .32)!,
                Color.lerp(baseB, accent, isDark ? .30 : .18)!,
              ],
            ),
            borderRadius: BorderRadius.circular(25),
            border: Border.all(
              color: accent.withValues(alpha: isDark ? .22 : .18),
            ),
            boxShadow: [
              BoxShadow(
                color: accent.withValues(alpha: isDark ? .10 : .08),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Align(
                    alignment: Alignment.topRight,
                    child: Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topRight,
                          end: Alignment.bottomLeft,
                          colors: [
                            accent.withValues(alpha: isDark ? .34 : .22),
                            Colors.white.withValues(alpha: isDark ? .06 : .30),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(17),
                      ),
                      child: Icon(icon, color: accent, size: 24),
                    ),
                  ),
                  const Spacer(),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.visible,
                      textAlign: TextAlign.right,
                      textDirection: TextDirection.rtl,
                      style: TextStyle(
                        color: accent,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.visible,
                      textAlign: TextAlign.right,
                      textDirection: TextDirection.rtl,
                      style: TextStyle(
                        color: isDark ? const Color(0xFFE1E7EA) : const Color(0xFF3E4A50),
                        fontSize: 13.0,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                  ),
                ],
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
    required this.isDark,
    required this.accent,
    this.onTap,
  });

  final String label;
  final bool isDark;
  final Color accent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final baseA = isDark ? const Color(0xFF132B3B) : const Color(0xFFFFF7EA);
    final baseB = isDark ? const Color(0xFF0B1E2C) : const Color(0xFFF2E3CE);

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          height: 62,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerRight,
              end: Alignment.centerLeft,
              colors: [
                Color.lerp(baseA, accent, isDark ? .50 : .32)!,
                Color.lerp(baseB, accent, isDark ? .30 : .18)!,
              ],
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: accent.withValues(alpha: isDark ? .34 : .22)),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: isDark ? .34 : .22),
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Icon(Icons.groups_rounded, color: accent, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF10263A),
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_left_rounded,
                color: isDark ? const Color(0xFFB7C0C6) : const Color(0xFF68747A),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
