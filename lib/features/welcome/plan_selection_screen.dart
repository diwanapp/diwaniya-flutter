import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../config/theme/app_colors.dart';
import '../../core/models/expense_models.dart';
import '../../core/models/mock_data.dart';
import '../../core/models/subscription_status.dart';
import '../../core/repositories/app_repository.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/expense_service.dart';
import '../../core/services/subscription_service.dart';
import '../../core/services/user_service.dart';
import '../../l10n/ar.dart';

class PlanSelectionScreen extends StatefulWidget {
  const PlanSelectionScreen({super.key});

  @override
  State<PlanSelectionScreen> createState() => _PlanSelectionScreenState();
}

class _PlanSelectionScreenState extends State<PlanSelectionScreen> {
  SubscriptionPlan _selected = SubscriptionPlan.yearly;
  bool _submitting = false;

  String get _paymentLabel {
    if (Platform.isIOS) return Ar.applePay;
    return Ar.androidPayEquivalent;
  }

  String get _title => 'ترقية الديوانية';

  String get _subtitle =>
      'ارفع حدود ديوانيتك واحصل على مزايا أوسع. الترقية تسري على الديوانية الحالية.';

  String get _ctaLabel => 'تأكيد الترقية';

  Future<void> _confirm() async {
    if (_submitting) return;
    setState(() => _submitting = true);

    await Future<void>.delayed(const Duration(milliseconds: 500));

    // Upgrade the currently selected diwaniya from free to the chosen
    // paid plan. This is local-only until backend subscription
    // integration lands.
    final ok = await AuthService.upgradeCurrentDiwaniyaToPlan(
      plan: _selected,
    );

    if (!mounted) return;
    if (!ok) {
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذّر تفعيل الترقية')),
      );
      return;
    }

    await _showExpenseSuggestion();
    if (!mounted) return;

    // Pop back to wherever the upgrade was triggered from (home banner,
    // settings card, contextual paywall). Router guard blocks earlier-
    // state screens so we are guaranteed to land somewhere safe.
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AuthService.nextRoute());
    }
  }

  Future<void> _showExpenseSuggestion() async {
    final sub = SubscriptionService.current;
    if (sub == null || sub.amountSar <= 0) return;

    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (d) {
        final dc = d.cl;
        return AlertDialog(
          backgroundColor: dc.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            Ar.addSubscriptionAsExpense,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: dc.t1,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: dc.accentSurface,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Icon(Icons.receipt_long_rounded, color: dc.accent),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '${sub.amountSar} ${Ar.sarCurrency} — ${Ar.splitEquallyAmongMembers}',
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.6,
                          color: dc.t1,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(d, false),
              child: Text(
                Ar.addLater,
                style: TextStyle(color: dc.t3),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(d, true),
              child: const Text(Ar.addExpenseNow),
            ),
          ],
        );
      },
    );

    if (accepted == true && mounted) {
      await _createSubscriptionExpense(sub.amountSar);
    }
  }

  Future<void> _createSubscriptionExpense(int amountSar) async {
    final members = currentMembers;
    if (members.isEmpty) return;

    final shares = <String, double>{};
    final perPerson = amountSar / members.length;

    for (final m in members) {
      if (m.name != UserService.currentName) {
        shares[m.name] = perPerson;
      }
    }

    try {
      await ExpenseService.createExpense(
        Expense(
          id: 'exp_${DateTime.now().microsecondsSinceEpoch}',
          title: Ar.subscriptionExpenseTitle,
          payer: UserService.currentName,
          category: 'أخرى',
          splitType: 'equal',
          amount: amountSar.toDouble(),
          shares: shares,
          createdAt: DateTime.now(),
          createdBy: UserService.currentName,
        ),
      );
      await AppRepository.saveActivities();
      await AppRepository.saveNotifications();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ExpenseService.friendlyMessage(e))),
      );
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
            _HeroCard(
              title: _title,
              subtitle: _subtitle,
            ),
            if (current != null) ...[
              const SizedBox(height: 16),
              _CurrentDiwaniyaCard(diw: current),
            ],
            const SizedBox(height: 16),
            const _BenefitsCard(),
            const SizedBox(height: 18),
            _PlanCard(
              title: 'الخطة السنوية',
              price: '294 ريال / سنة',
              badge: 'الأوفر',
              selected: _selected == SubscriptionPlan.yearly,
              bullets: const [
                '294 ريال سنويًا',
                'توفير 50% مقارنة بالخطة الشهرية',
                'انضمام الأعضاء دون رسوم',
              ],
              note: 'الأفضل للديوانيات المستمرة',
              onTap: () => setState(() => _selected = SubscriptionPlan.yearly),
            ),
            const SizedBox(height: 14),
            _PlanCard(
              title: 'الخطة الشهرية',
              price: '49 ريال / شهر',
              badge: 'الخيار المرن',
              selected: _selected == SubscriptionPlan.monthly,
              bullets: const [
                '49 ريال شهريًا',
                'تجديد تلقائي كل شهر',
                'انضمام الأعضاء دون رسوم',
              ],
              note: 'الأنسب للمرونة في الاشتراك',
              onTap: () => setState(() => _selected = SubscriptionPlan.monthly),
            ),
            const SizedBox(height: 18),
            _PaymentCard(paymentLabel: _paymentLabel),
            const SizedBox(height: 18),
            SizedBox(
              height: 54,
              child: ElevatedButton(
                onPressed: _confirm,
                child: Text(_submitting ? Ar.loading : _ctaLabel),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'الدفع في هذه النسخة محاكاة داخلية لأغراض التطوير، على أن يتم الربط الفعلي لاحقًا بطريقة دفع مناسبة.',
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
              label: 'عدد أعضاء أكبر',
            ),
          ),
          SizedBox(width: 10),
          Expanded(
            child: _ValuePill(
              icon: Icons.photo_library_rounded,
              label: 'ألبوم صور أوسع',
            ),
          ),
          SizedBox(width: 10),
          Expanded(
            child: _ValuePill(
              icon: Icons.tune_rounded,
              label: 'أدوات إدارة متقدمة',
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
              color: c.accentMuted,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.payments_rounded, color: c.accent),
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
                  paymentLabel,
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