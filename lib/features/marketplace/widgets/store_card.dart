import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../config/theme/app_colors.dart';
import '../../../core/navigation/app_routes.dart';
import '../../../l10n/ar.dart';
import '../models/store_model.dart';
import '../services/marketplace_service.dart';
import 'offer_chip.dart';
import 'store_badges.dart';

String _ratingText(Store store) {
  if (!store.hasRating) return '';
  return store.rating!.toStringAsFixed(1);
}

String _reviewText(Store store) {
  if (!store.hasReviewCount) return '';
  return ' (${store.reviewCount})';
}

String _distanceText(Store store) {
  if (!store.hasDistance) return '';
  final distance = store.distanceKm!;
  if (distance < 1) {
    return '${(distance * 1000).round()} م';
  }
  return '${distance.toStringAsFixed(1)} كم';
}

class StoreCard extends StatelessWidget {
  final Store store;
  final bool compact;
  final String? diwaniyaId;
  final String? cityId;
  final String? districtId;

  const StoreCard({
    super.key,
    required this.store,
    this.compact = false,
    this.diwaniyaId,
    this.cityId,
    this.districtId,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.cl;
    final ratingText = _ratingText(store);
    final reviewText = _reviewText(store);
    final distanceText = _distanceText(store);
    final sourceBadge = _sourceBadge(context);

    return GestureDetector(
      onTap: () {
        MarketplaceService.recordMarketplaceEventLater(
          eventType: 'marketplace_store_open',
          store: store,
          diwaniyaId: diwaniyaId,
          cityId: cityId,
          districtId: districtId,
        );
        context.push(AppRoutes.storeDetails, extra: store.id);
      },
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
            Row(children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: c.accent.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(store.icon, size: 22, color: c.accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      store.name,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: c.t1,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      store.category,
                      style: TextStyle(fontSize: 11, color: c.t3),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (store.isOpenNow != null)
                OpenClosedBadge(isOpen: store.isOpenNow!),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              if (ratingText.isNotEmpty) ...[
                Icon(Icons.star_rounded, size: 14, color: c.warning),
                const SizedBox(width: 3),
                Text(
                  ratingText,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: c.t1,
                  ),
                ),
                if (reviewText.isNotEmpty)
                  Text(
                    reviewText,
                    style: TextStyle(fontSize: 10, color: c.t3),
                  ),
              ],
              if (ratingText.isNotEmpty && distanceText.isNotEmpty)
                const SizedBox(width: 12),
              if (distanceText.isNotEmpty) ...[
                Icon(Icons.place_rounded, size: 13, color: c.t3),
                const SizedBox(width: 2),
                Text(
                  distanceText,
                  style: TextStyle(
                    fontSize: 11,
                    color: c.t3,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              if (store.deliveryEtaText != null) ...[
                const SizedBox(width: 8),
                Icon(Icons.schedule_rounded, size: 13, color: c.t3),
                const SizedBox(width: 2),
                Flexible(
                  child: Text(
                    store.deliveryEtaText!,
                    style: TextStyle(fontSize: 11, color: c.t3),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
              if (sourceBadge != null) ...[
                const Spacer(),
                sourceBadge,
              ],
            ]),
            if (store.hasActiveOffers && !compact) ...[
              const SizedBox(height: 8),
              OfferChip(offer: store.activeOffers.first),
            ],
          ],
        ),
      ),
    );
  }

  Widget? _sourceBadge(BuildContext context) {
    final c = context.cl;
    if (store.isSponsored) {
      return SmallBadge(label: Ar.sponsored, color: c.warning);
    }
    if (store.isVerifiedMerchant) {
      return SmallBadge(label: 'موثق في ديوانية', color: c.accent);
    }
    final label = store.attributionLabel?.trim();
    if (label != null && label.isNotEmpty) {
      return SmallBadge(label: label, color: c.info);
    }
    return null;
  }
}
