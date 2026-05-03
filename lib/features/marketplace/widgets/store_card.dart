import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../config/theme/app_colors.dart';
import '../../../core/navigation/app_routes.dart';
import '../../../l10n/ar.dart';
import '../models/store_model.dart';
import 'store_badges.dart';
import 'offer_chip.dart';

class StoreCard extends StatelessWidget {
  final Store store;
  final bool compact;
  const StoreCard({super.key, required this.store, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final c = context.cl;
    return GestureDetector(
      onTap: () => context.push(AppRoutes.storeDetails, extra: store.id),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header: icon + name + open badge
            Row(children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: c.accent.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(store.icon, size: 22, color: c.accent),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(store.name,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: c.t1),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(store.category, style: TextStyle(fontSize: 11, color: c.t3)),
                ],
              )),
              OpenClosedBadge(isOpen: store.isOpenNow),
            ]),
            const SizedBox(height: 10),

            // Meta: rating + distance + badges
            Row(children: [
              Icon(Icons.star_rounded, size: 14, color: c.warning),
              const SizedBox(width: 3),
              Text('${store.rating}',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.t1)),
              Text(' (${store.reviewCount})', style: TextStyle(fontSize: 10, color: c.t3)),
              const SizedBox(width: 12),
              Icon(Icons.place_rounded, size: 13, color: c.t3),
              const SizedBox(width: 2),
              Text('${store.distanceKm} ${Ar.km}', style: TextStyle(fontSize: 11, color: c.t3)),
              if (store.deliveryEtaText != null) ...[
                const SizedBox(width: 8),
                Icon(Icons.schedule_rounded, size: 13, color: c.t3),
                const SizedBox(width: 2),
                Flexible(child: Text(store.deliveryEtaText!,
                    style: TextStyle(fontSize: 11, color: c.t3),
                    overflow: TextOverflow.ellipsis)),
              ],
              if (store.isSponsored) ...[
                const Spacer(),
                SmallBadge(label: Ar.sponsored, color: c.warning),
              ] else if (store.isFeatured) ...[
                const Spacer(),
                SmallBadge(label: Ar.featured, color: c.accent),
              ],
            ]),

            // Offer (full mode only)
            if (store.hasActiveOffers && !compact) ...[
              const SizedBox(height: 8),
              OfferChip(offer: store.activeOffers.first),
            ],
          ],
        ),
      ),
    );
  }
}
