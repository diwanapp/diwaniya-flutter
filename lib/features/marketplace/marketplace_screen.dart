import 'package:flutter/material.dart';

import '../../config/theme/app_colors.dart';
import '../../core/models/mock_data.dart';
import '../../l10n/ar.dart';
import '../../shared/widgets/app_chip.dart';
import '../../shared/widgets/app_search_field.dart';
import 'models/marketplace_filter_model.dart';
import 'models/store_model.dart';
import 'services/marketplace_service.dart';
import 'widgets/empty_marketplace_state.dart';
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
  bool _loadingPlaces = false;
  String? _placesMessage;
  String? _placesLocationLabel;
  String? _lastPlacesRequestKey;
  DateTime? _lastPlacesRequestAt;

  @override
  void initState() {
    super.initState();
    MarketplaceService.configureResolver(() => _liveStores);
    dataVersion.addListener(_handleDataRefresh);
    Future<void>.microtask(_loadMarketplacePlaces);
  }

  @override
  void dispose() {
    dataVersion.removeListener(_handleDataRefresh);
    MarketplaceService.configureResolver(null);
    _searchCtrl.dispose();
    super.dispose();
  }

  void _handleDataRefresh() {
    if (!mounted) return;
    setState(() {});
    _loadMarketplacePlaces();
  }

  void _updateFilter(MarketplaceFilter Function(MarketplaceFilter) update) {
    setState(() => _filter = update(_filter));
  }

  Future<void> _loadMarketplacePlaces({String? category}) async {
    final requestCategory = category ?? _filter.selectedCategory;
    final active = _activeDiwaniya;
    if (active == null || active.id.trim().isEmpty) {
      if (!mounted) return;
      setState(() {
        _liveStores = const <Store>[];
        _placesMessage = 'no_diwaniya_selected';
        _placesLocationLabel = null;
      });
      return;
    }

    final requestKey = '${active.id}|${requestCategory ?? 'all'}';
    final now = DateTime.now();
    final lastAt = _lastPlacesRequestAt;
    if (_lastPlacesRequestKey == requestKey &&
        lastAt != null &&
        now.difference(lastAt).inSeconds < 3) {
      return;
    }

    _lastPlacesRequestKey = requestKey;
    _lastPlacesRequestAt = now;

    setState(() {
      _loadingPlaces = true;
    });

    try {
      final result = await MarketplaceService.loadBackendPlaces(
        diwaniyaId: active.id,
        category: requestCategory,
      );
      if (!mounted) return;
      setState(() {
        _liveStores = result.stores;
        _placesMessage = result.message ??
            (result.isConfigured && result.stores.isEmpty
                ? 'no_nearby_results'
                : null);
        _placesLocationLabel = result.locationLabel;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _liveStores = const <Store>[];
        _placesMessage = 'marketplace_connection_error';
      });
    } finally {
      if (mounted) {
        setState(() => _loadingPlaces = false);
      }
    }
  }

  String? _placesNoticeText() {
    switch (_placesMessage) {
      case 'google_places_not_configured':
        return 'سيتم عرض المحلات القريبة هنا بعد تفعيل الربط مع Google Places.';
      case 'location_missing':
        return 'حدد موقع الديوانية بدقة من تفاصيل الديوانية لعرض المحلات القريبة.';
      case 'no_diwaniya_selected':
        return 'اختر ديوانية أولًا لعرض السوق المرتبط بها.';
      case 'marketplace_connection_error':
        return 'تعذر تحديث السوق الآن. تحقق من الاتصال وحاول مرة أخرى.';
      case 'no_nearby_results':
        return 'لا توجد نتائج قريبة ضمن 10 كم لهذا التصنيف.';
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

  List<Store> _applyDiwaniyaLocation(List<Store> stores) {
    final active = _activeDiwaniya;
    if (active == null) return stores;

    final city = active.city.trim();
    final district = active.district.trim();

    if (city.isEmpty) return stores;

    final cityMatches = stores.where((s) => s.city == city).toList();
    if (district.isEmpty) return cityMatches;

    final districtMatches =
        cityMatches.where((s) => s.district == district).toList();

    if (districtMatches.isNotEmpty) return districtMatches;
    return cityMatches;
  }

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
    final isFiltering = _filter.isActive;
    final active = _activeDiwaniya;
    final locationLabel = _locationLabelFor(active) ?? _placesLocationLabel;
    final placesNoticeText = _placesNoticeText();

    final hasResults = _loadingPlaces
        ? (_liveStores.isNotEmpty || _allStores.isNotEmpty)
        : (isFiltering ? _filteredStores.isNotEmpty : _allStores.isNotEmpty);

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
                  'سوق الديوانية',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: c.t1,
                  ),
                ),
                Text(
                  locationLabel == null
                      ? 'خدمات قريبة من ديوانيتك'
                      : 'خدمات قريبة من $locationLabel',
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
                    hint: Ar.searchStoreHint,
                    onChanged: (v) =>
                        _updateFilter((f) => f.copyWith(query: v.trim())),
                    onClear: () => _updateFilter((f) => f.copyWith(query: '')),
                  ),
                  const SizedBox(height: 12),
                  _MarketplaceLocationBrief(
                    active: active,
                    locationLabel: locationLabel,
                  ),
                  const SizedBox(height: 12),
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
                        icon: Icons.star_rounded,
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
                      _loadMarketplacePlaces(category: cat);
                    },
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          if (!hasResults)
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
                    child: StoreCard(store: _filteredStores[i]),
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
              ),
            if (_topRatedStores.isNotEmpty)
              MarketplaceHorizontalSection(
                title: Ar.topRatedStores,
                stores: _topRatedStores,
              ),
            if (_storesWithOffers.isNotEmpty)
              MarketplaceHorizontalSection(
                title: Ar.todayOffers,
                stores: _storesWithOffers,
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
                    child: StoreCard(store: _allStores[i]),
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
                      ? 'السوق مرتبط بموقع الديوانية'
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
              'قريبًا Google',
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

