import 'package:flutter/material.dart';

import '../../marketplace/models/marketplace_ad_model.dart';
import '../../marketplace/services/marketplace_service.dart';

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
  MarketplaceAd? _ad;

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  @override
  void didUpdateWidget(covariant HomeAdBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.diwaniyaId != widget.diwaniyaId) {
      _loadAd();
    }
  }

  Future<void> _loadAd() async {
    final did = widget.diwaniyaId?.trim();
    if (did == null || did.isEmpty) {
      if (mounted) setState(() => _ad = null);
      return;
    }

    if (mounted) setState(() => _loading = true);

    try {
      final result = await MarketplaceService.loadApprovedAds(
        diwaniyaId: did,
        placementScreen: 'home',
        limit: 1,
      );

      if (!mounted) return;
      setState(() {
        _ad = result.ads.where(_hasDisplayImage).cast<MarketplaceAd?>().firstOrNull;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _ad = null;
        _loading = false;
      });
    }
  }

  bool _hasDisplayImage(MarketplaceAd ad) {
    final imageUrl = ad.imageUrl?.trim();
    return imageUrl != null && imageUrl.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _ad == null) return const SizedBox.shrink();

    final ad = _ad!;
    final imageUrl = ad.imageUrl?.trim();
    if (imageUrl == null || imageUrl.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 18),
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
                return const _AdImagePlaceholder();
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
}

class _AdImagePlaceholder extends StatelessWidget {
  const _AdImagePlaceholder();

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
