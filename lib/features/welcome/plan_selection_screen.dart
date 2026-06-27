import 'dart:io' show Platform;

import 'package:flutter/material.dart';

import '../../config/theme/app_colors.dart';
import '../../core/models/mock_data.dart';
import '../../l10n/ar.dart';

class PlanSelectionScreen extends StatefulWidget {
  const PlanSelectionScreen({super.key});

  @override
  State<PlanSelectionScreen> createState() => _PlanSelectionScreenState();
}

class _LaunchSubscriptionPlan {
  final String productId;
  final String title;
  final String price;
  final String badge;
  final int memberLimit;

  const _LaunchSubscriptionPlan({
    required this.productId,
    required this.title,
    required this.price,
    required this.badge,
    required this.memberLimit,
  });
}

const _launchPlans = <_LaunchSubscriptionPlan>[
  _LaunchSubscriptionPlan(
    productId: 'diwaniya_10_members_monthly',
    title: 'خطة 10 أعضاء',
    price: '10 ر.س / شهر',
    badge: 'حتى 10 أعضاء',
    memberLimit: 10,
  ),
  _LaunchSubscriptionPlan(
    productId: 'diwaniya_20_members_monthly',
    title: 'خطة 20 عضو',
    price: '20 ر.س / شهر',
    badge: 'حتى 20 عضو',
    memberLimit: 20,
  ),
  _LaunchSubscriptionPlan(
    productId: 'diwaniya_30_members_monthly',
    title: 'خطة 30 عضو',
    price: '30 ر.س / شهر',
    badge: 'حتى 30 عضو',
    memberLimit: 30,
  ),
];

class _PlanSelectionScreenState extends State<PlanSelectionScreen> {
  String _selectedProductId = _launchPlans.first.productId;
  bool _submitting = false;

  String get _paymentLabel {
    if (Platform.isIOS) return 'App Store In-App Purchase';
    return 'Google Play Billing';
  }

  _LaunchSubscriptionPlan get _selectedPlan => _launchPlans.firstWhere(
        (plan) => plan.productId == _selectedProductId,
        orElse: () => _launchPlans.first,
      );

  Future<void> _confirm() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      final c = context.cl;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            backgroundColor: c.card,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Text(
              'الدفع غير جاهز للإطلاق',
              style: TextStyle(
                color: c.t1,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            content: Text(
              'تفعيل ${_selectedPlan.productId} يتطلب إعداد المنتج في المتجر، وربط الشراء بتحقق الخادم قبل منح الاشتراك.',
              style: TextStyle(
                color: c.t2,
                height: 1.65,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('تم'),
              ),
            ],
          );
        },
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.cl;
    final current = allDiwaniyas
        .where((d) => d.id == currentDiwaniyaId)
        .firstOrNull;

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(backgroundColor: c.bg),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            const _HeroCard(
              title: 'ترقية الديوانية',
              subtitle:
                  'اختر حد الأعضاء المناسب. لن يتم تفعيل أي اشتراك إلا بعد شراء المتجر والتحقق من الخادم.',
            ),
            if (current != null) ...[
              const SizedBox(height: 16),
              _CurrentDiwaniyaCard(diw: current),
            ],
            const SizedBox(height: 16),
            const _BenefitsCard(),
            const SizedBox(height: 18),
            for (final plan in _launchPlans) ...[
              _PlanCard(
                title: plan.title,
                price: plan.price,
                badge: plan.badge,
                selected: _selectedProductId == plan.productId,
                bullets: [
                  'حتى ${plan.memberLimit} أعضاء',
                  'معرّف المنتج: ${plan.productId}',
                  'التفعيل بعد تحقق الخادم فقط',
                ],
                note: 'اشتراك شهري للديوانية الحالية',
                onTap: () => setState(() => _selectedProductId = plan.productId),
              ),
              const SizedBox(height: 14),
            ],
            _PaymentCard(paymentLabel: _paymentLabel),
            const SizedBox(height: 18),
            SizedBox(
              height: 54,
              child: ElevatedButton(
                onPressed: _confirm,
                child: Text(_submitting ? Ar.loading : 'متابعة الدفع'),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'الشراء داخل التطبيق لم يكتمل ربطه بعد. لا يمنح التطبيق أي صلاحية مدفوعة حتى يعتمد الخادم الاشتراك بعد تحقق المتجر.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                height: 1.7,
                color: c.t3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  final String title;
  final String subtitle;

  const _HeroCard({
    required this.title,
    required this.subtitle,
  });

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
              Icons.workspace_premium_rounded,
              color: c.accent,
              size: 22,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.w800,
              color: c.t1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
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

class _CurrentDiwaniyaCard extends StatelessWidget {
  final DiwaniyaInfo diw;

  const _CurrentDiwaniyaCard({required this.diw});

  @override
  Widget build(BuildContext context) {
    final c = context.cl;
    final locationParts = <String>[
      if (diw.district.isNotEmpty) diw.district,
      if (diw.city.isNotEmpty) diw.city,
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            diw.name,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: c.t1,
            ),
          ),
          if (locationParts.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              locationParts.join(' · '),
              style: TextStyle(color: c.t2),
            ),
          ],
          if (diw.invitationCode != null && diw.invitationCode!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'رمز الدعوة: ${diw.invitationCode}',
              style: TextStyle(color: c.t2),
            ),
          ],
        ],
      ),
    );
  }
}

class _BenefitsCard extends StatelessWidget {
  const _BenefitsCard();

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
      child: const Row(
        children: [
          Expanded(
            child: _ValuePill(
              icon: Icons.group_add_rounded,
              label: 'حد أعضاء أوضح',
            ),
          ),
          SizedBox(width: 10),
          Expanded(
            child: _ValuePill(
              icon: Icons.verified_user_rounded,
              label: 'تحقق من الخادم',
            ),
          ),
          SizedBox(width: 10),
          Expanded(
            child: _ValuePill(
              icon: Icons.restore_rounded,
              label: 'استعادة مشتريات مطلوبة',
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final String title;
  final String price;
  final String badge;
  final bool selected;
  final List<String> bullets;
  final String note;
  final VoidCallback onTap;

  const _PlanCard({
    required this.title,
    required this.price,
    required this.badge,
    required this.selected,
    required this.bullets,
    required this.note,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.cl;

    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: selected ? c.accent : c.border,
            width: selected ? 1.6 : 1,
          ),
          boxShadow:
              selected ? [BoxShadow(color: c.shadow, blurRadius: 10)] : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: c.t1,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: selected ? c.accentMuted : c.cardElevated,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    badge,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: selected ? c.accent : c.t2,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              price,
              style: TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.w900,
                color: c.t1,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              note,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.7,
                color: c.t2,
              ),
            ),
            const SizedBox(height: 12),
            for (final bullet in bullets)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.check_circle_rounded,
                      size: 18,
                      color: c.accent,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        bullet,
                        style: TextStyle(
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

class _PaymentCard extends StatelessWidget {
  final String paymentLabel;

  const _PaymentCard({required this.paymentLabel});

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
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: c.warningM,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.lock_clock_rounded, color: c.warning),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  Ar.paymentMethod,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: c.t1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$paymentLabel · بانتظار ربط التحقق',
                  style: TextStyle(color: c.t2),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ValuePill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _ValuePill({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.cl;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: c.cardElevated,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: c.accent),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: c.t1,
            ),
          ),
        ],
      ),
    );
  }
}
