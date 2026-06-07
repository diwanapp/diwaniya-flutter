class GeoCity {
  final String id;
  final String nameAr;
  final String? nameEn;
  final double? lat;
  final double? lng;

  const GeoCity({
    required this.id,
    required this.nameAr,
    this.nameEn,
    this.lat,
    this.lng,
  });

  factory GeoCity.fromJson(Map<String, dynamic> json) {
    return GeoCity(
      id: (json['id'] ?? '').toString(),
      nameAr: (json['name_ar'] ?? '').toString(),
      nameEn: json['name_en']?.toString(),
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble(),
    );
  }
}

class GeoDistrict {
  final String id;
  final String cityId;
  final String nameAr;
  final String? nameEn;
  final double? lat;
  final double? lng;

  const GeoDistrict({
    required this.id,
    required this.cityId,
    required this.nameAr,
    this.nameEn,
    this.lat,
    this.lng,
  });

  factory GeoDistrict.fromJson(Map<String, dynamic> json) {
    return GeoDistrict(
      id: (json['id'] ?? '').toString(),
      cityId: (json['city_id'] ?? '').toString(),
      nameAr: (json['name_ar'] ?? '').toString(),
      nameEn: json['name_en']?.toString(),
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble(),
    );
  }
}

class DiwaniyaLocation {
  final String id;
  final String? city;
  final String? cityId;
  final String? cityNameAr;
  final String? districtId;
  final String? districtNameAr;
  final double? locationLat;
  final double? locationLng;
  final String? locationSource;

  const DiwaniyaLocation({
    required this.id,
    this.city,
    this.cityId,
    this.cityNameAr,
    this.districtId,
    this.districtNameAr,
    this.locationLat,
    this.locationLng,
    this.locationSource,
  });

  factory DiwaniyaLocation.fromJson(Map<String, dynamic> json) {
    return DiwaniyaLocation(
      id: (json['id'] ?? '').toString(),
      city: json['city']?.toString(),
      cityId: json['city_id']?.toString(),
      cityNameAr: json['city_name_ar']?.toString(),
      districtId: json['district_id']?.toString(),
      districtNameAr: json['district_name_ar']?.toString(),
      locationLat: (json['location_lat'] as num?)?.toDouble(),
      locationLng: (json['location_lng'] as num?)?.toDouble(),
      locationSource: json['location_source']?.toString(),
    );
  }
}
