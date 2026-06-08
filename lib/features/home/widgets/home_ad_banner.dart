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
  static const _navy = Color(0xFF1F3A4D);
  static const _card = Color(0xFFFFFBF2);
  static const _textSoft = Color(0xFF5C6B73);

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
      setState(() => _ad = null);
      return;
    }

    setState(() => _loading = true);

    try {
      final result = await MarketplaceService.loadApprovedAds(
        diwaniyaId: did,
        placementScreen: 'home',
        limit: 1,
      );

      if (!mounted) return;
      setState(() {
        _ad = result.ads.isNotEmpty ? result.ads.first : null;
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

  @override
  Widget build(BuildContext context) {
    if (_loading || _ad == null) return const SizedBox.shrink();

    final ad = _ad!;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0x33C9A227), _card],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0x55C9A227)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _navy,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.campaign_rounded, color: Colors.white),
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
                    color: _textSoft,
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
                    color: _navy,
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
                      color: _textSoft,
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
