import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../config/theme/app_colors.dart';
import '../../../core/navigation/app_routes.dart';
import '../../../l10n/ar.dart';
import '../models/store_model.dart';

class MarketplaceBannerCarousel extends StatelessWidget {
  final List<Store> stores;
  const MarketplaceBannerCarousel({super.key, required this.stores});

  @override
  Widget build(BuildContext context) {
    if (stores.isEmpty) { return const SizedBox.shrink(); }
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: SizedBox(
        height: 160,
        child: PageView.builder(
          controller: PageController(viewportFraction: 0.88),
          itemCount: stores.length,
          itemBuilder: (_, i) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: _BannerCard(store: stores[i]),
          ),
        ),
      ),
    );
  }
}

class _BannerCard extends StatelessWidget {
  final Store store;
  const _BannerCard({required this.store});

  @override
  Widget build(BuildContext context) {
    final c = context.cl;
    return GestureDetector(
      onTap: () => context.push(AppRoutes.storeDetails, extra: store.id),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [c.accent.withValues(alpha: 0.15), c.accent.withValues(alpha: 0.05)],
            begin: Alignment.topRight, end: Alignment.bottomLeft,
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: c.accent.withValues(alpha: 0.15)),
        ),
        padding: const EdgeInsets.all(18),
        child: Row(children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (store.isSponsored)
                  Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: c.warning.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      Ar.sponsored,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: c.warning,
                      ),
                    ),
                  ),
                Text(
                  store.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: c.t1,
                  ),
                ),
                const SizedBox(height: 4),
                Flexible(
                  child: Text(
                    store.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, height: 1.4, color: c.t2),
                  ),
                ),
                if (store.hasActiveOffers) ...[
                  const SizedBox(height: 6),
                  Text(
                    store.activeOffers.first.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: c.accent,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 16),
          Container(
            width: 60, height: 60,
            decoration: BoxDecoration(
              color: c.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(store.icon, size: 28, color: c.accent),
          ),
        ]),
      ),
    );
  }
}
