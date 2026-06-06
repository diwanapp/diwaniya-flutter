import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../config/theme/app_colors.dart';
import '../../core/navigation/app_routes.dart';
import '../../core/services/auth_service.dart';

class DiwaniyaAccessScreen extends StatelessWidget {
  const DiwaniyaAccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.cl;

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 26),
          children: [
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: _SignOutChip(
                onTap: () => _confirmSignOut(context),
              ),
            ),
            const SizedBox(height: 12),
            _WelcomeHero(
              onExplore: () => _showExploreSheet(context),
            ),
            const SizedBox(height: 18),
            _AccessActionCard(
              title: 'إنشاء ديوانية',
              subtitle: 'ابدأ ديوانيتك، وشارك رمز الدعوة مع الأعضاء.',
              icon: Icons.storefront_rounded,
              color: c.accent,
              onTap: () => context.push(AppRoutes.createDiwaniya),
            ),
            const SizedBox(height: 12),
            _AccessActionCard(
              title: 'الانضمام برمز الدعوة',
              subtitle: 'أدخل الرمز المرسل لك من مدير الديوانية.',
              icon: Icons.login_rounded,
              color: const Color(0xFF60A5FA),
              onTap: () => context.push(AppRoutes.joinDiwaniya),
            ),
            const SizedBox(height: 12),
            _ExploreActionCard(
              onTap: () => _showExploreSheet(context),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final c = context.cl;

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: c.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: Text(
            'تسجيل الخروج؟',
            textAlign: TextAlign.right,
            style: TextStyle(
              color: c.t1,
              fontWeight: FontWeight.w900,
            ),
          ),
          content: Text(
            'يمكنك الدخول مرة أخرى برقم الجوال.',
            textAlign: TextAlign.right,
            style: TextStyle(
              color: c.t2,
              height: 1.45,
            ),
          ),
          actionsAlignment: MainAxisAlignment.start,
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(
                'إلغاء',
                style: TextStyle(
                  color: c.t2,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: c.error,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
              child: const Text(
                'تسجيل الخروج',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        );
      },
    );

    if (ok != true || !context.mounted) return;

    await AuthService.signOutFromApi();

    if (!context.mounted) return;
    context.go('/');
  }

  void _showExploreSheet(BuildContext context) {
    final c = context.cl;

    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
          decoration: BoxDecoration(
            color: c.card,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: c.border.withValues(alpha: 0.12)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.20),
                blurRadius: 26,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 46,
                height: 5,
                decoration: BoxDecoration(
                  color: c.border.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'كل أمور ديوانيتك في مكان واحد',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: c.t1,
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'نظرة سريعة على أهم المزايا قبل إنشاء ديوانيتك أو الانضمام لها.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: c.t2,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 18),
              const _FeatureGrid(),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        Navigator.of(sheetContext).pop();
                        context.push(AppRoutes.createDiwaniya);
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: c.accent,
                        foregroundColor: c.tInverse,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        'ابدأ الآن',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.of(sheetContext).pop();
                        context.push(AppRoutes.joinDiwaniya);
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF60A5FA),
                        side: BorderSide(
                          color: const Color(0xFF60A5FA).withValues(alpha: 0.30),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        'عندي رمز',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SignOutChip extends StatelessWidget {
  final VoidCallback onTap;

  const _SignOutChip({
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.cl;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: c.error.withValues(alpha: 0.060),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: c.error.withValues(alpha: 0.12)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.power_settings_new_rounded,
              size: 16,
              color: c.error,
            ),
            const SizedBox(width: 6),
            Text(
              'تسجيل الخروج',
              style: TextStyle(
                color: c.error,
                fontSize: 11.8,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WelcomeHero extends StatelessWidget {
  final VoidCallback onExplore;

  const _WelcomeHero({
    required this.onExplore,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.cl;

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: c.accent.withValues(alpha: 0.12)),
        gradient: LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          colors: [
            c.accent.withValues(alpha: 0.14),
            c.card,
            c.card,
          ],
        ),
      ),
      child: Stack(
        children: [
          PositionedDirectional(
            top: -38,
            end: -24,
            child: Icon(
              Icons.auto_awesome_rounded,
              color: c.accent.withValues(alpha: 0.08),
              size: 120,
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: c.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  Icons.waving_hand_rounded,
                  color: c.accent,
                  size: 25,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'أسفرت وأنورت',
                style: TextStyle(
                  color: c.t1,
                  fontSize: 27,
                  fontWeight: FontWeight.w900,
                  height: 1.08,
                ),
              ),
              const SizedBox(height: 9),
              Text(
                'أنشئ ديوانية جديدة أو انضم لديوانية قائمة برمز الدعوة.',
                style: TextStyle(
                  color: c.t2,
                  fontSize: 13.8,
                  fontWeight: FontWeight.w600,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: onExplore,
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
                  decoration: BoxDecoration(
                    color: c.inputBg.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: c.border.withValues(alpha: 0.10)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.play_circle_outline_rounded, color: c.accent, size: 17),
                      const SizedBox(width: 6),
                      Text(
                        'استكشف التطبيق',
                        style: TextStyle(
                          color: c.accent,
                          fontSize: 11.8,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AccessActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _AccessActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.cl;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: c.border.withValues(alpha: 0.11)),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.11),
                borderRadius: BorderRadius.circular(17),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: c.t1,
                      fontSize: 16.2,
                      fontWeight: FontWeight.w900,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: c.t2,
                      fontSize: 12.3,
                      fontWeight: FontWeight.w600,
                      height: 1.38,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_left_rounded, color: c.t3, size: 22),
          ],
        ),
      ),
    );
  }
}

class _ExploreActionCard extends StatelessWidget {
  final VoidCallback onTap;

  const _ExploreActionCard({
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.cl;
    const blue = Color(0xFF60A5FA);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        decoration: BoxDecoration(
          color: blue.withValues(alpha: 0.055),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: blue.withValues(alpha: 0.12)),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: blue.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(17),
              ),
              child: const Icon(Icons.explore_rounded, color: blue, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'استكشف التطبيق',
                    style: TextStyle(
                      color: c.t1,
                      fontSize: 16.2,
                      fontWeight: FontWeight.w900,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'تعرف على المزايا بدون الدخول إلى بيانات تشغيلية.',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: c.t2,
                      fontSize: 12.3,
                      fontWeight: FontWeight.w600,
                      height: 1.38,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_left_rounded, color: blue.withValues(alpha: 0.80), size: 22),
          ],
        ),
      ),
    );
  }
}

class _FeatureGrid extends StatelessWidget {
  const _FeatureGrid();

  @override
  Widget build(BuildContext context) {
    final c = context.cl;

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      childAspectRatio: 2.9,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      children: [
        const _FeaturePill(icon: Icons.chat_rounded, label: 'الدردشة', color: Color(0xFF60A5FA)),
        _FeaturePill(icon: Icons.event_available_rounded, label: 'التقويم', color: c.accent),
        _FeaturePill(icon: Icons.shopping_cart_rounded, label: 'المقاضي', color: c.warning),
        _FeaturePill(icon: Icons.account_balance_wallet_rounded, label: 'المصاريف', color: c.success),
        const _FeaturePill(icon: Icons.how_to_vote_rounded, label: 'التصويت', color: Color(0xFF60A5FA)),
        _FeaturePill(icon: Icons.photo_library_rounded, label: 'الألبوم', color: c.error),
      ],
    );
  }
}

class _FeaturePill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _FeaturePill({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.cl;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.075),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: color.withValues(alpha: 0.10)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 17),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: c.t1,
                fontSize: 11.7,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
