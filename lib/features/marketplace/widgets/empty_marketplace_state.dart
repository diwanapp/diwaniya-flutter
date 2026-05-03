import 'package:flutter/material.dart';

import '../../../config/theme/app_colors.dart';

class EmptyMarketplaceState extends StatelessWidget {
  final bool isFiltered;
  final String? cityLabel;

  const EmptyMarketplaceState({
    super.key,
    this.isFiltered = false,
    this.cityLabel,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.cl;
    final title = isFiltered ? 'لا توجد نتائج مطابقة' : 'السوق قيد التجهيز';
    final subtitle = isFiltered
        ? 'جرّب تغيير البحث أو الفلاتر لرؤية نتائج أكثر.'
        : cityLabel == null
            ? 'سيظهر هنا المتاجر والخدمات القريبة من ديوانيتك بعد تفعيل التجار الحقيقيين.'
            : 'نعمل على تجهيز التجار والخدمات القريبة من $cityLabel لعرضها هنا بشكل حي وموثوق.';

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: c.accent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(
                isFiltered
                    ? Icons.search_off_rounded
                    : Icons.storefront_outlined,
                size: 38,
                color: c.accent,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: c.t1,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: c.t3,
                fontSize: 13,
                height: 1.7,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
