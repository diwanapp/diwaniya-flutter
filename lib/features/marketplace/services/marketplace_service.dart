import '../data/marketplace_mock_data.dart';
import '../models/marketplace_filter_model.dart';
import '../models/store_model.dart';

typedef MarketplaceSourceResolver = List<Store> Function();

class MarketplaceService {
  MarketplaceService._();

  static MarketplaceSourceResolver? _overrideResolver;

  /// Production-safe default:
  /// marketplace remains available in the UI, but no mock merchants are shown
  /// unless a real resolver is configured or mock mode is explicitly enabled.
  static bool enableMockData = false;

  static void configureResolver(MarketplaceSourceResolver? resolver) {
    _overrideResolver = resolver;
  }

  static List<Store> get _source {
    final override = _overrideResolver;
    if (override != null) {
      return List<Store>.from(override());
    }
    if (enableMockData) {
      return List<Store>.from(mockStores);
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

  static Store? getStoreById(String id) {
    for (final store in _source) {
      if (store.id == id) return store;
    }
    return null;
  }

  static bool get hasLiveData => _source.isNotEmpty;
}
