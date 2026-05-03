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
    final localCount = AuthService.getLocalDiwaniyaDirectory().length;

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(backgroundColor: c.bg),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            const _AccessHeroCard(),
            const SizedBox(height: 18),
            _AccessActionCard(
              icon: Icons.add_business_rounded,
              color: c.accent,
              title: 'إنشاء ديوانية',
              subtitle:
                  'إنشاء ديوانية جديدة وإصدار رمز الدعوة الخاص بها، ثم البدء في دعوة الأعضاء وإدارة التفاصيل.',
              footer: 'الخيار المناسب لبدء ديوانية جديدة ضمن حسابكم.',
              onTap: () => context.push(AppRoutes.createDiwaniya),
            ),
            const SizedBox(height: 14),
            _AccessActionCard(
              icon: Icons.login_rounded,
              color: c.info,
              title: 'الانضمام إلى ديوانية',
              subtitle:
                  'الدخول إلى ديوانية قائمة عبر رمز الدعوة المرسل من مدير الديوانية.',
              footer: localCount > 0
                  ? 'تتوفر حاليًا $localCount رموز محلية لأغراض التجربة.'
                  : 'يمكن الانضمام مباشرة عند توفر رمز الدعوة.',
              onTap: () => context.push(AppRoutes.joinDiwaniya),
            ),
            const SizedBox(height: 18),
            const _AccessPremiumNoteCard(),
          ],
        ),
      ),
    );
  }
}

class _AccessHeroCard extends StatelessWidget {
  const _AccessHeroCard();

  @override
  Widget build(BuildContext context) {
    final c = context.cl;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            c.accent.withValues(alpha: 0.14),
            c.accent.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: c.accent.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: c.accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              Icons.groups_rounded,
              color: c.accent,
              size: 22,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'أسفرت وأنورت',
            style: TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.w800,
              color: c.t1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'أنشئ ديوانية جديدة أو انضم إلى ديوانية قائمة برمز الدعوة.',
            style: TextStyle(
              fontSize: 14.5,
              height: 1.8,
              color: c.t2,
            ),
          ),
        ],
      ),
    );
  }
}

class _AccessActionCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String footer;
  final VoidCallback onTap;

  const _AccessActionCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.footer,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.cl;

    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: c.border),
          boxShadow: [BoxShadow(color: c.shadow, blurRadius: 8)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: c.t1,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 14,
                height: 1.75,
                color: c.t2,
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: c.cardElevated,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, size: 18, color: color),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      footer,
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.6,
                        color: c.t2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccessPremiumNoteCard extends StatelessWidget {
  const _AccessPremiumNoteCard();

  @override
  Widget build(BuildContext context) {
    final c = context.cl;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: c.accentMuted,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.workspace_premium_rounded,
              color: c.accent,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'بريميوم متاح لمن يحتاج مزايا إضافية',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: c.t1,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'يمكن الترقية لاحقًا عند الحاجة لمزايا إضافية.',
                  style: TextStyle(
                    fontSize: 12.8,
                    height: 1.75,
                    color: c.t2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
