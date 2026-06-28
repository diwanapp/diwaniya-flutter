import 'dart:async';

import 'package:flutter/material.dart';

import '../../config/theme/app_colors.dart';
import '../../core/models/mock_data.dart';
import '../../l10n/ar.dart';
import '../../shared/widgets/app_chip.dart';
import '../../shared/widgets/app_search_field.dart';
import 'models/marketplace_ad_model.dart';
import 'models/marketplace_filter_model.dart';
import 'models/store_model.dart';
import 'services/marketplace_service.dart';
import 'widgets/empty_marketplace_state.dart';
import 'widgets/marketplace_ads_banner.dart';
import 'widgets/marketplace_banner_carousel.dart';
import 'widgets/marketplace_category_list.dart';
import 'widgets/marketplace_section_header.dart';
import 'widgets/store_card.dart';

class MarketplaceScreen extends StatefulWidget {
  const MarketplaceScreen({super.key});

  @override
  State<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends State<MarketplaceScreen> {
  final _searchCtrl = TextEditingController();
  MarketplaceFilter _filter = const MarketplaceFilter();
  List<Store> _liveStores = const <Store>[];
  List<MarketplaceAd> _marketplaceAds = const <MarketplaceAd>[];
  bool _loadingPlaces = false;
  String? _placesMessage;
  String? _placesLocationLabel;
  String? _lastPlacesRequestKey;
  Timer? _searchDebounce;
  final Set<String> _impressedStoreIds = <String>{};

  @override
  void initState() {
    super.initState();
    MarketplaceService.configureResolver(() => _liveStores);
    dataVersion.addListener(_handleDataRefresh);
    Future<void>.microtask(() => _loadMarketplacePlaces(force: true));
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    dataVersion.removeListener(_handleDataRefresh);
    MarketplaceService.configureResolver(null);
    _searchCtrl.dispose();
    super.dispose();
  }

  void _handleDataRefresh() {
    if (!mounted) return;
    _loadMarketplacePlaces(force: true);
  }

  void _updateFilter(MarketplaceFilter Function(MarketplaceFilter) update) {
    setState(() => _filter = update(_filter));
  }

  void _scheduleDiscoveryLoad() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(
      const Duration(milliseconds: 520),
      () => _loadMarketplacePlaces(force: true),
    );
  }

  Future<void> _loadMarketplacePlaces({
    String? category,
    String? queryText,
    bool force = false,
  }) async {
    final active = _activeDiwaniya;
    final requestCategory = category ?? _filter.selectedCategory;
    final requestQuery = queryText ?? _filter.query;

    if (active == null || active.id.trim().isEmpty) {
      if (!mounted) return;
      setState(() {
        _liveStores = const <Store>[];
        _marketplaceAds = const <MarketplaceAd>[];
        _placesMessage = 'no_diwaniya_selected';
        _placesLocationLabel = null;
      });
      return;
    }

    final requestKey = [
      active.id,
      active.cityId ?? '',
      active.districtId ?? '',
      requestCategory ?? '',
      requestQuery.trim(),
    ].join('|');
    if (!force && _lastPlacesRequestKey == requestKey) return;
    _lastPlacesRequestKey = requestKey;

    setState(() => _loadingPlaces = true);

    try {
      final result = await MarketplaceService.loadDiscovery(
        diwaniyaId: active.id,
        category: requestCategory,
        queryText: requestQuery,
        cityId: active.cityId,
        districtId: active.districtId,
        radiusKm: 10,
        limit: 20,
      );
      if (!mounted) return;
      setState(() {
        _liveStores = result.stores;
        _marketplaceAds = result.ads;
        _placesMessage = result.message ??
            (result.stores.isEmpty ? 'no_nearby_results' : null);
        _placesLocationLabel = result.locationLabel;
      });
      _recordStoreImpressions(
        result.stores.take(12),
        active: active,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _liveStores = const <Store>[];
        _marketplaceAds = const <MarketplaceAd>[];
        _placesMessage = 'marketplace_connection_error';
      });
    } finally {
      if (mounted) setState(() => _loadingPlaces = false);
    }
  }

  void _recordStoreImpressions(
    Iterable<Store> stores, {
    required DiwaniyaInfo active,
  }) {
    for (final store in stores) {
      final key = '${store.id}|${_filter.selectedCategory ?? ''}|${_filter.query}';
      if (!_impressedStoreIds.add(key)) continue;
      MarketplaceService.recordMarketplaceEventLater(
        eventType: 'marketplace_store_impression',
        store: store,
        diwaniyaId: active.id,
        cityId: active.cityId,
        districtId: active.districtId,
      );
    }
  }

  void _recordCategoryView(String categoryKey) {
    final active = _activeDiwaniya;
    MarketplaceService.recordMarketplaceCategoryViewLater(
      categoryKey: categoryKey,
      diwaniyaId: active?.id,
      cityId: active?.cityId,
      districtId: active?.districtId,
    );
  }

  String? _placesNoticeText() {
    switch (_placesMessage) {
      case 'google_places_disabled':
      case 'google_places_not_configured':
        return 'نعرض المتاجر المتاحة من ديوانية حاليًا.';
      case 'location_missing':
        return 'اختر المدينة أو الحي لعرض المتاجر الأقرب لديوانيتكم.';
      case 'no_diwaniya_selected':
        return 'اختر ديوانية أولًا لعرض السوق المرتبط بها.';
      case 'marketplace_connection_error':
        return 'تعذر تحميل السوق الآن. حاول مرة أخرى.';
      case 'no_nearby_results':
        return 'لا توجد نتائج قريبة حاليًا. جرّب تغيير التصنيف أو توسيع النطاق.';
      default:
        return null;
    }
  }

  DiwaniyaInfo? get _activeDiwaniya {
    if (currentDiwaniyaId.isEmpty) return null;
    return allDiwaniyas.where((d) => d.id == currentDiwaniyaId).firstOrNull;
  }

  String? _locationLabelFor(DiwaniyaInfo? active) {
    if (active == null) return null;

    final city = active.city.trim();
    final district = active.district.trim();

    if (city.isEmpty && district.isEmpty) return null;
    if (city.isEmpty) return district;
    if (district.isEmpty) return city;
    return '$district · $city';
  }

  List<Store> _applyDiwaniyaLocation(List<Store> stores) => stores;

  List<Store> get _filteredStores =>
      _applyDiwaniyaLocation(MarketplaceService.filterStores(_filter));

  List<Store> get _nearbyStores =>
      _applyDiwaniyaLocation(MarketplaceService.getNearbyStores());

  List<Store> get _topRatedStores =>
      _applyDiwaniyaLocation(MarketplaceService.getTopRatedStores());

  List<Store> get _storesWithOffers =>
      _applyDiwaniyaLocation(MarketplaceService.getStoresWithOffers());

  List<Store> get _featuredStores =>
      _applyDiwaniyaLocation(MarketplaceService.getFeaturedStores());

  List<Store> get _allStores =>
      _applyDiwaniyaLocation(MarketplaceService.allStores);

  @override
  Widget build(BuildContext context) {
    final c = context.cl;
    final active = _activeDiwaniya;
    final isFiltering = _filter.isActive;
    final locationLabel = _placesLocationLabel ?? _locationLabelFor(active);
    final placesNoticeText = _placesNoticeText();
    final hasResults =
        isFiltering ? _filteredStores.isNotEmpty : _allStores.isNotEmpty;
    final showSkeleton = _loadingPlaces && _allStores.isEmpty;

    return Scaffold(
      backgroundColor: c.bg,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            floating: true,
            snap: true,
            backgroundColor: c.bg,
            surfaceTintColor: Colors.transparent,
            toolbarHeight: 64,
            centerTitle: false,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'السوق',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: c.t1,
                  ),
                ),
                Text(
                  locationLabel ?? 'دليل محلي ذكي حول ديوانيتك',
                  style: TextStyle(fontSize: 12, color: c.t3),
                ),
              ],
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverList(
              delegate: SliverChildListDelegate(
                [
                  AppSearchField(
                    controller: _searchCtrl,
                    hint: 'ابحث عن مطعم، مقهى، حلويات...',
                    onChanged: (value) {
                      _updateFilter((f) => f.copyWith(query: value.trim()));
                      _scheduleDiscoveryLoad();
                    },
                    onClear: () {
                      _updateFilter((f) => f.copyWith(query: ''));
                      _loadMarketplacePlaces(force: true, queryText: '');
                    },
                  ),
                  const SizedBox(height: 12),
                  _MarketplaceLocationBrief(
                    active: active,
                    locationLabel: locationLabel,
                  ),
                  const SizedBox(height: 12),
                  MarketplaceAdsBanner(
                    ads: _marketplaceAds,
                    diwaniyaId: active?.id,
                    categoryKey: _filter.selectedCategory,
                    cityId: active?.cityId,
                    districtId: active?.districtId,
                  ),
                  if (placesNoticeText != null) ...[
                    _MarketplaceBackendNotice(message: placesNoticeText),
                    const SizedBox(height: 12),
                  ],
                  Row(
                    children: [
                      AppChip(
                        label: Ar.openNowFilter,
                        icon: Icons.access_time_rounded,
                        selected: _filter.onlyOpenNow,
                        onTap: () => _updateFilter(
                          (f) => f.copyWith(onlyOpenNow: !f.onlyOpenNow),
                        ),
                      ),
                      const SizedBox(width: 8),
                      AppChip(
                        label: Ar.featuredFilter,
                        icon: Icons.verified_rounded,
                        selected: _filter.onlyFeatured,
                        onTap: () => _updateFilter(
                          (f) => f.copyWith(onlyFeatured: !f.onlyFeatured),
                        ),
                      ),
                      if (isFiltering) ...[
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () {
                            _searchCtrl.clear();
                            setState(() => _filter = const MarketplaceFilter());
                            _loadMarketplacePlaces(force: true, queryText: '');
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: c.errorM,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Icon(
                              Icons.close_rounded,
                              size: 14,
                              color: c.error,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),
                  MarketplaceCategoryList(
                    selectedCategory: _filter.selectedCategory,
                    onCategoryChanged: (cat) {
                      _updateFilter(
                        (f) => f.copyWith(selectedCategory: () => cat),
                      );
                      if (cat != null) _recordCategoryView(cat);
                      _loadMarketplacePlaces(category: cat, force: true);
                    },
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          if (showSkeleton)
            const _MarketplaceLoadingSliver()
          else if (!hasResults)
            SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyMarketplaceState(
                isFiltered: isFiltering,
                cityLabel: locationLabel,
              ),
            )
          else if (isFiltering)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: StoreCard(
                      store: _filteredStores[i],
                      diwaniyaId: active?.id,
                      cityId: active?.cityId,
                      districtId: active?.districtId,
                    ),
                  ),
                  childCount: _filteredStores.length,
                ),
              ),
            )
          else ...[
            if (_featuredStores.isNotEmpty)
              SliverToBoxAdapter(
                child: MarketplaceBannerCarousel(stores: _featuredStores),
              ),
            if (_nearbyStores.isNotEmpty)
              MarketplaceHorizontalSection(
                title: Ar.nearbyStores,
                stores: _nearbyStores,
                diwaniyaId: active?.id,
                cityId: active?.cityId,
                districtId: active?.districtId,
              ),
            if (_topRatedStores.isNotEmpty)
              MarketplaceHorizontalSection(
                title: Ar.topRatedStores,
                stores: _topRatedStores,
                diwaniyaId: active?.id,
                cityId: active?.cityId,
                districtId: active?.districtId,
              ),
            if (_storesWithOffers.isNotEmpty)
              MarketplaceHorizontalSection(
                title: Ar.todayOffers,
                stores: _storesWithOffers,
                diwaniyaId: active?.id,
                cityId: active?.cityId,
                districtId: active?.districtId,
              ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              sliver: SliverToBoxAdapter(
                child: Text(
                  Ar.allStores,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: c.t1,
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: StoreCard(
                      store: _allStores[i],
                      diwaniyaId: active?.id,
                      cityId: active?.cityId,
                      districtId: active?.districtId,
                    ),
                  ),
                  childCount: _allStores.length,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MarketplaceLocationBrief extends StatelessWidget {
  final DiwaniyaInfo? active;
  final String? locationLabel;

  const _MarketplaceLocationBrief({
    required this.active,
    required this.locationLabel,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.cl;
    final hasLocation = locationLabel != null && locationLabel!.trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.card.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: c.border.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: c.accent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.location_on_rounded,
              color: c.accent,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasLocation
                      ? 'قريب من موقع الديوانية'
                      : 'حدد موقع الديوانية لنتائج أدق',
                  style: TextStyle(
                    color: c.t1,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  hasLocation
                      ? locationLabel!
                      : 'اختر المدينة والحي من تفاصيل الديوانية',
                  style: TextStyle(
                    color: c.t2,
                    fontSize: 12.2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
            decoration: BoxDecoration(
              color: c.accent.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '10 كم',
              style: TextStyle(
                color: c.accent,
                fontSize: 10.5,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MarketplaceBackendNotice extends StatelessWidget {
  final String message;

  const _MarketplaceBackendNotice({
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.cl;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: c.accent.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.accent.withValues(alpha: 0.10)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: c.accent,
            size: 19,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: c.t2,
                fontSize: 12.4,
                height: 1.45,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MarketplaceLoadingSliver extends StatelessWidget {
  const _MarketplaceLoadingSliver();

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (_, __) => const Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: _StoreSkeletonCard(),
          ),
          childCount: 5,
        ),
      ),
    );
  }
}

class _StoreSkeletonCard extends StatelessWidget {
  const _StoreSkeletonCard();

  @override
  Widget build(BuildContext context) {
    final c = context.cl;
    return Container(
      height: 104,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: c.inputBg,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _SkeletonLine(widthFactor: 0.62),
                SizedBox(height: 10),
                _SkeletonLine(widthFactor: 0.38),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SkeletonLine extends StatelessWidget {
  final double widthFactor;
  const _SkeletonLine({required this.widthFactor});

  @override
  Widget build(BuildContext context) {
    final c = context.cl;
    return FractionallySizedBox(
      widthFactor: widthFactor,
      alignment: Alignment.centerRight,
      child: Container(
        height: 10,
        decoration: BoxDecoration(
          color: c.inputBg,
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );
  }
}
