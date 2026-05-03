enum MarketplaceSortBy { nearest, topRated, name }

class MarketplaceFilter {
  final String query;
  final String? selectedCategory;
  final bool onlyOpenNow;
  final bool onlyFeatured;
  final MarketplaceSortBy sortBy;

  const MarketplaceFilter({
    this.query = '',
    this.selectedCategory,
    this.onlyOpenNow = false,
    this.onlyFeatured = false,
    this.sortBy = MarketplaceSortBy.nearest,
  });

  MarketplaceFilter copyWith({
    String? query,
    String? Function()? selectedCategory,
    bool? onlyOpenNow,
    bool? onlyFeatured,
    MarketplaceSortBy? sortBy,
  }) {
    return MarketplaceFilter(
      query: query ?? this.query,
      selectedCategory: selectedCategory != null ? selectedCategory() : this.selectedCategory,
      onlyOpenNow: onlyOpenNow ?? this.onlyOpenNow,
      onlyFeatured: onlyFeatured ?? this.onlyFeatured,
      sortBy: sortBy ?? this.sortBy,
    );
  }

  bool get isActive => query.isNotEmpty || selectedCategory != null || onlyOpenNow || onlyFeatured;
}
