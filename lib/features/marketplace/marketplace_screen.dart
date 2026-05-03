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

  @override
  void initState() {
    super.initState();
    dataVersion.addListener(_handleDataRefresh);
  }

  @override
  void dispose() {
    dataVersion.removeListener(_handleDataRefresh);
    _searchCtrl.dispose();
    super.dispose();
  }

  void _handleDataRefresh() {
    if (mounted) setState(() {});
  }

  void _updateFilter(MarketplaceFilter Function(MarketplaceFilter) update) {
    setState(() => _filter = update(_filter));
  }

  DiwaniyaInfo? get _activeDiwaniya {
    if (currentDiwaniyaId.isEmpty) return null;
    return allDiwaniyas.where((d) => d.id == currentDiwaniyaId).firstOrNull;
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
    final locationLabel = active == null
        ? null
        : '${active.city}${active.district.isNotEmpty ? ' · ${active.district}' : ''}';

    final hasResults = isFiltering ? _filteredStores.isNotEmpty : _allStores.isNotEmpty;

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
                  Ar.marketplace,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: c.t1,
                  ),
                ),
                Text(
                  locationLabel == null
                      ? Ar.marketplaceSubtitle
                      : 'يعرض محلات $locationLabel',
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
                    onCategoryChanged: (cat) => _updateFilter(
                      (f) => f.copyWith(selectedCategory: () => cat),
                    ),
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
