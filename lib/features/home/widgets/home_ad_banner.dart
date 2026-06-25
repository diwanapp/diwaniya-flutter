import 'package:flutter/material.dart';

import '../../marketplace/models/marketplace_ad_model.dart';
import '../../marketplace/services/marketplace_service.dart';
import '../../marketplace/widgets/rotating_merchant_ad_banner.dart';

class HomeAdBanner extends StatefulWidget {
  const HomeAdBanner({
    super.key,
    required this.diwaniyaId,
  });

  final String? diwaniyaId;

  @override
  State<HomeAdBanner> createState() => _HomeAdBannerState();
}

class _HomeAdBannerState extends State<HomeAdBanner> {
  bool _loading = false;
  List<MarketplaceAd> _ads = const <MarketplaceAd>[];

  @override
  void initState() {
    super.initState();
    _loadAds();
  }

  @override
  void didUpdateWidget(covariant HomeAdBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.diwaniyaId != widget.diwaniyaId) {
      _loadAds();
    }
  }

  Future<void> _loadAds() async {
    final did = widget.diwaniyaId?.trim();
    if (did == null || did.isEmpty) {
      if (mounted) {
        setState(() {
          _ads = const <MarketplaceAd>[];
          _loading = false;
        });
      }
      return;
    }

    if (mounted) setState(() => _loading = true);

    try {
      final result = await MarketplaceService.loadApprovedAds(
        diwaniyaId: did,
        placementScreen: 'home',
        limit: 5,
      );

      if (!mounted || widget.diwaniyaId?.trim() != did) return;
      setState(() {
        _ads = result.ads;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || widget.diwaniyaId?.trim() != did) return;
      setState(() {
        _ads = const <MarketplaceAd>[];
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const SizedBox.shrink();

    return RotatingMerchantAdBanner(
      ads: _ads,
      placementScreen: 'home',
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 18),
    );
  }
}
