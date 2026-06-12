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
    final ad = ads.where(_hasDisplayImage).cast<MarketplaceAd?>().firstOrNull;
    final imageUrl = ad?.imageUrl?.trim();

    if (imageUrl == null || imageUrl.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Semantics(
        button: false,
        image: true,
        label: 'إعلان',
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: AspectRatio(
            aspectRatio: 16 / 7,
            child: Image.network(
              imageUrl,
              width: double.infinity,
              fit: BoxFit.cover,
              filterQuality: FilterQuality.high,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return const _MarketplaceAdPlaceholder();
              },
              errorBuilder: (context, error, stackTrace) {
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      ),
    );
  }

  static bool _hasDisplayImage(MarketplaceAd ad) {
    final imageUrl = ad.imageUrl?.trim();
    return imageUrl != null && imageUrl.isNotEmpty;
  }
}

class _MarketplaceAdPlaceholder extends StatelessWidget {
  const _MarketplaceAdPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(24),
      ),
    );
  }
}

extension _FirstOrNullExtension<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    if (!iterator.moveNext()) return null;
    return iterator.current;
  }
}
