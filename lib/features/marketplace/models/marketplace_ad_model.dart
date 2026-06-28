class MarketplaceAd {
  const MarketplaceAd({
    required this.id,
    this.merchantStoreId,
    this.title,
    this.placementScreen,
    this.placementPriority = 100,
    this.storeName,
    this.storeCityNameAr,
    this.storeDistrictNameAr,
    this.storePhone,
    this.storeWhatsapp,
    this.storeGoogleMapsUrl,
    this.description,
    this.targetCategory,
    this.targetCity,
    this.targetCityId,
    this.targetCityNameAr,
    this.targetDistrictId,
    this.targetDistrictNameAr,
    this.targetDistrictNamesAr,
    this.targetDistricts,
    this.contactWhatsapp,
    this.contactUrl,
    this.mapUrl,
    this.imageUrl,
    this.placementSlot,
    this.placementStartsAt,
    this.placementEndsAt,
    this.source = 'merchant_ads',
  });

  final String id;
  final String? merchantStoreId;
  final String? storeName;
  final String? storeCityNameAr;
  final String? storeDistrictNameAr;
  final String? storePhone;
  final String? storeWhatsapp;
  final String? storeGoogleMapsUrl;
  final String? title;
  final String? description;
  final String? targetCategory;
  final String? targetCity;
  final String? targetCityId;
  final String? targetCityNameAr;
  final String? targetDistrictId;
  final String? targetDistrictNameAr;
  final List<String>? targetDistrictNamesAr;
  final List<String>? targetDistricts;
  final String? contactWhatsapp;
  final String? contactUrl;
  final String? mapUrl;
  final String? imageUrl;
  final String? placementScreen;
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

    List<String>? parseStringList(dynamic value) {
      if (value is! List) return null;
      final items = value
          .map((e) => e?.toString().trim() ?? '')
          .where((e) => e.isNotEmpty)
          .toList(growable: false);
      return items.isEmpty ? null : items;
    }

    return MarketplaceAd(
      id: (json['id'] ?? '').toString(),
      merchantStoreId: ((json['merchant_store_id'] ?? json['store_id']) as String?)?.trim(),
      storeName: ((json['store_name'] ?? json['merchant_name']) as String?)?.trim(),
      storeCityNameAr: (json['store_city_name_ar'] as String?)?.trim(),
      storeDistrictNameAr: (json['store_district_name_ar'] as String?)?.trim(),
      storePhone: (json['store_phone'] as String?)?.trim(),
      storeWhatsapp: (json['store_whatsapp'] as String?)?.trim(),
      storeGoogleMapsUrl: (json['store_google_maps_url'] as String?)?.trim(),
      title: (json['title'] as String?)?.trim(),
      description: (json['description'] as String?)?.trim(),
      targetCategory: (json['target_category'] as String?)?.trim(),
      targetCity: (json['target_city'] as String?)?.trim(),
      targetCityId: (json['target_city_id'] as String?)?.trim(),
      targetCityNameAr: (json['target_city_name_ar'] as String?)?.trim(),
      targetDistrictId: (json['target_district_id'] as String?)?.trim(),
      targetDistrictNameAr: (json['target_district_name_ar'] as String?)?.trim(),
      targetDistrictNamesAr: parseStringList(json['target_district_names_ar']),
      targetDistricts: parseStringList(json['target_districts']),
      contactWhatsapp: (json['contact_whatsapp'] as String?)?.trim(),
      contactUrl: ((json['contact_url'] ?? json['target_url']) as String?)?.trim(),
      mapUrl: (json['map_url'] as String?)?.trim(),
      imageUrl: (json['image_url'] as String?)?.trim(),
      placementScreen: ((json['placement_screen'] ?? json['placement']) as String?)?.trim(),
      placementSlot: (json['placement_slot'] as String?)?.trim(),
      placementPriority: (json['placement_priority'] as num?)?.toInt() ?? 100,
      placementStartsAt: parseDate(json['placement_starts_at']),
      placementEndsAt: parseDate(json['placement_ends_at']),
      source: (json['source'] ?? 'merchant_ads').toString(),
    );
  }

  bool isDisplayableForPlacement(String placement) {
    final image = imageUrl?.trim();
    if (image == null || image.isEmpty) return false;

    final returnedPlacement = placementScreen?.trim();
    if (returnedPlacement == null || returnedPlacement.isEmpty) return false;
    return returnedPlacement == placement ||
        (placement == 'marketplace' && returnedPlacement == 'marketplace_top') ||
        (placement == 'marketplace_top' && returnedPlacement == 'marketplace');
  }
}
