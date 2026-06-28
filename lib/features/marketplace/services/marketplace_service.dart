import 'dart:async';

import 'package:flutter/material.dart';
import '../../../core/api/diwaniya_api.dart';
import '../models/marketplace_filter_model.dart';
import '../models/marketplace_ad_model.dart';
import '../models/store_model.dart';
import '../data/marketplace_categories.dart';

typedef MarketplaceSourceResolver = List<Store> Function();


class MarketplaceAdsLoadResult {
  final String? message;
  final String placementScreen;
  final List<MarketplaceAd> ads;

  const MarketplaceAdsLoadResult({
    required this.ads,
    required this.placementScreen,
    this.message,
  });
}

class MarketplaceLoadResult {
  final List<Store> stores;
  final bool isConfigured;
  final String? message;
  final String? locationLabel;

  const MarketplaceLoadResult({
    required this.stores,
    required this.isConfigured,
    required this.message,
    required this.locationLabel,
  });
}

class MarketplaceDiscoveryLoadResult {
  final List<Store> stores;
  final List<MarketplaceAd> ads;
  final bool googleAttributionRequired;
  final String? message;
  final String? locationLabel;

  const MarketplaceDiscoveryLoadResult({
    required this.stores,
    required this.ads,
    required this.googleAttributionRequired,
    required this.message,
    required this.locationLabel,
  });
}

class MarketplaceService {
  MarketplaceService._();

  static MarketplaceSourceResolver? _overrideResolver;
  static final String _sessionId =
      'marketplace-${DateTime.now().millisecondsSinceEpoch}';

  static void configureResolver(MarketplaceSourceResolver? resolver) {
    _overrideResolver = resolver;
  }

  static List<Store> get _source {
    final override = _overrideResolver;
    if (override != null) {
      return List<Store>.from(override());
    }
    return const <Store>[];
  }

  static List<Store> get allStores => _source;

  static List<Store> getFeaturedStores() =>
      _source.where((s) => s.isFeatured || s.isSponsored).toList();

  static List<Store> getNearbyStores({int limit = 6}) {
    final sorted = List<Store>.from(_source)
      ..sort((a, b) => _sortNullableDistance(a).compareTo(_sortNullableDistance(b)));
    return sorted.take(limit).toList();
  }

  static List<Store> getTopRatedStores({int limit = 6}) {
    final sorted = _source.where((s) => s.hasRating).toList()
      ..sort((a, b) => (b.rating ?? 0).compareTo(a.rating ?? 0));
    return sorted.take(limit).toList();
  }

  static List<Store> getStoresWithOffers() =>
      _source.where((s) => s.hasActiveOffers).toList();

  static List<Store> searchStores(String query) {
    final base = _source;
    if (query.trim().isEmpty) return base;
    final q = query.trim().toLowerCase();
    return base.where((s) {
      return s.name.toLowerCase().contains(q) ||
          s.category.toLowerCase().contains(q) ||
          s.city.toLowerCase().contains(q) ||
          s.district.toLowerCase().contains(q) ||
          s.tags.any((t) => t.toLowerCase().contains(q)) ||
          s.description.toLowerCase().contains(q);
    }).toList();
  }

  static List<Store> filterStores(MarketplaceFilter filter) {
    var list = List<Store>.from(_source);

    if (filter.query.isNotEmpty) {
      final q = filter.query.toLowerCase();
      list = list.where((s) {
        return s.name.toLowerCase().contains(q) ||
            s.category.toLowerCase().contains(q) ||
            s.city.toLowerCase().contains(q) ||
            s.district.toLowerCase().contains(q) ||
            s.tags.any((t) => t.toLowerCase().contains(q)) ||
            s.description.toLowerCase().contains(q);
      }).toList();
    }
    if (filter.selectedCategory != null) {
      final selected = filter.selectedCategory;
      list = list
          .where((s) => s.categoryKey == selected || s.category == selected)
          .toList();
    }
    if (filter.onlyOpenNow) {
      list = list.where((s) => s.isOpenNow == true).toList();
    }
    if (filter.onlyFeatured) {
      list = list.where((s) => s.isFeatured || s.isSponsored).toList();
    }

    switch (filter.sortBy) {
      case MarketplaceSortBy.nearest:
        list.sort((a, b) => _sortNullableDistance(a).compareTo(_sortNullableDistance(b)));
        break;
      case MarketplaceSortBy.topRated:
        list.sort((a, b) => (b.rating ?? 0).compareTo(a.rating ?? 0));
        break;
      case MarketplaceSortBy.name:
        list.sort((a, b) => a.name.compareTo(b.name));
        break;
    }
    return list;
  }

  static Future<MarketplaceAdsLoadResult> loadApprovedAds({
    required String diwaniyaId,
    required String placementScreen,
    int limit = 5,
  }) async {
    final response = await DiwaniyaApi.loadMarketplaceAds(
      diwaniyaId: diwaniyaId,
      placementScreen: placementScreen,
      limit: limit,
    );

    final rawAds = response['ads'];
    final ads = rawAds is List
        ? rawAds
            .whereType<Map>()
            .map((e) => MarketplaceAd.fromJson(Map<String, dynamic>.from(e)))
            .where((ad) => ad.isDisplayableForPlacement(placementScreen))
            .toList(growable: false)
        : <MarketplaceAd>[];

    return MarketplaceAdsLoadResult(
      ads: ads,
      placementScreen: (response['placement_screen'] as String?) ?? placementScreen,
      message: ads.isEmpty ? 'no_approved_ads' : null,
    );
  }

  static Future<MarketplaceLoadResult> loadBackendPlaces({
    required String diwaniyaId,
    String? category,
    String? cityId,
    String? districtId,
    double? radiusKm,
  }) async {
    final response = await DiwaniyaApi.searchMarketplacePlaces(
      diwaniyaId: diwaniyaId,
      category: category,
      cityId: cityId,
      districtId: districtId,
      radiusKm: radiusKm,
    );

    final placesRaw = response['places'];
    final cleanCategory = (response['category'] as String?)?.trim();
    final locationLabel = (response['location_label'] as String?)?.trim();
    final message = (response['message'] as String?)?.trim();
    final isConfigured = response['is_configured'] == true;

    final stores = placesRaw is List
        ? placesRaw
            .whereType<Map>()
            .map(
              (e) => _storeFromPlace(
                Map<String, dynamic>.from(e),
                fallbackCategory: cleanCategory,
                locationLabel: locationLabel,
              ),
            )
            .where((s) => s.id.trim().isNotEmpty && s.name.trim().isNotEmpty)
            .toList(growable: false)
        : const <Store>[];

    return MarketplaceLoadResult(
      stores: stores,
      isConfigured: isConfigured,
      message: message == null || message.isEmpty ? null : message,
      locationLabel:
          locationLabel == null || locationLabel.isEmpty ? null : locationLabel,
    );
  }

  static Store _storeFromPlace(
    Map<String, dynamic> json, {
    required String? fallbackCategory,
    required String? locationLabel,
  }) {
    final jsonCategory = (json['category'] as String?)?.trim();
    final category = jsonCategory != null && jsonCategory.isNotEmpty
        ? jsonCategory
        : (fallbackCategory != null && fallbackCategory.trim().isNotEmpty
            ? fallbackCategory.trim()
            : 'خدمات');

    final coords = _locationParts(locationLabel);
    final cityName = (json['city_name_ar'] as String?)?.trim();
    final districtName = (json['district_name_ar'] as String?)?.trim();
    final ratingRaw = json['rating'];
    final reviewRaw = json['user_rating_count'];
    final distanceRaw = json['distance_km'];
    final openRaw = json['is_open_now'];

    return Store(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      category: category,
      city: cityName != null && cityName.isNotEmpty ? cityName : coords.$2,
      district: districtName != null && districtName.isNotEmpty
          ? districtName
          : coords.$1,
      rating: ratingRaw is num ? ratingRaw.toDouble() : null,
      reviewCount: reviewRaw is num ? reviewRaw.toInt() : null,
      distanceKm: distanceRaw is num ? distanceRaw.toDouble() : null,
      isOpenNow: openRaw is bool ? openRaw : null,
      mapUrl: (json['map_url'] as String?)?.trim().isNotEmpty == true
          ? (json['map_url'] as String).trim()
          : null,
      description: (json['address'] ?? '').toString(),
      tags: <String>[
        category,
        if ((json['address'] as String?)?.trim().isNotEmpty == true)
          (json['address'] as String).trim(),
      ],
      icon: _iconForCategory(category),
    );
  }

  static Future<MarketplaceDiscoveryLoadResult> loadDiscovery({
    required String diwaniyaId,
    String? category,
    String? queryText,
    String? cityId,
    String? districtId,
    double? radiusKm,
    int limit = 20,
  }) async {
    final response = await DiwaniyaApi.loadMarketplaceDiscovery(
      diwaniyaId: diwaniyaId,
      category: category,
      queryText: queryText,
      cityId: cityId,
      districtId: districtId,
      radiusKm: radiusKm,
      limit: limit,
    );

    final context = response['context'] is Map
        ? Map<String, dynamic>.from(response['context'] as Map)
        : const <String, dynamic>{};
    final sectionsRaw = response['sections'];
    final seen = <String>{};
    final stores = <Store>[];
    if (sectionsRaw is List) {
      for (final section in sectionsRaw.whereType<Map>()) {
        final items = section['items'];
        if (items is! List) continue;
        for (final raw in items.whereType<Map>()) {
          final store = _storeFromDiscoveryItem(
            Map<String, dynamic>.from(raw),
            context: context,
          );
          if (store.id.trim().isEmpty || store.name.trim().isEmpty) continue;
          if (seen.add(store.id)) stores.add(store);
        }
      }
    }

    final adsRaw = response['ads'];
    final ads = adsRaw is List
        ? adsRaw
            .whereType<Map>()
            .map((item) => MarketplaceAd.fromJson(Map<String, dynamic>.from(item)))
            .where((ad) => ad.isDisplayableForPlacement('marketplace_top'))
            .toList(growable: false)
        : const <MarketplaceAd>[];

    final label = (context['label'] ?? '').toString().trim();
    final message = (response['message'] ?? '').toString().trim();
    return MarketplaceDiscoveryLoadResult(
      stores: stores,
      ads: ads,
      googleAttributionRequired: response['google_attribution_required'] == true,
      message: message.isEmpty ? null : message,
      locationLabel: label.isEmpty ? null : label,
    );
  }

  static Future<Store> loadStoreDetails({
    required String diwaniyaId,
    required Store store,
    String? cityId,
    String? districtId,
    double? radiusKm,
  }) async {
    final response = await DiwaniyaApi.loadMarketplaceStoreDetails(
      diwaniyaId: diwaniyaId,
      storeId: store.id,
      category: store.categoryKey,
      cityId: cityId,
      districtId: districtId,
      radiusKm: radiusKm,
    );
    return _storeFromDiscoveryItem(
      response,
      context: <String, dynamic>{
        'city_name': store.city,
        'district_name': store.district,
      },
      fallback: store,
    );
  }

  static Future<void> recordMarketplaceEvent({
    required String eventType,
    required Store store,
    String? diwaniyaId,
    String? cityId,
    String? districtId,
  }) async {
    await DiwaniyaApi.recordMarketplaceEvents([
      {
        'event_type': eventType,
        'source': store.isSponsored ? 'sponsored' : store.source,
        'item_id': store.id,
        'merchant_store_id': store.merchantStoreId,
        'merchant_ad_id': store.merchantAdId,
        'place_id': store.placeId,
        'category_key': store.categoryKey,
        'city_id': cityId,
        'district_id': districtId,
        'diwaniya_id': diwaniyaId,
        'session_id': _sessionId,
        'occurred_at': DateTime.now().toUtc().toIso8601String(),
      }
    ]);
  }

  static Future<void> recordMarketplaceAdEvent({
    required String eventType,
    required MarketplaceAd ad,
    String? diwaniyaId,
    String? categoryKey,
    String? cityId,
    String? districtId,
  }) async {
    await DiwaniyaApi.recordMarketplaceEvents([
      {
        'event_type': eventType,
        'source': 'sponsored',
        'item_id': ad.id,
        'merchant_store_id': ad.merchantStoreId,
        'merchant_ad_id': ad.id,
        'category_key': categoryKey ?? ad.targetCategory,
        'city_id': cityId,
        'district_id': districtId,
        'diwaniya_id': diwaniyaId,
        'session_id': _sessionId,
        'occurred_at': DateTime.now().toUtc().toIso8601String(),
      }
    ]);
  }

  static Future<void> recordMarketplaceCategoryView({
    required String categoryKey,
    String? diwaniyaId,
    String? cityId,
    String? districtId,
  }) async {
    await DiwaniyaApi.recordMarketplaceEvents([
      {
        'event_type': 'marketplace_category_view',
        'source': 'diwaniya_merchant',
        'item_id': categoryKey,
        'category_key': categoryKey,
        'city_id': cityId,
        'district_id': districtId,
        'diwaniya_id': diwaniyaId,
        'session_id': _sessionId,
        'occurred_at': DateTime.now().toUtc().toIso8601String(),
      }
    ]);
  }

  static void recordMarketplaceEventLater({
    required String eventType,
    required Store store,
    String? diwaniyaId,
    String? cityId,
    String? districtId,
  }) {
    unawaited(
      recordMarketplaceEvent(
        eventType: eventType,
        store: store,
        diwaniyaId: diwaniyaId,
        cityId: cityId,
        districtId: districtId,
      ).catchError((_) {}),
    );
  }

  static void recordMarketplaceAdEventLater({
    required String eventType,
    required MarketplaceAd ad,
    String? diwaniyaId,
    String? categoryKey,
    String? cityId,
    String? districtId,
  }) {
    unawaited(
      recordMarketplaceAdEvent(
        eventType: eventType,
        ad: ad,
        diwaniyaId: diwaniyaId,
        categoryKey: categoryKey,
        cityId: cityId,
        districtId: districtId,
      ).catchError((_) {}),
    );
  }

  static void recordMarketplaceCategoryViewLater({
    required String categoryKey,
    String? diwaniyaId,
    String? cityId,
    String? districtId,
  }) {
    unawaited(
      recordMarketplaceCategoryView(
        categoryKey: categoryKey,
        diwaniyaId: diwaniyaId,
        cityId: cityId,
        districtId: districtId,
      ).catchError((_) {}),
    );
  }

  static Store _storeFromDiscoveryItem(
    Map<String, dynamic> json, {
    required Map<String, dynamic> context,
    Store? fallback,
  }) {
    final categoryKey = (json['category_key'] as String?)?.trim();
    final category = marketplaceCategoryByKey(categoryKey);
    final label = (json['category_label'] as String?)?.trim();
    final ratingRaw = json['rating'];
    final reviewRaw = json['review_count'];
    final distanceRaw = json['distance_km'];
    final openRaw = json['is_open_now'];
    final source = (json['source'] ?? '').toString();
    final isSponsored = json['is_sponsored'] == true || source == 'sponsored';
    final isVerified = json['is_verified_merchant'] == true ||
        source == 'diwaniya_merchant';
    final openingHours = _stringList(json['opening_hours']);
    final products = _productPreviews(json['products']);

    return Store(
      id: (json['id'] ?? fallback?.id ?? '').toString(),
      name: (json['name'] ?? fallback?.name ?? '').toString(),
      category: label != null && label.isNotEmpty
          ? label
          : (category?.label ?? 'خدمات'),
      categoryKey: categoryKey ?? fallback?.categoryKey,
      city: (json['city_name'] ?? context['city_name'] ?? fallback?.city ?? '')
          .toString(),
      district: (json['district_name'] ??
              context['district_name'] ??
              fallback?.district ??
              '')
          .toString(),
      coverImage: (json['image_url'] as String?)?.trim().isNotEmpty == true
          ? (json['image_url'] as String).trim()
          : fallback?.coverImage,
      gallery: fallback?.gallery ?? const [],
      rating: ratingRaw is num ? ratingRaw.toDouble() : fallback?.rating,
      reviewCount: reviewRaw is num ? reviewRaw.toInt() : fallback?.reviewCount,
      distanceKm:
          distanceRaw is num ? distanceRaw.toDouble() : fallback?.distanceKm,
      isOpenNow: openRaw is bool ? openRaw : fallback?.isOpenNow,
      isFeatured: fallback?.isFeatured ?? false,
      isSponsored: isSponsored,
      isVerifiedMerchant: isVerified,
      source: source.isEmpty ? 'diwaniya_merchant' : source,
      attributionLabel:
          _cleanText(json['attribution_label']) ?? fallback?.attributionLabel,
      placeId: _cleanText(json['place_id']) ?? fallback?.placeId,
      merchantStoreId:
          _cleanText(json['merchant_store_id']) ?? fallback?.merchantStoreId,
      merchantAdId: _cleanText(json['merchant_ad_id']) ?? fallback?.merchantAdId,
      phone: _cleanText(json['phone']) ?? fallback?.phone,
      whatsapp: _cleanText(json['whatsapp']) ?? fallback?.whatsapp,
      mapUrl: _cleanText(json['google_maps_url']) ?? fallback?.mapUrl,
      directionsUrl: _cleanText(json['directions_url']) ?? fallback?.directionsUrl,
      website: _cleanText(json['website']) ?? fallback?.website,
      openingHours:
          openingHours.isNotEmpty ? openingHours : (fallback?.openingHours ?? const []),
      attribution: _cleanText(json['attribution']) ?? fallback?.attribution,
      products: products.isNotEmpty ? products : (fallback?.products ?? const []),
      description: (json['address'] ?? fallback?.description ?? '').toString(),
      tags: <String>[
        if (categoryKey != null && categoryKey.isNotEmpty) categoryKey,
        if (label != null && label.isNotEmpty) label,
        if ((json['address'] as String?)?.trim().isNotEmpty == true)
          (json['address'] as String).trim(),
      ],
      icon: category?.icon ?? _iconForCategory(label ?? ''),
    );
  }

  static String? _cleanText(dynamic value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return null;
    return text;
  }

  static List<String> _stringList(dynamic value) {
    if (value is! List) return const <String>[];
    return value
        .map((item) => item?.toString().trim() ?? '')
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  static List<StoreProductPreview> _productPreviews(dynamic value) {
    if (value is! List) return const <StoreProductPreview>[];
    return value.whereType<Map>().map((raw) {
      final item = Map<String, dynamic>.from(raw);
      final price = item['price'];
      return StoreProductPreview(
        id: (item['id'] ?? '').toString(),
        name: (item['name'] ?? '').toString(),
        category: _cleanText(item['category']),
        description: _cleanText(item['description']),
        price: price is num ? price.toDouble() : null,
        currency: _cleanText(item['currency']),
        imageUrl: _cleanText(item['image_url']),
      );
    }).where((item) {
      return item.id.trim().isNotEmpty && item.name.trim().isNotEmpty;
    }).toList(growable: false);
  }

  static (String, String) _locationParts(String? locationLabel) {
    final clean = locationLabel?.trim();
    if (clean == null || clean.isEmpty) return ('', '');

    final parts = clean
        .replaceAll('Â·', '·')
        .split('·')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    if (parts.length >= 2) return (parts.first, parts.last);
    return ('', clean);
  }

  static IconData _iconForCategory(String category) {
    switch (category) {
      case 'بقالة':
        return Icons.shopping_basket_rounded;
      case 'شاهي وقهوة':
        return Icons.coffee_rounded;
      case 'حلا':
        return Icons.cake_rounded;
      case 'معسلات':
        return Icons.whatshot_rounded;
      case 'صيانة':
        return Icons.build_rounded;
      case 'خدمات نظافة':
        return Icons.cleaning_services_rounded;
      default:
        return Icons.storefront_rounded;
    }
  }

  static double _sortNullableDistance(Store store) =>
      store.distanceKm ?? 1000000;

  static Store? getStoreById(String id) {
    for (final store in _source) {
      if (store.id == id) return store;
    }
    return null;
  }

  static bool get hasLiveData => _source.isNotEmpty;
}
