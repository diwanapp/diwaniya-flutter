import 'package:flutter/material.dart';

import '../models/marketplace_ad_model.dart';

class MarketplaceAdsBanner extends StatelessWidget {
  const MarketplaceAdsBanner({
    super.key,
    required this.ads,
  });

  final List<MarketplaceAd> ads;

  @override
  Widget build(BuildContext context) {
    if (ads.isEmpty) return const SizedBox.shrink();

    const navy = Color(0xFF1F3A4D);
    const gold = Color(0xFFC9A227);
    final ad = ads.first;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: navy,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x331F3A4D),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: const Color(0x22FFFFFF),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.local_offer_rounded, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ad.storeName?.isNotEmpty == true ? ad.storeName! : 'إعلانك معنا',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: gold,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  ad.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (ad.description?.isNotEmpty == true) ...[
                  const SizedBox(height: 3),
                  Text(
                    ad.description!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xB8FFFFFF),
                      fontSize: 12,
                      height: 1.35,
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
