import 'package:flutter/material.dart';
import '../../../core/api/diwaniya_api.dart';
import '../models/marketplace_filter_model.dart';
import '../models/marketplace_ad_model.dart';
import '../models/store_model.dart';

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

class MarketplaceService {
  MarketplaceService._();

  static MarketplaceSourceResolver? _overrideResolver;

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
      ..sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
    return sorted.take(limit).toList();
  }

  static List<Store> getTopRatedStores({int limit = 6}) {
    final sorted = List<Store>.from(_source)
      ..sort((a, b) => b.rating.compareTo(a.rating));
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
      list = list.where((s) => s.category == filter.selectedCategory).toList();
    }
    if (filter.onlyOpenNow) {
      list = list.where((s) => s.isOpenNow).toList();
    }
    if (filter.onlyFeatured) {
      list = list.where((s) => s.isFeatured || s.isSponsored).toList();
    }

    switch (filter.sortBy) {
      case MarketplaceSortBy.nearest:
        list.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
        break;
      case MarketplaceSortBy.topRated:
        list.sort((a, b) => b.rating.compareTo(a.rating));
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
      rating: ratingRaw is num ? ratingRaw.toDouble() : 0,
      reviewCount: reviewRaw is num ? reviewRaw.toInt() : 0,
      distanceKm: distanceRaw is num ? distanceRaw.toDouble() : 0,
      isOpenNow: openRaw == true,
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

  static Store? getStoreById(String id) {
    for (final store in _source) {
      if (store.id == id) return store;
    }
    return null;
  }

  static bool get hasLiveData => _source.isNotEmpty;
}
