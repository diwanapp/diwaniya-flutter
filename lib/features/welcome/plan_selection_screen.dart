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

class _DiwaniyaPricingTier {
  final String label;
  final String productId;
  final int priceSar;
  final int minMembers;
  final int? maxMembers;
  final String rangeLabel;
  final String description;

  const _DiwaniyaPricingTier({
    required this.label,
    required this.productId,
    required this.priceSar,
    required this.minMembers,
    required this.maxMembers,
    required this.rangeLabel,
    required this.description,
  });

  bool matches(int memberCount) {
    final max = maxMembers;
    if (max == null) return memberCount >= minMembers;
    return memberCount >= minMembers && memberCount <= max;
  }
}

const _pricingTiers = <_DiwaniyaPricingTier>[
  _DiwaniyaPricingTier(
    label: '10',
    productId: 'diwaniya_10_monthly',
    priceSar: 10,
    minMembers: 1,
    maxMembers: 10,
    rangeLabel: '1-10 أعضاء',
    description: 'مناسب للديوانيات الصغيرة',
  ),
  _DiwaniyaPricingTier(
    label: '20',
    productId: 'diwaniya_20_monthly',
    priceSar: 20,
    minMembers: 11,
    maxMembers: 20,
    rangeLabel: '11-20 عضو',
    description: 'مناسب لديوانية نامية',
  ),
  _DiwaniyaPricingTier(
    label: '30',
    productId: 'diwaniya_30_monthly',
    priceSar: 30,
    minMembers: 21,
    maxMembers: 30,
    rangeLabel: '21-30 عضو',
    description: 'مناسب للمجموعات النشطة',
  ),
  _DiwaniyaPricingTier(
    label: '40',
    productId: 'diwaniya_40_monthly',
    priceSar: 40,
    minMembers: 31,
    maxMembers: 40,
    rangeLabel: '31-40 عضو',
    description: 'مناسب للديوانيات الكبيرة',
  ),
  _DiwaniyaPricingTier(
    label: '50+',
    productId: 'diwaniya_50_plus_monthly',
    priceSar: 50,
    minMembers: 41,
    maxMembers: null,
    rangeLabel: 'للديوانيات الكبيرة',
    description: 'أكثر من 40 عضو',
  ),
];

class _PlanSelectionScreenState extends State<PlanSelectionScreen> {
  String? _selectedProductId;
  bool _submitting = false;

  String get _paymentLabel {
    if (Platform.isIOS) return 'App Store';
    return 'Google Play';
  }

  _DiwaniyaPricingTier? _tierById(String? productId) {
    if (productId == null) return null;
    for (final tier in _pricingTiers) {
      if (tier.productId == productId) return tier;
    }
    return null;
  }

  _DiwaniyaPricingTier? _tierForMembers(int? memberCount) {
    if (memberCount == null || memberCount <= 0) return null;
    for (final tier in _pricingTiers) {
      if (tier.matches(memberCount)) return tier;
    }
    return _pricingTiers.last;
  }

  int? _memberCountFor(DiwaniyaInfo? diwaniya) {
    if (diwaniya == null) return null;
    final fromSnapshot = diwaniya.memberCount;
    if (fromSnapshot != null && fromSnapshot > 0) return fromSnapshot;
    final localMembers = diwaniyaMembers[diwaniya.id];
    if (localMembers != null && localMembers.isNotEmpty) {
      return localMembers.length;
    }
    return null;
  }

  Future<void> _confirm(_DiwaniyaPricingTier tier) async {
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
              borderRadius: BorderRadius.circular(22),
            ),
            title: Text(
              'الدفع قيد التفعيل',
              style: TextStyle(
                color: c.t1,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            content: Text(
              'سيتم تفعيل الدفع من خلال App Store وGoogle Play قبل الإطلاق الرسمي. لن يتم تفعيل ${tier.productId} أو منح أي صلاحية مدفوعة حتى يعتمد الخادم الاشتراك بعد تحقق المتجر.',
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
    final memberCount = _memberCountFor(current);
    final recommendedTier = _tierForMembers(memberCount);
    final effectiveSelectedId =
        _selectedProductId ?? recommendedTier?.productId;
    final selectedTier = _tierById(effectiveSelectedId);

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.bg,
        title: Text(
          'اشتراك الديوانية',
          style: TextStyle(
            color: c.t1,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            const _HeroCard(
              title: 'اختر باقة الديوانية',
              subtitle:
                  'اشتراك واحد للديوانية، والسعر يتدرج حسب عدد الأعضاء.',
            ),
            const SizedBox(height: 16),
            _PrinciplesCard(c: c),
            if (current != null) ...[
              const SizedBox(height: 16),
              _CurrentDiwaniyaCard(
                diwaniya: current,
                memberCount: memberCount,
                recommendedTier: recommendedTier,
              ),
            ],
            const SizedBox(height: 18),
            _SectionHeader(
              c: c,
              title: 'الباقات الشهرية',
              subtitle: memberCount == null
                  ? 'اختر الباقة المناسبة لحجم الديوانية.'
                  : 'عدد الأعضاء الحالي يرشح باقة ${recommendedTier?.label ?? '10'}.',
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final twoColumns = constraints.maxWidth >= 620;
                final itemWidth = twoColumns
                    ? (constraints.maxWidth - 12) / 2
                    : constraints.maxWidth;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final tier in _pricingTiers)
                      SizedBox(
                        width: itemWidth,
                        child: _TierCard(
                          tier: tier,
                          selected: effectiveSelectedId == tier.productId,
                          recommended:
                              recommendedTier?.productId == tier.productId,
                          onTap: () {
                            setState(() {
                              _selectedProductId = tier.productId;
                            });
                          },
                        ),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            _PaymentCard(
              paymentLabel: _paymentLabel,
              selectedTier: selectedTier,
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 54,
              child: ElevatedButton(
                onPressed: selectedTier == null
                    ? null
                    : () => _confirm(selectedTier),
                child: Text(
                  _submitting
                      ? Ar.loading
                      : selectedTier == null
                          ? 'اختر باقة للمتابعة'
                          : 'متابعة الدفع',
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'الدفع الحقيقي سيتم عبر App Store أو Google Play عند تفعيله. لا يتم تفعيل أي اشتراك من الجهاز فقط.',
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            c.accent.withValues(alpha: 0.18),
            c.card,
            c.cardElevated.withValues(alpha: 0.72),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: c.accent.withValues(alpha: 0.16)),
        boxShadow: [BoxShadow(color: c.shadow, blurRadius: 14)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: c.accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(
              Icons.workspace_premium_rounded,
              color: c.accent,
              size: 24,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
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

class _PrinciplesCard extends StatelessWidget {
  final CL c;

  const _PrinciplesCard({required this.c});

  @override
  Widget build(BuildContext context) {
    const items = [
      'الاشتراك على مستوى الديوانية',
      'السعر يعتمد على حجم الديوانية',
      'يمكن الترقية عند نمو عدد الأعضاء',
      'الصلاحيات والمزايا تبقى حسب الخطة المعتمدة',
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.border),
      ),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.check_circle_rounded, color: c.accent, size: 18),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    items[i],
                    style: TextStyle(
                      color: c.t2,
                      height: 1.55,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            if (i != items.length - 1) const SizedBox(height: 9),
          ],
        ],
      ),
    );
  }
}

class _CurrentDiwaniyaCard extends StatelessWidget {
  final DiwaniyaInfo diwaniya;
  final int? memberCount;
  final _DiwaniyaPricingTier? recommendedTier;

  const _CurrentDiwaniyaCard({
    required this.diwaniya,
    required this.memberCount,
    required this.recommendedTier,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.cl;
    final tier = recommendedTier;
    final locationParts = <String>[
      if (diwaniya.district.isNotEmpty) diwaniya.district,
      if (diwaniya.city.isNotEmpty) diwaniya.city,
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
          Row(
            children: [
              Expanded(
                child: Text(
                  diwaniya.name,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: c.t1,
                  ),
                ),
              ),
              if (memberCount != null)
                _SoftPill(
                  label: '$memberCount عضو',
                  color: c.accent,
                  background: c.accentMuted,
                ),
            ],
          ),
          if (locationParts.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              locationParts.join(' · '),
              style: TextStyle(color: c.t2),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            tier == null
                ? 'لم نستطع تحديد عدد الأعضاء تلقائيًا. اختر الباقة المناسبة لحجم الديوانية.'
                : 'الباقة المناسبة الآن: ${tier.label}. يمكن الترقية عند نمو الديوانية.',
            style: TextStyle(
              color: c.t2,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final CL c;
  final String title;
  final String subtitle;

  const _SectionHeader({
    required this.c,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: c.t1,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          subtitle,
          style: TextStyle(
            color: c.t3,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

class _TierCard extends StatelessWidget {
  final _DiwaniyaPricingTier tier;
  final bool selected;
  final bool recommended;
  final VoidCallback onTap;

  const _TierCard({
    required this.tier,
    required this.selected,
    required this.recommended,
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
        constraints: const BoxConstraints(minHeight: 178),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? c.cardElevated : c.card,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: selected ? c.accent : c.border,
            width: selected ? 1.7 : 1,
          ),
          boxShadow:
              selected ? [BoxShadow(color: c.shadow, blurRadius: 14)] : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 62,
                  height: 62,
                  decoration: BoxDecoration(
                    color: selected ? c.accent : c.accentMuted,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        tier.label,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: selected ? c.tInverse : c.accent,
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              tier.rangeLabel,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: c.t1,
                                fontSize: 15.5,
                                fontWeight: FontWeight.w800,
                                height: 1.35,
                              ),
                            ),
                          ),
                          if (recommended)
                            _SoftPill(
                              label: 'مناسبة الآن',
                              color: c.success,
                              background: c.successM,
                            ),
                        ],
                      ),
                      const SizedBox(height: 7),
                      Text(
                        tier.description,
                        style: TextStyle(
                          color: c.t3,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _PriceLine(priceSar: tier.priceSar),
            const SizedBox(height: 9),
            Text(
              'السعر حسب عدد الأعضاء، وليس تفعيلًا فوريًا للدفع.',
              style: TextStyle(
                color: c.t3,
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PriceLine extends StatelessWidget {
  final int priceSar;

  const _PriceLine({required this.priceSar});

  @override
  Widget build(BuildContext context) {
    final c = context.cl;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          '$priceSar',
          style: TextStyle(
            color: c.t1,
            fontSize: 31,
            fontWeight: FontWeight.w900,
            height: 1,
          ),
        ),
        const SizedBox(width: 6),
        Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: Text(
            '${Ar.sarCurrency} / شهر',
            style: TextStyle(
              color: c.t2,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _PaymentCard extends StatelessWidget {
  final String paymentLabel;
  final _DiwaniyaPricingTier? selectedTier;

  const _PaymentCard({
    required this.paymentLabel,
    required this.selectedTier,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.cl;
    final tier = selectedTier;

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
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: c.warningM,
              borderRadius: BorderRadius.circular(13),
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
                    fontWeight: FontWeight.w800,
                    color: c.t1,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'الدفع عبر $paymentLabel قيد التفعيل.',
                  style: TextStyle(color: c.t2, height: 1.55),
                ),
                if (tier != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    'معرّف المنتج المحضّر: ${tier.productId}',
                    style: TextStyle(
                      color: c.t3,
                      fontSize: 12,
                      height: 1.45,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SoftPill extends StatelessWidget {
  final String label;
  final Color color;
  final Color background;

  const _SoftPill({
    required this.label,
    required this.color,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
