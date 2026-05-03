import 'package:flutter/material.dart';

import '../../config/theme/app_colors.dart';
import '../../l10n/ar.dart';
import 'services/marketplace_service.dart';
import 'widgets/offer_chip.dart';
import 'widgets/store_action_row.dart';
import 'widgets/store_badges.dart';

class StoreDetailsScreen extends StatelessWidget {
  final String storeId;
  const StoreDetailsScreen({super.key, required this.storeId});

  @override
  Widget build(BuildContext context) {
    final c = context.cl;
    final store = MarketplaceService.getStoreById(storeId);

    if (store == null) {
      return Scaffold(
        backgroundColor: c.bg,
        appBar: AppBar(backgroundColor: c.bg),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.storefront_outlined, size: 44, color: c.t3),
                const SizedBox(height: 12),
                Text(
                  'تفاصيل المتجر غير متاحة حاليًا',
                  style: TextStyle(
                    color: c.t1,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'سيظهر هذا القسم عند تفعيل المتاجر والبيانات الحية داخل السوق.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: c.t3, height: 1.7),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: c.bg,
      body: CustomScrollView(slivers: [
        SliverAppBar(
          expandedHeight: 200,
          pinned: true,
          backgroundColor: c.bg,
          surfaceTintColor: Colors.transparent,
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [c.accent.withValues(alpha: 0.18), c.accent.withValues(alpha: 0.04)],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                ),
              ),
              child: Center(
                child: Icon(
                  store.icon,
                  size: 64,
                  color: c.accent.withValues(alpha: 0.5),
                ),
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              Row(children: [
                Expanded(
                  child: Text(
                    store.name,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: c.t1,
                    ),
                  ),
                ),
                OpenClosedBadge(isOpen: store.isOpenNow, fontSize: 12),
              ]),
              const SizedBox(height: 6),
              Text(
                '${store.category} · ${store.district}، ${store.city}',
                style: TextStyle(fontSize: 13, color: c.t3),
              ),
              const SizedBox(height: 10),
              Row(children: [
                Icon(Icons.star_rounded, size: 18, color: c.warning),
                const SizedBox(width: 4),
                Text(
                  '${store.rating}',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: c.t1),
                ),
                const SizedBox(width: 6),
                Text(
                  '(${store.reviewCount} ${Ar.reviews})',
                  style: TextStyle(fontSize: 13, color: c.t3),
                ),
                const SizedBox(width: 16),
                Icon(Icons.place_rounded, size: 16, color: c.t3),
                const SizedBox(width: 3),
                Text(
                  '${store.distanceKm} ${Ar.km}',
                  style: TextStyle(fontSize: 13, color: c.t3),
                ),
                if (store.deliveryEtaText != null) ...[
                  const SizedBox(width: 12),
                  Icon(Icons.schedule_rounded, size: 16, color: c.t3),
                  const SizedBox(width: 3),
                  Text(store.deliveryEtaText!, style: TextStyle(fontSize: 13, color: c.t3)),
                ],
              ]),
              if (store.isFeatured || store.isSponsored) ...[
                const SizedBox(height: 10),
                Row(children: [
                  if (store.isSponsored)
                    StoreBadge(label: Ar.sponsored, color: c.warning),
                  if (store.isSponsored && store.isFeatured) const SizedBox(width: 8),
                  if (store.isFeatured)
                    StoreBadge(label: Ar.featured, color: c.accent),
                ]),
              ],
              const SizedBox(height: 20),
              StoreActionRow(store: store),
              const SizedBox(height: 24),
              Text(
                Ar.aboutStore,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: c.t1),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: c.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: c.border),
                ),
                child: Text(
                  store.description,
                  style: TextStyle(fontSize: 14, height: 1.8, color: c.t2),
                ),
              ),
              if (store.tags.isNotEmpty) ...[
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: store.tags
                      .map(
                        (t) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: c.inputBg,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(t, style: TextStyle(fontSize: 12, color: c.t2)),
                        ),
                      )
                      .toList(),
                ),
              ],
              if (store.activeOffers.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text(
                  Ar.offersSection,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: c.t1),
                ),
                const SizedBox(height: 10),
                ...store.activeOffers.map((o) => OfferCard(offer: o)),
              ],
            ]),
          ),
        ),
      ]),
    );
  }
}
