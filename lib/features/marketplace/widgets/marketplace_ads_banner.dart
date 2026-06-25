import 'package:flutter/material.dart';

import '../models/marketplace_ad_model.dart';
import 'rotating_merchant_ad_banner.dart';

class MarketplaceAdsBanner extends StatelessWidget {
  const MarketplaceAdsBanner({
    super.key,
    required this.ads,
  });

  final List<MarketplaceAd> ads;

  @override
  Widget build(BuildContext context) {
    return RotatingMerchantAdBanner(
      ads: ads,
      placementScreen: 'marketplace',
      padding: const EdgeInsets.only(bottom: 18),
    );
  }
}
