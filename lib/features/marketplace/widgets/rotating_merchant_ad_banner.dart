import 'dart:async';

import 'package:flutter/material.dart';

import '../models/marketplace_ad_model.dart';
import '../services/marketplace_service.dart';
import 'advertiser_detail_sheet.dart';

class RotatingMerchantAdBanner extends StatefulWidget {
  const RotatingMerchantAdBanner({
    super.key,
    required this.ads,
    required this.placementScreen,
    this.padding = EdgeInsets.zero,
    this.borderRadius = 24,
    this.aspectRatio = 16 / 7,
    this.diwaniyaId,
    this.categoryKey,
    this.cityId,
    this.districtId,
  });

  final List<MarketplaceAd> ads;
  final String placementScreen;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final double aspectRatio;
  final String? diwaniyaId;
  final String? categoryKey;
  final String? cityId;
  final String? districtId;

  @override
  State<RotatingMerchantAdBanner> createState() => _RotatingMerchantAdBannerState();
}

class _RotatingMerchantAdBannerState extends State<RotatingMerchantAdBanner> {
  static const _rotationInterval = Duration(seconds: 4);
  static const _switchDuration = Duration(milliseconds: 420);

  Timer? _timer;
  int _index = 0;
  final Set<String> _impressedAdIds = <String>{};

  List<MarketplaceAd> get _displayAds => widget.ads
      .where((ad) => ad.isDisplayableForPlacement(widget.placementScreen))
      .take(5)
      .toList(growable: false);

  @override
  void initState() {
    super.initState();
    _configureTimer();
  }

  @override
  void didUpdateWidget(covariant RotatingMerchantAdBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    final ads = _displayAds;
    if (_index >= ads.length) _index = 0;
    if (oldWidget.ads != widget.ads ||
        oldWidget.placementScreen != widget.placementScreen) {
      _configureTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _configureTimer() {
    _timer?.cancel();
    final ads = _displayAds;
    if (ads.length < 2) return;

    _timer = Timer.periodic(_rotationInterval, (_) {
      if (!mounted) return;
      final currentAds = _displayAds;
      if (currentAds.length < 2) return;
      setState(() {
        _index = (_index + 1) % currentAds.length;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final ads = _displayAds;
    if (ads.isEmpty) return const SizedBox.shrink();

    final ad = ads[_index.clamp(0, ads.length - 1)];
    _recordImpression(ad);
    final imageUrl = ad.imageUrl?.trim();
    if (imageUrl == null || imageUrl.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: widget.padding,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(widget.borderRadius),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              MarketplaceService.recordMarketplaceAdEventLater(
                eventType: 'marketplace_ad_click',
                ad: ad,
                diwaniyaId: widget.diwaniyaId,
                categoryKey: widget.categoryKey,
                cityId: widget.cityId,
                districtId: widget.districtId,
              );
              showAdvertiserDetailSheet(context, ad);
            },
            child: AspectRatio(
              aspectRatio: widget.aspectRatio,
              child: AnimatedSwitcher(
                duration: _switchDuration,
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                child: Image.network(
                  imageUrl,
                  key: ValueKey('${ad.id}:$imageUrl'),
                  width: double.infinity,
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.high,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const _AdImageFallback();
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return const _AdImageFallback();
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _recordImpression(MarketplaceAd ad) {
    if (!_impressedAdIds.add(ad.id)) return;
    MarketplaceService.recordMarketplaceAdEventLater(
      eventType: 'marketplace_ad_impression',
      ad: ad,
      diwaniyaId: widget.diwaniyaId,
      categoryKey: widget.categoryKey,
      cityId: widget.cityId,
      districtId: widget.districtId,
    );
  }
}

class _AdImageFallback extends StatelessWidget {
  const _AdImageFallback();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ColoredBox(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.55),
    );
  }
}
