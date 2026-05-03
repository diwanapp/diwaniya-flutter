import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_theme.dart';
import '../../core/models/mock_data.dart';
import '../../core/models/subscription_status.dart';
import '../../core/navigation/app_routes.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/invite_share_service.dart';
import '../../core/services/paywall_service.dart';
import '../../core/services/subscription_service.dart';
import '../../core/services/user_service.dart';
import '../../l10n/ar.dart';
import '../legal/privacy_policy_screen.dart';
import '../legal/terms_of_use_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.cl;
    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        title: Text(
          Ar.settings,
          style: TextStyle(
            color: c.t1,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: c.bg,
      ),
      body: ValueListenableBuilder<int>(
        valueListenable: dataVersion,
        builder: (_, __, ___) {
          final profile = AuthService.profile;
          final visibleDiwaniyas = List<DiwaniyaInfo>.from(allDiwaniyas);

          final hasVisibleDiwaniyas = visibleDiwaniyas.isNotEmpty;
          final activeVisibleDiwaniyaId = hasVisibleDiwaniyas &&
                  visibleDiwaniyas.any((d) => d.id == currentDiwaniyaId)
              ? currentDiwaniyaId
              : '';

          final activeDiwaniyaSub = activeVisibleDiwaniyaId.isNotEmpty
              ? SubscriptionService.forDiwaniya(activeVisibleDiwaniyaId)
              : null;

          final hasPaidSubscription = activeDiwaniyaSub != null &&
              activeDiwaniyaSub.active == true &&
              (activeDiwaniyaSub.plan == SubscriptionPlan.monthly ||
                  activeDiwaniyaSub.plan == SubscriptionPlan.yearly);

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
            children: [
              GestureDetector(
                onTap: () => context.push(AppRoutes.accountDetails),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: c.card,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [BoxShadow(color: c.shadow, blurRadius: 8)],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              c.accent.withValues(alpha: 0.28),
                              c.accent.withValues(alpha: 0.08),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                _settingsAvatarLabel(profile?.fullName),
                                maxLines: 1,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w800,
                                  color: c.accent,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              profile?.fullName ?? Ar.account,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: c.t1,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              profile?.phone ?? '',
                              style: TextStyle(fontSize: 12.5, color: c.t3),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_left_rounded, size: 22, color: c.t3),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              _SectionLabel(c, Ar.myDiwaniyas),
              const SizedBox(height: 8),
              if (visibleDiwaniyas.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Text(
                    Ar.noDiwaniyas,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: c.t3),
                  ),
                )
              else
                ...visibleDiwaniyas.map((d) => _DiwaniyaCard(c: c, diw: d)),
              const SizedBox(height: 24),
              if (hasVisibleDiwaniyas &&
                  !hasPaidSubscription &&
                  activeVisibleDiwaniyaId.isNotEmpty) ...[
                _UpgradeCard(
                  c: c,
                  onTap: () => PaywallService.showFullPaywall(
                    context,
                    trigger: PaywallTrigger.settingsCard,
                  ),
                ),
                const SizedBox(height: 24),
              ],
              _SectionLabel(c, Ar.tools),
              const SizedBox(height: 8),
              _ToolsGroup(
                c: c,
                children: [
                  _ThemeSelector(c: c),
                  Divider(height: 1, color: c.divider, indent: 56),
                  _ToolRow(
                    c: c,
                    icon: Icons.share_rounded,
                    label: Ar.inviteShare,
                    onTap: () async {
                      final eligible = visibleDiwaniyas
                          .where(
                            (d) =>
                                d.invitationCode != null &&
                                d.invitationCode!.isNotEmpty,
                          )
                          .toList();

                      if (eligible.isEmpty) {
                        await InviteShareService.sharePlainText(
                          context,
                          InviteShareService.buildAppInviteMessage(),
                          subject: 'حمّل تطبيق ديوانية',
                        );
                        return;
                      }

                      DiwaniyaInfo? target;
                      if (eligible.length == 1) {
                        target = eligible.first;
                      } else {
                        target = await showModalBottomSheet<DiwaniyaInfo>(
                          context: context,
                          backgroundColor: Colors.transparent,
                          isScrollControlled: true,
                          builder: (sheetCtx) => SafeArea(
                            child: Container(
                              constraints: BoxConstraints(
                                maxHeight:
                                    MediaQuery.of(sheetCtx).size.height * 0.72,
                              ),
                              padding:
                                  const EdgeInsets.fromLTRB(20, 16, 20, 24),
                              decoration: BoxDecoration(
                                color: c.card,
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(22),
                                ),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment:
                                    CrossAxisAlignment.stretch,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: Text(
                                      'اختر الديوانية التي تريد مشاركتها',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                        color: c.t1,
                                      ),
                                    ),
                                  ),
                                  Flexible(
                                    child: ListView.separated(
                                      shrinkWrap: true,
                                      itemCount: eligible.length,
                                      separatorBuilder: (_, __) =>
                                          const SizedBox(height: 4),
                                      itemBuilder: (_, index) {
                                        final d = eligible[index];
                                        return ListTile(
                                          leading: Icon(
                                            Icons.groups_rounded,
                                            color: c.accent,
                                          ),
                                          title: Text(
                                            d.name,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              color: c.t1,
                                            ),
                                          ),
                                          subtitle: Text(
                                            'رمز الدعوة: ${d.invitationCode}',
                                            style: TextStyle(color: c.t3),
                                          ),
                                          onTap: () =>
                                              Navigator.of(sheetCtx).pop(d),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }

                      if (target == null || !context.mounted) return;
                      await InviteShareService.shareForDiwaniya(context, target);
                    },
                  ),
                  Divider(height: 1, color: c.divider, indent: 56),
                  _ToolRow(
                    c: c,
                    icon: Icons.notifications_outlined,
                    label: Ar.notificationPrefs,
                    onTap: () => context.push(AppRoutes.notifSettings),
                  ),
                  Divider(height: 1, color: c.divider, indent: 56),
                  _ToolRow(
                    c: c,
                    icon: Icons.help_outline_rounded,
                    label: Ar.helpSupport,
                    onTap: () => context.push(AppRoutes.inquiries),
                  ),
                  Divider(height: 1, color: c.divider, indent: 56),
                  _ToolRow(
                    c: c,
                    icon: Icons.privacy_tip_outlined,
                    label: 'سياسة الخصوصية',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const PrivacyPolicyScreen(),
                      ),
                    ),
                  ),
                  Divider(height: 1, color: c.divider, indent: 56),
                  _ToolRow(
                    c: c,
                    icon: Icons.description_outlined,
                    label: 'شروط الاستخدام',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const TermsOfUseScreen(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await AuthService.signOutFromApi();
                    if (!context.mounted) return;
                    context.go(AuthService.nextRoute());
                  },
                  icon: Icon(Icons.logout_rounded, color: c.error),
                  label: Text(Ar.signOut, style: TextStyle(color: c.error)),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

String _settingsAvatarLabel(String? fullName) {
  final parts = (fullName ?? '')
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.trim().isNotEmpty)
      .toList(growable: false);

  if (parts.isEmpty) return '؟';

  final firstName = parts.first.trim();
  if (parts.length == 1) return firstName;

  final lastInitial = _firstReadableChar(parts.last);
  return lastInitial.isEmpty ? firstName : '$firstName $lastInitial';
}

String _firstReadableChar(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return '';
  return String.fromCharCode(trimmed.runes.first);
}

class _DiwaniyaCard extends StatelessWidget {
  final CL c;
  final DiwaniyaInfo diw;
  const _DiwaniyaCard({required this.c, required this.diw});

  @override
  Widget build(BuildContext context) {
    final members = diwaniyaMembers[diw.id] ?? [];
    final isManager = UserService.isManager(diw.id);
    final rawSub = SubscriptionService.forDiwaniya(diw.id);
    final sub = (rawSub != null &&
            rawSub.active == true &&
            (rawSub.plan == SubscriptionPlan.monthly ||
                rawSub.plan == SubscriptionPlan.yearly))
        ? rawSub
        : null;
    final hasImage = diw.imagePath != null && File(diw.imagePath!).existsSync();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: () => context.push(AppRoutes.diwaniyaDetails, extra: diw.id),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: c.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: c.border),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: diw.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                  image: hasImage
                      ? DecorationImage(
                          image: FileImage(File(diw.imagePath!)),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: hasImage
                    ? null
                    : Center(
                        child: Text(
                          diw.name.trim().isEmpty
                              ? 'د'
                              : diw.name.trim().substring(0, 1),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: diw.color,
                          ),
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      diw.name,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: c.t1,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${diw.district} · ${diw.city} · ${members.length} ${Ar.memberUnit}',
                      style: TextStyle(fontSize: 11, color: c.t3),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        _RoleBadge(c: c, isManager: isManager),
                        if (sub != null) ...[
                          const SizedBox(width: 6),
                          _SubBadge(c: c, sub: sub),
                          const SizedBox(width: 6),
                          _PremiumBadge(c: c),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_left_rounded, size: 20, color: c.t3),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  final CL c;
  final bool isManager;
  const _RoleBadge({required this.c, required this.isManager});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isManager ? c.accentMuted : c.cardElevated,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        isManager ? Ar.manager : Ar.memberUnit,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: isManager ? c.accent : c.t3,
        ),
      ),
    );
  }
}

class _SubBadge extends StatelessWidget {
  final CL c;
  final SubscriptionStatus sub;
  const _SubBadge({required this.c, required this.sub});

  @override
  Widget build(BuildContext context) {
    final isActive = sub.active == true;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isActive ? c.successM : c.errorM,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        isActive ? Ar.subscriptionActive : Ar.subscriptionExpired,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: isActive ? c.success : c.error,
        ),
      ),
    );
  }
}

class _ToolsGroup extends StatelessWidget {
  final CL c;
  final List<Widget> children;
  const _ToolsGroup({required this.c, required this.children});

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: c.shadow, blurRadius: 6)],
        ),
        child: Column(children: children),
      );
}

class _ToolRow extends StatelessWidget {
  final CL c;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ToolRow({
    required this.c,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: c.accentMuted,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, size: 17, color: c.accent),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(fontSize: 14, color: c.t1),
                ),
              ),
              Icon(Icons.chevron_left_rounded, size: 18, color: c.t3),
            ],
          ),
        ),
      );
}

class _SectionLabel extends StatelessWidget {
  final CL c;
  final String t;
  const _SectionLabel(this.c, this.t);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 2),
        child: Text(
          t,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: c.t3,
          ),
        ),
      );
}

class _ThemeSelector extends StatelessWidget {
  final CL c;
  const _ThemeSelector({required this.c});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: c.accentMuted,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(Icons.palette_rounded, size: 17, color: c.accent),
                ),
                const SizedBox(width: 11),
                Text(
                  Ar.themeMode,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: c.t1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ValueListenableBuilder<ThemeMode>(
              valueListenable: themeNotifier,
              builder: (_, mode, __) => Row(
                children: [
                  _ThemeChip(
                    c,
                    Ar.themeLight,
                    Icons.light_mode_rounded,
                    mode == ThemeMode.light,
                    () => saveThemePreference(ThemeMode.light),
                  ),
                  const SizedBox(width: 8),
                  _ThemeChip(
                    c,
                    Ar.themeDark,
                    Icons.dark_mode_rounded,
                    mode == ThemeMode.dark,
                    () => saveThemePreference(ThemeMode.dark),
                  ),
                  const SizedBox(width: 8),
                  _ThemeChip(
                    c,
                    Ar.themeAuto,
                    Icons.brightness_auto_rounded,
                    mode == ThemeMode.system,
                    () => saveThemePreference(ThemeMode.system),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class _ThemeChip extends StatelessWidget {
  final CL c;
  final String label;
  final IconData icon;
  final bool sel;
  final VoidCallback onTap;
  const _ThemeChip(this.c, this.label, this.icon, this.sel, this.onTap);

  @override
  Widget build(BuildContext context) => Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: sel ? c.accentMuted : c.inputBg,
              borderRadius: BorderRadius.circular(10),
              border:
                  sel ? Border.all(color: c.accent.withValues(alpha: 0.4)) : null,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 20, color: sel ? c.accent : c.t3),
                const SizedBox(height: 5),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: sel ? FontWeight.w600 : FontWeight.w500,
                    color: sel ? c.accent : c.t2,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

class _PremiumBadge extends StatelessWidget {
  final CL c;
  const _PremiumBadge({required this.c});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: c.accentMuted,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        Ar.premiumPill,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: c.accent,
        ),
      ),
    );
  }
}

class _UpgradeCard extends StatelessWidget {
  final CL c;
  final VoidCallback onTap;
  const _UpgradeCard({required this.c, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              c.accent.withValues(alpha: 0.16),
              c.accent.withValues(alpha: 0.08),
            ],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: c.accent.withValues(alpha: 0.18)),
          boxShadow: [BoxShadow(color: c.shadow, blurRadius: 8)],
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: c.accent.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.workspace_premium_rounded,
                color: c.accent,
                size: 26,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ترقية الديوانية',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: c.t1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'ارفع حدود الأعضاء والصور والتصويتات بترقية الديوانية.',
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.6,
                      color: c.t2,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: c.accent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'ترقية',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: c.tInverse,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}