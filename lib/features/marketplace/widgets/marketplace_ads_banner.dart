import 'package:flutter/material.dart';

import '../models/marketplace_ad_model.dart';
import 'rotating_merchant_ad_banner.dart';

class MarketplaceAdsBanner extends StatelessWidget {
  const MarketplaceAdsBanner({
    super.key,
    required this.ads,
    this.diwaniyaId,
    this.categoryKey,
    this.cityId,
    this.districtId,
  });

  final List<MarketplaceAd> ads;
  final String? diwaniyaId;
  final String? categoryKey;
  final String? cityId;
  final String? districtId;

  @override
  Widget build(BuildContext context) {
    return RotatingMerchantAdBanner(
      ads: ads,
      placementScreen: 'marketplace_top',
      padding: const EdgeInsets.only(bottom: 18),
      diwaniyaId: diwaniyaId,
      categoryKey: categoryKey,
      cityId: cityId,
      districtId: districtId,
    );
  }
}
