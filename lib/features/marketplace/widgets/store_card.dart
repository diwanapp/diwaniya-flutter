import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

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
    final actions = _cardActions(context, store);

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
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: c.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _StoreThumbnail(store: store, compact: compact),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              store.name,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: c.t1,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              store.category,
                              style: TextStyle(
                                fontSize: 11.5,
                                color: c.t3,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      if (store.isOpenNow != null) ...[
                        const SizedBox(width: 8),
                        OpenClosedBadge(isOpen: store.isOpenNow!),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 10,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (ratingText.isNotEmpty)
                        _MiniMeta(
                          icon: Icons.star_rounded,
                          label: '$ratingText$reviewText',
                          color: c.warning,
                        ),
                      if (distanceText.isNotEmpty)
                        _MiniMeta(
                          icon: Icons.place_rounded,
                          label: distanceText,
                          color: c.t3,
                        ),
                      if (store.deliveryEtaText != null)
                        _MiniMeta(
                          icon: Icons.schedule_rounded,
                          label: store.deliveryEtaText!,
                          color: c.t3,
                        ),
                      if (sourceBadge != null) sourceBadge,
                    ],
                  ),
                  if (store.hasActiveOffers && !compact) ...[
                    const SizedBox(height: 8),
                    OfferChip(offer: store.activeOffers.first),
                  ],
                  if (actions.isNotEmpty) ...[
                    const SizedBox(height: 9),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final action in actions)
                          _MiniActionButton(
                            spec: action,
                            onTap: () => _launchAction(context, action),
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<_CardActionSpec> _cardActions(BuildContext context, Store store) {
    final c = context.cl;
    final whatsappUri = _whatsAppUri(store.whatsapp ?? store.phone);
    final phoneUri = _phoneUri(store.phone);
    final mapsUri = _webUri(store.directionsUrl ?? store.mapUrl);
    final websiteUri = _webUri(store.website);

    return [
      if (whatsappUri != null)
        _CardActionSpec(
          icon: Icons.chat_rounded,
          label: Ar.whatsappAction,
          color: const Color(0xFF25D366),
          eventType: 'marketplace_whatsapp_click',
          uri: whatsappUri,
        ),
      if (phoneUri != null)
        _CardActionSpec(
          icon: Icons.call_rounded,
          label: Ar.callAction,
          color: c.success,
          eventType: 'marketplace_call_click',
          uri: phoneUri,
        ),
      if (mapsUri != null)
        _CardActionSpec(
          icon: Icons.map_rounded,
          label: Ar.mapsAction,
          color: c.info,
          eventType: 'marketplace_directions_click',
          uri: mapsUri,
        ),
      if (websiteUri != null)
        _CardActionSpec(
          icon: Icons.public_rounded,
          label: 'الموقع',
          color: c.accent,
          eventType: 'marketplace_website_click',
          uri: websiteUri,
        ),
    ];
  }

  Future<void> _launchAction(BuildContext context, _CardActionSpec spec) async {
    MarketplaceService.recordMarketplaceEventLater(
      eventType: spec.eventType,
      store: store,
      diwaniyaId: diwaniyaId,
      cityId: cityId,
      districtId: districtId,
    );
    final ok = await launchUrl(spec.uri, mode: LaunchMode.externalApplication);
    if (ok || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تعذر فتح الرابط الآن.')),
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

class _StoreThumbnail extends StatelessWidget {
  final Store store;
  final bool compact;

  const _StoreThumbnail({required this.store, required this.compact});

  @override
  Widget build(BuildContext context) {
    final image = store.coverImage?.trim();
    final size = compact ? 54.0 : 64.0;
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        width: size,
        height: size,
        child: image != null && image.isNotEmpty
            ? Image.network(
                image,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.medium,
                errorBuilder: (_, __, ___) =>
                    _CategoryPlaceholder(store: store),
              )
            : _CategoryPlaceholder(store: store),
      ),
    );
  }
}

class _CategoryPlaceholder extends StatelessWidget {
  final Store store;

  const _CategoryPlaceholder({required this.store});

  @override
  Widget build(BuildContext context) {
    final c = context.cl;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            c.accent.withValues(alpha: 0.22),
            const Color(0xFF123044),
          ],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
      ),
      child: Center(
        child: Icon(
          store.icon,
          size: 24,
          color: Colors.white.withValues(alpha: 0.88),
        ),
      ),
    );
  }
}

class _MiniMeta extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _MiniMeta({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: context.cl.t3,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      );
}

class _CardActionSpec {
  final IconData icon;
  final String label;
  final Color color;
  final String eventType;
  final Uri uri;

  const _CardActionSpec({
    required this.icon,
    required this.label,
    required this.color,
    required this.eventType,
    required this.uri,
  });
}

class _MiniActionButton extends StatelessWidget {
  final _CardActionSpec spec;
  final VoidCallback onTap;

  const _MiniActionButton({
    required this.spec,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: spec.color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(spec.icon, size: 12.5, color: spec.color),
              const SizedBox(width: 4),
              Text(
                spec.label,
                style: TextStyle(
                  color: spec.color,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      );
}

Uri? _phoneUri(String? value) {
  final digits = _sanitizedPhone(value);
  if (digits == null) return null;
  return Uri(scheme: 'tel', path: digits);
}

Uri? _whatsAppUri(String? value) {
  final web = _webUri(value);
  if (web != null && web.host.contains('wa.me')) return web;
  final digits = _sanitizedPhone(value);
  if (digits == null) return null;
  return Uri.https(
    'wa.me',
    '/$digits',
    {'text': 'السلام عليكم، وصلت لكم من تطبيق ديوانية.'},
  );
}

Uri? _webUri(String? value) {
  final text = value?.trim();
  if (text == null || text.isEmpty) return null;
  final uri = Uri.tryParse(text);
  if (uri == null || !uri.hasScheme || uri.host.isEmpty) return null;
  if (uri.scheme != 'https' && uri.scheme != 'http') return null;
  return uri;
}

String? _sanitizedPhone(String? value) {
  final digits = value?.replaceAll(RegExp(r'\D'), '');
  if (digits == null || digits.length < 7 || digits.length > 15) return null;
  return digits;
}
