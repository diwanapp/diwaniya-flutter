import 'package:flutter/material.dart';

import '../../config/theme/app_colors.dart';
import '../../core/models/mock_data.dart';
import '../../l10n/ar.dart';
import 'models/store_model.dart';
import 'services/marketplace_service.dart';
import 'widgets/store_action_row.dart';
import 'widgets/store_badges.dart';

class StoreDetailsScreen extends StatefulWidget {
  final String storeId;
  const StoreDetailsScreen({super.key, required this.storeId});

  @override
  State<StoreDetailsScreen> createState() => _StoreDetailsScreenState();
}

class _StoreDetailsScreenState extends State<StoreDetailsScreen> {
  Store? _store;
  bool _loading = false;
  bool _attemptedDetails = false;

  @override
  void initState() {
    super.initState();
    _store = MarketplaceService.getStoreById(widget.storeId);
    _loadDetails();
  }

  DiwaniyaInfo? get _activeDiwaniya {
    if (currentDiwaniyaId.isEmpty) return null;
    return allDiwaniyas.where((d) => d.id == currentDiwaniyaId).firstOrNull;
  }

  Future<void> _loadDetails() async {
    final active = _activeDiwaniya;
    final store = _store;
    if (_attemptedDetails ||
        active == null ||
        active.id.trim().isEmpty ||
        store == null) {
      return;
    }
    _attemptedDetails = true;
    setState(() => _loading = true);
    try {
      final details = await MarketplaceService.loadStoreDetails(
        diwaniyaId: active.id,
        store: store,
        cityId: active.cityId,
        districtId: active.districtId,
        radiusKm: 10,
      );
      if (!mounted) return;
      setState(() => _store = details);
    } catch (_) {
      // Keep the list result visible if the richer detail request is unavailable.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.cl;
    final active = _activeDiwaniya;
    final store = _store;

    if (store == null) {
      return Scaffold(
        backgroundColor: c.bg,
        appBar: AppBar(backgroundColor: c.bg),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.storefront_outlined, size: 44, color: c.t3),
                const SizedBox(height: 12),
                Text(
                  'تفاصيل المتجر غير متاحة حاليًا',
                  style: TextStyle(
                    color: c.t1,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'ارجع للسوق وافتح المتجر مرة أخرى بعد تحديث النتائج.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: c.t3, height: 1.7),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final subtitle = _subtitle(store);
    final meta = _metaItems(store);
    final badges = _badges(context, store);

    return Scaffold(
      backgroundColor: c.bg,
      body: CustomScrollView(slivers: [
        SliverAppBar(
          expandedHeight: 210,
          pinned: true,
          backgroundColor: c.bg,
          surfaceTintColor: Colors.transparent,
          flexibleSpace: FlexibleSpaceBar(
            background: _DetailsHero(store: store),
          ),
          bottom: _loading
              ? PreferredSize(
                  preferredSize: const Size.fromHeight(2),
                  child: LinearProgressIndicator(
                    minHeight: 2,
                    color: c.accent,
                    backgroundColor: Colors.transparent,
                  ),
                )
              : null,
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              Row(children: [
                Expanded(
                  child: Text(
                    store.name,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: c.t1,
                    ),
                  ),
                ),
                if (store.isOpenNow != null)
                  OpenClosedBadge(isOpen: store.isOpenNow!, fontSize: 12),
              ]),
              if (subtitle != null) ...[
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 13, color: c.t3),
                ),
              ],
              if (meta.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 14,
                  runSpacing: 8,
                  children: meta,
                ),
              ],
              if (badges.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(spacing: 8, runSpacing: 8, children: badges),
              ],
              const SizedBox(height: 20),
              StoreActionRow(
                store: store,
                diwaniyaId: active?.id,
                cityId: active?.cityId,
                districtId: active?.districtId,
              ),
              if (store.description.trim().isNotEmpty) ...[
                const SizedBox(height: 24),
                const _SectionTitle(label: Ar.aboutStore),
                const SizedBox(height: 10),
                _SoftPanel(
                  child: Text(
                    store.description,
                    style: TextStyle(fontSize: 14, height: 1.8, color: c.t2),
                  ),
                ),
              ],
              if (store.openingHours.isNotEmpty) ...[
                const SizedBox(height: 24),
                const _SectionTitle(label: 'ساعات العمل'),
                const SizedBox(height: 10),
                _SoftPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final line in store.openingHours)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text(
                            line,
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.5,
                              color: c.t2,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
              if (store.products.isNotEmpty) ...[
                const SizedBox(height: 24),
                const _SectionTitle(label: 'منتجات مميزة'),
                const SizedBox(height: 10),
                ...store.products.map((product) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _ProductPreview(product: product),
                    )),
              ],
              if ((store.attribution ?? store.attributionLabel)?.trim().isNotEmpty ==
                  true) ...[
                const SizedBox(height: 16),
                Text(
                  (store.attribution ?? store.attributionLabel)!.trim(),
                  style: TextStyle(
                    color: c.t3,
                    fontSize: 11.5,
                    height: 1.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ]),
          ),
        ),
      ]),
    );
  }

  String? _subtitle(Store store) {
    final parts = <String>[
      store.category,
      [store.district.trim(), store.city.trim()]
          .where((part) => part.isNotEmpty)
          .join('، '),
    ].where((part) => part.trim().isNotEmpty).toList();
    if (parts.isEmpty) return null;
    return parts.join(' · ');
  }

  List<Widget> _metaItems(Store store) {
    return [
      if (store.hasRating)
        _MetaPill(
          icon: Icons.star_rounded,
          label: store.hasReviewCount
              ? '${store.rating!.toStringAsFixed(1)} (${store.reviewCount} ${Ar.reviews})'
              : store.rating!.toStringAsFixed(1),
        ),
      if (store.hasDistance)
        _MetaPill(
          icon: Icons.place_rounded,
          label: store.distanceKm! < 1
              ? '${(store.distanceKm! * 1000).round()} م'
              : '${store.distanceKm!.toStringAsFixed(1)} ${Ar.km}',
        ),
      if (store.deliveryEtaText != null)
        _MetaPill(
          icon: Icons.schedule_rounded,
          label: store.deliveryEtaText!,
        ),
    ];
  }

  List<Widget> _badges(BuildContext context, Store store) {
    final c = context.cl;
    return [
      if (store.isSponsored) StoreBadge(label: Ar.sponsored, color: c.warning),
      if (store.isVerifiedMerchant)
        StoreBadge(label: 'موثق في ديوانية', color: c.accent),
      if (!store.isVerifiedMerchant &&
          !store.isSponsored &&
          store.attributionLabel?.trim().isNotEmpty == true)
        StoreBadge(label: store.attributionLabel!.trim(), color: c.info),
    ];
  }
}

class _DetailsHero extends StatelessWidget {
  final Store store;
  const _DetailsHero({required this.store});

  @override
  Widget build(BuildContext context) {
    final image = store.coverImage?.trim();
    if (image != null && image.isNotEmpty) {
      return Image.network(
        image,
        width: double.infinity,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.high,
        errorBuilder: (_, __, ___) => _PlaceholderHero(store: store),
      );
    }
    return _PlaceholderHero(store: store);
  }
}

class _PlaceholderHero extends StatelessWidget {
  final Store store;
  const _PlaceholderHero({required this.store});

  @override
  Widget build(BuildContext context) {
    final c = context.cl;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            c.accent.withValues(alpha: 0.18),
            c.accent.withValues(alpha: 0.04),
          ],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
      ),
      child: Center(
        child: Icon(
          store.icon,
          size: 64,
          color: c.accent.withValues(alpha: 0.5),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String label;
  const _SectionTitle({required this.label});

  @override
  Widget build(BuildContext context) {
    final c = context.cl;
    return Text(
      label,
      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: c.t1),
    );
  }
}

class _SoftPanel extends StatelessWidget {
  final Widget child;
  const _SoftPanel({required this.child});

  @override
  Widget build(BuildContext context) {
    final c = context.cl;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
      ),
      child: child,
    );
  }
}

class _MetaPill extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MetaPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final c = context.cl;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: c.t3),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(fontSize: 13, color: c.t2),
        ),
      ],
    );
  }
}

class _ProductPreview extends StatelessWidget {
  final StoreProductPreview product;
  const _ProductPreview({required this.product});

  @override
  Widget build(BuildContext context) {
    final c = context.cl;
    return _SoftPanel(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: c.accent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.inventory_2_outlined, color: c.accent, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  style: TextStyle(
                    color: c.t1,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (product.category?.trim().isNotEmpty == true) ...[
                  const SizedBox(height: 3),
                  Text(
                    product.category!.trim(),
                    style: TextStyle(color: c.t3, fontSize: 12),
                  ),
                ],
                if (product.description?.trim().isNotEmpty == true) ...[
                  const SizedBox(height: 6),
                  Text(
                    product.description!.trim(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: c.t2, fontSize: 12.5, height: 1.45),
                  ),
                ],
              ],
            ),
          ),
          if (product.price != null) ...[
            const SizedBox(width: 8),
            Text(
              '${product.price!.toStringAsFixed(0)} ${product.currency ?? ''}',
              style: TextStyle(
                color: c.accent,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
