class MarketplaceAd {
  const MarketplaceAd({
    required this.id,
    required this.merchantStoreId,
    required this.title,
    required this.placementScreen,
    required this.placementPriority,
    this.storeName,
    this.description,
    this.targetCategory,
    this.imageUrl,
    this.placementSlot,
    this.placementStartsAt,
    this.placementEndsAt,
    this.source = 'merchant_ads',
  });

  final String id;
  final String merchantStoreId;
  final String? storeName;
  final String title;
  final String? description;
  final String? targetCategory;
  final String? imageUrl;
  final String placementScreen;
  final String? placementSlot;
  final int placementPriority;
  final DateTime? placementStartsAt;
  final DateTime? placementEndsAt;
  final String source;

  factory MarketplaceAd.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      final text = value.toString().trim();
      if (text.isEmpty) return null;
      return DateTime.tryParse(text);
    }

    return MarketplaceAd(
      id: (json['id'] ?? '').toString(),
      merchantStoreId: (json['merchant_store_id'] ?? '').toString(),
      storeName: (json['store_name'] as String?)?.trim(),
      title: (json['title'] ?? '').toString(),
      description: (json['description'] as String?)?.trim(),
      targetCategory: (json['target_category'] as String?)?.trim(),
      imageUrl: (json['image_url'] as String?)?.trim(),
      placementScreen: (json['placement_screen'] ?? '').toString(),
      placementSlot: (json['placement_slot'] as String?)?.trim(),
      placementPriority: (json['placement_priority'] as num?)?.toInt() ?? 100,
      placementStartsAt: parseDate(json['placement_starts_at']),
      placementEndsAt: parseDate(json['placement_ends_at']),
      source: (json['source'] ?? 'merchant_ads').toString(),
    );
  }
}
